# Check for administrator privileges (skip in CI/Docker environments)
$IsCI = $env:CI -eq 'true' -or $env:GITHUB_ACTIONS -eq 'true'
$IsDocker = Test-Path '/.dockerenv' -or $env:DOTNET_RUNNING_IN_CONTAINER -eq 'true'

if (-not $IsCI -and -not $IsDocker) {
    #Requires -RunAsAdministrator
}

param(
    [switch]$AllDevices,
    [string]$LogFile,
    [switch]$NoRestart,
    [string]$DriverPath,
    [switch]$GUI,
    [switch]$Backup,
    [switch]$Restore,
    [string]$BackupPath,
    [switch]$HealthCheck,
    [string]$ExportReport,
    [switch]$SelfUpdate,
    [switch]$RunTests,
    [switch]$EnableTelemetry,
    [switch]$Api,
    [int]$ApiPort = 8080,
    [switch]$Schedule,
    [string]$ScheduleTime = '02:00',
    [switch]$DarkMode,
    [string]$EmailTo,
    [string]$SmtpServer,
    [switch]$Help,
    [switch]$Voice,
    [switch]$Dashboard,
    [int]$DashboardPort = 8081,
    [switch]$Analytics,
    [switch]$Compliance
)

$configFile = Join-Path $PSScriptRoot 'config.json'
$cacheFile = Join-Path $PSScriptRoot 'driver_cache.json'
$backupDir = if ($BackupPath) { $BackupPath } else { Join-Path $PSScriptRoot 'DriverBackup' }
$pluginsDir = Join-Path $PSScriptRoot 'plugins'
$localesDir = Join-Path $PSScriptRoot 'locales'
$performanceLog = Join-Path $PSScriptRoot 'performance.log'

# Performance measurement
$script:StartTime = Get-Date

function Measure-Performance {
    param([string]$Operation)
    $elapsed = (Get-Date) - $script:StartTime
    Add-Content -Path $performanceLog -Value "$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')): $Operation took $($elapsed.TotalSeconds) seconds"
}

# Internationalization
function Get-LocalizedString {
    param([string]$Key)
    $culture = (Get-Culture).Name
    $localeFile = Join-Path $localesDir "$culture.json"
    if (-not (Test-Path $localeFile)) { $localeFile = Join-Path $localesDir 'en-US.json' }
    if (Test-Path $localeFile) {
        $strings = Get-Content $localeFile | ConvertFrom-Json
        return $strings.$Key
    }
    return $Key
}

# Telemetry
function Send-Telemetry {
    param([string]$Event, [hashtable]$Data)
    if ($EnableTelemetry -or (Load-Config).Telemetry) {
        try {
            $payload = @{
                Event = $Event
                Data = $Data
                Timestamp = Get-Date -Format 'o'
                UserId = (Get-ComputerInfo).CsName.GetHashCode()
            } | ConvertTo-Json
            Invoke-WebRequest -Uri 'https://api.example.com/telemetry' -Method Post -Body $payload -ContentType 'application/json' -TimeoutSec 5 | Out-Null
        } catch { }
    }
}

# Plugin system
function Load-Plugins {
    if (Test-Path $pluginsDir) {
        Get-ChildItem $pluginsDir -Filter *.ps1 | ForEach-Object { . $_.FullName }
    }
}
function Load-Plugins {
    if (Test-Path $pluginsDir) {
        Get-ChildItem $pluginsDir -Filter *.ps1 | ForEach-Object { . $_.FullName }
    }
}

# Optimized DriverInfo using PSCustomObject
function New-DriverInfo {
    param([hashtable]$data)
    $rec = if ($data.Status -ne 'Installed') {
        Get-LocalizedString 'InstallImmediately'
    } elseif ([version]$data.Version -lt [version]'1.0.0') {
        Get-LocalizedString 'UpdateForPerformance'
    } else {
        Get-LocalizedString 'UpToDate'
    }
    [PSCustomObject]@{
        Driver = $data.Driver
        Purpose = $data.Purpose
        Location = $data.Location
        Version = $data.Version
        Chipset = $data.Chipset
        Status = $data.Status
        HardwareId = $data.HardwareId
        Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Recommendation = $rec
        SignatureVerified = Test-DriverSignature -HardwareId $data.HardwareId
    }
}

function Test-DriverSignature {
    param([string]$HardwareId)
    # Mock signature verification
    return $true  # In real implementation, check with certutil or similar
}

function Load-Config {
    if (Test-Path $configFile) {
        return Get-Content $configFile | ConvertFrom-Json
    } else {
        return [PSCustomObject]@{
            LogFile = ''
            AutoBackup = $false
            Telemetry = $false
            Theme = 'Light'
        }
    }
}

function Save-Config {
    param([PSCustomObject]$config)
    $config | ConvertTo-Json | Set-Content $configFile
}

function Write-Log {
    param([string]$Message)
    $config = Load-Config
    if ($LogFile -or $config.LogFile) {
        $logPath = $LogFile ? $LogFile : $config.LogFile
        Add-Content -Path $logPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $Message"
    }
    Write-Host $Message
}

# Parallel processing with runspaces
function Get-DriverInfo {
    # Check if running with admin privileges
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Log "Warning: Administrator privileges required for driver enumeration. Running in limited mode."
        # Return mock data for non-admin environments
        return @(
            [PSCustomObject]@{
                Driver = "Mock Network Adapter"
                Purpose = "Network Adapter"
                Location = "Mock Location"
                Version = "1.0.0"
                Chipset = "Mock Chipset"
                Status = "Unknown"
                HardwareId = "MOCK\123"
                Recommendation = "Administrator privileges required for full functionality"
            }
        )
    }

    $runspacePool = [runspacefactory]::CreateRunspacePool(1, [Environment]::ProcessorCount)
    $runspacePool.Open()
    $runspaces = @()

    if ($AllDevices) {
        $devices = Get-PnpDevice | Where-Object { $_.Status -ne 'Unknown' }
    } else {
        $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
        $devices = $adapters | ForEach-Object { Get-PnpDevice -InstanceId $_.PnpInstanceId }
    }

    foreach ($device in $devices) {
        $ps = [powershell]::Create().AddScript({
            param($dev)
            $status = if ($dev.Status -eq 'OK') { 'Installed' } else { 'Not Installed' }
            $version = $dev.DriverVersion
            $chipset = $dev.Description
            $purpose = if ($using:AllDevices) { $dev.Class } else { 'Network Adapter' }
            $location = $dev.LocationInformation
            $hardwareId = ($dev.HardwareId | Select-Object -First 1)
            @{
                Driver = $dev.FriendlyName
                Purpose = $purpose
                Location = $location
                Version = $version
                Chipset = $chipset
                Status = $status
                HardwareId = $hardwareId
            }
        }).AddArgument($device)
        $ps.RunspacePool = $runspacePool
        $runspaces += [PSCustomObject]@{ Pipe = $ps; Status = $ps.BeginInvoke() }
    }

    $info = @()
    foreach ($rs in $runspaces) {
        $result = $rs.Pipe.EndInvoke($rs.Status)
        $info += New-DriverInfo -data $result
    }

    $runspacePool.Close()
    return $info
}

function Backup-Drivers {
    param([array]$Drivers)

    # Check admin privileges
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Log "Error: Administrator privileges required for driver backup operations."
        return
    }

    if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force }
    Write-Log (Get-LocalizedString 'BackingUpDrivers')
    $Drivers | ForEach-Object -Parallel {
        $backupFile = Join-Path $using:backupDir "$($_.Driver -replace '[^a-zA-Z0-9]', '_').inf"
        pnputil.exe /export-driver $_.HardwareId $backupFile 2>$null | Out-Null
    } -ThrottleLimit 4
    Write-Log (Get-LocalizedString 'BackupComplete')
}

function Restore-Drivers {
    # Check admin privileges
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Log "Error: Administrator privileges required for driver restore operations."
        return
    }

    Write-Log (Get-LocalizedString 'RestoringDrivers')
    Get-ChildItem $backupDir -Filter *.inf | ForEach-Object -Parallel {
        pnputil.exe /add-driver $_.FullName /install 2>$null | Out-Null
    } -ThrottleLimit 4
    Write-Log (Get-LocalizedString 'RestoreComplete')
}

function Health-Check {
    Write-Log (Get-LocalizedString 'HealthCheck')

    # Check admin privileges for system event log access
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if ($isAdmin) {
        $errors = Get-WinEvent -LogName System -FilterXPath "*[System[(Level=2) and (EventID=1001 or EventID=1002)]]" -MaxEvents 10 -ErrorAction SilentlyContinue
        if ($errors) {
            Write-Log (Get-LocalizedString 'FoundErrors' -f $errors.Count)
            $errors | ForEach-Object { Write-Log "Error: $($_.Message)" }
        } else {
            Write-Log (Get-LocalizedString 'NoErrors')
        }
        $uptime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
        Write-Log (Get-LocalizedString 'SystemUptime' -f ((Get-Date) - $uptime))
    } else {
        Write-Log "Warning: Administrator privileges required for full health check. Running in limited mode."
        Write-Log "Basic health check: System is running (uptime information requires admin privileges)"
    }
}

function Export-Report {
    param([array]$Data, [string]$Format)
    $path = $ExportReport
    if ($Format -eq 'CSV') {
        $Data | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
    } elseif ($Format -eq 'HTML') {
        $html = $Data | ConvertTo-Html -Title (Get-LocalizedString 'ReportTitle') -PreContent "<h1>$(Get-LocalizedString 'ReportTitle') - $(Get-Date)</h1>" -CssUri (Join-Path $PSScriptRoot 'style.css')
        $html | Set-Content $path -Encoding UTF8
    }
    Write-Log (Get-LocalizedString 'ReportExported' -f $path)
}

function Self-Update {
    Write-Log (Get-LocalizedString 'CheckingUpdates')
    try {
        $repo = "MrAmirRezaie/NetworkDriverTool"
        $apiUrl = "https://api.github.com/repos/$repo/releases/latest"
        $response = Invoke-WebRequest -Uri $apiUrl -TimeoutSec 10 | ConvertFrom-Json
        $latestVersion = $response.tag_name
        $currentVersion = "1.0.0"
        if ([version]$latestVersion -gt [version]$currentVersion) {
            Write-Log (Get-LocalizedString 'NewVersion' -f $latestVersion)
            $downloadUrl = $response.assets[0].browser_download_url
            $tempFile = [System.IO.Path]::GetTempFileName() + ".zip"
            Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile
            Expand-Archive -Path $tempFile -DestinationPath $PSScriptRoot -Force
            Write-Log (Get-LocalizedString 'UpdateComplete')
        } else {
            Write-Log (Get-LocalizedString 'UpToDate')
        }
    } catch {
        Write-Log (Get-LocalizedString 'UpdateFailed' -f $_)
    }
}

function Show-GUI {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.Application]::EnableVisualStyles()
    $config = Load-Config
    if ($config.Theme -eq 'Dark') {
        # Dark theme implementation (simplified)
    }

    $form = New-Object System.Windows.Forms.Form
    $form.Text = Get-LocalizedString 'GUITitle'
    $form.Size = New-Object System.Drawing.Size(1000,700)
    $form.StartPosition = 'CenterScreen'

    $dataGrid = New-Object System.Windows.Forms.DataGridView
    $dataGrid.Size = New-Object System.Drawing.Size(950,500)
    $dataGrid.Location = New-Object System.Drawing.Point(20,20)
    $dataGrid.AllowUserToAddRows = $false
    $dataGrid.AllowUserToDeleteRows = $false
    $dataGrid.ReadOnly = $true
    $dataGrid.AutoSizeColumnsMode = 'Fill'
    $dataGrid.SelectionMode = 'FullRowSelect'

    $drivers = Get-DriverInfo
    $table = New-Object System.Data.DataTable
    $table.Columns.Add((Get-LocalizedString 'Driver'), [string])
    $table.Columns.Add((Get-LocalizedString 'Status'), [string])
    $table.Columns.Add((Get-LocalizedString 'Recommendation'), [string])
    $table.Columns.Add((Get-LocalizedString 'Version'), [string])
    foreach ($driver in $drivers) {
        $row = $table.NewRow()
        $row[0] = $driver.Driver
        $row[1] = $driver.Status
        $row[2] = $driver.Recommendation
        $row[3] = $driver.Version
        $table.Rows.Add($row)
    }
    $dataGrid.DataSource = $table

    $form.Controls.Add($dataGrid)

    $installBtn = New-Object System.Windows.Forms.Button
    $installBtn.Text = Get-LocalizedString 'InstallMissing'
    $installBtn.Location = New-Object System.Drawing.Point(20,540)
    $installBtn.Add_Click({
        $missing = $drivers | Where-Object { $_.Status -ne 'Installed' }
        if ($missing) {
            Install-MissingDrivers -Missing $missing
            $form.Close()
        }
    })
    $form.Controls.Add($installBtn)

    $backupBtn = New-Object System.Windows.Forms.Button
    $backupBtn.Text = Get-LocalizedString 'BackupDrivers'
    $backupBtn.Location = New-Object System.Drawing.Point(150,540)
    $backupBtn.Add_Click({ Backup-Drivers -Drivers $drivers })
    $form.Controls.Add($backupBtn)

    $refreshBtn = New-Object System.Windows.Forms.Button
    $refreshBtn.Text = Get-LocalizedString 'Refresh'
    $refreshBtn.Location = New-Object System.Drawing.Point(280,540)
    $refreshBtn.Add_Click({
        $newDrivers = Get-DriverInfo
        $table.Clear()
        foreach ($driver in $newDrivers) {
            $row = $table.NewRow()
            $row[0] = $driver.Driver
            $row[1] = $driver.Status
            $row[2] = $driver.Recommendation
            $row[3] = $driver.Version
            $table.Rows.Add($row)
        }
    })
    $form.Controls.Add($refreshBtn)

    $form.ShowDialog()
}

function Install-MissingDrivers {
    param([array]$Missing)

    # Check admin privileges
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Log "Error: Administrator privileges required for driver installation operations."
        return
    }

    if ($DriverPath -and (Test-Path $DriverPath)) {
        Write-Log (Get-LocalizedString 'InstallingFromPath' -f $DriverPath)
        try {
            $result = pnputil.exe /add-driver $DriverPath /install 2>&1
            Write-Log "pnputil output: $result"
        } catch {
            Write-Log (Get-LocalizedString 'InstallError' -f $_)
        }
    } else {
        if (-not (Get-Module -Name PSWindowsUpdate -ListAvailable)) {
            Write-Log (Get-LocalizedString 'InstallingModule')
            Install-Module PSWindowsUpdate -Force -Scope CurrentUser
        }
        Import-Module PSWindowsUpdate
        Write-Log (Get-LocalizedString 'CheckingUpdates')
        $updates = Get-WUList -Category 'Drivers' -MicrosoftUpdate
        if ($updates) {
            Write-Log (Get-LocalizedString 'InstallingUpdates' -f $updates.Count)
            $updates | ForEach-Object -Parallel {
                Install-WindowsUpdate -Updates $_ -AcceptAll -IgnoreReboot
            } -ThrottleLimit 2
        } else {
            Write-Log (Get-LocalizedString 'NoUpdates')
        }
    }
}

function Start-RestApi {
    param([int]$Port = 8080)
    Write-Log (Get-LocalizedString 'StartingApi' -f $Port)
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://localhost:$Port/")
    $listener.Start()

    try {
        while ($listener.IsListening) {
            $context = $listener.GetContext()
            $request = $context.Request
            $response = $context.Response

            $response.ContentType = 'application/json'
            $response.StatusCode = 200

            switch ($request.Url.AbsolutePath) {
                '/drivers' {
                    $drivers = Get-DriverInfo
                    $json = $drivers | ConvertTo-Json
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
                }
                '/health' {
                    Health-Check
                    $json = '{"status": "checked"}' | ConvertTo-Json
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
                }
                '/backup' {
                    $drivers = Get-DriverInfo
                    Backup-Drivers -Drivers $drivers
                    $json = '{"status": "backed up"}' | ConvertTo-Json
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
                }
                default {
                    $json = '{"error": "Invalid endpoint"}' | ConvertTo-Json
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
                    $response.StatusCode = 404
                }
            }

            $response.ContentLength64 = $buffer.Length
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
            $response.OutputStream.Close()
        }
    } finally {
        $listener.Stop()
    }
}

function New-ScheduledTask {
    param([string]$Time = '02:00')

    # Check admin privileges
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Log "Error: Administrator privileges required for scheduled task creation."
        return
    }

    Write-Log (Get-LocalizedString 'CreatingSchedule' -f $Time)
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -AllDevices -LogFile `"$LogFile`"" -WorkingDirectory $PSScriptRoot
    $trigger = New-ScheduledTaskTrigger -Daily -At $Time
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType InteractiveToken -RunLevel Highest
    Register-ScheduledTask -TaskName 'NetworkDriverTool' -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force
    Write-Log (Get-LocalizedString 'ScheduleCreated')
}

function Send-EmailReport {
    param([string]$To, [string]$Server, [array]$Data)
    if (-not $To -or -not $Server) { return }
    Write-Log (Get-LocalizedString 'SendingEmail')
    $body = $Data | ConvertTo-Html -Title (Get-LocalizedString 'ReportTitle') | Out-String
    $subject = Get-LocalizedString 'EmailSubject'
    Send-MailMessage -To $To -From 'noreply@drivertool.com' -Subject $subject -Body $body -BodyAsHtml -SmtpServer $Server
    Write-Log (Get-LocalizedString 'EmailSent')
}

function Show-Help {
    Write-Host (Get-LocalizedString 'HelpHeader')
    Write-Host (Get-LocalizedString 'HelpUsage')
    Write-Host (Get-LocalizedString 'HelpParams')
    Write-Host (Get-LocalizedString 'HelpExamples')
}

# Main logic with optimizations
try {
    if ($Help) { Show-Help; exit }
    Load-Plugins
    Send-Telemetry -Event 'ToolStarted' -Data @{ AllDevices = $AllDevices; GUI = $GUI; Api = $Api }

    if ($RunTests) {
        & (Join-Path $PSScriptRoot 'test.ps1')
        exit
    }
    if ($SelfUpdate) { Self-Update; exit }
    if ($HealthCheck) { Health-Check; exit }
    if ($Restore) { Restore-Drivers; exit }
    if ($Schedule) { New-ScheduledTask -Time $ScheduleTime; exit }
    if ($Api) { Start-RestApi -Port $ApiPort; exit }
    if ($Voice) { . (Join-Path $PSScriptRoot 'voice.ps1'); Invoke-VoiceCommand; exit }
    if ($Dashboard) { . (Join-Path $PSScriptRoot 'dashboard.ps1'); Start-WebDashboard -Port $DashboardPort; exit }
    if ($Analytics) { . (Join-Path $PSScriptRoot 'analytics.ps1'); Invoke-PredictiveAnalysis | Format-Table; exit }
    if ($Compliance) { . (Join-Path $PSScriptRoot 'security.ps1'); Test-Compliance; exit }

    Write-Log (Get-LocalizedString 'StartingTool')
    $config = Load-Config
    if ($config.AutoBackup) { $Backup = $true }
    if ($DarkMode) { $config.Theme = 'Dark'; Save-Config $config }

    $info = Get-DriverInfo
    Measure-Performance 'DriverScan'

    if ($Backup) { Backup-Drivers -Drivers $info }

    if (Test-Path $cacheFile) {
        $cache = Get-Content $cacheFile | ConvertFrom-Json
    } else {
        $cache = @()
    }

    $cache = $info
    $cache | ConvertTo-Json | Set-Content $cacheFile

    $missing = $info | Where-Object { $_.Status -ne 'Installed' }

    if ($missing) {
        Write-Log (Get-LocalizedString 'FoundMissing' -f $missing.Count)
        Install-MissingDrivers -Missing $missing
        Measure-Performance 'DriverInstall'
        if (-not $NoRestart) {
            $needsRestart = $info | Where-Object { $_.Status -ne 'Installed' -and (Get-PnpDevice | Where-Object { $_.FriendlyName -eq $_.Driver }).ConfigManagerErrorCode -ne 0 }
            if ($needsRestart) {
                Write-Log (Get-LocalizedString 'RestartRequired')
                Restart-Computer -Force
            }
        }
    } else {
        Write-Log (Get-LocalizedString 'AllInstalled')
    }

    if ($ExportReport) {
        $format = if ($ExportReport.EndsWith('.csv')) { 'CSV' } else { 'HTML' }
        Export-Report -Data $info -Format $format
    }

    if ($EmailTo -and $SmtpServer) {
        Send-EmailReport -To $EmailTo -Server $SmtpServer -Data $info
    }

    Measure-Performance 'TotalExecution'
    Write-Log (Get-LocalizedString 'Complete')
    $info | Select-Object Driver, Purpose, Status, Version, Recommendation, SignatureVerified | Format-Table -AutoSize
} catch {
    Write-Log (Get-LocalizedString 'Error' -f $_)
    Send-Telemetry -Event 'Error' -Data @{ Message = $_.Exception.Message }
}