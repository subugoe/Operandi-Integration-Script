#!/bin/bash

#this script is done to upload ocr bagit to OLA-HD 
# OLA_USR should be added as an env variable and it refers to ola-hd username:password

#operandi script should store the results path inside process/directory($s1)/.ocrd_results_path

SCRIPT_PATH="$(dirname "$(realpath "$0")")"
cd "$SCRIPT_PATH"
SERVER_ADDR=141.5.99.53
CURRENT_TIME=`date +"%m%d%Y_%H%M%S"`
WORKSPACE_DIR="$PWD/ws_$CURRENT_TIME"
RESULTS_AVAILABLE=false
ERROR_LOG="error_log.txt"
LOG_FILE="log_file.txt"
METS_PATH_URL=""
OCRD_RESULTS=""

#Get the options
while getopts ":s:f:m:u:w:i:c:r:n:elz:o:" opt; do
    case $opt in
        s) SERVER_ADDR="$OPTARG" ;;
        m) METS_PATH_URL="$OPTARG" ;;
        w) WORKSPACE_DIR="$OPTARG" ;;
        z) OCRD_RESULTS="$OPTARG" 
        RESULTS_AVAILABLE=true;;
        o) OLA_USR="$OPTARG";;
        \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
        :) echo "Option -$OPTARG requires an argument." >&2; exit 1 ;;
    esac
done




# Function to log errors and information with timestamp and workspace name
log_info() {
    local log_message="$1"
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - (Upload to OLA) Workspace: $WORKSPACE_DIR - $log_message"
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - (Upload to OLA) Workspace: $WORKSPACE_DIR - $log_message" >> "$LOG_FILE"
}

# Function to log errors with timestamp and workspace name
log_error() {
    local error_message="$1"
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - (Upload to OLA) Workspace: $WORKSPACE_DIR - $error_message" >> "$ERROR_LOG"
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - (Upload to OLA) Workspace: $WORKSPACE_DIR - $error_message" >> "$LOG_FILE"
}


upload_to_ola_hd() {
    log_info "Uploading the results to OLA-HD..."
    curl -X POST $SERVER_ADDR/api/bag -u "$OLA_USR" -H 'content-type: multipart/form-data' -F file=@"$OCRD_RESULTS"
    if [ $? -ne 0 ]; then
        log_error "Failed to download the results."
        exit 1
    fi
}

create_workspace() {

    # Function to generate OCR-D zip
    log_info "Creating workspace..."
    $DOCKER_RAPPER ocrd workspace -d "/data/$PROCESS_TITLE" clone $METS_PATH_URL 
 
    if [ $? -ne 0 ]; then
        log_error "Failed to generate the OCR-D zip."
        exit 1
    fi


}

# Function to generate OCR-D zip
generate_ocrd_zip() {
    log_info "Generating an OCR-D zip..."
    $DOCKER_RAPPER ocrd zip bag -i "$PROCESS_TITLE" -d "/data/$PROCESS_TITLE"
 
    if [ $? -ne 0 ]; then
        log_error "Failed to generate the OCR-D zip."
        exit 1
    fi
}

# Function to validate OCR-D zip
validate_ocrd_zip() {
    log_info "Validating the OCR-D zip..."
    $DOCKER_RAPPER ocrd zip validate "/data/$PROCESS_TITLE.ocrd.zip"
    if [ $? -ne 0 ]; then
        log_error "Validation failed. The OCR-D zip is not valid."
        exit 1
    fi
}

cleanup() {
    rm -r $WORKSPACE_DIR ocrd.log $OCRD_RESULTS $SCRIPT_PATH/tmp
}

main() {

    PROCESS_TITLE=$(basename "$WORKSPACE_DIR")
    PARENT_WORKSPACE=$(dirname "$WORKSPACE_DIR")
    DOCKER_RAPPER="docker run --rm -u $(id -u) -v $SCRIPT_PATH/tmp:/tmp -v $SCRIPT_PATH/ocrd-models:/ocrd-models -v $PARENT_WORKSPACE:/data -- ocrd/all:maximum"

   if [ "$RESULTS_AVAILABLE" == false ] ; then

        if [ -z "$METS_PATH_URL" ] ; then 
            log_error "METS URL is not given..."
            exit 1
        fi
            create_workspace
            generate_ocrd_zip
            validate_ocrd_zip
            OCRD_RESULTS=$WORKSPACE_DIR.ocrd.zip
    fi

    upload_to_ola_hd
    cleanup

}

main

