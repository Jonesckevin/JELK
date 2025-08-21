FROM ubuntu:22.04

# Install dependencies and PowerShell
RUN apt-get update && apt-get install -y \
    wget \
    git \
    perl \
    gawk \
    sed \
    sleuthkit \
    cpanminus \
    build-essential \
    curl \
    dos2unix \
    && rm -rf /var/lib/apt/lists/*

# Install PowerShell
RUN wget -q https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && \
    apt-get update && \
    apt-get install -y powershell && \
    rm -rf /var/lib/apt/lists/*

# Install required Perl modules for RegRipper
RUN cpanm Parse::Win32Registry

# Create working directories
RUN mkdir -p /tools /scripts /data_input /data_output /shared

# Download RegRipper
WORKDIR /tools
RUN git clone https://github.com/warewolf/regripper.git

# Make RegRipper tools executable
RUN chmod +x /tools/regripper/rip.pl
RUN find /tools/regripper/plugins -name "*.pl" -exec chmod +x {} \;

# Copy shared upload functions and processing script
COPY upload-functions.ps1 /shared/
COPY process_registry.sh /scripts/process_registry.sh
# Normalize line endings and ensure executable
RUN dos2unix /scripts/process_registry.sh || sed -i 's/\r$//' /scripts/process_registry.sh \
    && chmod +x /scripts/process_registry.sh

WORKDIR /data_input
