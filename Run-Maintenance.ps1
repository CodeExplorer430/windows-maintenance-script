<#
.SYNOPSIS
    Standalone launcher for the Windows Maintenance Framework.

.DESCRIPTION
    This script provides a simple, standalone way to run the Windows Maintenance Framework
    without manually importing modules or managing paths. It handles all the setup
    automatically and provides clear feedback about the maintenance process.

    The script will:
    - Check for Administrator privileges
    - Import the WindowsMaintenance module
    - Load the configuration
    - Execute the maintenance tasks
    - Display summary results

.PARAMETER ConfigPath
    Path to custom configuration file. If not specified, uses the default configuration
    located at WindowsMaintenance\config\maintenance-config.json

.PARAMETER WhatIf
    Runs the maintenance in simulation mode without making any actual changes.
    Useful for testing or seeing what would be done.

.PARAMETER DetailedOutput
    Enables comprehensive detailed logging to separate log files for enterprise auditing.

.PARAMETER ManageEventLogs
    Enables automatic event log optimization including archival and cleanup operations.

.PARAMETER ScanLevel
    Controls Windows Defender scan intensity.
    Valid values: "Quick", "Full", "Custom"
    Default: "Quick"

.PARAMETER ShowMessageBoxes
    Enables interactive GUI notifications and confirmations during execution.

.PARAMETER SilentMode
    Enables unattended execution with no user interaction required.

.PARAMETER SkipExternalDrives
    Prevents optimization operations on external USB drives and removable media.

.PARAMETER FastMode
    Reduces operation timeouts and skips non-critical maintenance for faster execution.

.EXAMPLE
    .\Run-Maintenance.ps1
    Runs maintenance with default settings.

.EXAMPLE
    .\Run-Maintenance.ps1 -WhatIf
    Simulates maintenance without making changes.

.EXAMPLE
    .\Run-Maintenance.ps1 -ConfigPath ".\examples\config-developer.json"
    Runs maintenance using a custom configuration.

.EXAMPLE
    .\Run-Maintenance.ps1 -DetailedOutput -ManageEventLogs
    Runs with detailed logging and event log management enabled.

.EXAMPLE
    .\Run-Maintenance.ps1 -SilentMode -FastMode
    Runs in silent mode with reduced timeouts for unattended execution.

.NOTES
    File Name      : Run-Maintenance.ps1
    Author         : Miguel Velasco
    Prerequisite   : PowerShell 5.1+, Administrator privileges
    Version        : 4.0.0
    Last Updated   : October 2025

    Requirements:
    - Windows 10/11
    - PowerShell 5.1 or later
    - Administrator privileges
    - WindowsMaintenance module in .\WindowsMaintenance\
#>

#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$false, HelpMessage="Path to custom configuration file")]
    [ValidateScript({Test-Path $_})]
    [string]$ConfigPath,

    [Parameter(Mandatory=$false, HelpMessage="Simulation mode - no changes made")]
    [switch]$WhatIf = $false,

    [Parameter(Mandatory=$false, HelpMessage="Enable detailed logging")]
    [switch]$DetailedOutput = $false,

    [Parameter(Mandatory=$false, HelpMessage="Enable event log management")]
    [switch]$ManageEventLogs = $false,

    [Parameter(Mandatory=$false, HelpMessage="Security scan level")]
    [ValidateSet('Quick', 'Full', 'Custom')]
    [string]$ScanLevel = 'Quick',

    [Parameter(Mandatory=$false, HelpMessage="Show interactive message boxes")]
    [switch]$ShowMessageBoxes = $false,

    [Parameter(Mandatory=$false, HelpMessage="Silent mode - no user interaction")]
    [switch]$SilentMode = $false,

    [Parameter(Mandatory=$false, HelpMessage="Skip external drive optimization")]
    [switch]$SkipExternalDrives = $false,

    [Parameter(Mandatory=$false, HelpMessage="Fast mode - reduced timeouts")]
    [switch]$FastMode = $false
)

# Script banner
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Windows Maintenance Framework v4.0.0" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Function to check for Administrator privileges
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Check for Administrator privileges
Write-Host "Checking prerequisites..." -ForegroundColor Yellow
if (-not (Test-Administrator)) {
    Write-Host ""
    Write-Host "ERROR: This script requires Administrator privileges." -ForegroundColor Red
    Write-Host ""
    Write-Host "Please run PowerShell as Administrator:" -ForegroundColor Yellow
    Write-Host "1. Right-click PowerShell" -ForegroundColor Gray
    Write-Host "2. Select 'Run as Administrator'" -ForegroundColor Gray
    Write-Host "3. Navigate to this directory and run the script again" -ForegroundColor Gray
    Write-Host ""
    exit 1
}

Write-Host "  Administrator privileges: OK" -ForegroundColor Green

# Check PowerShell version
$psVersion = $PSVersionTable.PSVersion
if ($psVersion.Major -lt 5 -or ($psVersion.Major -eq 5 -and $psVersion.Minor -lt 1)) {
    Write-Host ""
    Write-Host "ERROR: PowerShell 5.1 or later is required." -ForegroundColor Red
    Write-Host "Current version: $($psVersion.ToString())" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

Write-Host "  PowerShell version: $($psVersion.ToString()) OK" -ForegroundColor Green

# Determine script location
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModulePath = Join-Path $ScriptRoot "WindowsMaintenance.psd1"

# Check if WindowsMaintenance module exists
if (-not (Test-Path $ModulePath)) {
    Write-Host ""
    Write-Host "ERROR: WindowsMaintenance module not found!" -ForegroundColor Red
    Write-Host "Expected location: $ModulePath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Please ensure you're running this script from the correct directory." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

Write-Host "  WindowsMaintenance module: Found" -ForegroundColor Green

# Determine configuration path
if (-not $ConfigPath) {
    $ConfigPath = Join-Path $ScriptRoot "WindowsMaintenance\config\maintenance-config.json"
}

# Verify configuration exists
if (-not (Test-Path $ConfigPath)) {
    Write-Host ""
    Write-Host "ERROR: Configuration file not found!" -ForegroundColor Red
    Write-Host "Expected location: $ConfigPath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Please ensure the configuration file exists or specify a valid -ConfigPath parameter." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

Write-Host "  Configuration file: Found" -ForegroundColor Green

# Display execution mode
Write-Host ""
Write-Host "Execution Mode:" -ForegroundColor Cyan
Write-Host "  Configuration: $ConfigPath" -ForegroundColor Gray
if ($WhatIf) {
    Write-Host "  Mode: SIMULATION (WhatIf) - No changes will be made" -ForegroundColor Yellow
} else {
    Write-Host "  Mode: LIVE - Changes will be made to the system" -ForegroundColor Green
}
if ($DetailedOutput) {
    Write-Host "  Logging: Detailed output enabled" -ForegroundColor Gray
}
if ($ManageEventLogs) {
    Write-Host "  Event Logs: Management enabled" -ForegroundColor Gray
}
Write-Host "  Scan Level: $ScanLevel" -ForegroundColor Gray
if ($SilentMode) {
    Write-Host "  Interaction: Silent mode" -ForegroundColor Gray
} elseif ($ShowMessageBoxes) {
    Write-Host "  Interaction: Message boxes enabled" -ForegroundColor Gray
}
if ($FastMode) {
    Write-Host "  Speed: Fast mode - reduced timeouts" -ForegroundColor Gray
}
if ($SkipExternalDrives) {
    Write-Host "  External Drives: Skipped" -ForegroundColor Gray
}

Write-Host ""

# Confirmation prompt (unless in SilentMode or WhatIf)
if (-not $SilentMode -and -not $WhatIf) {
    Write-Host "Ready to start maintenance." -ForegroundColor Yellow
    $response = Read-Host "Continue? (Y/N)"
    if ($response -ne 'Y' -and $response -ne 'y') {
        Write-Host ""
        Write-Host "Maintenance cancelled by user." -ForegroundColor Yellow
        Write-Host ""
        exit 0
    }
}

Write-Host ""
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "  Starting Maintenance" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

# Import the WindowsMaintenance module
try {
    Write-Host "Loading WindowsMaintenance module..." -ForegroundColor Yellow
    Import-Module $ModulePath -Force -ErrorAction Stop
    Write-Host "  Module loaded successfully" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Host ""
    Write-Host "ERROR: Failed to import WindowsMaintenance module!" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

# Prepare parameters for Invoke-WindowsMaintenance
$MaintenanceParams = @{
    ConfigPath = $ConfigPath
    WhatIf = $WhatIf
    DetailedOutput = $DetailedOutput
    ManageEventLogs = $ManageEventLogs
    ScanLevel = $ScanLevel
    ShowMessageBoxes = $ShowMessageBoxes
    SilentMode = $SilentMode
    SkipExternalDrives = $SkipExternalDrives
    FastMode = $FastMode
}

# Execute maintenance
$StartTime = Get-Date
try {
    Invoke-WindowsMaintenance @MaintenanceParams
    $Success = $true
}
catch {
    Write-Host ""
    Write-Host "ERROR: Maintenance execution failed!" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Stack Trace:" -ForegroundColor Gray
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    Write-Host ""
    $Success = $false
}
$EndTime = Get-Date
$Duration = $EndTime - $StartTime

# Display summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Maintenance Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Start Time:    $($StartTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
Write-Host "End Time:      $($EndTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
Write-Host "Duration:      $($Duration.ToString('hh\:mm\:ss'))" -ForegroundColor Gray
Write-Host ""

if ($Success) {
    Write-Host "Status:        COMPLETED SUCCESSFULLY" -ForegroundColor Green

    if ($WhatIf) {
        Write-Host ""
        Write-Host "NOTE: This was a simulation (WhatIf mode)." -ForegroundColor Yellow
        Write-Host "No changes were made to the system." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Check the following locations for detailed information:" -ForegroundColor Cyan

    # Try to get log path from config
    try {
        $Config = Get-Content $ConfigPath | ConvertFrom-Json
        if ($Config.LogsPath) {
            Write-Host "  Logs:    $($Config.LogsPath)" -ForegroundColor Gray
        }
        if ($Config.ReportsPath) {
            Write-Host "  Reports: $($Config.ReportsPath)" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "  Logs:    C:\Temp\MaintenanceLogs (default)" -ForegroundColor Gray
        Write-Host "  Reports: C:\Temp\MaintenanceReports (default)" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Maintenance Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""

    exit 0
}
else {
    Write-Host "Status:        FAILED" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please review the error messages above and check the log files." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "For troubleshooting:" -ForegroundColor Cyan
    Write-Host "1. Check the log files for detailed error information" -ForegroundColor Gray
    Write-Host "2. Verify your configuration file is valid" -ForegroundColor Gray
    Write-Host "3. Ensure all prerequisites are met" -ForegroundColor Gray
    Write-Host "4. Try running with -WhatIf first to test" -ForegroundColor Gray
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "  Maintenance Failed" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""

    exit 1
}
