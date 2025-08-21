FROM ubuntu:22.04

# Install dependencies and PowerShell
RUN dpkg --add-architecture i386 && \
    apt-get update && apt-get install -y \
    wget \
    unzip \
    wine32 \
    wine \
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

# Create working directories
RUN mkdir -p /tools /scripts /data_input /data_output /shared

# Download and install EvtxECmd
WORKDIR /tools
RUN wget https://download.ericzimmermanstools.com/EvtxECmd.zip && \
    unzip EvtxECmd.zip && \
    chmod +x EvtxeCmd/EvtxECmd.exe

# Download latest Maps from Eric Zimmerman's GitHub repository
RUN apt-get update && apt-get install -y git && \
    rm -rf /var/lib/apt/lists/* && \
    git clone --depth=1 --no-checkout https://github.com/EricZimmerman/evtx.git /tmp/evtx-repo && \
    cd /tmp/evtx-repo && \
    git sparse-checkout init --cone && \
    git sparse-checkout set evtx/Maps && \
    git checkout && \
    cp -r evtx/Maps /tools/EvtxeCmd/ && \
    rm -rf /tmp/evtx-repo

# Copy shared upload functions and processing script
COPY upload-functions.ps1 /shared/
COPY process_evtx.sh /scripts/process_evtx.sh
# Normalize line endings and ensure executable
RUN dos2unix /scripts/process_evtx.sh || sed -i 's/\r$//' /scripts/process_evtx.sh \
    && chmod +x /scripts/process_evtx.sh

WORKDIR /data_input
