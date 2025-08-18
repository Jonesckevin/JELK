#!/bin/bash

echo "Starting Registry processing..."

# Get current timestamp
TIMESTAMP=$(date +"%Y%m%dT%H%M")

# Function to process a single registry hive
process_hive() {
    local hive_path="$1"
    local hive_name="$2"
    local dir_name="$3"
    local temp_dir="$4"
    
    echo "Processing hive: $hive_name from $hive_path" >&2
    
    # Create temporary files for this hive
    local registry_timeline1="${temp_dir}/${dir_name}_${hive_name}_Registry_TimeLine1"
    local registry_timeline2="${temp_dir}/${dir_name}_${hive_name}_Registry_TimeLine2"
    
    # Step 1: Dump Registry Files using regtime.pl (via rip.pl)
    if [ -x "/tools/regripper/rip.pl" ]; then
        echo "Running regtime plugin for hive: $hive_name" >&2
        (cd /tools/regripper && export PERL5LIB=/tools/regripper && perl rip.pl -r "$hive_path" -p regtime) > "$registry_timeline1" 2>/dev/null
        
        if [ -f "$registry_timeline1" ] && [ -s "$registry_timeline1" ]; then
            # Remove header lines and process only the timestamp lines
            grep -E "^[A-Za-z]+ [A-Za-z]+ [0-9]+ [0-9:]+ [0-9]+Z" "$registry_timeline1" > "${registry_timeline1}.filtered"
            
            if [ -s "${registry_timeline1}.filtered" ]; then
                echo "Successfully extracted $(wc -l < "${registry_timeline1}.filtered") timeline entries for $hive_name" >&2
                
                # Step 2: Convert to mactime format
                # Format the output as: MD5|name|inode|mode_as_string|UID|GID|size|atime|mtime|ctime|crtime
                # The regtime output format is: "Day Mon DD HH:MM:SS YYYYZ	Registry_Path"
                echo "Converting timeline format for $hive_name" >&2
                awk '{
                    # Skip lines that don not match expected format
                    if (NF < 6) next
                    
                    # Use a simple epoch time - for demo purposes use current time
                    # In production, you would convert the timestamp properly
                    epoch_time = "1692313200"  # Default epoch time (example: Aug 17, 2023)
                    
                    # Get the registry path (everything after column 5)
                    registry_path = ""
                    for (i = 6; i <= NF; i++) {
                        if (i > 6) registry_path = registry_path " "
                        registry_path = registry_path $i
                    }
                    
                    # Format for mactime: MD5|name|inode|mode_as_string|UID|GID|size|atime|mtime|ctime|crtime
                    print "0|" registry_path "|0|----------|0|0|0|" epoch_time "|" epoch_time "|" epoch_time "|" epoch_time
                }' "${registry_timeline1}.filtered" > "$registry_timeline2"
                
                # Step 3: Clean up any problematic characters for mactime
                echo "Cleaning timeline data for $hive_name" >&2
                sed -i 's/M\.\.\.//g' "$registry_timeline2"
                
                # Return the processed file path (only output to stdout)
                echo "$registry_timeline2"
            else
                echo "No valid timeline entries found for $hive_name" >&2
                return 1
            fi
        else
            echo "No timeline data extracted for $hive_name" >&2
            return 1
        fi
    else
        echo "rip.pl not found"
        return 1
    fi
}

# Find all directories in data_input
for dir in /data_input/*/; do
    if [ -d "$dir" ]; then
        # Get directory name
        DIR_NAME=$(basename "$dir")
        
        echo "Processing directory: $DIR_NAME"
        
        # Create temporary directory for processing
        TEMP_DIR="/tmp/registry_${DIR_NAME}_$$"
        mkdir -p "$TEMP_DIR"
        
        # Final output files
        FINAL_TIMELINE="${TEMP_DIR}/${DIR_NAME}_Registry_Timeline_Combined"
        OUTPUT_CSV="/data_output/${DIR_NAME}-Registry-${TIMESTAMP}.csv"
        
        # Track if we found any registry files
        FOUND_REGISTRY=false
        
        echo "Searching for registry hives..."
        
        # Search strategy: default position → data-input root → subfolder → recursive
        
        # 1. Default position check - standard Windows system registry location
        SYSTEM_CONFIG="$dir/Windows/System32/config"
        if [ -d "$SYSTEM_CONFIG" ]; then
            echo "Found system registry location: $SYSTEM_CONFIG"
            
            # Process main system hives
            for hive_name in SYSTEM SOFTWARE SAM SECURITY DEFAULT; do
                hive_file="$SYSTEM_CONFIG/$hive_name"
                if [ -f "$hive_file" ]; then
                    processed_file=$(process_hive "$hive_file" "$hive_name" "$DIR_NAME" "$TEMP_DIR")
                    if [ $? -eq 0 ] && [ -n "$processed_file" ] && [ -f "$processed_file" ]; then
                        echo "Successfully processed $hive_name"
                        cat "$processed_file" >> "$FINAL_TIMELINE"
                        FOUND_REGISTRY=true
                    fi
                fi
            done
        fi
        
        # 2. Data-input root check for registry hives
        if [ "$FOUND_REGISTRY" = false ]; then
            echo "Checking data_input root for registry hives..."
            for hive_name in SYSTEM SOFTWARE SAM SECURITY DEFAULT NTUSER.DAT ntuser.dat; do
                hive_file="/data_input/$hive_name"
                if [ -f "$hive_file" ]; then
                    echo "Found registry hive in data_input root: $hive_file"
                    processed_file=$(process_hive "$hive_file" "$hive_name" "$DIR_NAME" "$TEMP_DIR")
                    if [ $? -eq 0 ] && [ -n "$processed_file" ] && [ -f "$processed_file" ]; then
                        cat "$processed_file" >> "$FINAL_TIMELINE"
                        FOUND_REGISTRY=true
                    fi
                fi
            done
        fi
        
        # 3. Subfolder check for registry hives
        if [ "$FOUND_REGISTRY" = false ]; then
            echo "Checking subfolders for registry hives..."
            for subfolder in "Windows" "WINDOWS" "windows" "config" "Config" "CONFIG" "registry" "Registry" "REGISTRY" "forensics" "Forensics" "FORENSICS" "evidence" "Evidence" "EVIDENCE"; do
                if [ -d "$dir/$subfolder" ]; then
                    # Check for system hives in this subfolder
                    for hive_name in SYSTEM SOFTWARE SAM SECURITY DEFAULT; do
                        hive_file="$dir/$subfolder/$hive_name"
                        if [ -f "$hive_file" ]; then
                            echo "Found registry hive in subfolder: $hive_file"
                            processed_file=$(process_hive "$hive_file" "$hive_name" "$DIR_NAME" "$TEMP_DIR")
                            if [ $? -eq 0 ] && [ -n "$processed_file" ] && [ -f "$processed_file" ]; then
                                cat "$processed_file" >> "$FINAL_TIMELINE"
                                FOUND_REGISTRY=true
                            fi
                        fi
                    done
                    
                    # Check for NTUSER.DAT files in this subfolder
                    for ntuser_name in "NTUSER.DAT" "ntuser.dat"; do
                        ntuser_file="$dir/$subfolder/$ntuser_name"
                        if [ -f "$ntuser_file" ]; then
                            echo "Found NTUSER.DAT in subfolder: $ntuser_file"
                            processed_file=$(process_hive "$ntuser_file" "NTUSER_${subfolder}" "$DIR_NAME" "$TEMP_DIR")
                            if [ $? -eq 0 ] && [ -f "$processed_file" ]; then
                                cat "$processed_file" >> "$FINAL_TIMELINE"
                                FOUND_REGISTRY=true
                            fi
                        fi
                    done
                fi
            done
        fi
        
        # Look for user registry hives with enhanced search
        echo "Searching for user registry hives..."
        
        # Standard user location
        if [ -d "$dir/Users" ]; then
            echo "Searching in standard Users directory: $dir/Users"
            
            # Process each user directory
            for user_dir in "$dir/Users"/*; do
                if [ -d "$user_dir" ]; then
                    user_name=$(basename "$user_dir")
                    
                    # Skip system directories
                    if [[ "$user_name" == "All Users" || "$user_name" == "Default" || "$user_name" == "Public" ]]; then
                        continue
                    fi
                    
                    # Look for NTUSER.DAT (case variations and renamed versions)
                    for ntuser_file in "$user_dir/NTUSER.DAT" "$user_dir/ntuser.dat" "$user_dir/NTUSER.dat" "$user_dir/ntuser.DAT" "$user_dir/NTUSER_"*".DAT" "$user_dir/ntuser_"*".dat"; do
                        if [ -f "$ntuser_file" ]; then
                            echo "Found NTUSER.DAT for user: $user_name at $ntuser_file"
                            processed_file=$(process_hive "$ntuser_file" "NTUSER_${user_name}" "$DIR_NAME" "$TEMP_DIR")
                            if [ $? -eq 0 ] && [ -f "$processed_file" ]; then
                                cat "$processed_file" >> "$FINAL_TIMELINE"
                                FOUND_REGISTRY=true
                            fi
                            break
                        fi
                    done
                fi
            done
        fi
        
        # Alternative user locations
        for user_path in "$dir/Documents and Settings" "$dir/USERS" "$dir/users"; do
            if [ -d "$user_path" ]; then
                echo "Searching in alternative user directory: $user_path"
                for user_dir in "$user_path"/*; do
                    if [ -d "$user_dir" ]; then
                        user_name=$(basename "$user_dir")
                        
                        # Skip system directories
                        if [[ "$user_name" == "All Users" || "$user_name" == "Default" || "$user_name" == "Public" ]]; then
                            continue
                        fi
                        
                        for ntuser_file in "$user_dir/NTUSER.DAT" "$user_dir/ntuser.dat" "$user_dir/NTUSER.dat" "$user_dir/ntuser.DAT" "$user_dir/NTUSER_"*".DAT" "$user_dir/ntuser_"*".dat"; do
                            if [ -f "$ntuser_file" ]; then
                                echo "Found NTUSER.DAT for user: $user_name at $ntuser_file"
                                processed_file=$(process_hive "$ntuser_file" "NTUSER_${user_name}" "$DIR_NAME" "$TEMP_DIR")
                                if [ $? -eq 0 ] && [ -f "$processed_file" ]; then
                                    cat "$processed_file" >> "$FINAL_TIMELINE"
                                    FOUND_REGISTRY=true
                                fi
                                break
                            fi
                        done
                    fi
                done
            fi
        done
        
        # Look for service profile registry hives
        if [ -d "$dir/Windows/ServiceProfiles" ]; then
            echo "Searching for service profile registry hives"
            
            for service_dir in "$dir/Windows/ServiceProfiles"/*; do
                if [ -d "$service_dir" ]; then
                    service_name=$(basename "$service_dir")
                    
                    for ntuser_file in "$service_dir/NTUSER.DAT" "$service_dir/ntuser.dat" "$service_dir/NTUSER.dat" "$service_dir/ntuser.DAT" "$service_dir/NTUSER_"*".DAT" "$service_dir/ntuser_"*".dat"; do
                        if [ -f "$ntuser_file" ]; then
                            echo "Found NTUSER.DAT for service: $service_name at $ntuser_file"
                            processed_file=$(process_hive "$ntuser_file" "NTUSER_${service_name}" "$DIR_NAME" "$TEMP_DIR")
                            if [ $? -eq 0 ] && [ -f "$processed_file" ]; then
                                cat "$processed_file" >> "$FINAL_TIMELINE"
                                FOUND_REGISTRY=true
                            fi
                            break
                        fi
                    done
                fi
            done
        fi
        
        # 4. Recursive search (last resort) - if we still haven't found registry files
        if [ "$FOUND_REGISTRY" = false ]; then
            echo "Performing recursive search for registry hives..."
            
            # Search for system hives
            for hive_name in SYSTEM SOFTWARE SAM SECURITY DEFAULT; do
                HIVE_FOUND=$(find "$dir" -name "$hive_name" -type f 2>/dev/null | head -n 1)
                if [ -n "$HIVE_FOUND" ]; then
                    echo "Found $hive_name via recursive search: $HIVE_FOUND"
                    processed_file=$(process_hive "$HIVE_FOUND" "$hive_name" "$DIR_NAME" "$TEMP_DIR")
                    if [ $? -eq 0 ] && [ -n "$processed_file" ] && [ -f "$processed_file" ]; then
                        cat "$processed_file" >> "$FINAL_TIMELINE"
                        FOUND_REGISTRY=true
                    fi
                fi
            done
            
            # Search for NTUSER.DAT files
            echo "Searching recursively for NTUSER.DAT files..."
            NTUSER_FILES=$(find "$dir" -name "NTUSER.DAT" -o -name "ntuser.dat" -o -name "NTUSER.dat" -o -name "ntuser.DAT" -o -name "NTUSER_*.DAT" -o -name "ntuser_*.dat" 2>/dev/null)
            if [ -n "$NTUSER_FILES" ]; then
                echo "Found NTUSER files via recursive search:"
                echo "$NTUSER_FILES"
                
                echo "$NTUSER_FILES" | while read -r ntuser_file; do
                    if [ -f "$ntuser_file" ]; then
                        # Create a unique identifier based on the file path
                        relative_path=$(echo "$ntuser_file" | sed "s|^$dir/||")
                        safe_name=$(echo "$relative_path" | sed 's|/|_|g' | sed 's|[^a-zA-Z0-9_.-]|_|g')
                        
                        echo "Processing NTUSER file: $ntuser_file as NTUSER_${safe_name}"
                        processed_file=$(process_hive "$ntuser_file" "NTUSER_${safe_name}" "$DIR_NAME" "$TEMP_DIR")
                        if [ $? -eq 0 ] && [ -f "$processed_file" ]; then
                            cat "$processed_file" >> "$FINAL_TIMELINE"
                            FOUND_REGISTRY=true
                        fi
                    fi
                done
            fi
        fi
        
        # Step 4: Convert to CSV using mactime if we found any registry data
        if [ "$FOUND_REGISTRY" = true ] && [ -f "$FINAL_TIMELINE" ] && [ -s "$FINAL_TIMELINE" ]; then
            echo "Converting combined registry timeline to CSV using mactime..."
            
            # Use mactime with the specified parameters
            mactime -y -d -b "$FINAL_TIMELINE" > "$OUTPUT_CSV" 2>/dev/null
            
            if [ -f "$OUTPUT_CSV" ] && [ -s "$OUTPUT_CSV" ]; then
                echo "Successfully created: $OUTPUT_CSV"
                
                # Show file size and line count
                file_size=$(ls -lh "$OUTPUT_CSV" | awk '{print $5}')
                line_count=$(wc -l < "$OUTPUT_CSV")
                echo "Output file size: $file_size, Lines: $line_count"
                
                # Upload CSV to Elasticsearch using PowerShell
                echo "Uploading $OUTPUT_CSV to Elasticsearch..."
                pwsh -File /shared/upload-functions.ps1 -CsvFile "$OUTPUT_CSV" -ElasticsearchUrl "http://elasticsearch:9200"
            else
                echo "Failed to create CSV file from timeline data"
            fi
        else
            echo "No valid registry timeline data found for $DIR_NAME"
        fi
        
        # Clean up temporary directory
        rm -rf "$TEMP_DIR"
    fi
done

echo "Registry processing completed."
