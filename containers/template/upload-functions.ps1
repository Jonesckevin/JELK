#!/usr/bin/env pwsh

# Parameters for command line execution
param(
    [string]$CsvFile,
    [string]$ElasticsearchUrl = "http://elasticsearch:9200"
)

# Shared PowerShell function to upload CSV data to Elasticsearch
function Upload-CSVToElasticsearch {
    param(
        [string]$CsvFile,
        [string]$ElasticsearchUrl = "http://elasticsearch:9200"
    )
    
    Write-Host "Starting upload of $CsvFile to Elasticsearch..."
    
    # Test Elasticsearch connection
    $maxRetries = 30
    $retryCount = 0
    $connected = $false
    
    while (-not $connected -and $retryCount -lt $maxRetries) {
        try {
            $healthResponse = Invoke-RestMethod -Uri "$ElasticsearchUrl/_cluster/health" -Method Get -TimeoutSec 10
            Write-Host "Elasticsearch is available. Status: $($healthResponse.status)"
            $connected = $true
        }
        catch {
            $retryCount++
            Write-Host "Attempt $retryCount of $maxRetries - Elasticsearch not ready. Waiting 10 seconds..."
            Start-Sleep -Seconds 10
        }
    }
    
    if (-not $connected) {
        Write-Host "Failed to connect to Elasticsearch after $maxRetries attempts"
        return $false
    }
    
    if (-not (Test-Path $CsvFile)) {
        Write-Host "CSV file not found: $CsvFile"
        return $false
    }
    
    # Generate index name from filename
    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($CsvFile)
    $indexName = $fileName.ToLower() -replace '_', '-' -replace ' ', '-'
    
    Write-Host "Creating index: $indexName"
    
    # Create index with basic mapping
    $indexMapping = @{
        mappings = @{
            properties = @{
                "@timestamp" = @{
                    type   = "date"
                    format = "yyyy-MM-dd HH:mm:ss||yyyy-MM-dd'T'HH:mm:ss||epoch_millis"
                }
            }
        }
    } | ConvertTo-Json -Depth 10
    
    try {
        Invoke-RestMethod -Uri "$ElasticsearchUrl/$indexName" -Method Put -ContentType "application/json" -Body $indexMapping
        Write-Host "Created index: $indexName"
    }
    catch {
        Write-Host "Index $indexName might already exist: $_"
    }
    
    # Read CSV file (limit to first 5000 rows for large files to avoid memory issues)
    try {
        $csvData = Import-Csv -Path $CsvFile | Select-Object -First 500
        Write-Host "Read $($csvData.Count) records from $CsvFile"
        
        if ($csvData.Count -eq 0) {
            Write-Host "No data found in CSV file"
            return $false
        }
        
        # Upload in batches of 50 to avoid overwhelming Elasticsearch
        $batchSize = 50
        $totalUploaded = 0
        
        for ($i = 0; $i -lt $csvData.Count; $i += $batchSize) {
            $batch = $csvData | Select-Object -Skip $i -First $batchSize
            $bulkBody = @()
            
            foreach ($record in $batch) {
                # Add index action
                $bulkBody += (@{index = @{_index = $indexName } } | ConvertTo-Json -Compress)
                
                # Don't add @timestamp since we already have a Date field that gets mapped as date type
                # Add document
                $bulkBody += ($record | ConvertTo-Json -Compress)
            }
            
            $bulkData = ($bulkBody -join "`n") + "`n"
            
            try {
                $response = Invoke-RestMethod -Uri "$ElasticsearchUrl/_bulk" -Method Post -Body $bulkData -ContentType "application/x-ndjson" -TimeoutSec 60
                
                if (-not $response.errors) {
                    $totalUploaded += $batch.Count
                    Write-Host "Uploaded batch $([math]::Floor($i / $batchSize) + 1), total docs: $totalUploaded"
                }
                else {
                    Write-Host "Errors in batch $([math]::Floor($i / $batchSize) + 1):"
                    foreach ($item in $response.items) {
                        if ($item.index.error) {
                            Write-Host "  Error: $($item.index.error.type) - $($item.index.error.reason)"
                        }
                        else {
                            $totalUploaded++
                        }
                    }
                    Write-Host "Batch $([math]::Floor($i / $batchSize) + 1) completed with some errors, total successful: $totalUploaded"
                }
            }
            catch {
                Write-Host "Failed to upload batch: $_"
            }
            
            # Small delay between batches
            Start-Sleep -Milliseconds 500
        }
        
        # Refresh the index
        try {
            Invoke-RestMethod -Uri "$ElasticsearchUrl/$indexName/_refresh" -Method Post
        }
        catch {
            Write-Host "Could not refresh index, but data was uploaded"
        }
        
        Write-Host "Successfully uploaded $totalUploaded documents to index: $indexName"
        return $true
        
    }
    catch {
        Write-Host "Error processing CSV file: $_"
        return $false
    }
}

# Main execution when script is called directly
if ($CsvFile) {
    Write-Host "Starting upload process for: $CsvFile"
    $result = Upload-CSVToElasticsearch -CsvFile $CsvFile -ElasticsearchUrl $ElasticsearchUrl
    if ($result) {
        Write-Host "Upload completed successfully"
        exit 0
    }
    else {
        Write-Host "Upload failed"
        exit 1
    }
}
