#this script is done to upload ocr bagit to OLA-HD

#ocr bagit path
OCRD_RESULTS=$1

#ola-hd username:password
OLA=$2



upload_to_ola_hd() {
    echo "Uploading the results to OLA-HD..."
    curl -X POST 141.5.99.53/api/bag -u "$OLA" -H 'content-type: multipart/form-data' -F file=@"$OCRD_RESULTS"
    if [ $? -ne 0 ]; then
        log_error "Failed to download the results."
        exit 1
    fi
}

upload_to_ola_hd
