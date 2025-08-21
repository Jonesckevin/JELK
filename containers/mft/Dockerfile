FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    python3 \
    python3-pip \
    sleuthkit \
    sed \
    dos2unix \
    && rm -rf /var/lib/apt/lists/*

# Create working directories
RUN mkdir -p /tools /scripts /data_input /data_output /shared

# Download and install MFTECmd
WORKDIR /tools
RUN wget https://download.ericzimmermanstools.com/MFTECmd.zip && \
    unzip MFTECmd.zip && \
    chmod +x MFTECmd.exe

# Install Wine to run Windows executables and PowerShell
RUN dpkg --add-architecture i386 && \
    apt-get update && apt-get install -y \
    wine32 \
    wine \
    wget \
    cabextract \
    curl \
    sed \
    dos2unix \
    && rm -rf /var/lib/apt/lists/*

# Install PowerShell
RUN wget -q https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && \
    apt-get update && \
    apt-get install -y powershell && \
    rm -rf /var/lib/apt/lists/*

# Install Wine Mono manually
RUN cd /tmp && \
    wget https://dl.winehq.org/wine/wine-mono/8.1.0/wine-mono-8.1.0-x86.msi && \
    WINEDLLOVERRIDES="mscoree=d" wineboot --init && \
    wine msiexec /i wine-mono-8.1.0-x86.msi /quiet

# Copy shared upload functions and processing script
COPY upload-functions.ps1 /shared/
COPY process_mft.sh /scripts/process_mft.sh
# Normalize line endings (handle potential CRLF) and ensure executable
RUN dos2unix /scripts/process_mft.sh || sed -i 's/\r$//' /scripts/process_mft.sh \
    && chmod +x /scripts/process_mft.sh

WORKDIR /data_input
