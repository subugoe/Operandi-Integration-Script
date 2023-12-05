#!/bin/bash

# Set the OCRD_DOWNLOAD_RETRIES environment variable
export OCRD_DOWNLOAD_RETRIES=3

# Default values
WORKSPACE_DIR=$(pwd)
EXISTING_METS=false
SERVER_ADDR="http://operandi.ocr-d.de" 
FILE_GROUP="DEFAULT"
WORKFLOW=""
METS_URL=""
OPERANDI_USER_PASS="" 
IMAGE_DIR=$(pwd)/images
EXT="jpg"
CPUs=4
RAM=8
ZIP=""
workflow_id="3515bd6c-3c79-41a4-9890-fb8bfd479162"
OLA=""
LOCAL_OCRD=false
CURRENT_TIME=`date +"%m%d%Y_%H%M%S"`
FORKS=1
OCRD_RESULTS=""
PAGES=1


#Get the options
while getopts ":s:f:m:u:w:i:x:c:r:n:elz:o:" opt; do
    case $opt in
        s) SERVER_ADDR="$OPTARG" ;;
        f) FILE_GROUP="$OPTARG" ;;
        m) METS_URL="$OPTARG" ;;
        u) OPERANDI_USER_PASS="$OPTARG" ;;
        w) WORKSPACE_DIR="$OPTARG" ;;
        x) EXT="$OPTARG" ;;
        e) EXISTING_METS=true ;;
        i) IMAGE_DIR="$OPTARG" ;;
        c) CPUs="$OPTARG" ;;
        r) RAM="$OPTARG" ;;
        n) WORKFLOW="$OPTARG" ;;
        z) ZIP="$OPTARG" ;;
        o) OLA="$OPTARG" ;;
        l) LOCAL_OCRD=true ;;
        \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
        :) echo "Option -$OPTARG requires an argument." >&2; exit 1 ;;
    esac
done

check_required_flags() {
    # Check if -e was set and at least mets URL or file was given
    if [ "$EXISTING_METS" == true ] && [ -z "$METS_URL" ] && [ ! -e "$WORKSPACE_DIR/mets.xml" ]; then
        echo "Error: -e was set, but METS_URL is missing or WORKSPACE_DIR does not contain mets.xml."
        exit 1
    fi

    # Check if OPERANDI_USER_PASS is missing
    if [ -z "$OPERANDI_USER_PASS" ] && [ "$LOCAL_OCRD" == false ]; then
        echo "Error: OPERANDI user:password  is missing."
        exit 1
    fi

}

# Function to create workspace directory and clone mets file from url
clone_mets() {
    echo "Cloning mets from URL..."
    if [ -n "$METS_URL" ]; then
        mkdir -p "$WORKSPACE_DIR"
        ocrd workspace -d $WORKSPACE_DIR clone "$METS_URL"
        if [ $? -ne 0 ]; then
            echo "Failed to create the workspace from METS."
            exit 1
        fi
    fi
}

# Function to create a workspace without METS
create_workspace_without_mets() {
    echo "Creating a workspace without mets..."
    ocrd workspace -d $WORKSPACE_DIR init
    ocrd workspace -d $WORKSPACE_DIR set-id 'unique ID'
    mkdir -p $WORKSPACE_DIR/images
    cp -r $IMAGE_DIR/* $WORKSPACE_DIR/images
    MEDIATYPE="image/$EXT"  # the actual MIME type of the images
    cd $WORKSPACE_DIR

    for path in images/*.$EXT; do
        base=`basename $path $EXT`;
        ocrd workspace add -G $FILE_GROUP -i ${FILE_GROUP}_${base} -g P_$base -m $MEDIATYPE $path
    done
    cd ->/dev/null
    if [ $? -ne 0 ]; then
        echo "Failed to create the workspace."
        exit 1
    fi
   
}

# Function to create workspace based on the flag
create_workspace() {
    if [ "$EXISTING_METS" == true ]; then
        clone_mets
        download_file_group
    else
        create_workspace_without_mets
    fi
}

# Function to download selected file group
download_file_group() {
    if [ -n "$FILE_GROUP" ]; then
        echo "Downloading the selected file group: $FILE_GROUP..."
	    ocrd workspace -d "$WORKSPACE_DIR" find --file-grp "$FILE_GROUP" --download
    fi
}

# Function to generate OCR-D zip
generate_ocrd_zip() {
    echo "Generating an OCR-D zip..."
    ocrd zip bag -i "$WORKSPACE_DIR" -d "$WORKSPACE_DIR"

    if [ $? -ne 0 ]; then
        echo "Failed to generate the OCR-D zip."
        exit 1
    fi
}

# Function to validate OCR-D zip
validate_ocrd_zip() {
    echo "Validating the OCR-D zip..."
    ocrd zip validate "$WORKSPACE_DIR".ocrd.zip
    if [ $? -ne 0 ]; then
        echo "Validation failed. The OCR-D zip is not valid."
        exit 1
    fi
}

# Function to upload OCR-D zip to Operandi
upload_ocrd_zip() {
    echo "Uploading the OCR-D zip to $SERVER_ADDR..."
    json_data=$(curl -X POST "$SERVER_ADDR/workspace" -H "Content-Type: multipart/form-data" -F "workspace=@$WORKSPACE_DIR".ocrd.zip -u "$OPERANDI_USER_PASS")
    echo $json_data
    if [ $? -ne 0 ]; then
        echo "Failed to upload the OCR-D zip."
        exit 1
    fi
    workspace_id=$(echo "$json_data" | grep -o '"resource_id":"[^"]*' | cut -d '"' -f 4)
    echo "Extracted workspace_id: $workspace_id"
}

# Function to get one workflow ID from Operandi
extract_workflow_id() {
    json_data=$(curl -X GET "$SERVER_ADDR/workflow" -u "$OPERANDI_USER_PASS")
    workflow_id=$(echo "$json_data" | grep -o '"resource_id":"[^"]*' | cut -d '"' -f 4 | head -n 1)
    echo "Extracted workflow ID: $workflow_id"
}

# Function to upload a new nextflow workflow
upload_workflow() {
    json_data=$(curl -X POST "$SERVER_ADDR/workflow" -F nextflow_script=@$WORKFLOW -u "$OPERANDI_USER_PASS")
    workflow_id=$(echo "$json_data" | grep -o '"resource_id":"[^"]*' | cut -d '"' -f 4)
    echo "Uploaded Workflow ID: $workflow_id"
}

# Function to submit a job
submit_job() {
    url="$SERVER_ADDR/workflow/$workflow_id"
    echo "The upload URL is: $url"
    json_data=$(curl -X POST "$url" -u "$OPERANDI_USER_PASS" -H "Content-Type: application/json" -d '{ "workflow_args": { "workspace_id": "'"$workspace_id"'", "input_file_grp": "'"$FILE_GROUP"'", "mets_name": "mets.xml" }, "sbatch_args": { "cpus": "'"$CPUs"'", "ram": "'"$RAM"'"} }')
    job_id=$(echo "$json_data" | grep -o '"resource_id":"[^"]*' | cut -d '"' -f 4 | head -n 1)
}

# Function to use local ocrd
process_with_local_ocrd() {

    if [[ $WORKSPACE_DIR != *$(pwd)* ]]; then
        WORKSPACE_DIR_LOCAL=$(pwd)/"$WORKSPACE_DIR"_local/data
    else
        WORKSPACE_DIR_LOCAL="$WORKSPACE_DIR"_local/data
    fi

    METS_SERVER_LOG="${WORKSPACE_DIR_LOCAL}/mets_server.log"
    SOCKET_PATH="${WORKSPACE_DIR_LOCAL}/mets_server.sock"
    unzip "$WORKSPACE_DIR".ocrd.zip -d "$WORKSPACE_DIR"_local
    PAGES=$(find "$WORKSPACE_DIR_LOCAL/$FILE_GROUP" -type f | wc -l)
    ocrd workspace -U "${SOCKET_PATH}" -d "${WORKSPACE_DIR_LOCAL}" server start > "${METS_SERVER_LOG}" 2>&1 &

    # Execute the Nextflow script
    nextflow run "${WORKFLOW}" \
    -ansi-log false \
    -with-report "report-${CPUs}-${RAM}-${FORKS}-${CURRENT_TIME}.html" \
    --input_file_group "${FILE_GROUP}" \
    --mets "${WORKSPACE_DIR_LOCAL}/mets.xml" \
    --mets_socket "${SOCKET_PATH}" \
    --workspace_dir "${WORKSPACE_DIR_LOCAL}" \
    --singularity_wrapper " " \
    --pages "${PAGES}" \
    --cpus "${CPUs}" \
    --ram "${RAM}" \
    --forks "${FORKS}"
    # Stop the mets server started above
    ocrd workspace -U "${SOCKET_PATH}" -d "${WORKSPACE_DIR_LOCAL}" server stop
    ocrd zip bag -i "$WORKSPACE_DIR_LOCAL" -d "$WORKSPACE_DIR_LOCAL"
    OCRD_RESULTS="$WORKSPACE_DIR_LOCAL".ocrd.zip
}


# Function to download results
download_results() {
    echo "Downloading the results..."
    curl -X GET "$SERVER_ADDR/workspace/$workspace_id" -u "$OPERANDI_USER_PASS" -H "accept: application/vnd.ocrd+zip" -o "$OCRD_RESULTS"
    if [ $? -ne 0 ]; then
        echo "Failed to download the results."
        exit 1
    fi
    echo "Results are available now"
}

# Function to download results
upload_to_ola_hd() {
    echo "Uploading the results to OLA-HD..."
    curl -X POST 141.5.99.53/api/bag -u "$OLA" -H 'content-type: multipart/form-data' -F file=@"$OCRD_RESULTS"
    if [ $? -ne 0 ]; then
        echo "Failed to download the results."
        exit 1
    fi
}

# Function to check workflow status and download results
check_workflow_status() {
    while true; do
        # Sleep for a while before checking again
	sleep 30

	url="$SERVER_ADDR/workflow/$workflow_id/$job_id"
        echo "the url is: $url"
        json_data=$(curl -X GET "$url" -u "$OPERANDI_USER_PASS")

        # Extract the current job state
        job_state=$(grep -o '"job_state":"[^"]*' <<< "$json_data" | cut -d '"' -f 4)
        echo "Current Job State: $job_state"

	if [ "$job_state" == "SUCCESS" ]; then
        echo "Job completed successfully."
        download_results
        break
    fi

	if [ "$job_state" == "FAILED" ]; then
        echo "Job failed"
        break
    fi
    done
}


# Main script
main() {
    #remove the / from the end of server address
    SERVER_ADDR="${SERVER_ADDR%/}"
    OCRD_RESULTS="$WORKSPACE_DIR"_results.zip

    check_required_flags
    #check if the zip is already given or not    
    if [ -z "$ZIP" ]; then
        create_workspace
        generate_ocrd_zip
        validate_ocrd_zip
    else
        WORKSPACE_DIR="${ZIP%.ocrd.zip}"
    fi

    if [ "$LOCAL_OCRD" == true ]; then
        process_with_local_ocrd
    else
        upload_ocrd_zip
        if [ ! -z "$WORKFLOW" ]; then
            upload_workflow
        fi
        submit_job
        check_workflow_status
    fi
    if [ ! -z "$OLA" ]; then
        echo "Uploading to OLA-HD..."
        upload_to_ola_hd
    fi
}

main

