# Windows Maintenance Module

Comprehensive Windows maintenance and optimization framework with modular architecture for PowerShell 5.1+.

## Overview

The Windows Maintenance Module provides automated maintenance across multiple system areas including updates, disk management, security, performance optimization, system health, and developer tools. Built with a modular architecture for maintainability, extensibility, and enterprise-grade reliability.

## Features

### Core Capabilities
- **Modular Architecture**: Clean separation of concerns with dedicated modules for each maintenance area
- **Comprehensive Logging**: Enterprise-grade logging with multiple levels and detailed operation tracking
- **WhatIf Mode**: Safe testing without making actual changes
- **Memory Management**: Intelligent memory optimization throughout execution
- **Error Handling**: Robust error recovery and detailed error reporting
- **Configuration**: JSON-based configuration for easy customization
- **Real-time Progress**: Live output for long-running operations

### Maintenance Modules

#### 1. System Updates
- Windows Update management with PSWindowsUpdate
- WinGet package manager updates with real-time output
- Chocolatey package management with enhanced error handling
- Package conflict detection and resolution
- Security update prioritization

#### 2. Disk Maintenance
- Intelligent disk cleanup with age-based retention
- Windows Disk Cleanup (cleanmgr) automation
- Emergency cleanup for low disk space
- SSD TRIM operations
- HDD defragmentation with fragmentation analysis
- External drive detection
- Linux partition detection

#### 3. System Health Repair
- DISM operations (ScanHealth, CheckHealth, RestoreHealth)
- System File Checker (SFC) with detailed result parsing
- CHKDSK scheduling for disk health
- Comprehensive health reporting
- Real-time progress for long-running repairs

#### 4. Security Scans
- Windows Defender signature updates
- Configurable scan levels (Quick, Full, Custom)
- No timeout restrictions for thorough scanning
- Scan conflict detection and prevention
- Firewall status validation
- Security update verification

#### 5. Developer Maintenance
- **Package Managers**: NPM, pip, Composer
- **Container Platforms**: Docker cleanup
- **Development SDKs**: JDK, .NET SDK, Windows SDK, MinGW
- **IDEs**: JetBrains suite, Visual Studio, VS Code
- **Database Tools**: MySQL, PostgreSQL, XAMPP, WAMP
- **Design Tools**: Adobe suite, Figma
- **Version Control**: Git, GitHub Desktop
- **API Tools**: Postman
- Security vulnerability scanning for NPM packages

#### 6. Performance Optimization
- Event log size analysis and management
- Startup item validation and cleanup
- Invalid startup entry removal
- System resource analysis (CPU, Memory, Disk I/O)
- Process resource consumption reporting
- Performance baseline establishment

### Common Modules

#### Logging (`Logging.psm1`)
- Multiple log levels: INFO, WARNING, ERROR, SUCCESS, DEBUG, PROGRESS, DETAIL, SKIP
- Color-coded console output
- Multiple file outputs for different log levels
- Performance metrics logging
- Detailed operation tracking

#### Memory Management (`MemoryManagement.psm1`)
- Automatic garbage collection
- Standard and aggressive cleanup modes
- Memory pressure detection
- Adaptive memory thresholds

#### Safe Execution (`SafeExecution.psm1`)
- Command wrapper with error handling
- Timeout protection
- Performance metrics
- Context preservation

#### UI Helpers (`UIHelpers.psm1`)
- Message box management
- Silent mode support
- Progress notifications
- Risk assessment dialogs

#### String Formatting (`StringFormatting.psm1`)
- Safe parameter substitution
- Injection prevention
- File size formatting
- NaN/Infinity handling

#### System Detection (`SystemDetection.psm1`)
- Multi-method hardware detection
- Memory information
- Fallback mechanisms

#### Real-time Progress Output (`RealTimeProgressOutput.psm1`)
- Live command output streaming
- Progress bar integration
- Color-coded output
- Timeout protection

#### Drive Analysis (`DriveAnalysis.psm1`)
- SSD/HDD/External drive detection
- TRIM capability validation
- Caching with 5-minute timeout
- Linux partition detection

## Installation

### Method 1: Direct Installation
```powershell
# Copy the WindowsMaintenance folder to your PowerShell modules directory
Copy-Item -Path ".\WindowsMaintenance" -Destination "$env:USERPROFILE\Documents\PowerShell\Modules\" -Recurse -Force
```

### Method 2: Import from Custom Location
```powershell
# Import directly from the module directory
Import-Module "C:\Path\To\WindowsMaintenance\WindowsMaintenance.psd1" -Force
```

## Configuration

The module uses a JSON configuration file located at `Config\maintenance-config.json`.

### Configuration Structure
```json
{
  "EnabledModules": [
    "SystemUpdates",
    "DiskMaintenance",
    "SystemHealthRepair",
    "SecurityScans",
    "DeveloperMaintenance",
    "PerformanceOptimization"
  ],
  "LogsPath": "C:\\Maintenance\\Logs",
  "ReportsPath": "C:\\Maintenance\\Reports",
  "MaxEventLogSizeMB": 100,
  "DiskCleanup": {
    "TemporaryFilesRetentionDays": 7,
    "RecycleBinRetentionDays": 14,
    "DownloadsRetentionDays": 30,
    "EmergencyCleanupThresholdMB": 2048
  },
  "SecurityScans": {
    "ScanLevel": "Quick",
    "UpdateDefinitions": true
  }
}
```

### Configuration Options

- **EnabledModules**: Array of module names to execute
- **LogsPath**: Directory for log files
- **ReportsPath**: Directory for generated reports
- **MaxEventLogSizeMB**: Threshold for event log size warnings
- **DiskCleanup**: Disk maintenance settings
- **SecurityScans**: Security scan configuration

## Usage

### Basic Usage
```powershell
# Import the module
Import-Module WindowsMaintenance

# Run with default configuration
Invoke-WindowsMaintenance
```

### Custom Configuration
```powershell
# Run with custom configuration file
Invoke-WindowsMaintenance -ConfigPath "C:\MyConfig\maintenance-config.json"
```

### WhatIf Mode (Safe Testing)
```powershell
# Test what would be done without making changes
Invoke-WindowsMaintenance -WhatIf
```

### Silent Mode
```powershell
# Run without message boxes
Invoke-WindowsMaintenance -SilentMode
```

### Verbose Output
```powershell
# Enable verbose logging
Invoke-WindowsMaintenance -Verbose
```

### Combined Options
```powershell
# Combine options for different scenarios
Invoke-WindowsMaintenance -ConfigPath ".\Config\maintenance-config.json" -WhatIf -Verbose
```

## Examples

### Example 1: Weekly Maintenance
```powershell
# Create a weekly maintenance configuration
$config = @{
    EnabledModules = @(
        "SystemUpdates",
        "DiskMaintenance",
        "SecurityScans"
    )
    LogsPath = "C:\Maintenance\Logs"
    ReportsPath = "C:\Maintenance\Reports"
} | ConvertTo-Json

$config | Out-File ".\weekly-config.json"

# Run weekly maintenance
Invoke-WindowsMaintenance -ConfigPath ".\weekly-config.json"
```

### Example 2: Developer Workstation Maintenance
```powershell
# Focus on developer tools
$config = @{
    EnabledModules = @(
        "DeveloperMaintenance",
        "DiskMaintenance",
        "PerformanceOptimization"
    )
} | ConvertTo-Json

$config | Out-File ".\dev-config.json"

Invoke-WindowsMaintenance -ConfigPath ".\dev-config.json"
```

### Example 3: Quick Security Check
```powershell
# Security-focused maintenance
$config = @{
    EnabledModules = @(
        "SystemUpdates",
        "SecurityScans",
        "SystemHealthRepair"
    )
} | ConvertTo-Json

$config | Out-File ".\security-config.json"

Invoke-WindowsMaintenance -ConfigPath ".\security-config.json"
```

## Requirements

- **PowerShell**: Version 5.1 or higher
- **Privileges**: Administrator rights required
- **Operating System**: Windows 10/11 or Windows Server 2016+
- **.NET Framework**: 4.5 or higher (usually pre-installed)

### Optional Components
- **PSWindowsUpdate**: For Windows Update management
- **WinGet**: For package management
- **Chocolatey**: For package management
- **Docker**: For container cleanup
- **Node.js/NPM**: For NPM package updates
- **Python/pip**: For Python package updates

## Logs and Reports

### Log Files
Logs are stored in the configured `LogsPath` directory:
- `maintenance_YYYYMMDD_HHmmss.log`: Main maintenance log
- `maintenance_errors_YYYYMMDD_HHmmss.log`: Error-specific log
- `maintenance_warnings_YYYYMMDD_HHmmss.log`: Warning-specific log

### Reports
Reports are stored in the configured `ReportsPath` directory:
- `event_log_analysis_*.txt`: Event log size analysis
- `startup_analysis_*.txt`: Startup item analysis
- `process_analysis_*.txt`: System resource analysis
- `system_health_report_*.txt`: System health status
- `disk_optimization_report_*.txt`: Disk optimization results

## Troubleshooting

### Module Import Errors
```powershell
# Check module path
$env:PSModulePath -split ';'

# Import with full path
Import-Module "C:\Full\Path\To\WindowsMaintenance\WindowsMaintenance.psd1" -Force
```

### Permission Issues
```powershell
# Verify administrator privileges
([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# Run PowerShell as Administrator
Start-Process PowerShell -Verb RunAs
```

### Configuration Issues
```powershell
# Validate JSON configuration
Get-Content ".\Config\maintenance-config.json" | ConvertFrom-Json

# Use default configuration
Invoke-WindowsMaintenance  # Will use built-in defaults if config file not found
```

### Memory Issues
The module includes automatic memory management, but for systems with limited resources:
```powershell
# Disable specific resource-intensive modules
# Edit maintenance-config.json and remove modules from EnabledModules array
```

## Best Practices

1. **Test First**: Always use `-WhatIf` mode before running on production systems
2. **Schedule Wisely**: Run during off-hours to minimize user impact
3. **Monitor Logs**: Regularly review logs for warnings and errors
4. **Backup Important Data**: Always maintain backups before maintenance
5. **Start Small**: Enable only necessary modules initially
6. **Review Reports**: Check generated reports for system health insights
7. **Update Regularly**: Keep the module updated for latest features and fixes

## Architecture

```
WindowsMaintenance/
├── WindowsMaintenance.psm1          # Root orchestrator module
├── WindowsMaintenance.psd1          # Module manifest
├── Config/
│   └── maintenance-config.json      # Configuration file
├── Modules/
│   ├── Common/                      # Common utility modules
│   │   ├── Logging.psm1
│   │   ├── MemoryManagement.psm1
│   │   ├── SafeExecution.psm1
│   │   ├── UIHelpers.psm1
│   │   ├── StringFormatting.psm1
│   │   ├── SystemDetection.psm1
│   │   ├── RealTimeProgressOutput.psm1
│   │   └── DriveAnalysis.psm1
│   ├── SystemUpdates.psm1           # Windows Update, WinGet, Chocolatey
│   ├── DiskMaintenance.psm1         # Disk cleanup and optimization
│   ├── SystemHealthRepair.psm1      # DISM, SFC, CHKDSK
│   ├── SecurityScans.psm1           # Windows Defender scans
│   ├── DeveloperMaintenance.psm1    # Developer tools maintenance
│   └── PerformanceOptimization.psm1 # Performance tuning
├── Tests/
│   ├── Unit/                        # Unit tests
│   └── Integration/                 # Integration tests
└── README.md                        # This file
```

## Version History

### v4.0.0 (October 2025)
- Complete modular refactoring
- Enhanced logging framework
- Real-time progress output
- Developer tools maintenance
- Performance optimization module
- Improved error handling
- Comprehensive documentation

### v3.x
- Monolithic script with all features
- Basic logging
- Windows Update support
- Disk cleanup features

## Contributing

Contributions are welcome! Please ensure:
1. Follow PowerShell best practices
2. Include comprehensive XML documentation
3. Test on multiple Windows versions
4. Update README with new features
5. Maintain backward compatibility

## License

Copyright (c) 2025 Miguel Velasco. All rights reserved.

## Support

For issues, questions, or feature requests:
1. Check the logs in the configured LogsPath
2. Review this README
3. Test with `-WhatIf` mode
4. Check module dependencies

## Acknowledgments

Built following PowerShell best practices and enterprise design patterns for maintainability, reliability, and performance.
