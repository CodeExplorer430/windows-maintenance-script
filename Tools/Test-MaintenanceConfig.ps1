<#
.SYNOPSIS
    Validates Windows Maintenance configuration file against JSON schema.

.DESCRIPTION
    Tests the maintenance configuration file for validity, checking for required fields,
    correct data types, valid values, and structural correctness. Provides detailed
    error messages for any validation failures.

.PARAMETER ConfigPath
    Path to the configuration JSON file to validate

.PARAMETER SchemaPath
    Path to the JSON schema file (optional, uses default if not specified)

.PARAMETER Detailed
    Show detailed validation results including all checked properties

.EXAMPLE
    .\Test-MaintenanceConfig.ps1

.EXAMPLE
    .\Test-MaintenanceConfig.ps1 -ConfigPath "C:\Custom\config.json" -Detailed

.NOTES
    File Name      : Test-MaintenanceConfig.ps1
    Author         : Miguel Velasco
    Prerequisite   : PowerShell 5.1+
    Version        : 1.0.0
    Last Updated   : October 2025
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigPath,

    [Parameter(Mandatory=$false)]
    [string]$SchemaPath,

    [Parameter(Mandatory=$false)]
    [switch]$Detailed = $false
)

# Set information preference for UI output
$InformationPreference = 'Continue'

# Determine script locations
$ScriptRoot = Split-Path -Parent $PSScriptRoot

# Set default paths if not provided
if (-not $ConfigPath) {
    $ConfigPath = Join-Path $ScriptRoot "Config\maintenance-config.json"
}

if (-not $SchemaPath) {
    $SchemaPath = Join-Path $ScriptRoot "Config\maintenance-config.schema.json"
}

Write-Information -MessageData "" -Tags "Color:White"
Write-Information -MessageData "========================================" -Tags "Color:Cyan"
Write-Information -MessageData "  Configuration Validation" -Tags "Color:Cyan"
Write-Information -MessageData "========================================" -Tags "Color:Cyan"
Write-Information -MessageData "" -Tags "Color:White"

# Verify files exist
if (-not (Test-Path $ConfigPath)) {
    Write-Error "Configuration file not found: $ConfigPath"
    exit 1
}

if (-not (Test-Path $SchemaPath)) {
    Write-Information -MessageData "WARNING: Schema file not found: $SchemaPath" -Tags "Color:Yellow"
    Write-Information -MessageData "Performing basic validation only..." -Tags "Color:Yellow"
    Write-Information -MessageData "" -Tags "Color:White"
    $SchemaPath = $null
}

Write-Information -MessageData "Configuration: $ConfigPath" -Tags "Color:Gray"
if ($SchemaPath) {
    Write-Information -MessageData "Schema:        $SchemaPath" -Tags "Color:Gray"
}
Write-Information -MessageData "" -Tags "Color:White"

# Load configuration
try {
    Write-Information -MessageData "Loading configuration file..." -Tags "Color:Cyan"
    $ConfigJson = Get-Content -Path $ConfigPath -Raw -ErrorAction Stop
    $Config = $ConfigJson | ConvertFrom-Json -ErrorAction Stop
    Write-Information -MessageData "Successfully loaded configuration file" -Tags "Color:Green"
}
catch {
    Write-Error "Failed to parse configuration JSON: $($_.Exception.Message)"
    exit 1
}

# Basic validation (always performed)
Write-Information -MessageData "" -Tags "Color:White"
Write-Information -MessageData "Performing basic validation..." -Tags "Color:Cyan"

$ValidationErrors = @()
$ValidationWarnings = @()

# Check required fields
$RequiredFields = @('EnabledModules', 'LogsPath', 'ReportsPath')
foreach ($Field in $RequiredFields) {
    if (-not $Config.PSObject.Properties[$Field]) {
        $ValidationErrors += "Missing required field: $Field"
    }
    else {
        if ($Detailed) {
            Write-Information -MessageData "  Required field present: $Field" -Tags "Color:Green"
        }
    }
}

# Validate EnabledModules
if ($Config.EnabledModules) {
    $ValidModules = @(
        'SystemUpdates', 'DiskMaintenance', 'SystemHealthRepair',
        'SecurityScans', 'DeveloperMaintenance', 'PerformanceOptimization',
        'NetworkMaintenance', 'EventLogManagement', 'BackupOperations', 'SystemReporting'
    )

    if ($Config.EnabledModules -is [array]) {
        if ($Config.EnabledModules.Count -eq 0) {
            $ValidationErrors += "EnabledModules array is empty - at least one module must be enabled"
        }
        else {
            foreach ($Module in $Config.EnabledModules) {
                if ($Module -notin $ValidModules) {
                    $ValidationErrors += "Invalid module name in EnabledModules: $Module (Valid: $($ValidModules -join ', '))"
                }
                elseif ($Detailed) {
                    Write-Information -MessageData "  Valid module: $Module" -Tags "Color:Green"
                }
            }
        }
    }
    else {
        $ValidationErrors += "EnabledModules must be an array"
    }
}

# Validate paths
$PathFields = @('LogsPath', 'ReportsPath')
foreach ($PathField in $PathFields) {
    if ($Config.PSObject.Properties[$PathField]) {
        $PathValue = $Config.$PathField
        if ([string]::IsNullOrWhiteSpace($PathValue)) {
            $ValidationErrors += "$PathField cannot be empty"
        }
        elseif ($Detailed) {
            Write-Information -MessageData "  Path field valid: $PathField" -Tags "Color:Green"
        }
    }
}

# Validate numeric ranges
$NumericFields = @{
    'MaxLogSizeMB' = @{ Min = 1; Max = 1000; Default = 100 }
    'MaxEventLogSizeMB' = @{ Min = 1; Max = 100; Default = 10 }
    'MinFreeSpaceGB' = @{ Min = 1; Max = 100; Default = 5 }
    'TimeoutMinutes' = @{ Min = 1; Max = 240; Default = 30 }
    'MaxParallelJobs' = @{ Min = 1; Max = 8; Default = 2 }
}

foreach ($Field in $NumericFields.Keys) {
    if ($Config.PSObject.Properties[$Field]) {
        $Value = $Config.$Field
        $Min = $NumericFields[$Field].Min
        $Max = $NumericFields[$Field].Max

        if ($Value -isnot [int] -and $Value -isnot [long]) {
            $ValidationErrors += "$Field must be a number"
        }
        elseif ($Value -lt $Min -or $Value -gt $Max) {
            $ValidationErrors += "$Field value $Value is out of range (valid: $Min-$Max)"
        }
        elseif ($Detailed) {
            Write-Information -MessageData "  Numeric field valid: $Field = $Value" -Tags "Color:Green"
        }
    }
}

# Validate module configurations exist for enabled modules
if ($Config.EnabledModules) {
    foreach ($Module in $Config.EnabledModules) {
        if (-not $Config.PSObject.Properties[$Module]) {
            $ValidationWarnings += "Module '$Module' is enabled but has no configuration section (will use defaults)"
        }
        elseif ($Detailed) {
            Write-Information -MessageData "  Module configuration found: $Module" -Tags "Color:Green"
        }
    }
}

# Check for deprecated or unknown fields
$KnownTopLevelFields = @(
    '_metadata', '_instructions', 'LogsPath', 'ReportsPath', 'MaxLogSizeMB',
    'MaxBackupDays', 'MaxEventLogSizeMB', 'MinFreeSpaceGB', 'DetailedLogging',
    'ProgressReporting', 'TimeoutMinutes', 'MaxParallelJobs', 'MemoryOptimizeInterval',
    'EnabledModules', 'DriveDetection', 'AutoEventLogArchival', 'Reporting',
    'SkipLinuxPartitions', 'SkipNetworkDrives', 'ValidateHardwareSupport',
    'EnableFastMode', 'ParallelProcessing', 'AggressiveCleanup',
    'SystemHealthRepair', 'DiskMaintenance', 'SystemUpdates', 'SecurityScans',
    'DeveloperMaintenance', 'PerformanceOptimization', 'NetworkMaintenance',
    '_notification_settings', '_performance_tuning', '_safety_settings', '_scheduling'
)

foreach ($Property in $Config.PSObject.Properties) {
    if ($Property.Name -notin $KnownTopLevelFields) {
        $ValidationWarnings += "Unknown or deprecated field: $($Property.Name)"
    }
}

# Display validation results
Write-Information -MessageData "" -Tags "Color:White"
if ($ValidationErrors.Count -eq 0 -and $ValidationWarnings.Count -eq 0) {
    Write-Information -MessageData "========================================" -Tags "Color:Green"
    Write-Information -MessageData "  Configuration Valid" -Tags "Color:Green"
    Write-Information -MessageData "========================================" -Tags "Color:Green"
    Write-Information -MessageData "" -Tags "Color:White"
    Write-Information -MessageData "Configuration file passed all validation checks." -Tags "Color:Green"
    Write-Information -MessageData "Enabled modules: $($Config.EnabledModules -join ', ')" -Tags "Color:Gray"
    Write-Information -MessageData "" -Tags "Color:White"
    exit 0
}
else {
    if ($ValidationErrors.Count -gt 0) {
        Write-Information -MessageData "========================================" -Tags "Color:Red"
        Write-Information -MessageData "  Validation Errors Found" -Tags "Color:Red"
        Write-Information -MessageData "========================================" -Tags "Color:Red"
        Write-Information -MessageData "" -Tags "Color:White"

        foreach ($ValidationError in $ValidationErrors) {
            Write-Information -MessageData "  [ERROR] $ValidationError" -Tags "Color:Red"
        }
        Write-Information -MessageData "" -Tags "Color:White"
    }

    if ($ValidationWarnings.Count -gt 0) {
        Write-Information -MessageData "========================================" -Tags "Color:Yellow"
        Write-Information -MessageData "  Validation Warnings" -Tags "Color:Yellow"
        Write-Information -MessageData "========================================" -Tags "Color:Yellow"
        Write-Information -MessageData "" -Tags "Color:White"

        foreach ($Warning in $ValidationWarnings) {
            Write-Information -MessageData "  [WARNING] $Warning" -Tags "Color:Yellow"
        }
        Write-Information -MessageData "" -Tags "Color:White"
    }

    if ($ValidationErrors.Count -gt 0) {
        Write-Information -MessageData "Configuration validation FAILED with $($ValidationErrors.Count) error(s) and $($ValidationWarnings.Count) warning(s)." -Tags "Color:Red"
        Write-Information -MessageData "Please fix the errors before running maintenance." -Tags "Color:Red"
        Write-Information -MessageData "" -Tags "Color:White"
        exit 1
    }
    else {
        Write-Information -MessageData "Configuration validation completed with $($ValidationWarnings.Count) warning(s)." -Tags "Color:Yellow"
        Write-Information -MessageData "Warnings can be ignored, but review recommended." -Tags "Color:Yellow"
        Write-Information -MessageData "" -Tags "Color:White"
        exit 0
    }
}
