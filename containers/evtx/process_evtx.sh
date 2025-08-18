#!/bin/bash

echo "Starting EVTX processing..."

# Get current timestamp
TIMESTAMP=$(date +"%Y%m%dT%H%M")

# Find all directories in data_input
for dir in /data_input/*/; do
    if [ -d "$dir" ]; then
        # Get directory name
        DIR_NAME=$(basename "$dir")
        
        echo "Processing directory: $DIR_NAME"
        
        # Look for EventLogs directory or .evtx files
        EVTX_DIR=""
        
        echo "Searching for EVTX files..."
        
        # Search strategy: default position → data-input root → subfolder → recursive
        
        # 1. Default position check - standard Windows locations
        if [ -d "$dir/Windows/System32/winevt/Logs" ]; then
            EVTX_DIR="$dir/Windows/System32/winevt/Logs"
            echo "Found EVTX directory at default location: $EVTX_DIR"
        elif [ -d "$dir/Windows/System32/config" ]; then
            # Check if there are any .evtx files in config
            if find "$dir/Windows/System32/config" -name "*.evtx" -type f | grep -q .; then
                EVTX_DIR="$dir/Windows/System32/config"
                echo "Found EVTX files in config directory: $EVTX_DIR"
            fi
        elif [ -d "$dir/EventLogs" ]; then
            EVTX_DIR="$dir/EventLogs"
            echo "Found EventLogs directory: $EVTX_DIR"
        fi
        
        # 2. Data-input root check
        if [ -z "$EVTX_DIR" ]; then
            # Check for .evtx files directly in data_input root
            if find "/data_input" -maxdepth 1 -name "*.evtx" -type f | grep -q .; then
                EVTX_DIR="/data_input"
                echo "Found EVTX files in data_input root: $EVTX_DIR"
            # Check for common EventLog folder names in root
            elif [ -d "/data_input/EventLogs" ]; then
                EVTX_DIR="/data_input/EventLogs"
                echo "Found EventLogs directory in data_input root: $EVTX_DIR"
            elif [ -d "/data_input/Logs" ]; then
                EVTX_DIR="/data_input/Logs"
                echo "Found Logs directory in data_input root: $EVTX_DIR"
            fi
        fi
        
        # 3. Subfolder check - common locations
        if [ -z "$EVTX_DIR" ]; then
            for subfolder in "Windows" "WINDOWS" "windows" "EventLogs" "Logs" "logs" "Events" "events" "forensics" "Forensics" "FORENSICS" "evidence" "Evidence" "EVIDENCE"; do
                if [ -d "$dir/$subfolder" ]; then
                    # Check if this subfolder contains .evtx files
                    if find "$dir/$subfolder" -name "*.evtx" -type f | grep -q .; then
                        EVTX_DIR="$dir/$subfolder"
                        echo "Found EVTX files in subfolder: $EVTX_DIR"
                        break
                    fi
                    # Check for nested standard locations
                    if [ -d "$dir/$subfolder/System32/winevt/Logs" ]; then
                        EVTX_DIR="$dir/$subfolder/System32/winevt/Logs"
                        echo "Found EVTX directory in subfolder: $EVTX_DIR"
                        break
                    fi
                fi
            done
        fi
        
        # 4. Recursive search (last resort)
        if [ -z "$EVTX_DIR" ]; then
            echo "Performing recursive search for EVTX files..."
            # Search for any .evtx files in the directory tree
            EVTX_FILES=$(find "$dir" -name "*.evtx" -type f 2>/dev/null | head -n 10)
            if [ -n "$EVTX_FILES" ]; then
                # Use the parent directory of the first .evtx file found
                EVTX_DIR=$(dirname $(echo "$EVTX_FILES" | head -n 1))
                echo "Found EVTX files via recursive search: $EVTX_DIR"
                echo "Total EVTX files found: $(echo "$EVTX_FILES" | wc -l)"
            fi
        fi
        
        if [ -n "$EVTX_DIR" ] && [ -d "$EVTX_DIR" ]; then
            echo "Found EVTX directory: $EVTX_DIR"
            
            # Create output filename
            OUTPUT_CSV="/data_output/${DIR_NAME}-EVTX-${TIMESTAMP}.csv"
            
            # Run EvtxECmd using wine
            echo "Running EvtxECmd..."
            echo "Command: wine EvtxeCmd/EvtxECmd.exe -d \"$EVTX_DIR\" --csv /data_output --csvf \"${DIR_NAME}-EVTX-${TIMESTAMP}.csv\" --maps /tools/EvtxeCmd/Maps"
            cd /tools
            wine EvtxeCmd/EvtxECmd.exe -d "$EVTX_DIR" --csv /data_output --csvf "${DIR_NAME}-EVTX-${TIMESTAMP}.csv" --maps /tools/EvtxeCmd/Maps
            
            # Check if file was created
            echo "Checking for CSV file: $OUTPUT_CSV"
            
            # List all files in /data_output to see what was actually created
            echo "Files in /data_output:"
            ls -la /data_output/
            
            # Look for any CSV files with similar names
            echo "Looking for any EVTX CSV files:"
            find /data_output -name "*EVTX*" -o -name "*evtx*" 2>/dev/null || echo "No EVTX files found"
            
            if [ -f "$OUTPUT_CSV" ]; then
                echo "Successfully created: $OUTPUT_CSV"
                file_size=$(ls -lh "$OUTPUT_CSV" | awk '{print $5}')
                line_count=$(wc -l < "$OUTPUT_CSV")
                echo "CSV file size: $file_size, Lines: $line_count"
                
                # Upload CSV to Elasticsearch using PowerShell
                echo "Uploading $OUTPUT_CSV to Elasticsearch..."
                pwsh -File /shared/upload-functions.ps1 -CsvFile "$OUTPUT_CSV" -ElasticsearchUrl "http://elasticsearch:9200"
            else
                echo "Failed to create CSV file at expected location: $OUTPUT_CSV"
                
                # Try to find any CSV file that was created recently
                RECENT_CSV=$(find /data_output -name "*.csv" -newermt '1 minute ago' 2>/dev/null | grep -i evtx | head -n 1)
                if [ -n "$RECENT_CSV" ]; then
                    echo "Found recent EVTX CSV file: $RECENT_CSV"
                    echo "Uploading found CSV file..."
                    pwsh -File /shared/upload-functions.ps1 -CsvFile "$RECENT_CSV" -ElasticsearchUrl "http://elasticsearch:9200"
                else
                    echo "No recent EVTX CSV files found"
                fi
            fi
        else
            echo "No EVTX files found in $DIR_NAME"
        fi
    fi
done

echo "EVTX processing completed."
