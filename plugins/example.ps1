# Example plugin for NetworkDriverTool
# This plugin demonstrates how to extend the tool with custom functionality
# It adds enhanced driver analysis, manufacturer lookup, and additional recommendations

function Invoke-ExamplePlugin {
    Write-Log "Example plugin: Enhanced driver analysis started."

    # Get current driver info
    $drivers = Get-DriverInfo

    # Perform enhanced analysis
    foreach ($driver in $drivers) {
        # Check for known issues
        $issues = Get-KnownDriverIssues -DriverName $driver.Driver -Version $driver.Version
        if ($issues) {
            $driver | Add-Member -NotePropertyName 'KnownIssues' -NotePropertyValue $issues -Force
            Write-Log "Plugin: Found issues for $($driver.Driver): $issues"
        }

        # Lookup manufacturer info
        $manufacturer = Get-DriverManufacturer -HardwareId $driver.HardwareId
        if ($manufacturer) {
            $driver | Add-Member -NotePropertyName 'Manufacturer' -NotePropertyValue $manufacturer -Force
        }

        # Enhanced recommendation
        $enhancedRec = Get-EnhancedRecommendation -Driver $driver
        if ($enhancedRec) {
            $driver.Recommendation = "$($driver.Recommendation) | $enhancedRec"
        }
    }

    Write-Log "Example plugin: Enhanced analysis complete."
}

function Get-KnownDriverIssues {
    param([string]$DriverName, [string]$Version)
    # Mock database of known issues
    $knownIssues = @{
        'Intel Wireless' = @{
            '22.0' = 'Known connectivity issues; update recommended'
        }
        'Realtek Audio' = @{
            '6.0.1' = 'Audio distortion reported; check for updates'
        }
    }

    if ($knownIssues.ContainsKey($DriverName)) {
        $driverIssues = $knownIssues[$DriverName]
        if ($driverIssues.ContainsKey($Version)) {
            return $driverIssues[$Version]
        }
    }
    return $null
}

function Get-DriverManufacturer {
    param([string]$HardwareId)
    # Mock manufacturer lookup
    $manufacturers = @{
        'PCI\VEN_8086' = 'Intel Corporation'
        'PCI\VEN_10EC' = 'Realtek Semiconductor'
        'USB\VID_0BDA' = 'Realtek'
    }

    foreach ($key in $manufacturers.Keys) {
        if ($HardwareId -like "*$key*") {
            return $manufacturers[$key]
        }
    }
    return 'Unknown'
}

function Get-EnhancedRecommendation {
    param($Driver)
    $recs = @()

    # Check version age
    if ($Driver.Version -and [version]::TryParse($Driver.Version, [ref]$null)) {
        $version = [version]$Driver.Version
        if ($version.Major -lt 10) {
            $recs += 'Consider major version update'
        }
    }

    # Check manufacturer support
    if ($Driver.Manufacturer -eq 'Unknown') {
        $recs += 'Verify manufacturer compatibility'
    }

    # Check for known issues
    if ($Driver.KnownIssues) {
        $recs += 'Address known issues'
    }

    return $recs -join '; '
}

# Register plugin
if (-not $global:Plugins) { $global:Plugins = @() }
$global:Plugins += 'Invoke-ExamplePlugin'

Write-Log "Example plugin loaded successfully."