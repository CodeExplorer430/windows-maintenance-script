# Windows Maintenance Framework - Configuration Guide

This guide provides comprehensive documentation for configuring the Windows Maintenance Framework.

## Table of Contents
- [Overview](#overview)
- [Configuration File Location](#configuration-file-location)
- [Configuration Structure](#configuration-structure)
- [Global Settings](#global-settings)
- [Module Configurations](#module-configurations)
- [Advanced Settings](#advanced-settings)
- [Examples](#examples)
- [Validation](#validation)
- [Best Practices](#best-practices)

---

## Overview

The Windows Maintenance Framework uses a JSON configuration file to control all aspects of maintenance operations. The configuration allows you to:

- Enable/disable specific maintenance modules
- Configure paths for logs and reports
- Set timeouts and resource limits
- Customize module-specific behaviors
- Control notification preferences
- Tune performance and safety settings

---

## Configuration File Location

**Default Location**: `config/maintenance-config.json`

You can specify a custom configuration path when invoking the maintenance:

```powershell
Invoke-WindowsMaintenance -ConfigPath "C:\Custom\Path\config.json"
```

---

## Configuration Structure

### Metadata Section

```json
{
  "_metadata": {
    "version": "4.0.0",
    "description": "Windows Maintenance Framework Configuration File - Modular Architecture",
    "last_updated": "2025-10-26",
    "author": "Your Name",
    "notes": "Custom notes about this configuration"
  }
}
```

Fields prefixed with `_` are optional metadata and comments. They are ignored during execution.

---

## Global Settings

### Paths

```json
{
  "LogsPath": "%TEMP%\\WindowsMaintenance\\Logs",
  "ReportsPath": "%TEMP%\\WindowsMaintenance\\Reports"
}
```

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `LogsPath` | string | `%TEMP%\WindowsMaintenance\Logs` | Directory for log files |
| `ReportsPath` | string | `%TEMP%\WindowsMaintenance\Reports` | Directory for report files |

**Supported Path Variables**:
- `%TEMP%` - Temporary directory
- `%USERPROFILE%` - User profile directory
- `%SystemRoot%` - Windows directory
- `%LOCALAPPDATA%` - Local AppData directory

### Resource Limits

```json
{
  "MaxLogSizeMB": 100,
  "MaxBackupDays": 30,
  "MaxEventLogSizeMB": 10,
  "MinFreeSpaceGB": 5,
  "TimeoutMinutes": 30,
  "MaxParallelJobs": 2,
  "MemoryOptimizeInterval": 5
}
```

| Setting | Type | Range | Default | Description |
|---------|------|-------|---------|-------------|
| `MaxLogSizeMB` | integer | 1-1000 | 100 | Maximum log file size |
| `MaxBackupDays` | integer | 1-365 | 30 | Maximum age for backups |
| `MaxEventLogSizeMB` | integer | 1-100 | 10 | Maximum event log size |
| `MinFreeSpaceGB` | integer | 1-100 | 5 | Minimum required free space |
| `TimeoutMinutes` | integer | 1-240 | 30 | General operation timeout |
| `MaxParallelJobs` | integer | 1-8 | 2 | Maximum concurrent operations |
| `MemoryOptimizeInterval` | integer | 1-60 | 5 | Memory cleanup interval (minutes) |

### Global Flags

```json
{
  "DetailedLogging": true,
  "ProgressReporting": true,
  "DriveDetection": true,
  "AutoEventLogArchival": false,
  "Reporting": true,
  "SkipLinuxPartitions": true,
  "SkipNetworkDrives": true,
  "ValidateHardwareSupport": true,
  "EnableFastMode": false,
  "ParallelProcessing": true,
  "AggressiveCleanup": false
}
```

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `DetailedLogging` | boolean | true | Enable verbose logging |
| `ProgressReporting` | boolean | true | Show progress indicators |
| `DriveDetection` | boolean | true | Automatically detect drives |
| `AutoEventLogArchival` | boolean | false | Archive old event logs |
| `Reporting` | boolean | true | Generate reports |
| `SkipLinuxPartitions` | boolean | true | Skip Linux file systems |
| `SkipNetworkDrives` | boolean | true | Skip network drives |
| `ValidateHardwareSupport` | boolean | true | Check hardware compatibility |
| `EnableFastMode` | boolean | false | Reduce checks for faster execution |
| `ParallelProcessing` | boolean | true | Enable parallel operations |
| `AggressiveCleanup` | boolean | false | More aggressive cleanup (use with caution) |

### Enabled Modules

```json
{
  "EnabledModules": [
    "SystemUpdates",
    "DiskMaintenance",
    "SystemHealthRepair",
    "SecurityScans",
    "DeveloperMaintenance",
    "PerformanceOptimization",
    "NetworkMaintenance"
  ]
}
```

**Available Modules**:
- `SystemUpdates` - Windows Update, WinGet, Chocolatey package updates
- `DiskMaintenance` - Disk cleanup, optimization, defragmentation
- `SystemHealthRepair` - DISM, SFC, CHKDSK system repairs
- `SecurityScans` - Windows Defender scans
- `DeveloperMaintenance` - Developer tools cleanup (NPM, Python, Docker, etc.)
- `PerformanceOptimization` - Event logs, startup items, resource analysis
- `NetworkMaintenance` - DNS/ARP cache, network diagnostics

---

## Module Configurations

### SystemHealthRepair

System integrity checking and repair using DISM, SFC, and CHKDSK.

```json
{
  "SystemHealthRepair": {
    "EnableDISM": true,
    "EnableSFC": true,
    "EnableCHKDSK": false,
    "DISMTimeout": 30,
    "SFCTimeout": 20,
    "AutoRepair": true,
    "ScheduleCHKDSKOnErrors": false,
    "SkipDISMIfHealthy": true,
    "SkipSFCIfDISMHealthy": false,
    "GenerateDetailedReports": true,
    "NotifyOnRepairs": true,
    "ForceOfflineScan": false
  }
}
```

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `EnableDISM` | boolean | true | Run DISM component store health check |
| `EnableSFC` | boolean | true | Run System File Checker |
| `EnableCHKDSK` | boolean | false | Schedule disk check (requires restart) |
| `DISMTimeout` | integer | 30 | DISM timeout in minutes (15-45 min typical) |
| `SFCTimeout` | integer | 20 | SFC timeout in minutes (10-30 min typical) |
| `AutoRepair` | boolean | true | Automatically attempt repairs |
| `ScheduleCHKDSKOnErrors` | boolean | false | Schedule CHKDSK if errors found |
| `SkipDISMIfHealthy` | boolean | true | Skip DISM if system is healthy |
| `SkipSFCIfDISMHealthy` | boolean | false | Skip SFC if DISM reports healthy |
| `GenerateDetailedReports` | boolean | true | Generate detailed health reports |
| `NotifyOnRepairs` | boolean | true | Notify when repairs are performed |
| `ForceOfflineScan` | boolean | false | Force offline DISM scan |

**Important Notes**:
- DISM can take 15-45 minutes depending on system size
- SFC can take 10-30 minutes
- CHKDSK requires system restart and runs at boot
- AutoRepair uses `/RestoreHealth` for DISM

### DiskMaintenance

Disk cleanup and optimization operations.

```json
{
  "DiskMaintenance": {
    "EnableCleanup": true,
    "EnableOptimization": true,
    "EnableWindowsCleanup": true,
    "EnableRecycleBinCleanup": false,
    "CleanupLocations": [
      {
        "Path": "%TEMP%",
        "Name": "User Temp",
        "Priority": "High",
        "RetentionDays": 7
      }
    ],
    "OptimizeSSDs": true,
    "DefragmentHDDs": true,
    "AnalyzeBeforeOptimize": true,
    "SkipExternalDrives": false,
    "MinimumFragmentation": 10,
    "EnableTRIM": true,
    "OptimizationPriority": "Normal",
    "CleanupTimeout": 30,
    "EmergencyThresholdGB": 2,
    "AutoEmergencyCleanup": false,
    "StateFlag": 1001
  }
}
```

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `EnableCleanup` | boolean | true | Enable disk cleanup operations |
| `EnableOptimization` | boolean | true | Enable disk optimization |
| `EnableWindowsCleanup` | boolean | true | Use Windows Disk Cleanup utility |
| `EnableRecycleBinCleanup` | boolean | false | Empty Recycle Bin (use with caution) |
| `OptimizeSSDs` | boolean | true | Run TRIM on SSDs |
| `DefragmentHDDs` | boolean | true | Defragment traditional HDDs |
| `AnalyzeBeforeOptimize` | boolean | true | Analyze fragmentation first |
| `SkipExternalDrives` | boolean | false | Skip external/removable drives |
| `MinimumFragmentation` | integer | 10 | Minimum fragmentation % to trigger defrag |
| `EnableTRIM` | boolean | true | Enable TRIM for SSDs |
| `OptimizationPriority` | string | Normal | Priority: Low, Normal, High |
| `CleanupTimeout` | integer | 30 | Cleanup timeout in minutes |
| `EmergencyThresholdGB` | integer | 2 | Trigger emergency cleanup at this free space |
| `AutoEmergencyCleanup` | boolean | false | Automatically run emergency cleanup |
| `StateFlag` | integer | 1001 | Registry StateFlag for cleanup configuration |

**Cleanup Locations**:
```json
{
  "Path": "%TEMP%",
  "Name": "User Temp",
  "Priority": "High",
  "RetentionDays": 7
}
```

- `Path`: Directory to clean (supports environment variables)
- `Name`: Friendly name for logging
- `Priority`: High, Medium, or Low
- `RetentionDays`: Keep files newer than this many days

**Default Cleanup Locations**:
- User Temp Files (`%TEMP%`)
- System Temp Files (`%SystemRoot%\Temp`)
- Windows Update Cache
- Internet Cache
- Windows Log Files
- Local AppData Temp

### SystemUpdates

Windows Update and package manager updates.

```json
{
  "SystemUpdates": {
    "EnableWindowsUpdate": true,
    "EnableWinGet": true,
    "EnableChocolatey": true,
    "AutoInstallUpdates": false,
    "UpdateTimeout": 60,
    "IncludeOptionalUpdates": false,
    "RestartAfterUpdates": false,
    "DownloadOnly": false
  }
}
```

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `EnableWindowsUpdate` | boolean | true | Check for Windows Updates |
| `EnableWinGet` | boolean | true | Update WinGet packages |
| `EnableChocolatey` | boolean | true | Update Chocolatey packages |
| `AutoInstallUpdates` | boolean | false | Automatically install updates (use with caution) |
| `UpdateTimeout` | integer | 60 | Update timeout in minutes |
| `IncludeOptionalUpdates` | boolean | false | Include optional Windows updates |
| `RestartAfterUpdates` | boolean | false | Restart after updates |
| `DownloadOnly` | boolean | false | Only download, don't install |

### SecurityScans

Windows Defender and security scanning.

```json
{
  "SecurityScans": {
    "EnableDefenderScan": true,
    "ScanType": "Quick",
    "DefenderTimeout": 30,
    "EnableSecurityPolicyAudit": false,
    "EnableFirewallCheck": false,
    "SkipIfRecentScan": true,
    "RecentScanThresholdHours": 24,
    "DetectConflictingAV": true,
    "UpdateDefinitionsBeforeScan": true,
    "ScanRemovableDrives": false
  }
}
```

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `EnableDefenderScan` | boolean | true | Run Windows Defender scan |
| `ScanType` | string | Quick | Quick, Full, or Custom |
| `DefenderTimeout` | integer | 30 | Scan timeout in minutes |
| `EnableSecurityPolicyAudit` | boolean | false | Audit security policies |
| `EnableFirewallCheck` | boolean | false | Check firewall status |
| `SkipIfRecentScan` | boolean | true | Skip if recently scanned |
| `RecentScanThresholdHours` | integer | 24 | Hours to consider scan recent |
| `DetectConflictingAV` | boolean | true | Detect conflicting antivirus |
| `UpdateDefinitionsBeforeScan` | boolean | true | Update definitions before scan |
| `ScanRemovableDrives` | boolean | false | Include removable drives |

**Important Notes**:
- Quick scan: 5-15 minutes
- Full scan: 1-3 hours
- Defender will skip if conflicting AV detected
- Automatically updates definitions if enabled

### DeveloperMaintenance

Developer tools and IDE maintenance.

```json
{
  "DeveloperMaintenance": {
    "EnableNPM": true,
    "EnablePython": true,
    "EnableDocker": true,
    "EnableJDK": true,
    "EnableMinGW": false,
    "EnableDotNetSDK": false,
    "EnableWindowsSDK": false,
    "EnableVCRedist": false,
    "EnableComposer": false,
    "EnablePostgreSQL": false,
    "EnableJetBrainsIDEs": false,
    "EnableVisualStudio2022": false,
    "EnableVSCode": false,
    "EnableDatabaseTools": false,
    "EnableAdobeTools": false,
    "EnableVersionControl": true,
    "EnableLegacyCppTools": false,
    "NPMCacheRetentionDays": 30,
    "PythonCacheRetentionDays": 30,
    "DockerCleanupAggressiveness": "Medium",
    "JDKCacheRetentionDays": 90,
    "UpdateDevTools": false
  }
}
```

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `EnableNPM` | boolean | true | Clean NPM cache |
| `EnablePython` | boolean | true | Clean Python cache (`__pycache__`, pip) |
| `EnableDocker` | boolean | true | Docker cleanup (images, containers, volumes) |
| `EnableJDK` | boolean | true | Java development cache cleanup |
| `EnableMinGW` | boolean | false | MinGW compiler cache |
| `EnableDotNetSDK` | boolean | false | .NET SDK cache |
| `EnableWindowsSDK` | boolean | false | Windows SDK cache |
| `EnableVCRedist` | boolean | false | Visual C++ redistributables |
| `EnableComposer` | boolean | false | PHP Composer cache |
| `EnablePostgreSQL` | boolean | false | PostgreSQL logs/temp |
| `EnableJetBrainsIDEs` | boolean | false | JetBrains IDE caches |
| `EnableVisualStudio2022` | boolean | false | Visual Studio cache |
| `EnableVSCode` | boolean | false | VS Code cache |
| `EnableDatabaseTools` | boolean | false | Database tool caches |
| `EnableAdobeTools` | boolean | false | Adobe application caches |
| `EnableVersionControl` | boolean | true | Git cleanup |
| `EnableLegacyCppTools` | boolean | false | Legacy C/C++ tool caches |
| `NPMCacheRetentionDays` | integer | 30 | NPM cache retention |
| `PythonCacheRetentionDays` | integer | 30 | Python cache retention |
| `DockerCleanupAggressiveness` | string | Medium | Low, Medium, or High |
| `JDKCacheRetentionDays` | integer | 90 | JDK cache retention |
| `UpdateDevTools` | boolean | false | Update package managers (npm, pip, etc.) |

**Important Notes**:
- Only enable tools that are actually installed
- Tools not found are safely skipped
- UpdateDevTools may take additional time
- Docker cleanup levels:
  - Low: Dangling images only
  - Medium: Unused images, stopped containers
  - High: All unused resources (use with caution)

### PerformanceOptimization

System performance tuning and optimization.

```json
{
  "PerformanceOptimization": {
    "EnableStartupOptimization": true,
    "EnableEventLogCleanup": true,
    "EnableMemoryOptimization": true,
    "RemoveInvalidStartupItems": true,
    "AnalyzeStartupImpact": true,
    "EnableResourceAnalysis": true,
    "EventLogRetentionDays": 30,
    "MaxEventLogSizeMB": 20
  }
}
```

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `EnableStartupOptimization` | boolean | true | Analyze and optimize startup items |
| `EnableEventLogCleanup` | boolean | true | Clean old event log entries |
| `EnableMemoryOptimization` | boolean | true | Optimize memory usage |
| `RemoveInvalidStartupItems` | boolean | true | Remove broken startup entries |
| `AnalyzeStartupImpact` | boolean | true | Analyze startup impact |
| `EnableResourceAnalysis` | boolean | true | Analyze system resources |
| `EventLogRetentionDays` | integer | 30 | Keep event logs this many days |
| `MaxEventLogSizeMB` | integer | 20 | Maximum event log size |

### NetworkMaintenance

Network diagnostics and maintenance.

```json
{
  "NetworkMaintenance": {
    "EnableDNSCacheClear": true,
    "EnableARPCacheClear": true,
    "EnableNetBIOSCacheClear": true,
    "EnableConnectivityTest": true,
    "EnableAdapterAnalysis": true,
    "EnableWinsockReset": false,
    "ConnectivityTestEndpoints": [
      "8.8.8.8",
      "1.1.1.1",
      "www.google.com",
      "www.microsoft.com"
    ],
    "ConnectivityTimeout": 5,
    "RequireUserConfirmationForWinsockReset": true
  }
}
```

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `EnableDNSCacheClear` | boolean | true | Flush DNS resolver cache |
| `EnableARPCacheClear` | boolean | true | Clear ARP cache |
| `EnableNetBIOSCacheClear` | boolean | true | Clear NetBIOS name cache |
| `EnableConnectivityTest` | boolean | true | Test network connectivity |
| `EnableAdapterAnalysis` | boolean | true | Analyze network adapters |
| `EnableWinsockReset` | boolean | false | Reset Winsock catalog (requires restart) |
| `ConnectivityTestEndpoints` | array | [various] | Endpoints to test connectivity |
| `ConnectivityTimeout` | integer | 5 | Connectivity test timeout (seconds) |
| `RequireUserConfirmationForWinsockReset` | boolean | true | Confirm before Winsock reset |

**Important Notes**:
- DNS, ARP, and NetBIOS cache clearing is safe
- Winsock reset should only be used for persistent network issues
- Winsock reset may require system restart
- Connectivity tests verify both IP and DNS resolution

---

## Advanced Settings

### Notification Settings

```json
{
  "_notification_settings": {
    "ShowMessageBoxes": false,
    "SilentMode": true,
    "NotifyOnErrors": true,
    "NotifyOnCompletion": false,
    "EmailNotifications": false
  }
}
```

### Performance Tuning

```json
{
  "_performance_tuning": {
    "FastMode": false,
    "ReducedTimeout": false,
    "SkipNonCritical": false,
    "ParallelExecution": true,
    "MaxConcurrentOperations": 2
  }
}
```

### Safety Settings

```json
{
  "_safety_settings": {
    "WhatIfMode": false,
    "ValidateBeforeDelete": true,
    "CreateBackupBeforeChanges": true,
    "MinimumDiskSpaceGB": 5,
    "ConfirmDangerousOperations": true
  }
}
```

### Scheduling Preferences

```json
{
  "_scheduling": {
    "RecommendedFrequency": "Weekly",
    "BestExecutionTime": "Off-hours",
    "EstimatedDuration": "30-60 minutes",
    "RequiresRestart": false
  }
}
```

---

## Examples

### Minimal Configuration
```json
{
  "LogsPath": "%TEMP%\\Maintenance\\Logs",
  "ReportsPath": "%TEMP%\\Maintenance\\Reports",
  "EnabledModules": [
    "DiskMaintenance",
    "SecurityScans"
  ]
}
```

### Development Workstation
```json
{
  "EnabledModules": [
    "DiskMaintenance",
    "DeveloperMaintenance",
    "PerformanceOptimization",
    "NetworkMaintenance"
  ],
  "DeveloperMaintenance": {
    "EnableNPM": true,
    "EnablePython": true,
    "EnableDocker": true,
    "EnableVSCode": true,
    "EnableGit": true,
    "UpdateDevTools": true
  }
}
```

### Server Configuration
```json
{
  "EnabledModules": [
    "SystemUpdates",
    "DiskMaintenance",
    "SystemHealthRepair",
    "SecurityScans",
    "PerformanceOptimization"
  ],
  "SystemUpdates": {
    "AutoInstallUpdates": false,
    "DownloadOnly": true
  },
  "_notification_settings": {
    "SilentMode": true,
    "NotifyOnErrors": true
  }
}
```

### Aggressive Cleanup
```json
{
  "AggressiveCleanup": true,
  "DiskMaintenance": {
    "EnableRecycleBinCleanup": true,
    "AutoEmergencyCleanup": true,
    "CleanupLocations": [
      {"Path": "%TEMP%", "RetentionDays": 3},
      {"Path": "%SystemRoot%\\Temp", "RetentionDays": 3}
    ]
  },
  "DeveloperMaintenance": {
    "DockerCleanupAggressiveness": "High",
    "NPMCacheRetentionDays": 7
  }
}
```

---

## Validation

Validate your configuration using the included validation script:

```powershell
.\Scripts\Test-MaintenanceConfig.ps1
```

With detailed output:
```powershell
.\Scripts\Test-MaintenanceConfig.ps1 -Detailed
```

Custom configuration path:
```powershell
.\Scripts\Test-MaintenanceConfig.ps1 -ConfigPath "C:\Custom\config.json"
```

---

## Best Practices

### General
1. **Start Conservative**: Begin with default settings and adjust based on needs
2. **Test First**: Use `-WhatIf` mode to preview changes
3. **Validate Configuration**: Always validate after changes
4. **Backup Configuration**: Keep backup copies of working configurations
5. **Document Changes**: Use the notes field in metadata

### Performance
1. **Adjust Timeouts**: Increase timeouts for slower systems
2. **Limit Parallel Jobs**: Reduce on systems with limited resources
3. **Enable Fast Mode**: Only on reliable, well-maintained systems
4. **Schedule Wisely**: Run during off-hours for best performance

### Safety
1. **Avoid Aggressive Cleanup**: Unless disk space is critical
2. **Test CHKDSK Carefully**: Requires restart, plan accordingly
3. **Backup Before Major Changes**: Especially system health repairs
4. **Monitor First Run**: Watch logs during initial maintenance runs
5. **Keep Recycle Bin**: Don't enable RecycleBinCleanup unless necessary

### Developer Workstations
1. **Enable Only Installed Tools**: Reduces execution time
2. **Adjust Retention Days**: Balance cleanup vs build cache efficiency
3. **Docker Cleanup Level**: Medium for active development
4. **Update Dev Tools Sparingly**: Can interrupt workflow

### Servers
1. **Silent Mode**: Enable for automated execution
2. **Conservative Updates**: Use DownloadOnly for Windows Updates
3. **Extended Timeouts**: Servers may have more data to process
4. **Detailed Logging**: Enable for troubleshooting
5. **Regular Scheduling**: Weekly maintenance recommended

### Troubleshooting
1. **Enable Detailed Logging**: Helps identify issues
2. **Run Modules Individually**: Isolate problems
3. **Check Event Logs**: Review Windows Event Viewer
4. **Validate Configuration**: Ensure JSON is valid
5. **Review Documentation**: Check module-specific notes

---

## Additional Resources

- **Main Documentation**: See README.md
- **Testing Documentation**: See Tests/README.md
- **JSON Schema**: config/maintenance-config.schema.json
- **Validation Script**: Scripts/Test-MaintenanceConfig.ps1
- **Example Configurations**: Examples directory (if available)

---

## Support

For issues, questions, or contributions:
- Review logs in the LogsPath directory
- Check Windows Event Viewer
- Validate configuration using Test-MaintenanceConfig.ps1
- Review module documentation in source files

---

**Last Updated**: October 2025
**Version**: 4.0.0
**Author**: Miguel Velasco
