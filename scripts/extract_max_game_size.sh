#!/bin/bash

INPUT_FILE="$1"

if [[ -z "$INPUT_FILE" || ! -f "$INPUT_FILE" ]]; then
    echo "Error: Please provide a valid existing file as the first parameter."
    exit 1
fi

STORAGE_START=$(cat $INPUT_FILE | grep GAME_DATA_STORAGE | scripts/extract_magic.sh)
DZX0_ADDRESS=$(cat $INPUT_FILE | grep DZX0_ADDRESS | scripts/extract_magic.sh)

if [[ "$STORAGE_START" == *"Error"* || "$DZX0_ADDRESS" == *"Error"* ]]; then
    echo "Can't determine STORAGE_START or DZX0_ADDRESS"
    exit 1
fi

GAME_MAX_SIZE=$((DZX0_ADDRESS - STORAGE_START))

echo "$GAME_MAX_SIZE"