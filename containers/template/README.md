# JELK Parser Template

This template provides a standardized structure for adding new artifact parsers to the JELK (Digital Forensics Timeline Analysis) system.

## Quick Start

1. **Copy this template directory:**
   ```powershell
   Copy-Item -Path ".\containers\template" -Destination ".\containers\YOUR_PARSER_NAME" -Recurse
   ```

2. **Customize the files** (see detailed instructions below)

3. **Add to docker-compose.yml** (see example below)

4. **Test your parser:**
   ```powershell
   docker-compose up --build YOUR_PARSER_NAME-processor
   ```

## File Structure

```
containers/YOUR_PARSER_NAME/
├── README.md                    # This file - customize for your parser
├── Dockerfile                   # Docker container definition
├── process_YOUR_PARSER_NAME.sh  # Main processing script
├── upload-functions.ps1         # PowerShell upload functions (copy from shared)
└── tools/                       # Optional: Parser-specific tools
```

## Customization Steps

### 1. Dockerfile

The template Dockerfile provides a base Ubuntu 22.04 container with:
- Wine (for running Windows forensic tools)
- PowerShell (for upload functionality)
- Basic tools (wget, unzip, curl, etc.)

**Customize:**
- Add your specific forensic tool downloads and installation
- Install any additional dependencies
- Set up proper tool permissions

### 2. Processing Script (process_YOUR_PARSER_NAME.sh)

The template processing script provides:
- Directory iteration through `/data_input/`
- Timestamp generation for output files
- Basic file search patterns
- Error handling and logging

**Customize:**
- Define your artifact search patterns
- Add your parsing tool commands
- Implement CSV output formatting
- Add validation and error handling

### 3. Upload Functions (upload-functions.ps1)

Copy the shared upload functions:
```powershell
Copy-Item -Path ".\containers\shared\upload-functions.ps1" -Destination ".\containers\YOUR_PARSER_NAME\upload-functions.ps1"
```

**Customize if needed:**
- Modify index naming conventions
- Add parser-specific field mappings
- Implement custom data transformations

### 4. Docker Compose Integration

Add your new parser to `docker-compose.yml`:

```yaml
  YOUR_PARSER_NAME-processor:
    restart: "no"
    build:
      context: ./containers/YOUR_PARSER_NAME
      dockerfile: Dockerfile
    volumes:
      - ./data_input:/data_input:ro
      - ./data_output:/data_output
    environment:
      - TZ=UTC
    command: ["/scripts/process_YOUR_PARSER_NAME.sh"]
    depends_on:
      elasticsearch:
        condition: service_healthy
```

## Parser Development Guidelines

### Input Data Expectations

- **Read-only access** to `/data_input/` containing forensic image directories
- Each subdirectory represents a complete file system image (e.g., `L1_C/`)
- Your parser should search for artifacts within these directory structures

### Output Requirements

- **CSV format** output to `/data_output/`
- **Naming convention:** `{DirectoryName}-{PARSER_NAME}-{YYYYMMDDTHHMM}.csv`
- **UTC timestamps** for all temporal data
- **Body format compatibility** when possible (MAC times, path, size, etc.)

### Standard CSV Columns (recommended)

```csv
Date,Time,Size,Type,Mode,UID,GID,Meta,File Name,Description
```

Or use body format:
```
MD5|name|inode|mode_as_string|UID|GID|size|atime|mtime|ctime|crtime|path
```

### Error Handling

- Log all processing steps with timestamps
- Handle missing artifacts gracefully
- Provide meaningful error messages
- Continue processing other directories on individual failures

### Performance Considerations

- Process directories in parallel when possible
- Use efficient file searching (avoid full recursive scans when possible)
- Implement progress indicators for large datasets
- Consider memory usage for large artifact files

## Common Forensic Tools Integration

### Windows Tools via Wine

Most Windows forensic tools can be run via Wine:

```dockerfile
# Download tool
RUN wget https://example.com/tool.zip && \
    unzip tool.zip && \
    chmod +x Tool/Tool.exe

# In processing script
wine /tools/Tool/Tool.exe -input "$ARTIFACT_PATH" -output "$OUTPUT_PATH"
```

### Linux Native Tools

For Linux-compatible tools:

```dockerfile
RUN apt-get update && apt-get install -y \
    tool-name \
    && rm -rf /var/lib/apt/lists/*
```

### Python-based Tools

```dockerfile
RUN apt-get update && apt-get install -y python3 python3-pip && \
    pip3 install tool-package
```

## Testing Your Parser

### 1. Build and Test Individually

```powershell
# Build only your parser
docker-compose build YOUR_PARSER_NAME-processor

# Run only your parser
docker-compose up YOUR_PARSER_NAME-processor

# Check logs
docker-compose logs YOUR_PARSER_NAME-processor
```

### 2. Validate Output

- Check for CSV files in `data_output/`
- Verify CSV format and column headers
- Test with sample forensic data
- Validate timestamps are in UTC

### 3. Integration Testing

```powershell
# Test with full stack
docker-compose up --build

# Check Elasticsearch ingestion
curl http://localhost:9200/_cat/indices

# View in Kibana
# Navigate to http://localhost:5601
```

## Common Artifact Types & Search Patterns

### Registry Hives
```bash
find "$dir" -name "SYSTEM" -o -name "SOFTWARE" -o -name "SECURITY" -o -name "SAM" -o -name "DEFAULT" -o -name "NTUSER.DAT" -o -name "UsrClass.dat"
```

### Event Logs
```bash
find "$dir" -name "*.evtx" -type f
```

### File System Metadata
```bash
find "$dir" -name "\$MFT" -o -name "\$J" -o -name "\$LogFile"
```

### Browser Artifacts
```bash
find "$dir" -name "History" -o -name "Cookies" -o -name "places.sqlite"
```

### Memory Dumps
```bash
find "$dir" -name "*.dmp" -o -name "hiberfil.sys" -o -name "pagefile.sys"
```

## Troubleshooting

### Common Issues

1. **Wine initialization fails**
   - Ensure proper Wine setup in Dockerfile
   - Check WINEDLLOVERRIDES settings

2. **Tool permissions**
   - Add `chmod +x` for executables
   - Check file ownership in container

3. **Missing dependencies**
   - Verify all required packages are installed
   - Check for missing libraries

4. **Path issues**
   - Use absolute paths in scripts
   - Verify mount points are correct

5. **Output formatting**
   - Validate CSV headers and data types
   - Ensure UTF-8 encoding
   - Check for special characters in file paths

### Debug Commands

```powershell
# Enter container for debugging
docker-compose run --rm YOUR_PARSER_NAME-processor /bin/bash

# Check file permissions
docker-compose run --rm YOUR_PARSER_NAME-processor ls -la /tools/

# Test tool execution
docker-compose run --rm YOUR_PARSER_NAME-processor wine /tools/YourTool.exe --help
```

## Examples

See existing parsers for reference:
- **MFT Parser** (`containers/mft/`) - File system timeline
- **EVTX Parser** (`containers/evtx/`) - Windows Event Logs  
- **Registry Parser** (`containers/registry/`) - Registry timestamps

## Contributing

When contributing new parsers:
1. Follow this template structure
2. Include comprehensive documentation
3. Test with various input data formats
4. Provide sample output examples
5. Update main README.md with parser description

---

**Template Version:** 1.0  
**Last Updated:** August 2025  
**Compatible with:** JELK System v1.0
