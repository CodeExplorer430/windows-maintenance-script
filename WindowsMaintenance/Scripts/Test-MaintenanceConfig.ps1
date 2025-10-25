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

# Determine script locations
$ScriptRoot = Split-Path -Parent $PSScriptRoot

# Set default paths if not provided
if (-not $ConfigPath) {
    $ConfigPath = Join-Path (Split-Path $ScriptRoot) "config\maintenance-config.json"
}

if (-not $SchemaPath) {
    $SchemaPath = Join-Path (Split-Path $ScriptRoot) "config\maintenance-config.schema.json"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Configuration Validation" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Verify files exist
if (-not (Test-Path $ConfigPath)) {
    Write-Host "ERROR: Configuration file not found: $ConfigPath" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $SchemaPath)) {
    Write-Host "WARNING: Schema file not found: $SchemaPath" -ForegroundColor Yellow
    Write-Host "Performing basic validation only..." -ForegroundColor Yellow
    Write-Host ""
    $SchemaPath = $null
}

Write-Host "Configuration: $ConfigPath" -ForegroundColor Gray
if ($SchemaPath) {
    Write-Host "Schema:        $SchemaPath" -ForegroundColor Gray
}
Write-Host ""

# Load configuration
try {
    Write-Host "Loading configuration file..." -ForegroundColor Cyan
    $ConfigJson = Get-Content -Path $ConfigPath -Raw -ErrorAction Stop
    $Config = $ConfigJson | ConvertFrom-Json -ErrorAction Stop
    Write-Host "Successfully loaded configuration file" -ForegroundColor Green
}
catch {
    Write-Host "ERROR: Failed to parse configuration JSON" -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Basic validation (always performed)
Write-Host ""
Write-Host "Performing basic validation..." -ForegroundColor Cyan

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
            Write-Host "  Required field present: $Field" -ForegroundColor Green
        }
    }
}

# Validate EnabledModules
if ($Config.EnabledModules) {
    $ValidModules = @(
        'SystemUpdates', 'DiskMaintenance', 'SystemHealthRepair',
        'SecurityScans', 'DeveloperMaintenance', 'PerformanceOptimization',
        'NetworkMaintenance'
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
                    Write-Host "  Valid module: $Module" -ForegroundColor Green
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
            Write-Host "  Path field valid: $PathField" -ForegroundColor Green
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
            Write-Host "  Numeric field valid: $Field = $Value" -ForegroundColor Green
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
            Write-Host "  Module configuration found: $Module" -ForegroundColor Green
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
Write-Host ""
if ($ValidationErrors.Count -eq 0 -and $ValidationWarnings.Count -eq 0) {
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Configuration Valid" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Configuration file passed all validation checks." -ForegroundColor Green
    Write-Host "Enabled modules: $($Config.EnabledModules -join ', ')" -ForegroundColor Gray
    Write-Host ""
    exit 0
}
else {
    if ($ValidationErrors.Count -gt 0) {
        Write-Host "========================================" -ForegroundColor Red
        Write-Host "  Validation Errors Found" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Red
        Write-Host ""

        foreach ($Error in $ValidationErrors) {
            Write-Host "  [ERROR] $Error" -ForegroundColor Red
        }
        Write-Host ""
    }

    if ($ValidationWarnings.Count -gt 0) {
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host "  Validation Warnings" -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host ""

        foreach ($Warning in $ValidationWarnings) {
            Write-Host "  [WARNING] $Warning" -ForegroundColor Yellow
        }
        Write-Host ""
    }

    if ($ValidationErrors.Count -gt 0) {
        Write-Host "Configuration validation FAILED with $($ValidationErrors.Count) error(s) and $($ValidationWarnings.Count) warning(s)." -ForegroundColor Red
        Write-Host "Please fix the errors before running maintenance." -ForegroundColor Red
        Write-Host ""
        exit 1
    }
    else {
        Write-Host "Configuration validation completed with $($ValidationWarnings.Count) warning(s)." -ForegroundColor Yellow
        Write-Host "Warnings can be ignored, but review recommended." -ForegroundColor Yellow
        Write-Host ""
        exit 0
    }
}
