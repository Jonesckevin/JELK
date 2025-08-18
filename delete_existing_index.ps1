# Test Elasticsearch connection and delete indices script

# Elasticsearch configuration
$ElasticsearchUrl = "http://localhost:9200"

try {
    # Test connection to Elasticsearch
    Write-Host "Testing connection to Elasticsearch..." -ForegroundColor Yellow
    $response = Invoke-RestMethod -Uri "$ElasticsearchUrl/_cluster/health" -Method Get
    Write-Host "✓ Connected to Elasticsearch successfully" -ForegroundColor Green
    Write-Host "Cluster Status: $($response.status)" -ForegroundColor Cyan
    
    # Get all indices
    Write-Host "`nRetrieving current indices..." -ForegroundColor Yellow
    $indices = Invoke-RestMethod -Uri "$ElasticsearchUrl/_cat/indices?format=json" -Method Get
    
    if ($indices.Count -eq 0) {
        Write-Host "No indices found in Elasticsearch." -ForegroundColor Green
        return
    }
    
    # Filter out internal and Kibana indices
    $deletableIndices = $indices | Where-Object { 
        -not ($_.index.StartsWith(".internal") -or $_.index.StartsWith(".kibana"))
    }
    
    if ($deletableIndices.Count -eq 0) {
        Write-Host "`nNo deletable indices found (all indices are protected)." -ForegroundColor Green
        return
    }
    
    Write-Host "`nIndices that will be deleted:" -ForegroundColor Cyan
    foreach ($index in $deletableIndices) {
        Write-Host "- $($index.index) (docs: $($index.'docs.count'), size: $($index.'store.size'))" -ForegroundColor White
    }
    
    # Ask user for confirmation
    Write-Host "`nWARNING: This will delete $($deletableIndices.Count) non-system indices and their data!" -ForegroundColor Red
    Write-Host "Protected indices (.internal* and .kibana*) will be preserved." -ForegroundColor Yellow
    $confirmation = Read-Host "Do you want to delete the non-system indices? (yes/no)"
    
    if ($confirmation -eq "yes") {
        Write-Host "`nDeleting non-system indices..." -ForegroundColor Yellow
        foreach ($index in $deletableIndices) {
            try {
                Invoke-RestMethod -Uri "$ElasticsearchUrl/$($index.index)" -Method Delete | Out-Null
                Write-Host "✓ Deleted index: $($index.index)" -ForegroundColor Green
            }
            catch {
                Write-Host "✗ Failed to delete index: $($index.index)" -ForegroundColor Red
            }
        }
        Write-Host "`nAll deletable indices have been processed." -ForegroundColor Green
    }
    else {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
    }
}
catch {
    Write-Host "✗ Error connecting to Elasticsearch: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Make sure Elasticsearch is running on $ElasticsearchUrl" -ForegroundColor Yellow
}
