# Dockerfile for NetworkDriverTool
FROM mcr.microsoft.com/powershell:latest

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Copy all files
COPY . .

# Create necessary directories
RUN mkdir -p /app/logs /app/DriverBackup /app/data

# Install required PowerShell modules
RUN pwsh -Command "& { \
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted; \
    Install-Module -Name Pester -Force -Scope AllUsers; \
    Write-Host 'Modules installed successfully' \
}"

# Make scripts executable
RUN chmod +x NetworkDriverTool.ps1

# Create non-root user for security
RUN useradd -m -s /bin/bash appuser && chown -R appuser:appuser /app
USER appuser

# Expose ports for API and Dashboard
EXPOSE 8080 8081

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD pwsh -Command "& { \
        try { \
            $response = Invoke-WebRequest -Uri http://localhost:8080/health -TimeoutSec 10; \
            if ($response.StatusCode -eq 200) { exit 0 } else { exit 1 } \
        } catch { exit 1 } \
    }"

# Set entrypoint with proper command handling
ENTRYPOINT ["pwsh"]
CMD ["-File", "NetworkDriverTool.ps1", "-Api", "-Dashboard"]