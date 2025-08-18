# JELK Parser Template

## Core Files

| File | Purpose | Status |
|------|---------|---------|
| `README.md` | Complete documentation and setup guide |  |
| `Dockerfile` | Container definition with base tools | ⚠️ Needs customization |
| `process_YOUR_PARSER_NAME.sh` | Main processing script | ⚠️ Needs customization |
| `upload-functions.ps1` | PowerShell upload utilities | Ideally Should work to pre-parse. Give it a try. |
| `docker-compose-example.yml` | Example service definition | ⚠️ Add to Prod compose |

## Quick Start

1. **Copy and customize the template:**

   ```powershell
   .\setup-parser.ps1 -ParserName "your-parser" -Description "Your parser description"
   ```

2. **Or manually copy and rename:**

   ```powershell
   Copy-Item -Path ".\containers\template" -Destination ".\containers\your-parser" -Recurse
   ```

## Customization Checklist

### Essential Changes ⚠️

- [ ] Update `Dockerfile` to install your specific forensic tool
- [ ] Modify `process_your-parser.sh` with actual parsing logic
- [ ] Add artifact search patterns for your file types
- [ ] Implement CSV output formatting
- [ ] Test with sample data

### Optional Enhancements

- [ ] Customize Elasticsearch upload logic
- [ ] Add error handling and validation
- [ ] Include progress indicators
- [ ] Add support for multiple output formats

### Integration

- [ ] Add service definition to main `docker-compose.yml`
- [ ] Test with full JELK stack
