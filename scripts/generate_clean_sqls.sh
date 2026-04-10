#!/bin/bash

# Ask the user for the subject name
read -p "Enter the subject name (e.g., Dog Breeds): " subject_name

# Check if the user entered anything
if [ -z "$subject_name" ]; then
    echo "Error: Subject name cannot be empty."
    exit 1
fi

# Run the python script with the provided subject name
python3 generate_clean_sqls_by_subject.py "$subject_name"
