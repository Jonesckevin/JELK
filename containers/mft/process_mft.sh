#!/bin/bash

echo "Starting MFT processing..."

# Get current timestamp
TIMESTAMP=$(date +"%Y%m%dT%H%M")

# Find all directories in data_input
for dir in /data_input/*/; do
    if [ -d "$dir" ]; then
        # Get directory name
        DIR_NAME=$(basename "$dir")
        
        echo "Processing directory: $DIR_NAME"
        
        # Look for $MFT file - check multiple locations and names
        MFT_FILE=""
        
        # Search strategy: default position → data-input root → subfolder → recursive
        echo "Searching for MFT file..."
        
        # 1. Default position check - standard locations
        for mft_name in "\$MFT" "MFT" "\$MFT*" "MFT*"; do
            if [ -f "$dir/$mft_name" ]; then
                MFT_FILE="$dir/$mft_name"
                echo "Found MFT file at default location: $MFT_FILE"
                break
            fi
        done
        
        # 2. Data-input root check (if not found in default position)
        if [ -z "$MFT_FILE" ]; then
            for mft_name in "\$MFT" "MFT" "\$MFT*" "MFT*"; do
                if [ -f "/data_input/$mft_name" ]; then
                    MFT_FILE="/data_input/$mft_name"
                    echo "Found MFT file in data_input root: $MFT_FILE"
                    break
                fi
            done
        fi
        
        # 3. Subfolder check - common Windows locations
        if [ -z "$MFT_FILE" ]; then
            for subfolder in "Windows" "WINDOWS" "windows" "forensics" "Forensics" "FORENSICS" "evidence" "Evidence" "EVIDENCE"; do
                if [ -d "$dir/$subfolder" ]; then
                    for mft_name in "\$MFT" "MFT" "\$MFT*" "MFT*"; do
                        if [ -f "$dir/$subfolder/$mft_name" ]; then
                            MFT_FILE="$dir/$subfolder/$mft_name"
                            echo "Found MFT file in subfolder: $MFT_FILE"
                            break 2
                        fi
                    done
                fi
            done
        fi
        
        # 4. Recursive search (last resort)
        if [ -z "$MFT_FILE" ]; then
            echo "Performing recursive search for MFT file..."
            for mft_pattern in "\$MFT" "MFT" "*MFT*"; do
                MFT_FOUND=$(find "$dir" -name "$mft_pattern" -type f 2>/dev/null | head -n 1)
                if [ -n "$MFT_FOUND" ]; then
                    MFT_FILE="$MFT_FOUND"
                    echo "Found MFT file via recursive search: $MFT_FILE"
                    break
                fi
            done
        fi
        
        if [ -n "$MFT_FILE" ]; then
            echo "Found MFT file: $MFT_FILE"
            
            # Run MFTECmd using wine to create body file
            echo "Running MFTECmd..."
            cd /tools
            wine MFTECmd.exe -f "$MFT_FILE" --bdl C --body /data_output --bodyf "${DIR_NAME}-MFT-${TIMESTAMP}.body"
            
            # Check if body file was created successfully
            OUTPUT_BODY="/data_output/${DIR_NAME}-MFT-${TIMESTAMP}.body"
            OUTPUT_CSV="/data_output/${DIR_NAME}-MFT-${TIMESTAMP}.csv"
            
            if [ -f "$OUTPUT_BODY" ] && [ -s "$OUTPUT_BODY" ]; then
                echo "MFTECmd body file created successfully"
                
                # Convert body file to CSV using mactime
                echo "Converting body file to CSV using mactime..."
                mactime -d -y -b "$OUTPUT_BODY" > "$OUTPUT_CSV"
                
                if [ -f "$OUTPUT_CSV" ] && [ -s "$OUTPUT_CSV" ]; then
                    echo "Successfully created: $OUTPUT_CSV"
                    
                    # Upload CSV to Elasticsearch using PowerShell
                    echo "Uploading $OUTPUT_CSV to Elasticsearch..."
                    pwsh -File /shared/upload-functions.ps1 -CsvFile "$OUTPUT_CSV" -ElasticsearchUrl "http://elasticsearch:9200"
                    
                    # Clean up body file
                    rm "$OUTPUT_BODY"
                else
                    echo "Failed to create CSV file from body file"
                fi
            else
                echo "MFTECmd failed to create body file"
            fi
        else
            echo "No \$MFT file found in $DIR_NAME"
        fi
    fi
done

echo "MFT processing completed."
