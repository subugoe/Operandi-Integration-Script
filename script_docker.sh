#!/bin/bash
# Get the path of the script
SCRIPT_PATH="$(dirname "$(realpath "$0")")"

# Change the current working directory to the script path
cd "$SCRIPT_PATH"

# Email settings
SMTP_SERVER="smtp://email.gwdg.de:587"
SENDER_EMAIL="ocrdimpl@sub.uni-goettingen.de"
SENDER_PASSWORD=""
AUTH_USER="ocrdimpl"
RECIPIENT_EMAIL=""



# Set the OCRD_DOWNLOAD_RETRIES environment variable
export OCRD_DOWNLOAD_RETRIES=3

# Default values
EXISTING_METS=false
SERVER_ADDR="http://operandi.ocr-d.de" 
FILE_GROUP="DEFAULT"
WORKFLOW="default_workflow.nf"
METS_URL=""
IMAGE_DIR=$(pwd)/images
EXT="jpg"
CPUs=8
RAM=64
ZIP=""
workflow_id="default_workflow"
LOCAL_OCRD=false
CURRENT_TIME=`date +"%m%d%Y_%H%M%S"`
WORKSPACE_DIR="ws_$CURRENT_TIME"
FORKS=1
OCRD_RESULTS=""
OCRD_RESULTS_LOGS=""
PAGES=1
ERROR_LOG="error_log.txt"
LOG_FILE="log_file.txt"
OLA=false
CLEAN_RESULTS=false
OLA_HD_SERVER="141.5.99.53"

UNCOMPLETED_STEP=false
DOCKER_RAPPER=""
PARENT_WORKSPACE="" 
PROCESS_TITLE=""
UPLOAD_WF=false
LAREX_VIEW=false

#Get the options
while getopts ":s:f:m:u:w:i:c:r:n:elz:o:" opt; do
    case $opt in
        s) SERVER_ADDR="$OPTARG" ;;
        f) FILE_GROUP="$OPTARG" ;;
        m) METS_URL="$OPTARG" ;;
        u) OPERANDI_USER_PASS="$OPTARG" ;;
        w) WORKSPACE_DIR="$OPTARG" ;;
        e) EXISTING_METS=true ;;
        i) IMAGE_DIR="$OPTARG" ;;
        c) CPUs="$OPTARG" ;;
        v) LAREX_VIEW=false ;;
        r) RAM="$OPTARG" ;;
        n) WORKFLOW="$OPTARG" 
        UPLOAD_WF=true;;
        z) ZIP="$OPTARG" ;;
        o) OLA_USR="$OPTARG"
	   OLA=true;;
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

# Function to send log file content by email using mail
send_log_by_email() {
    mail -s "$WORKSPACE_DIR - Logs" "$RECIPIENT_EMAIL" < "$LOG_FILE"
}

# Function to send log file content by email using curl
send_log_by_email2() {
    # Check if the log file exists
    if [ -f "$LOG_FILE" ]; then
        # Prepare email content in mail.txt format
        echo "From: \"Operandi Logs\" <$SENDER_EMAIL>" > mail.txt
        echo "To: \"Operandi User\" <$RECIPIENT_EMAIL>" >> mail.txt
        echo "Subject: $WORKSPACE_DIR - Logs" >> mail.txt
        echo "" >> mail.txt
        cat "$LOG_FILE" >> mail.txt

        # Use curl to send the email
        curl    --ssl-reqd \
                --url "$SMTP_SERVER" \
                --user "$AUTH_USER:$SENDER_PASSWORD" \
                --mail-from "$SENDER_EMAIL" \
                --mail-rcpt "$RECIPIENT_EMAIL" \
                --upload-file mail.txt

        # Clean up the temporary mail.txt file
        rm mail.txt
    else
        echo "Log file not found: $LOG_FILE"
    fi
}

# Function to log errors and information with timestamp and workspace name
log_info() {
    local log_message="$1"
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - Workspace: $WORKSPACE_DIR - $log_message"
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - Workspace: $WORKSPACE_DIR - $log_message" >> "$LOG_FILE"
}

# Function to log errors with timestamp and workspace name
log_error() {
    local error_message="$1"
    rm -r $SCRIPT_PATH/work
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - Workspace: $WORKSPACE_DIR - $error_message" >> "$ERROR_LOG"
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - Workspace: $WORKSPACE_DIR - $error_message" >> "$LOG_FILE"
    if [ -n "$RECIPIENT_EMAIL" ]; then
        echo "Sending log by email to $RECIPIENT_EMAIL..."
        send_log_by_email
    fi
}

# Function to check if a step has completed
check_step_completion() {
    local step_name="$1"
    local completion_flag="$WORKSPACE_DIR/.${step_name}_completed"

    local step_dir="$WORKSPACE_DIR/.${step_name}_snapshot"
    if [ -d "$step_dir" ]; then
        # Source relevant parameters from the directory using specific filenames
        workflow_id=$(<"$step_dir/workflow_id")
        job_id=$(<"$step_dir/job_id")
        workspace_id=$(<"$step_dir/workspace_id")
    fi

    if [ -f "$completion_flag" ] && [ "$UNCOMPLETED_STEP" == false ]; then
        log_info "Skipping $step_name as it has already been completed."
        return 0  # Step already completed
    else
        log_info "Resuming $step_name..."
        UNCOMPLETED_STEP=true
        return 1  # Step needs to be executed
    fi
}


# Function to mark a step as completed
mark_step_completed() {
    local step_name="$1"
    local completion_flag="$WORKSPACE_DIR/.${step_name}_completed"
    touch "$completion_flag"

    # Create a directory for the step
    local step_dir="$WORKSPACE_DIR/.${step_name}_snapshot"
    mkdir -p "$step_dir"

    # Store relevant parameters as files in the directory
    echo "$workflow_id" > "$step_dir/workflow_id"
    echo "$job_id" > "$step_dir/job_id"
    echo "$workspace_id" > "$step_dir/workspace_id"
}


extract_extension() {
    # Check if the directory exists
    if [ ! -d "$IMAGE_DIR" ]; then
        log_error "Directory $IMAGE_DIR does not exist."
        exit 1
    fi
    # Get the first file in the directory
    first_file=$(find "$IMAGE_DIR" -maxdepth 1 -type f | head -n 1)

    # Check if there are any files in the directory
    if [ -z "$first_file" ]; then
        log_error "No files found in $IMAGE_DIR."
        exit 1
    fi
    EXT="${first_file##*.}"
}

# Function to create workspace directory and clone mets file from url
clone_mets() {
    echo "Cloning mets from URL..."
    log_info "Cloning mets from URL..."
    if [ -n "$METS_URL" ]; then
        mkdir -p "$WORKSPACE_DIR"
        $DOCKER_RAPPER ocrd workspace -d "/data/$PROCESS_TITLE" clone "$METS_URL"
        if [ $? -ne 0 ]; then
            log_error "Failed to create the workspace from METS."
            exit 1
        fi
    fi
}

submit_mets_url() {
    mkdir -p "$WORKSPACE_DIR"
    log_info "Submitting METS URL: $METS_URL..."
    json_data=$(curl -X POST "$SERVER_ADDR/import_external_workspace?mets_url=$METS_URL&preserve_file_grps=$FILE_GROUP&mets_basename=meta.xml" -u "$OPERANDI_USER_PASS")
    if [ $? -ne 0 ]; then
        log_error "Failed to import the workspace from METS URL."
        exit 1
    fi
    echo "$json_data"
    workspace_id=$(echo "$json_data" | grep -o '"resource_id":"[^"]*' | cut -d '"' -f 4)
    echo "Extracted workspace_id: $workspace_id"
    if [ -z "$workspace_id" ] ; then
       log_error "workspace_id is empty. Response: $json_data"
       exit 1
    fi
}


# Function to create a workspace without METS
create_workspace_without_mets() {
    echo "Creating a workspace without mets..."
    extract_extension
    mkdir -p $WORKSPACE_DIR/images
    cp -r $IMAGE_DIR/* $WORKSPACE_DIR/images
    MEDIATYPE="image/$EXT"  # the actual MIME type of the images
    cd $WORKSPACE_DIR 
    $DOCKER_RAPPER ocrd workspace -d "/data/$PROCESS_TITLE" init
    $DOCKER_RAPPER ocrd workspace -d "/data/$PROCESS_TITLE" set-id 'unique ID'
    for path in images/*.$EXT; do
        base=`basename $path .$EXT`;
        $DOCKER_RAPPER ocrd workspace -d "/data/$PROCESS_TITLE" add -G $FILE_GROUP -i ${FILE_GROUP}_${base} -g P_$base -m $MEDIATYPE $path
    done
 
    cd ->/dev/null
    if [ $? -ne 0 ]; then
        log_error "Failed to create workspace without mets."
        exit 1
    fi
   
}

# Function to create workspace based on the flag
create_workspace() {
    if [ "$EXISTING_METS" == true ]; then
        if [ "$LOCAL_OCRD" != true ] ; then
            submit_mets_url
        fi
    else
        create_workspace_without_mets
    fi

    if [ $? -ne 0 ]; then
    log_error "Failed to create workspace."
    exit 1
    fi

}

# Function to download selected file group
download_file_group() {
    if [ -n "$FILE_GROUP" ]; then
        echo "Downloading the selected file group: $FILE_GROUP..."
	    $DOCKER_RAPPER ocrd workspace -d "/data/$PROCESS_TITLE" find --file-grp "$FILE_GROUP" --download
    fi
    if [ $? -ne 0 ]; then
        log_error "Failed to download file group."
        exit 1
    fi
}

# Function to generate OCR-D zip
generate_ocrd_zip() {
    echo "Generating an OCR-D zip..."
    $DOCKER_RAPPER ocrd zip bag -i "$PROCESS_TITLE" -d "/data/$PROCESS_TITLE"
 
    if [ $? -ne 0 ]; then
        log_error "Failed to generate the OCR-D zip."
        exit 1
    fi
}

# Function to validate OCR-D zip
validate_ocrd_zip() {
    echo "Validating the OCR-D zip..."
    $DOCKER_RAPPER ocrd zip validate "/data/$PROCESS_TITLE.ocrd.zip"
    if [ $? -ne 0 ]; then
        log_error "Validation failed. The OCR-D zip is not valid."
        exit 1
    fi
}

# Function to upload OCR-D zip to Operandi
upload_ocrd_zip() {
    echo "Uploading the OCR-D zip to $SERVER_ADDR..."
    json_data=$(curl -X POST "$SERVER_ADDR/workspace" -H "Content-Type: multipart/form-data" -F "workspace=@$WORKSPACE_DIR".ocrd.zip -u "$OPERANDI_USER_PASS")
    if [ $? -ne 0 ]; then
        log_error "Failed to upload the OCR-D zip."
        exit 1
    fi
    echo $json_data
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
    if [ $? -ne 0 ]; then
        log_error "Failed to upload the workflow."
        exit 1
    fi
    workflow_id=$(echo "$json_data" | grep -o '"resource_id":"[^"]*' | cut -d '"' -f 4)
    echo "Uploaded Workflow ID: $workflow_id"
}

# Function to submit a job
submit_job() {
    url="$SERVER_ADDR/workflow/$workflow_id"
    echo "The upload URL is: $url"
    
    # Construct the JSON payload
    json_payload=$(cat <<EOF
    {
        "workflow_args": {
            "workspace_id": "$workspace_id",
            "input_file_grp": "$FILE_GROUP",
            "remove_file_grps": "",
            "preserve_file_grps": "$FILE_GROUP,OCR-D-OCR" ,
            "mets_name": "mets.xml"
        },
        "sbatch_args": {
            "partition": "standard96:shared",
            "cpus": $CPUs,
            "ram": $RAM
        }
    }
EOF
    )

    # Send the POST request
    json_data=$(curl -X POST "$url" -u "$OPERANDI_USER_PASS" \
        -H "Content-Type: application/json" \
        -d "$json_payload")

    echo $json_data
    
    if [ $? -ne 0 ]; then
        log_error "Failed to submit the job."
        exit 1
    fi

    # Extract job_id from the response
    job_id=$(echo "$json_data" | grep -o '"resource_id":"[^"]*' | cut -d '"' -f 4 | head -n 1)
    
    if [ -z "$job_id" ]; then
        log_error "job_id is empty. Response: $json_data"
        exit 1
    fi
    
    echo "Job successfully submitted with ID: $job_id"
}


# Function to use local ocrd
process_with_local_ocrd() {

    WORKSPACE_DIR_LOCAL="$WORKSPACE_DIR"_local/data
    WS_LOCAL_OCRD_PATH="/data/"$PROCESS_TITLE"_local/data"
    METS_SERVER_LOG="${WS_LOCAL_OCRD_PATH}/mets_server.log"
    SOCKET_PATH="${WS_LOCAL_OCRD_PATH}/mets_server.sock"
    unzip -o "$WORKSPACE_DIR".ocrd.zip -d "$WORKSPACE_DIR"_local
    PAGES=$(find "$WORKSPACE_DIR_LOCAL/$FILE_GROUP" -type f | wc -l)
    #"$DOCKER_RAPPER" ocrd workspace -U "${SOCKET_PATH}" -d "${WS_LOCAL_OCRD_PATH}" server start > "${METS_SERVER_LOG}" 2>&1 &

    # Execute the Nextflow script
    nextflow run "${WORKFLOW}" \
    -ansi-log false \
    -with-report "report-${CPUs}-${RAM}-${FORKS}-${CURRENT_TIME}.html" \
    --input_file_group "${FILE_GROUP}" \
    --mets "${WS_LOCAL_OCRD_PATH}/mets.xml" \
    --mets_socket "${SOCKET_PATH}" \
    --workspace_dir "${WS_LOCAL_OCRD_PATH}" \
    --singularity_wrapper "docker run --rm -u $(id -u) -v $SCRIPT_PATH/tmp:/tmp -v $SCRIPT_PATH/ocrd-models:/ocrd-models -v $PARENT_WORKSPACE:/data -- ocrd/all:maximum" \
    --pages "${PAGES}" \
    --cpus "${CPUs}" \
    --ram "${RAM}" 
    
    if [ $? -ne 0 ]; then
        log_error "Failed to process with local ocrd."
        exit 1
    fi
    # Stop the mets server started above
    #$DOCKER_RAPPER ocrd workspace -U "${SOCKET_PATH}" -d "${WORKSPACE_DIR_LOCAL}" server stop
    $DOCKER_RAPPER ocrd zip bag -i "$PROCESS_TITLE" -d "$WS_LOCAL_OCRD_PATH"
    OCRD_RESULTS="$WORKSPACE_DIR_LOCAL".ocrd.zip
    mv $OCRD_RESULTS $PARENT_WORKSPACE/
    OCRD_RESULTS="$PARENT_WORKSPACE/data.ocrd.zip"
    mv $OCRD_RESULTS $PARENT_WORKSPACE/$PROCESS_TITLE"_results.zip"
    OCRD_RESULTS=$PARENT_WORKSPACE/$PROCESS_TITLE"_results.zip"
}


# Function to download results
download_results() {
    echo "Downloading the results..."
    curl -X GET "$SERVER_ADDR/workspace/$workspace_id" -u "$OPERANDI_USER_PASS" -H "accept: application/vnd.ocrd+zip" -o "$OCRD_RESULTS"
    if [ $? -ne 0 ]; then
        log_error "Failed to download the results."
        exit 1
    fi 
    echo "Results are available now"
    log_info "Results are available now"
}

# Function to download results
download_results_logs() {
    echo "Downloading the results..."
    curl -X GET "$SERVER_ADDR/workflow/$workflow_id/$job_id/logs" -u "$OPERANDI_USER_PASS" -H "accept: application/vnd.zip" -o "$OCRD_RESULTS_LOGS"
    if [ $? -ne 0 ]; then
        log_error "Failed to download the results logs."
        exit 1
    fi
    echo "Results Logs are available now"
    log_info "Results Logs are available now"
}

# Function to delete the workspace
delete_workspace() {
    echo "Deleting the workspace..."
    curl -X DELETE "$SERVER_ADDR/workspace/$workspace_id" -u "$OPERANDI_USER_PASS"
    if [ $? -ne 0 ]; then
        log_error "Failed to delete the workspace."
        exit 1
    fi
    echo "Workspace deleted successfully"
    log_info "Workspace deleted successfully"
}


# Function to upload to OLA-HD
upload_to_ola_hd() {
    log_info "Uploading the results to OLA-HD..."
    json_data=$(curl -X POST $OLA_HD_SERVER/api/bag -u "$OLA_USR" -H 'content-type: multipart/form-data' -F file=@"$OCRD_RESULTS")

    # Extract the PID value
    ola_pid=$(echo "$json_data" | grep -o '"pid":"[^"]*' | cut -d '"' -f 4 | head -n 1)
    echo "$(basename "$WORKSPACE_DIR") >>> $OLA_HD_SERVER/search-detail?id=$ola_pid"  >> "ola_hd_pids.txt"
    
    if [ $? -ne 0 ]; then
        log_error "Failed to download the results."
        exit 1
    fi
}

# Function to check workflow status and download results
check_job_status() {
    while true; do
        # Sleep for a while before checking again
	sleep 30

	url="$SERVER_ADDR/workflow/$workflow_id/$job_id"
        log_info "The job URL is: $url"
        json_data=$(curl -X GET "$url" -u "$OPERANDI_USER_PASS")
        if [ $? -ne 0 ]; then
            log_error "Failed to check for the job status."
            exit 1
        fi
        # Extract the current job state
        job_state=$(grep -o '"job_state":"[^"]*' <<< "$json_data" | cut -d '"' -f 4)
        echo "Current Job State: $job_state"
        log_info "Current Job State: $job_state"

	if [ "$job_state" == "SUCCESS" ]; then
        log_info "Job completed successfully."
        download_results
        download_results_logs
        delete_workspace
        break
    fi

	if [ "$job_state" == "FAILED" ]; then
        log_info "Job failed"
        break
    fi 
    done
}

clean_results(){
    unzip -o $OCRD_RESULTS -d ${WORKSPACE_DIR}_cleaned_results

    file_groups=$(docker run --rm -u $(id -u) -v $SCRIPT_PATH/tmp:/tmp -v $SCRIPT_PATH/ocrd-models:/ocrd-models -v ${WORKSPACE_DIR}_cleaned_results/data:/data -- ocrd/all:maximum ocrd workspace list-group)
    # Loop over each line in the output and print it
    while IFS= read -r group; do
        # Check if the group is not DEFAULT or OCR-D-OCR
    if [[ "$group" != $FILE_GROUP && "$group" != "OCR-D-OCR" ]]; then
        # Remove the group using the specified command
        echo "Removing file group: $group"
        $DOCKER_RAPPER ocrd workspace -d "/data/${PROCESS_TITLE}_cleaned_results/data" remove-group -r -f "$group"
    fi
    done <<< "$file_groups"

    $DOCKER_RAPPER ocrd zip bag -i "$PROCESS_TITLE" -d /data/${PROCESS_TITLE}_cleaned_results/data
    mv $OCRD_RESULTS ${PROCESS_TITLE}_uncleaned.zip
    mv ${WORKSPACE_DIR}_cleaned_results/data.ocrd.zip $OCRD_RESULTS
    rm -r ${WORKSPACE_DIR}_cleaned_results
}

create_zip_from_url() {
    clone_mets
    download_file_group
    generate_ocrd_zip
    validate_ocrd_zip
}

execute_step() {
    local step_name="$1"

    check_step_completion "$step_name" || {
        # The step has not been done yet, so we execute it
        "$step_name" || {
            # There was an error executing the function
            log_error "Failed to execute $step_name"
            exit 1
        }
        
        # The function succeeded
        mark_step_completed "$step_name"
    }
}


# Main script
main() {
    if [[ "$WORKSPACE_DIR" != /* ]]; then
        WORKSPACE_DIR="$PWD/$WORKSPACE_DIR"
    fi
    log_info "workspace:  $WORKSPACE_DIR"
    #remove the / from the end of server address
    SERVER_ADDR="${SERVER_ADDR%/}"
    PROCESS_TITLE=$(basename "$WORKSPACE_DIR")
    OCRD_RESULTS="$WORKSPACE_DIR"_results.zip
    OCRD_RESULTS_LOGS="$WORKSPACE_DIR"_results_logs.zip
    PARENT_WORKSPACE=$(dirname "$WORKSPACE_DIR")
    DOCKER_RAPPER="docker run --rm -u $(id -u) -v $SCRIPT_PATH/tmp:/tmp -v $PARENT_WORKSPACE:/data -- ocrd/core"
    check_required_flags
    #extract_workflow_id

    # Check if the zip is already given or not
    if [ -z "$ZIP" ] ; then
        execute_step "create_workspace"
        if [ -z "$METS_URL" ] ; then
            execute_step "generate_ocrd_zip"
            execute_step "validate_ocrd_zip"
        fi
    else
        WORKSPACE_DIR="${ZIP%.ocrd.zip}"
    fi

    if [ "$LOCAL_OCRD" == true ] ; then
        if [ ! -z "$METS_URL" ] ; then
            execute_step "create_zip_from_url"
        fi
        execute_step "process_with_local_ocrd"
    else
        if [ -z "$METS_URL" ] ; then 
            execute_step "upload_ocrd_zip"
        fi
        if [ "$UPLOAD_WF" == true ] ; then
            execute_step "upload_workflow"
        fi    
            execute_step "submit_job"
            execute_step "check_job_status"
    fi

    if [ "$CLEAN_RESULTS" == true ] ; then
        execute_step "clean_results"
    fi

    if [ "$LAREX_VIEW" == true ] ; then
        ./view_in_larex.sh $OCRD_RESULTS $FILE_GROUP
    fi

    if [ "$OLA" == true ] ; then
        execute_step "upload_to_ola_hd"
    fi
    
    if [ -n "$RECIPIENT_EMAIL" ] ; then
        echo "Sending log by email to $RECIPIENT_EMAIL..."
        send_log_by_email
    fi
    
}

main

