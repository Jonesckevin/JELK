# Digital Forensics Timeline Analysis Docker Setup

This Docker Compose setup processes forensic artifacts from Windows systems to create timeline CSV files for MFT, EVTX, and Registry data.

## Usage

1. Place your forensic data in the `data_input/` directory. Each subdirectory should contain a complete file system image (e.g., `L1_C/`).

2. Run the analysis:

   ```bash
   # You should only need to build once.
   docker compose up --build

   # After first build, you can continue with `up` to activate processors.
   docker compose up
   ```

When viewing the index in Kibana for the first time. Do not select @timestamp first. Change this to:

`"I do not want to use the time filter"`

3. The processed CSV files will appear in `data_output/` with naming convention:
   - `{DirectoryName}-MFT-{YYYYMMDDTHHMM}.csv`
   - `{DirectoryName}-EVTX-{YYYYMMDDTHHMM}.csv`
   - `{DirectoryName}-Registry-{YYYYMMDDTHHMM}.csv`

## Delete existing index

You can either run the `delete_existing_index.ps1` or do a `docker compose down` adelete the volume manually.

1. Use `Docker Desktop`
2. `docker volume rm <volume_name>`