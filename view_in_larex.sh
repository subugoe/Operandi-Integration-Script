#!/bin/bash

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <path_to_zip_file> <file_group>"
    exit 1
fi

SCRIPT_PATH="$(dirname "$(realpath "$0")")"
WORKSPACE="${1%.*}"
FILE_GROUP=$2
unzip -o $WORKSPACE -d "$WORKSPACE"_larex

# rename the files by removing OCR-D-OCR_
for FILE in "$WORKSPACE"_larex/data/OCR-D-OCR/OCR-D-OCR_*.xml; do
    if [ ! -e "$FILE" ]; then
        echo "No files matching the pattern in '$DIRECTORY'."
        break
    fi
    NEW_FILE="${FILE/OCR-D-OCR_/}"
    mv "$FILE" "$NEW_FILE"
    echo "Renamed '$FILE' to '$NEW_FILE'"
done


mkdir -p $SCRIPT_PATH/Larex_Data/
mkdir -p $SCRIPT_PATH/Larex_Data/$(basename "$WORKSPACE")
mv "$WORKSPACE"_larex/data/OCR-D-OCR/* $SCRIPT_PATH/Larex_Data/$(basename "$WORKSPACE")
mv "$WORKSPACE"_larex/data/$FILE_GROUP/* $SCRIPT_PATH/Larex_Data/$(basename "$WORKSPACE")

rm -r "$WORKSPACE"_larex

if [ ! "$(docker ps -q -f name=larex)" ]; then
    echo "Larex is not running. Starting the container..."
    docker run -d -p 1476:8080 --name larex -v $SCRIPT_PATH/Larex_Data:/home/books uniwuezpd/larex
    
    if [ $? -ne 0 ]; then
        log_error "Failed to start larex docker image."
        exit 1
    fi
fi
echo "the results are accessible now through Larex at http://localhost:1476/Larex/"