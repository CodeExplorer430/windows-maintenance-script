# Windows Maintenance Framework - Configuration Guide

This guide provides comprehensive documentation for configuring the Windows Maintenance Framework (v4.1.0).

## Overview

The Windows Maintenance Framework uses a JSON configuration file to control all aspects of maintenance operations. The configuration system is designed to be decoupled from the core logic, supporting **Dependency Injection** for better testability and performance.

---

## Configuration File Location

**Default Location**: `Config/maintenance-config.json`

You can specify a custom configuration path when invoking the maintenance orchestrator:

```powershell
Invoke-WindowsMaintenance -ConfigPath "C:\Custom\maintenance-settings.json"
```

---

## Configuration Structure

### Metadata Section
Fields prefixed with `_` are optional metadata and comments. They are ignored during execution but helpful for documentation.

```json
{
  "_metadata": {
    "version": "4.1.0",
    "description": "Windows Maintenance Framework Configuration - PowerShell 7.4 Optimized",
    "last_updated": "2026-02-13"
  }
}
```

---

## Global Settings

### Paths
| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `LogsPath` | string | `$env:TEMP\WindowsMaintenance\Logs` | Directory for detailed audit logs |
| `ReportsPath` | string | `$env:TEMP\WindowsMaintenance\Reports` | Directory for health and execution reports |

### Resource & Performance
| Setting | Type | Range | Default | Description |
|---------|------|-------|---------|-------------|
| `MaxEventLogSizeMB` | integer | 1-500 | 100 | Threshold for event log archival |
| `MaxParallelJobs` | integer | 1-16 | 4 | **PS 7.4 only**: Number of simultaneous threads |
| `TimeoutMinutes` | integer | 1-240 | 30 | Global operation timeout |

### Global Optimization Flags
| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `ParallelProcessing` | boolean | true | Enables multi-threading on PowerShell 7+ |
| `ValidateHardwareSupport`| boolean | true | Uses CIM to verify TRIM/Defrag capability |
| `SkipExternalDrives` | boolean | true | Prevents maintenance on USB/removable drives |

---

## Enabled Modules

Control which tasks are performed by adding or removing items from this array:

```json
{
  "EnabledModules": [
    "SystemUpdates",
    "DiskMaintenance",
    "SystemHealthRepair",
    "SecurityScans",
    "DeveloperMaintenance",
    "PerformanceOptimization",
    "NetworkMaintenance",
    "GPUMaintenance",
    "EventLogManagement",
    "BackupOperations",
    "SystemReporting"
  ]
}
```

---

## Key Module Settings

### DiskMaintenance
- `EnableWindowsCleanup`: Launches `cleanmgr.exe` with `/sagerun`.
- `AutoEmergencyCleanup`: Triggers aggressive cleanup if free space < `EmergencyThresholdGB`.
- `OptimizeSSDs`: Runs TRIM via `Optimize-Volume`.

### DeveloperMaintenance
Supports automated cleanup for 14+ tools including:
- `EnableNPM`, `EnablePython`, `EnableDocker`, `EnableVSCode`, `EnableDotNetSDK`.
- `NPMCacheRetentionDays`: (Default: 30) - Age of cache files to prune.

### SecurityScans
- `ScanLevel`: "Quick" (default) or "Full".
- `UpdateDefinitionsBeforeScan`: (Default: true) - Synchronizes Windows Defender signatures.

---

## Validation

Always validate your JSON file before deployment to prevent runtime errors:

```powershell
# Run the validation tool
.\Tools\Test-MaintenanceConfig.ps1
```

---

## Best Practices

1.  **Safety First**: Always run a simulation first using `Invoke-WindowsMaintenance -WhatIf`.
2.  **Performance**: If using PowerShell 7.4, ensure `ParallelProcessing` is `true` to significantly reduce execution time.
3.  **Scheduling**: For automated runs, use the `-SilentMode` flag to prevent the script from waiting for user input on non-critical errors.
4.  **Admin Rights**: Ensure your execution environment has Administrator privileges, or many system-level modules will be automatically skipped.

---

**Last Updated**: February 2026
**Version**: 4.1.0
**Author**: Miguel Velasco
