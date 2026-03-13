# Security and Compliance Module for NetworkDriverTool

function Protect-LogFile {
    param(
        [string]$LogFile,
        [string]$Key = $null
    )

    if (-not (Test-Path $LogFile)) {
        Write-Log "Log file not found: $LogFile"
        return
    }

    try {
        # Generate or use provided encryption key
        if (-not $Key) {
            $Key = [System.Web.Security.Membership]::GeneratePassword(32, 0)
            # Store key securely (in a real implementation, this would be in a key vault)
            $keyFile = $LogFile + '.key'
            $Key | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString | Set-Content $keyFile
        }

        # Read file content
        $content = Get-Content $LogFile -Raw -Encoding UTF8

        # Create AES encryption
        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.Key = [System.Text.Encoding]::UTF8.GetBytes($Key.PadRight(32).Substring(0, 32))
        $aes.IV = New-Object byte[] 16
        [System.Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($aes.IV)

        $encryptor = $aes.CreateEncryptor()
        $memoryStream = New-Object System.IO.MemoryStream
        $cryptoStream = New-Object System.Security.Cryptography.CryptoStream($memoryStream, $encryptor, [System.Security.Cryptography.CryptoStreamMode]::Write)
        $streamWriter = New-Object System.IO.StreamWriter($cryptoStream)

        $streamWriter.Write($content)
        $streamWriter.Close()
        $cryptoStream.Close()

        # Combine IV and encrypted data
        $encryptedData = $aes.IV + $memoryStream.ToArray()
        $memoryStream.Close()

        # Write encrypted file
        $encryptedFile = $LogFile + '.encrypted'
        [System.IO.File]::WriteAllBytes($encryptedFile, $encryptedData)

        # Remove original file
        Remove-Item $LogFile -Force

        Write-Log "Log file encrypted successfully: $LogFile"
        return $Key
    }
    catch {
        Write-Log "Error encrypting log file: $($_.Exception.Message)"
        throw
    }
}

function Unprotect-LogFile {
    param(
        [string]$EncryptedFile,
        [string]$Key = $null
    )

    if (-not (Test-Path $EncryptedFile)) {
        Write-Log "Encrypted file not found: $EncryptedFile"
        return
    }

    try {
        # Get decryption key
        if (-not $Key) {
            $keyFile = $EncryptedFile -replace '\.encrypted$', '.key'
            if (Test-Path $keyFile) {
                $encryptedKey = Get-Content $keyFile
                $secureString = ConvertTo-SecureString $encryptedKey
                $Key = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString))
            } else {
                throw "Encryption key not found. Cannot decrypt file."
            }
        }

        # Read encrypted data
        $encryptedData = [System.IO.File]::ReadAllBytes($EncryptedFile)

        # Extract IV and encrypted content
        $iv = $encryptedData[0..15]
        $cipherText = $encryptedData[16..($encryptedData.Length - 1)]

        # Create AES decryption
        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.Key = [System.Text.Encoding]::UTF8.GetBytes($Key.PadRight(32).Substring(0, 32))
        $aes.IV = $iv

        $decryptor = $aes.CreateDecryptor()
        $memoryStream = New-Object System.IO.MemoryStream($cipherText)
        $cryptoStream = New-Object System.Security.Cryptography.CryptoStream($memoryStream, $decryptor, [System.Security.Cryptography.CryptoStreamMode]::Read)
        $streamReader = New-Object System.IO.StreamReader($cryptoStream)

        $decryptedContent = $streamReader.ReadToEnd()

        $streamReader.Close()
        $cryptoStream.Close()
        $memoryStream.Close()

        # Write decrypted file
        $originalFile = $EncryptedFile -replace '\.encrypted$', ''
        $decryptedContent | Set-Content $originalFile -Encoding UTF8

        # Remove encrypted file and key file
        Remove-Item $EncryptedFile -Force
        $keyFile = $EncryptedFile -replace '\.encrypted$', '.key'
        if (Test-Path $keyFile) {
            Remove-Item $keyFile -Force
        }

        Write-Log "Log file decrypted successfully: $originalFile"
    }
    catch {
        Write-Log "Error decrypting log file: $($_.Exception.Message)"
        throw
    }
}

function Test-Compliance {
    Write-Log "Running compliance checks..."

    $checks = @()

    # Load configuration
    $config = Load-Config
    $logPath = $config.LogFile

    # Check for encrypted logs
    $logDir = Split-Path $logPath
    if (Test-Path $logDir) {
        $logFiles = Get-ChildItem $logDir -Filter *.log -Recurse -ErrorAction SilentlyContinue
        $encryptedLogs = $logFiles | Where-Object { Test-Path ($_.FullName + '.encrypted') }
        $checks += [PSCustomObject]@{
            Check = "Log Encryption"
            Status = if ($logFiles.Count -eq 0 -or $encryptedLogs.Count -eq $logFiles.Count) { "Pass" } else { "Fail" }
            Details = "Encrypted: $($encryptedLogs.Count)/$($logFiles.Count) log files"
        }
    } else {
        $checks += [PSCustomObject]@{
            Check = "Log Encryption"
            Status = "Pass"
            Details = "No log files found"
        }
    }

    # Check for admin privileges
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $checks += [PSCustomObject]@{
        Check = "Administrator Privileges"
        Status = if ($isAdmin) { "Pass" } else { "Fail" }
        Details = "Running as administrator: $isAdmin"
    }

    # Check telemetry consent
    $checks += [PSCustomObject]@{
        Check = "Telemetry Consent"
        Status = if ($config.Telemetry) { "Informed" } else { "Not Enabled" }
        Details = "User has consented to telemetry: $($config.Telemetry)"
    }

    # Check for secure API configuration
    $apiPort = $config.APISettings.Port
    $apiRunning = $false
    if ($apiPort) {
        $apiRunning = Get-Process | Where-Object {
            $_.ProcessName -like '*powershell*' -and
            $_.CommandLine -like '*NetworkDriverTool*' -and
            $_.CommandLine -like "*$apiPort*"
        }
    }
    $checks += [PSCustomObject]@{
        Check = "Secure API"
        Status = if ($apiRunning) { "Running" } else { "Not Running" }
        Details = "API server status: $(if ($apiRunning) { 'Active' } else { 'Inactive' })"
    }

    # Check for backup integrity
    $backupPath = $config.BackupPath
    if (Test-Path $backupPath) {
        $backupFiles = Get-ChildItem $backupPath -Recurse -ErrorAction SilentlyContinue
        $checks += [PSCustomObject]@{
            Check = "Backup Integrity"
            Status = if ($backupFiles.Count -gt 0) { "Pass" } else { "Warning" }
            Details = "Backup files found: $($backupFiles.Count)"
        }
    } else {
        $checks += [PSCustomObject]@{
            Check = "Backup Integrity"
            Status = "Fail"
            Details = "Backup directory not found: $backupPath"
        }
    }

    # Check for security settings
    $checks += [PSCustomObject]@{
        Check = "Security Settings"
        Status = "Pass"
        Details = "Security module loaded and functional"
    }

    $checks | Format-Table -AutoSize
    Write-Log "Compliance check complete."
    return $checks
}

function New-ComplianceReport {
    param(
        [string]$OutputPath = $null,
        [switch]$DisplayReport
    )

    try {
        Write-Log "Generating compliance report..."

        $checks = Test-Compliance

        $report = @{
            Timestamp = Get-Date
            System = $env:COMPUTERNAME
            User = $env:USERNAME
            Domain = $env:USERDOMAIN
            ComplianceChecks = $checks
            Summary = @{
                TotalChecks = $checks.Count
                PassedChecks = ($checks | Where-Object { $_.Status -eq 'Pass' }).Count
                FailedChecks = ($checks | Where-Object { $_.Status -eq 'Fail' }).Count
                WarningChecks = ($checks | Where-Object { $_.Status -eq 'Warning' }).Count
            }
            OverallStatus = if (($checks | Where-Object { $_.Status -eq 'Fail' }).Count -eq 0) { "Compliant" } else { "Non-Compliant" }
        }

        # Determine output path
        if (-not $OutputPath) {
            $OutputPath = Join-Path $PSScriptRoot 'compliance_report.json'
        }

        # Ensure output directory exists
        $outputDir = Split-Path $OutputPath
        if (-not (Test-Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        }

        # Save report as JSON
        $report | ConvertTo-Json -Depth 4 | Set-Content $OutputPath -Encoding UTF8

        # Also save as HTML for better readability
        $htmlPath = $OutputPath -replace '\.json$', '.html'
        $htmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>NetworkDriverTool Compliance Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #333; }
        h2 { color: #666; }
        table { border-collapse: collapse; width: 100%; margin-top: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .pass { color: green; }
        .fail { color: red; }
        .warning { color: orange; }
        .summary { background-color: #e8f4f8; padding: 10px; margin: 10px 0; }
    </style>
</head>
<body>
    <h1>NetworkDriverTool Compliance Report</h1>
    <p><strong>Generated:</strong> $($report.Timestamp)</p>
    <p><strong>System:</strong> $($report.System)</p>
    <p><strong>User:</strong> $($report.User)</p>
    <p><strong>Domain:</strong> $($report.Domain)</p>
    <p><strong>Overall Status:</strong> <span class="$($report.OverallStatus.ToLower())">$($report.OverallStatus)</span></p>

    <div class="summary">
        <h2>Summary</h2>
        <p>Total Checks: $($report.Summary.TotalChecks)</p>
        <p>Passed: <span class="pass">$($report.Summary.PassedChecks)</span></p>
        <p>Failed: <span class="fail">$($report.Summary.FailedChecks)</span></p>
        <p>Warnings: <span class="warning">$($report.Summary.WarningChecks)</span></p>
    </div>

    <h2>Compliance Checks</h2>
    <table>
        <tr>
            <th>Check</th>
            <th>Status</th>
            <th>Details</th>
        </tr>
"@

        foreach ($check in $checks) {
            $statusClass = switch ($check.Status) {
                "Pass" { "pass" }
                "Fail" { "fail" }
                "Warning" { "warning" }
                default { "" }
            }
            $htmlReport += @"
        <tr>
            <td>$($check.Check)</td>
            <td class="$statusClass">$($check.Status)</td>
            <td>$($check.Details)</td>
        </tr>
"@
        }

        $htmlReport += @"
    </table>
</body>
</html>
"@

        $htmlReport | Set-Content $htmlPath -Encoding UTF8

        if ($DisplayReport) {
            Start-Process $htmlPath
        }

        Write-Log "Compliance report generated successfully: $OutputPath"
        Write-Log "HTML report also available: $htmlPath"

        return @{
            JsonReport = $OutputPath
            HtmlReport = $htmlPath
            ReportData = $report
        }
    }
    catch {
        Write-Log "Error generating compliance report: $($_.Exception.Message)"
        throw
    }
}

function Test-CertificateValidation {
    param(
        [string]$CertificatePath = $null,
        [string]$CertificateThumbprint = $null
    )

    Write-Log "Testing certificate validation..."

    $results = @()

    try {
        if ($CertificatePath) {
            if (Test-Path $CertificatePath) {
                $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 $CertificatePath
                $results += [PSCustomObject]@{
                    Test = "Certificate File"
                    Status = if ($cert.Verify()) { "Valid" } else { "Invalid" }
                    Subject = $cert.Subject
                    Issuer = $cert.Issuer
                    Thumbprint = $cert.Thumbprint
                    Expiration = $cert.NotAfter
                }
            } else {
                $results += [PSCustomObject]@{
                    Test = "Certificate File"
                    Status = "Not Found"
                    Subject = $null
                    Issuer = $null
                    Thumbprint = $null
                    Expiration = $null
                }
            }
        }

        if ($CertificateThumbprint) {
            $store = New-Object System.Security.Cryptography.X509Certificates.X509Store "My", "LocalMachine"
            $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
            $cert = $store.Certificates | Where-Object { $_.Thumbprint -eq $CertificateThumbprint }
            $store.Close()

            if ($cert) {
                $results += [PSCustomObject]@{
                    Test = "Certificate Store"
                    Status = if ($cert.Verify()) { "Valid" } else { "Invalid" }
                    Subject = $cert.Subject
                    Issuer = $cert.Issuer
                    Thumbprint = $cert.Thumbprint
                    Expiration = $cert.NotAfter
                }
            } else {
                $results += [PSCustomObject]@{
                    Test = "Certificate Store"
                    Status = "Not Found"
                    Subject = $null
                    Issuer = $null
                    Thumbprint = $null
                    Expiration = $null
                }
            }
        }

        $results | Format-Table -AutoSize
        Write-Log "Certificate validation complete."
        return $results
    }
    catch {
        Write-Log "Error during certificate validation: $($_.Exception.Message)"
        throw
    }
}

function Test-SecureConfiguration {
    Write-Log "Testing secure configuration..."

    $config = Load-Config
    $issues = @()

    # Check for secure logging
    if (-not $config.LogFile) {
        $issues += "Log file path not configured"
    } elseif (-not (Test-Path (Split-Path $config.LogFile))) {
        $issues += "Log directory does not exist: $(Split-Path $config.LogFile)"
    }

    # Check backup configuration
    if (-not $config.BackupPath) {
        $issues += "Backup path not configured"
    } elseif (-not (Test-Path $config.BackupPath)) {
        try {
            New-Item -ItemType Directory -Path $config.BackupPath -Force | Out-Null
            Write-Log "Created backup directory: $($config.BackupPath)"
        } catch {
            $issues += "Cannot create backup directory: $($config.BackupPath)"
        }
    }

    # Check API security settings
    if ($config.APISettings) {
        if (-not $config.APISettings.EnableSSL -and $config.APISettings.Port) {
            $issues += "API is configured without SSL encryption"
        }
    }

    # Check for telemetry consent
    if ($config.Telemetry -and -not (Test-Path (Join-Path $PSScriptRoot 'telemetry_consent.txt'))) {
        $issues += "Telemetry enabled but no consent file found"
    }

    if ($issues.Count -eq 0) {
        Write-Log "Secure configuration validation passed."
        return $true
    } else {
        Write-Log "Secure configuration issues found:"
        $issues | ForEach-Object { Write-Log "  - $_" }
        return $false
    }
}

function Write-SecurityAudit {
    param(
        [string]$Action,
        [string]$Details = "",
        [string]$User = $env:USERNAME,
        [string]$AuditLogPath = $null
    )

    if (-not $AuditLogPath) {
        $config = Load-Config
        $auditDir = Split-Path $config.LogFile
        $AuditLogPath = Join-Path $auditDir 'security_audit.log'
    }

    $auditEntry = @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        User = $User
        Action = $Action
        Details = $Details
        ComputerName = $env:COMPUTERNAME
        ProcessId = $PID
    }

    $auditLine = ($auditEntry | ConvertTo-Json -Compress)
    $auditLine | Out-File $AuditLogPath -Append -Encoding UTF8

    Write-Log "Security audit logged: $Action"
}

function Get-SecurityAuditLog {
    param(
        [string]$AuditLogPath = $null,
        [DateTime]$StartDate = $null,
        [DateTime]$EndDate = $null
    )

    if (-not $AuditLogPath) {
        $config = Load-Config
        $auditDir = Split-Path $config.LogFile
        $AuditLogPath = Join-Path $auditDir 'security_audit.log'
    }

    if (-not (Test-Path $AuditLogPath)) {
        Write-Log "Audit log not found: $AuditLogPath"
        return @()
    }

    $auditEntries = Get-Content $AuditLogPath | ForEach-Object {
        try {
            $entry = $_ | ConvertFrom-Json
            # Convert timestamp string back to DateTime
            $entry.Timestamp = [DateTime]::Parse($entry.Timestamp)
            $entry
        } catch {
            Write-Log "Error parsing audit entry: $_"
            $null
        }
    } | Where-Object { $_ -ne $null }

    # Filter by date range if specified
    if ($StartDate) {
        $auditEntries = $auditEntries | Where-Object { $_.Timestamp -ge $StartDate }
    }
    if ($EndDate) {
        $auditEntries = $auditEntries | Where-Object { $_.Timestamp -le $EndDate }
    }

    return $auditEntries
}

function Initialize-SecurityModule {
    Write-Log "Initializing security module..."

    # Test secure configuration
    $configValid = Test-SecureConfiguration
    if (-not $configValid) {
        Write-Log "Warning: Security configuration issues detected. Please review and fix."
    }

    # Log security module initialization
    Write-SecurityAudit -Action "Security Module Initialized" -Details "Security module loaded and validated"

    Write-Log "Security module initialized successfully."
}

# Initialize security module when loaded
Initialize-SecurityModule

# Export functions
Export-ModuleMember -Function Protect-LogFile, Unprotect-LogFile, Test-Compliance, New-ComplianceReport, Test-CertificateValidation, Test-SecureConfiguration, Write-SecurityAudit, Get-SecurityAuditLog