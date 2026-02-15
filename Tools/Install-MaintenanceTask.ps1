<#
.SYNOPSIS
    Installation script for Windows Maintenance scheduled task.

.DESCRIPTION
    Creates a scheduled task to run Windows Maintenance automatically.
    Provides interactive configuration or accepts parameters for automated installation.

.PARAMETER TaskName
    Name for the scheduled task (default: "Windows Maintenance")

.PARAMETER Schedule
    Schedule type: Daily, Weekly, Monthly, AtStartup, OnIdle (default: Weekly)

.PARAMETER Time
    Time to run in 24-hour format (default: "02:00")

.PARAMETER DaysOfWeek
    Days for Weekly schedule (default: "Sunday")

.PARAMETER RunAsSystem
    Run as SYSTEM account instead of current user

.PARAMETER Interactive
    Show interactive prompts for configuration

.EXAMPLE
    .\Install-MaintenanceTask.ps1

.EXAMPLE
    .\Install-MaintenanceTask.ps1 -Schedule Daily -Time "03:00"

.EXAMPLE
    .\Install-MaintenanceTask.ps1 -Schedule Weekly -DaysOfWeek "Sunday,Wednesday" -RunAsSystem

.NOTES
    File Name      : Install-MaintenanceTask.ps1
    Author         : Miguel Velasco
    Prerequisite   : PowerShell 5.1+, Administrator privileges
    Version        : 1.0.0
    Last Updated   : October 2025
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$TaskName = "Windows Maintenance",

    [Parameter(Mandatory=$false)]
    [ValidateSet("Daily", "Weekly", "Monthly", "AtStartup", "OnIdle")]
    [string]$Schedule = "Weekly",

    [Parameter(Mandatory=$false)]
    [string]$Time = "02:00",

    [Parameter(Mandatory=$false)]
    [string]$DaysOfWeek = "Sunday",

    [Parameter(Mandatory=$false)]
    [switch]$RunAsSystem = $false,

    [Parameter(Mandatory=$false)]
    [switch]$Interactive = $false
)

# Set information preference for UI output
$InformationPreference = 'Continue'

# Determine script location
$ScriptRoot = Split-Path -Parent $PSScriptRoot
$ModulePath = Join-Path $ScriptRoot "WindowsMaintenance.psd1"

# Import required modules
try {
    Import-Module (Join-Path $ScriptRoot "Modules\TaskScheduler.psm1") -Force
    Import-Module (Join-Path $ScriptRoot "Modules\Common\Logging.psm1") -Force
}
catch {
    Write-Error "Failed to import required modules: $($_.Exception.Message)"
    exit 1
}

# Verify module exists
if (-not (Test-Path $ModulePath)) {
    Write-MaintenanceLog -Message "ERROR: WindowsMaintenance module not found at: $ModulePath" -Level ERROR
    exit 1
}

Write-Information -MessageData "`n========================================" -Tags "Color:Cyan"
Write-Information -MessageData "  Windows Maintenance Task Installer" -Tags "Color:Cyan"
Write-Information -MessageData "========================================`n" -Tags "Color:Cyan"

# Interactive mode
if ($Interactive) {
    Write-Information -MessageData "Configure scheduled maintenance task interactively`n" -Tags "Color:Yellow"

    # Task name
    $InputTaskName = Read-Host "Task name [Windows Maintenance]"
    if ($InputTaskName) { $TaskName = $InputTaskName }

    # Schedule type
    Write-Information -MessageData "`nSchedule types:" -Tags "Color:White"
    Write-Information -MessageData "  1. Daily" -Tags "Color:White"
    Write-Information -MessageData "  2. Weekly (recommended)" -Tags "Color:White"
    Write-Information -MessageData "  3. Monthly" -Tags "Color:White"
    Write-Information -MessageData "  4. At Startup" -Tags "Color:White"
    Write-Information -MessageData "  5. On Idle" -Tags "Color:White"

    $ScheduleChoice = Read-Host "`nSelect schedule type [2]"
    $Schedule = switch ($ScheduleChoice) {
        "1" { "Daily" }
        "2" { "Weekly" }
        "3" { "Monthly" }
        "4" { "AtStartup" }
        "5" { "OnIdle" }
        default { "Weekly" }
    }

    # Time (for scheduled types)
    if ($Schedule -in @("Daily", "Weekly", "Monthly")) {
        $InputTime = Read-Host "Run time in 24-hour format [02:00]"
        if ($InputTime) { $Time = $InputTime }
    }

    # Days of week (for Weekly)
    if ($Schedule -eq "Weekly") {
        Write-Information -MessageData "`nDays of week (comma-separated):" -Tags "Color:White"
        Write-Information -MessageData "  Examples: Sunday  |  Monday,Wednesday,Friday  |  Saturday,Sunday" -Tags "Color:White"
        $InputDays = Read-Host "Days [Sunday]"
        if ($InputDays) { $DaysOfWeek = $InputDays }
    }

    # Run as SYSTEM
    $InputSystem = Read-Host "`nRun as SYSTEM account? [N]"
    $RunAsSystem = ($InputSystem -eq 'Y' -or $InputSystem -eq 'y')

    Write-Information -MessageData "" -Tags "Color:White"
}

# Display configuration
Write-Information -MessageData "Task Configuration:" -Tags "Color:Green"
Write-Information -MessageData "  Name:     $TaskName" -Tags "Color:White"
Write-Information -MessageData "  Schedule: $Schedule" -Tags "Color:White"
if ($Schedule -in @("Daily", "Weekly", "Monthly")) {
    Write-Information -MessageData "  Time:     $Time" -Tags "Color:White"
}
if ($Schedule -eq "Weekly") {
    Write-Information -MessageData "  Days:     $DaysOfWeek" -Tags "Color:White"
}
Write-Information -MessageData "  Run As:   $(if ($RunAsSystem) { 'SYSTEM' } else { $env:USERNAME })" -Tags "Color:White"
Write-Information -MessageData "  Module:   $ModulePath`n" -Tags "Color:White"

# Confirm
if (-not $Interactive) {
    $Confirm = Read-Host "Create this scheduled task? [Y/N]"
    if ($Confirm -ne 'Y' -and $Confirm -ne 'y') {
        Write-Information -MessageData "Installation cancelled." -Tags "Color:Yellow"
        exit 0
    }
}

# Create wrapper script
$WrapperScriptPath = Join-Path $ScriptRoot "Scripts\Run-Maintenance.ps1"
$WrapperContent = @"
#Requires -Version 5.1
#Requires -RunAsAdministrator

# Windows Maintenance Wrapper Script
# Auto-generated by Install-MaintenanceTask.ps1

`$ModulePath = Join-Path `$PSScriptRoot "..\WindowsMaintenance.psd1"

try {
    Import-Module `$ModulePath -Force
    Invoke-WindowsMaintenance
}
catch {
    Write-Error "Maintenance failed: `$(`$_.Exception.Message)"
    exit 1
}
"@

try {
    # Create wrapper script
    $WrapperContent | Out-File -FilePath $WrapperScriptPath -Encoding UTF8 -Force
    Write-Information -MessageData "Created wrapper script: $WrapperScriptPath" -Tags "Color:Green"

    # Create scheduled task
    $TaskParams = @{
        TaskName = $TaskName
        ScriptPath = $WrapperScriptPath
        Schedule = $Schedule
        Description = "Automated Windows Maintenance - Created $(Get-Date -Format 'yyyy-MM-dd')"
    }

    if ($Schedule -in @("Daily", "Weekly", "Monthly")) {
        $TaskParams.Add("Time", $Time)
    }

    if ($Schedule -eq "Weekly") {
        $TaskParams.Add("DaysOfWeek", $DaysOfWeek)
    }

    if ($RunAsSystem) {
        $TaskParams.Add("RunAsSystem", $true)
    }

    $Success = New-MaintenanceTask @TaskParams

    if ($Success) {
        Write-Information -MessageData "`n========================================" -Tags "Color:Green"
        Write-Information -MessageData "  Installation Successful!" -Tags "Color:Green"
        Write-Information -MessageData "========================================`n" -Tags "Color:Green"

        Write-Information -MessageData "Scheduled task created successfully." -Tags "Color:Green"
        Write-Information -MessageData "`nTo manage the task:" -Tags "Color:Cyan"
        Write-Information -MessageData "  - View in Task Scheduler: taskschd.msc" -Tags "Color:White"
        Write-Information -MessageData "  - Run manually: Start-ScheduledTask -TaskName '$TaskName'" -Tags "Color:White"
        Write-Information -MessageData "  - Disable: Disable-ScheduledTask -TaskName '$TaskName'" -Tags "Color:White"
        Write-Information -MessageData "  - Remove: Unregister-ScheduledTask -TaskName '$TaskName'`n" -Tags "Color:White"
    }
    else {
        Write-MaintenanceLog -Message "ERROR: Failed to create scheduled task." -Level ERROR
        exit 1
    }
}
catch {
    Write-MaintenanceLog -Message "ERROR: Installation failed: $($_.Exception.Message)" -Level ERROR
    exit 1
}
