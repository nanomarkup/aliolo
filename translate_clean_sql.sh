#!/bin/bash

# Ask the user for the SQL file name
read -p "Enter the path to the clean SQL file (e.g., update_all_dog_breeds_clean.sql): " sql_file

# Check if the user entered anything
if [ -z "$sql_file" ]; then
    echo "Error: File path cannot be empty."
    exit 1
fi

# Run the python translation script
python3 translate_clean_sql.py "$sql_file"
