#!/bin/bash

# Ask the user for the Card ID
read -p "Enter the Card ID to translate: " card_id

# Check if the user entered anything
if [ -z "$card_id" ]; then
    echo "Error: Card ID cannot be empty."
    exit 1
fi

# Run the python script with the provided Card ID
python3 translate_single_card.py "$card_id"
