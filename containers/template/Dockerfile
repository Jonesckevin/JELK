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

# TODO: Download and install your forensic tool here
# Example:
# WORKDIR /tools
# RUN wget https://example.com/your-tool.zip && \
#     unzip your-tool.zip && \
#     chmod +x your-tool/YourTool.exe

# TODO: Copy any configuration files or maps
# Example:
# COPY config/ /tools/your-tool/config/

# Copy shared upload functions and processing script
COPY upload-functions.ps1 /shared/
COPY process_YOUR_PARSER_NAME.sh /scripts/
RUN chmod +x /scripts/process_YOUR_PARSER_NAME.sh

WORKDIR /data_input

# TODO: Set default command or entry point
CMD ["/scripts/process_YOUR_PARSER_NAME.sh"]
