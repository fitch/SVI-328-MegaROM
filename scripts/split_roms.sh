#!/bin/bash

# Please provide input file name in this format: arkanoid.msx.32.rom
INPUT_FILE="$1"

if [[ -z "$INPUT_FILE" || ! -f "$INPUT_FILE" ]]; then
    echo "Error: Please provide a valid existing file as the first parameter."
    exit 1
fi

if [[ "${INPUT_FILE}" == *.rom ]]; then
    BASE_NAME="${INPUT_FILE%.rom}.part"
elif [[ "${INPUT_FILE}" == *.dat ]]; then
    BASE_NAME="${INPUT_FILE%.dat}.part"
else
    BASE_NAME="${INPUT_FILE}.part"
fi

FILE_SIZE=$(stat -f%z "$INPUT_FILE")

SPLIT=16384
if [[ "$FILE_SIZE" -eq 49152 ]]; then
    SPLIT=32768
elif [[ "$FILE_SIZE" -ne 8192 && "$FILE_SIZE" -ne 16384 && "$FILE_SIZE" -ne 32768 ]]; then
    echo "Error: ROM file size is $FILE_SIZE bytes, which is not supported at the moment"
    exit 1
fi

gsplit --numeric-suffixes=1 -b $SPLIT -a 1 --additional-suffix=.dat $INPUT_FILE $BASE_NAME

for FILE in "${BASE_NAME}"*; do
    if [[ -f "$FILE" ]]; then
        echo "Compressing file: $FILE"
        zx0 $FILE
    fi
done