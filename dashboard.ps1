# Web Dashboard for NetworkDriverTool using PowerShell Universal

# Note: This requires PowerShell Universal to be installed
# Install-Module Universal -Scope CurrentUser

function New-Dashboard {
    $dashboard = New-UDDashboard -Title "Advanced Driver Management" -Content {
        New-UDRow {
            New-UDColumn -Size 6 {
                New-UDCard -Title "Driver Statistics" -Content {
                    $stats = Get-AnalyticsDashboard
                    New-UDTable -Data $stats -Columns @(
                        New-UDTableColumn -Property TotalDrivers -Title "Total Drivers"
                        New-UDTableColumn -Property InstalledDrivers -Title "Installed"
                        New-UDTableColumn -Property MissingDrivers -Title "Missing"
                        New-UDTableColumn -Property HighRiskDrivers -Title "High Risk"
                    )
                }
            }
            New-UDColumn -Size 6 {
                New-UDCard -Title "Quick Actions" -Content {
                    New-UDButton -Text "Check Drivers" -OnClick {
                        $drivers = Get-DriverInfo
                        Show-UDToast -Message "Driver check complete. Found $($drivers.Count) drivers."
                    }
                    New-UDButton -Text "Backup Drivers" -OnClick {
                        Backup-Drivers -Drivers (Get-DriverInfo)
                        Show-UDToast -Message "Backup complete."
                    }
                    New-UDButton -Text "Health Check" -OnClick {
                        Health-Check
                        Show-UDToast -Message "Health check complete."
                    }
                }
            }
        }
        New-UDRow {
            New-UDColumn -Size 12 {
                New-UDCard -Title "Driver List" -Content {
                    $drivers = Get-DriverInfo
                    New-UDTable -Data $drivers -Columns @(
                        New-UDTableColumn -Property Driver -Title "Driver"
                        New-UDTableColumn -Property Status -Title "Status"
                        New-UDTableColumn -Property Version -Title "Version"
                        New-UDTableColumn -Property Recommendation -Title "Recommendation"
                    )
                }
            }
        }
    }

    return $dashboard
}

function Start-WebDashboard {
    param([int]$Port = 8081)
    Write-Log "Starting web dashboard on port $Port..."
    try {
        $dashboard = New-Dashboard
        Start-UDDashboard -Dashboard $dashboard -Port $Port -Wait
    } catch {
        Write-Log "Dashboard requires PowerShell Universal. Install with: Install-Module Universal"
    }
}

# Export functions
Export-ModuleMember -Function Start-WebDashboard