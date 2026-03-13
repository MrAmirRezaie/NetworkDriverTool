# Advanced Driver Management Tool

An ultra-advanced, unique PowerShell script with AI-like recommendations, GUI interface, backup/restore capabilities, health monitoring, and self-updating features for comprehensive driver management.

**Author:** MrAmirRezaie

## Features

- **AI-Powered Recommendations:** Intelligent suggestions for driver actions based on status and version analysis.
- **Graphical User Interface:** Modern GUI with interactive data grid, one-click actions, and real-time updates.
- **Driver Backup & Restore:** Parallel backup and restore of drivers with full disaster recovery.
- **System Health Monitoring:** Advanced analysis of Windows Event Logs for driver-related issues and system metrics.
- **Flexible Reporting:** Export comprehensive reports in CSV or HTML with custom styling.
- **Self-Updating Mechanism:** Automatic version checking and update downloads from GitHub.
- **Configuration Management:** JSON-based config file for persistent user settings and themes.
- **Advanced Caching:** Optimized PSCustomObject caching with timestamps and hardware IDs.
- **Multi-Mode Operation:** CLI, GUI, backup, restore, health check, and testing modes.
- **Progress Tracking:** Real-time progress bars and detailed performance logging.
- **Parallel Processing:** Runspace-based parallel driver scanning and installation for speed.
- **Plugin System:** Extensible architecture with custom plugins.
- **Internationalization:** Culture-specific localization support.
- **Telemetry & Analytics:** Opt-in usage tracking for improvement.
- **Driver Signature Verification:** Security checks for driver authenticity.
- **Performance Profiling:** Detailed execution time measurement and logging.
- **Error Resilience:** Comprehensive error handling and telemetry reporting.
- **Unique Architecture:** Uses PowerShell classes, runspaces, and advanced cmdlets for unparalleled functionality.

## Requirements

- Windows 10/11
- PowerShell 5.1 or higher (.NET Framework for GUI)
- Internet connection (for updates and Windows Update)
- Administrator privileges

## Usage

Run as Administrator:

```powershell
.\NetworkDriverTool.ps1 [parameters]
```

### Parameters

- `-AllDevices`: Check all PnP devices instead of just network adapters.
- `-LogFile <path>`: Specify a log file path.
- `-NoRestart`: Skip automatic system restart.
- `-DriverPath <path>`: Path to local driver INF files.
- `-GUI`: Launch graphical interface.
- `-Backup`: Backup current drivers.
- `-Restore`: Restore drivers from backup.
- `-BackupPath <path>`: Custom backup directory.
- `-HealthCheck`: Perform system health analysis.
- `-ExportReport <path>`: Export report (CSV or HTML).
- `-SelfUpdate`: Check for tool updates.
- `-RunTests`: Execute Pester tests.
- `-EnableTelemetry`: Enable usage telemetry.
- `-Api`: Start REST API server.
- `-ApiPort <port>`: Port for REST API (default 8080).
- `-Schedule`: Create scheduled task for daily runs.
- `-ScheduleTime <time>`: Time for scheduled task (default 02:00).
- `-DarkMode`: Enable dark theme.
- `-EmailTo <email>`: Send report via email.
- `-SmtpServer <server>`: SMTP server for email.
- `-Voice`: Enable voice command recognition and feedback.
- `-Dashboard`: Start web-based dashboard (requires PowerShell Universal).
- `-DashboardPort <port>`: Port for web dashboard (default 8081).
- `-Analytics`: Run predictive failure analysis.
- `-Compliance`: Perform security and compliance checks.

### Examples

- GUI Mode: `.\NetworkDriverTool.ps1 -GUI`
- Backup Drivers: `.\NetworkDriverTool.ps1 -Backup`
- Health Check: `.\NetworkDriverTool.ps1 -HealthCheck`
- Export HTML Report: `.\NetworkDriverTool.ps1 -ExportReport report.html`
- Full Scan with Logging: `.\NetworkDriverTool.ps1 -AllDevices -LogFile C:\logs\driver.log -ExportReport report.csv`
- Start REST API: `.\NetworkDriverTool.ps1 -Api -ApiPort 9090`
- Schedule Daily Run: `.\NetworkDriverTool.ps1 -Schedule -ScheduleTime 03:00`
- Email Report: `.\NetworkDriverTool.ps1 -ExportReport report.html -EmailTo admin@company.com -SmtpServer smtp.company.com`
- Run Tests: `.\NetworkDriverTool.ps1 -RunTests`
- Voice Commands: `.\NetworkDriverTool.ps1 -Voice`
- Web Dashboard: `.\NetworkDriverTool.ps1 -Dashboard`
- Predictive Analytics: `.\NetworkDriverTool.ps1 -Analytics`
- Compliance Check: `.\NetworkDriverTool.ps1 -Compliance`
- Help: `.\NetworkDriverTool.ps1 -Help`

## Configuration

Edit `config.json` to set defaults:
- `LogFile`: Default log file path
- `AutoBackup`: Enable automatic backups
- `Telemetry`: Opt-in for usage analytics (future feature)

## GUI Features

- Interactive device list with status indicators
- One-click driver installation
- Backup controls
- Real-time status updates
- Color-coded recommendations

## Unique Capabilities

- **AI Recommendations:** Analyzes driver versions and status to provide actionable insights.
- **Self-Healing:** Automatic backup before changes, with rollback options.
- **Comprehensive Monitoring:** Event log analysis for proactive issue detection.
- **Modular Design:** Easily extensible with new features via PowerShell classes.
- **Enterprise-Ready:** Supports offline installations, custom backups, and detailed reporting.

## Voice Interaction

Use `-Voice` to enable speech recognition and synthesis. Say commands like:
- "check drivers"
- "backup drivers"
- "health check"
- "install missing"
- "show gui"

## Web Dashboard

Requires PowerShell Universal. Provides a web-based interface for monitoring and management.

## Predictive Analytics

Uses machine learning-like algorithms to predict driver failure risks and provide proactive recommendations.

## Security & Compliance

Includes log encryption, compliance reporting, and security audits for enterprise environments.

## Docker Deployment

### Build and Run with Docker Compose
```bash
# Build and start the container
docker-compose up -d

# View logs
docker-compose logs -f

# Stop the container
docker-compose down
```

### Manual Docker Commands
```bash
# Build the image
docker build -t network-driver-tool .

# Run the container
docker run -p 8080:8080 -v C:\DriverData:/app/data network-driver-tool -API
```

### Environment Variables
- `API_PORT`: Port for REST API (default: 8080)
- `LOG_LEVEL`: Logging verbosity (Info, Warning, Error)
- `BACKUP_PATH`: Path for driver backups inside container