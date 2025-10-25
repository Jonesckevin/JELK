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
                "@timestamp"  = @{
                    type   = "date"
                    format = "yyyy-MM-dd HH:mm:ss||yyyy-MM-dd'T'HH:mm:ss||epoch_millis"
                }
                ParsedPayload = @{
                    enabled = $false
                }
            }
        }
    } | ConvertTo-Json -Depth 10
    
    # Create ingest pipeline for parsing JSON Payload field
    $pipelineName = "evtx-payload-parser"
    $pipelineBody = @{
        description = "Parse EVTX Payload JSON and extract fields"
        processors  = @(
            @{
                json = @{
                    field          = "Payload"
                    target_field   = "ParsedPayload"
                    ignore_failure = $true
                }
            },
            @{
                script = @{
                    lang           = "painless"
                    source         = @"
if (ctx.ParsedPayload?.EventData?.Data != null) {
  def data = ctx.ParsedPayload.EventData.Data;
  if (data instanceof List) {
    for (def item : data) {
      if (item instanceof Map && item.containsKey('@Name') && item.containsKey('#text')) {
        def fieldName = 'Parsed_' + item['@Name'];
        ctx[fieldName] = item['#text'];
      }
    }
  } else if (data instanceof String) {
    ctx.Parsed_DataString = data;
  }
}
"@
                    ignore_failure = $true
                }
            }
        )
    } | ConvertTo-Json -Depth 10
    
    try {
        Invoke-RestMethod -Uri "$ElasticsearchUrl/_ingest/pipeline/$pipelineName" -Method Put -Body $pipelineBody -ContentType "application/json" | Out-Null
        Write-Host "Created ingest pipeline: $pipelineName"
    }
    catch {
        Write-Host "Pipeline may already exist or error creating: $_"
    }
    
    try {
        Invoke-RestMethod -Uri "$ElasticsearchUrl/$indexName" -Method Put -ContentType "application/json" -Body $indexMapping
        Write-Host "Created index: $indexName"
    }
    catch {
        Write-Host "Index $indexName might already exist: $_"
    }
    
    # Read CSV file
    try {
        $csvData = Import-Csv -Path $CsvFile
        Write-Host "Read $($csvData.Count) records from $CsvFile"
        
        if ($csvData.Count -eq 0) {
            Write-Host "No data found in CSV file"
            return $false
        }

        # Upload in batches of 500 to avoid overwhelming Elasticsearch
        $batchSize = 1500
        $totalUploaded = 0
        $totalFailed = 0
        
        for ($i = 0; $i -lt $csvData.Count; $i += $batchSize) {
            $batch = $csvData | Select-Object -Skip $i -First $batchSize
            $bulkBody = @()
            
            foreach ($record in $batch) {
                # Add index action with pipeline
                $bulkBody += (@{index = @{_index = $indexName; pipeline = "evtx-payload-parser" } } | ConvertTo-Json -Compress)
                
                # Convert PSCustomObject to hashtable to ensure proper JSON serialization
                $docHash = @{}
                $record.PSObject.Properties | ForEach-Object {
                    $docHash[$_.Name] = $_.Value
                }
                
                # Add document (Elasticsearch will parse the Payload via the pipeline)
                $bulkBody += ($docHash | ConvertTo-Json -Compress -Depth 10)
            }
            
            $bulkData = ($bulkBody -join "`n") + "`n"
            
            try {
                $response = Invoke-RestMethod -Uri "$ElasticsearchUrl/_bulk" -Method Post -Body $bulkData -ContentType "application/x-ndjson" -TimeoutSec 60
                
                $batchNum = [math]::Floor($i / $batchSize) + 1
                $batchSuccessful = 0
                $batchFailed = 0
                
                if (-not $response.errors) {
                    $batchSuccessful = $batch.Count
                    $totalUploaded += $batch.Count
                    Write-Host "Batch ${batchNum}: ${batchSuccessful} successful, 0 failed. Total: ${totalUploaded} successful"
                }
                else {
                    foreach ($item in $response.items) {
                        if ($item.index.error) {
                            $batchFailed++
                            $totalFailed++
                        }
                        else {
                            $batchSuccessful++
                            $totalUploaded++
                        }
                    }
                    Write-Host "Batch ${batchNum}: ${batchSuccessful} successful, ${batchFailed} failed. Total: ${totalUploaded} successful, ${totalFailed} failed"
                }
            }
            catch {
                Write-Host "Failed to upload batch: $_"
                $totalFailed += $batch.Count
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
        
        Write-Host ""
        Write-Host "=========================================="
        Write-Host "Upload Summary:"
        Write-Host "  Total records in CSV: $($csvData.Count)"
        Write-Host "  Successfully uploaded: $totalUploaded"
        Write-Host "  Failed to upload: $totalFailed"
        Write-Host "  Success rate: $([math]::Round(($totalUploaded / $csvData.Count) * 100, 2))%"
        Write-Host "  Index: $indexName"
        Write-Host "=========================================="
        Write-Host ""
        
        if ($totalFailed -gt 0) {
            Write-Host "WARNING: $totalFailed records failed to upload due to mapping conflicts."
            Write-Host "These records have incompatible data structures (string vs array in EventData.Data)"
        }
        
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
