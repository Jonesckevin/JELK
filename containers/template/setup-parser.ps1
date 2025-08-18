#!/usr/bin/env pwsh

# JELK Parser Template Setup Script
# This script helps you quickly set up a new parser from the template

param(
    [Parameter(Mandatory = $true)]
    [string]$ParserName,
    
    [string]$Description = "",
    
    [switch]$Help
)

if ($Help) {
    Write-Host @"
JELK Parser Template Setup Script

Usage: .\setup-parser.ps1 -ParserName <name> [-Description <description>]

Parameters:
  -ParserName    Name of your new parser (e.g., 'prefetch', 'usnjrnl', 'shellbags')
  -Description   Optional description of what the parser does
  -Help          Show this help message

Examples:
  .\setup-parser.ps1 -ParserName "prefetch" -Description "Windows Prefetch file parser"
  .\setup-parser.ps1 -ParserName "usnjrnl" -Description "NTFS USN Journal parser"

This script will:
1. Copy the template to containers/<parser-name>
2. Rename files appropriately
3. Update placeholder text in files
4. Display next steps for customization
"@
    return
}

# Validate parser name
if ($ParserName -notmatch '^[a-zA-Z0-9_-]+$') {
    Write-Error "Parser name must contain only letters, numbers, underscores, and hyphens"
    return
}

$ParserName = $ParserName.ToLower()
$SourcePath = ".\containers\template"
$DestPath = ".\containers\$ParserName"

# Check if template exists
if (-not (Test-Path $SourcePath)) {
    Write-Error "Template directory not found: $SourcePath"
    return
}

# Check if destination already exists
if (Test-Path $DestPath) {
    Write-Error "Parser directory already exists: $DestPath"
    return
}

Write-Host "Setting up new parser: $ParserName" -ForegroundColor Green

# Copy template directory
try {
    Copy-Item -Path $SourcePath -Destination $DestPath -Recurse
    Write-Host "✓ Copied template to $DestPath"
}
catch {
    Write-Error "Failed to copy template: $_"
    return
}

# Rename the processing script
$OldScriptPath = Join-Path $DestPath "process_YOUR_PARSER_NAME.sh"
$NewScriptPath = Join-Path $DestPath "process_$ParserName.sh"

if (Test-Path $OldScriptPath) {
    Move-Item -Path $OldScriptPath -Destination $NewScriptPath
    Write-Host "✓ Renamed processing script to process_$ParserName.sh"
}

# Update placeholders in files
$FilesToUpdate = @(
    (Join-Path $DestPath "README.md"),
    (Join-Path $DestPath "Dockerfile"),
    (Join-Path $DestPath "process_$ParserName.sh"),
    (Join-Path $DestPath "docker-compose-example.yml")
)

foreach ($File in $FilesToUpdate) {
    if (Test-Path $File) {
        try {
            $Content = Get-Content $File -Raw
            $Content = $Content -replace "YOUR_PARSER_NAME", $ParserName
            $Content = $Content -replace "YOUR PARSER NAME", $ParserName.ToUpper()
            
            if ($Description) {
                $Content = $Content -replace "TODO: Add description", $Description
            }
            
            Set-Content -Path $File -Value $Content -NoNewline
            Write-Host "✓ Updated placeholders in $(Split-Path $File -Leaf)"
        }
        catch {
            Write-Warning "Failed to update placeholders in $File`: $_"
        }
    }
}

Write-Host "`nParser setup completed successfully!" -ForegroundColor Green

Write-Host @"

Next Steps:
1. Edit $DestPath\Dockerfile to add your forensic tool
2. Customize $DestPath\process_$ParserName.sh with your parsing logic
3. Update $DestPath\README.md with parser-specific documentation
4. Add the service definition to docker-compose.yml (see docker-compose-example.yml)
5. Test your parser:
   docker-compose build $ParserName-processor
   docker-compose up $ParserName-processor

Quick Start Commands:
  cd $DestPath
  code .  # Open in VS Code for editing

For detailed instructions, see: $DestPath\README.md
"@ -ForegroundColor Yellow
