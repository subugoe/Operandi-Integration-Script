#this script is done to upload ocr bagit to OLA-HD 
# OLA_USR should be added as an env variable and it refers to ola-hd username:password

#operandi script should store the results path inside process/directory($s1)/.ocrd_results_path

#ocr bagit path
OCRD_RESULTS=$(<"$1/.ocrd_results_path")
upload_to_ola_hd() {
    echo "Uploading the results to OLA-HD..."
    curl -X POST 141.5.99.53/api/bag -u "$OLA_USR" -H 'content-type: multipart/form-data' -F file=@"$OCRD_RESULTS"
    if [ $? -ne 0 ]; then
        log_error "Failed to download the results."
        exit 1
    fi
}

upload_to_ola_hd
