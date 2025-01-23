#!/bin/bash

read -r line

hex_value=${line#*\$}
hex_value=${hex_value%%[!0-9A-Fa-f]*}

if [ -n "$hex_value" ]; then
    decimal_value=$((16#$hex_value))
    echo "$decimal_value"
else
    echo "Error: No hexadecimal value found from input."
fi
