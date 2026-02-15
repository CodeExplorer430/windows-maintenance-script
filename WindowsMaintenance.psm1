<#
.SYNOPSIS
    Windows Maintenance Script - Modular PowerShell Maintenance Framework

.DESCRIPTION
    Comprehensive Windows maintenance and optimization framework with modular architecture.
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator

# Module root path
$ModuleRoot = $PSScriptRoot

# Import Common modules
Import-Module "$ModuleRoot\Modules\Common\Logging.psm1" -Force
Import-Module "$ModuleRoot\Modules\Common\StringFormatting.psm1" -Force
Import-Module "$ModuleRoot\Modules\Common\SystemDetection.psm1" -Force
Import-Module "$ModuleRoot\Modules\Common\MemoryManagement.psm1" -Force
Import-Module "$ModuleRoot\Modules\Common\SafeExecution.psm1" -Force
Import-Module "$ModuleRoot\Modules\Common\UIHelpers.psm1" -Force
Import-Module "$ModuleRoot\Modules\Common\RealTimeProgressOutput.psm1" -Force
Import-Module "$ModuleRoot\Modules\Common\DriveAnalysis.psm1" -Force
Import-Module "$ModuleRoot\Modules\Common\Database.psm1" -Force
Import-Module "$ModuleRoot\Modules\Common\HardwareDiagnostics.psm1" -Force
Import-Module "$ModuleRoot\Modules\Common\EmailNotifications.psm1" -Force
Import-Module "$ModuleRoot\Modules\Common\CloudReporting.psm1" -Force

# Import Feature modules
Import-Module "$ModuleRoot\Modules\SystemUpdates.psm1" -Force
Import-Module "$ModuleRoot\Modules\DiskMaintenance.psm1" -Force
Import-Module "$ModuleRoot\Modules\SystemHealthRepair.psm1" -Force
Import-Module "$ModuleRoot\Modules\SecurityScans.psm1" -Force
Import-Module "$ModuleRoot\Modules\DeveloperMaintenance.psm1" -Force
Import-Module "$ModuleRoot\Modules\PerformanceOptimization.psm1" -Force
Import-Module "$ModuleRoot\Modules\NetworkMaintenance.psm1" -Force
Import-Module "$ModuleRoot\Modules\GPUMaintenance.psm1" -Force
Import-Module "$ModuleRoot\Modules\EventLogMaintenance.psm1" -Force
Import-Module "$ModuleRoot\Modules\BackupMaintenance.psm1" -Force
Import-Module "$ModuleRoot\Modules\SystemReporting.psm1" -Force
Import-Module "$ModuleRoot\Modules\PrivacyMaintenance.psm1" -Force
Import-Module "$ModuleRoot\Modules\BloatwareRemoval.psm1" -Force
Import-Module "$ModuleRoot\Modules\MultimediaMaintenance.psm1" -Force

<#
.SYNOPSIS
    Main Windows Maintenance orchestration function.
#>
function Invoke-WindowsMaintenance {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$false)]
        [string]$ConfigPath = "$ModuleRoot\Config\maintenance-config.json",

        [Parameter(Mandatory=$false)]
        [switch]$SilentMode = $false
    )

    # Set InformationPreference to ensure Write-Information is visible
    $InformationPreference = 'Continue'

    # Script start time
    $ScriptStartTime = Get-Date

    try {
        # Load configuration
        $Config = if (Test-Path $ConfigPath) {
            $ConfigJson = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
            $TempConfig = @{}
            $ConfigJson.PSObject.Properties | ForEach-Object {
                $TempConfig[$_.Name] = $_.Value
            }
            $TempConfig
        }
        else {
            @{
                EnabledModules = @(
                    "SystemUpdates",
                    "DiskMaintenance",
                    "SystemHealthRepair",
                    "SecurityScans",
                    "DeveloperMaintenance",
                    "MultimediaMaintenance",
                    "PerformanceOptimization",
                    "EventLogManagement",
                    "BackupOperations",
                    "SystemReporting"
                )
                LogsPath = "$env:TEMP\WindowsMaintenance\Logs"
                ReportsPath = "$env:TEMP\WindowsMaintenance\Reports"
                MaxEventLogSizeMB = 100
            }
        }

        # Ensure directories exist
        if (-not (Test-Path $Config.LogsPath)) {
            New-Item -Path $Config.LogsPath -ItemType Directory -Force | Out-Null
        }
        if (-not (Test-Path $Config.ReportsPath)) {
            New-Item -Path $Config.ReportsPath -ItemType Directory -Force | Out-Null
        }

        # Initialize log file paths
        $LogTimestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $LogFiles = @{
            LogFile       = Join-Path $Config.LogsPath "maintenance_$LogTimestamp.log"
            ErrorLog      = Join-Path $Config.LogsPath "errors_$LogTimestamp.log"
            OperationsLog = Join-Path $Config.LogsPath "operations_$LogTimestamp.log"
            DetailedLog   = Join-Path $Config.LogsPath "detailed_$LogTimestamp.log"
        }

        # Configure logging system
        $EnableVerbose = if ($VerbosePreference -eq 'Continue') { $true } else { $false }
        Set-LoggingConfig @LogFiles -EnableVerbose:$EnableVerbose -DetailedOutput:$true -SilentMode:$SilentMode

        Write-MaintenanceLog -Message "========================================" -Level INFO
        Write-MaintenanceLog -Message "Windows Maintenance Script Started" -Level INFO

        # Initialize Database
        $DbPath = Join-Path $Config.LogsPath "maintenance_history.db"
        Initialize-MaintenanceDatabase -DbPath $DbPath

        # Check for Pending Reboot
        $RebootStatus = Test-PendingReboot
        if ($RebootStatus.IsRebootPending) {
            $RebootMsg = "A system restart is pending (Reasons: $($RebootStatus.Reasons -join ', ')). It is recommended to restart before proceeding."
            Write-MaintenanceLog -Message $RebootMsg -Level WARNING

            if (-not $SilentMode) {
                $Prompt = Show-MaintenanceMessageBox -Message "$RebootMsg`n`nDo you want to continue anyway?" -Title "Pending Reboot Detected" -Buttons "YesNo" -Icon "Warning"
                if ($Prompt -eq "No") {
                    Write-MaintenanceLog -Message "Maintenance cancelled by user due to pending reboot" -Level INFO
                    return
                }
            }
        }

        # Log Telemetry for Analytics
        $SystemDrive = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"
        $FreeGB = [math]::Round($SystemDrive.FreeSpace / 1GB, 2)
        Invoke-SQLiteQuery -Query "INSERT INTO SystemMetrics (MetricName, MetricValue, Unit) VALUES ('SystemDriveFreeGB', $FreeGB, 'GB');"

        Write-MaintenanceLog -Message "Version: 4.1.0" -Level INFO
        Write-MaintenanceLog -Message "WhatIf Mode: $WhatIfPreference" -Level INFO
        Write-MaintenanceLog -Message "========================================" -Level INFO

        # Execute maintenance modules in optimal order
        $ModuleExecutionOrder = @(
            @{ Name = "SystemUpdates"; Function = "Invoke-SystemUpdate" },
            @{ Name = "DiskMaintenance"; Function = "Invoke-DiskMaintenance" },
            @{ Name = "SystemHealthRepair"; Function = "Invoke-SystemHealthRepair" },
            @{ Name = "SecurityScans"; Function = "Invoke-SecurityScan" },
            @{ Name = "DeveloperMaintenance"; Function = "Invoke-DeveloperMaintenance" },
            @{ Name = "MultimediaMaintenance"; Function = "Invoke-MultimediaMaintenance" },
            @{ Name = "PerformanceOptimization"; Function = "Invoke-PerformanceOptimization" },
            @{ Name = "NetworkMaintenance"; Function = "Invoke-NetworkMaintenance" },
            @{ Name = "GPUMaintenance"; Function = "Invoke-GPUMaintenance" },
            @{ Name = "EventLogManagement"; Function = "Invoke-EventLogManagement" },
            @{ Name = "BackupOperations"; Function = "Invoke-BackupOperation" },
            @{ Name = "BloatwareRemoval"; Function = "Invoke-BloatwareRemoval" },
            @{ Name = "PrivacyMaintenance"; Function = "Invoke-PrivacyMaintenance" },
            @{ Name = "SystemReporting"; Function = "Invoke-SystemReporting" }
        )

        foreach ($Module in $ModuleExecutionOrder) {
            if ($Module.Name -in $Config.EnabledModules) {
                Write-MaintenanceLog -Message "`nExecuting module: $($Module.Name)" -Level INFO

                $ModStartTime = Get-Date
                $ModStatus = "Success"
                $ModError = ""

                try {
                    # Pass config and common preferences to each module
                    & $Module.Function -Config $Config -WhatIf:$WhatIfPreference -Verbose:($VerbosePreference -eq 'Continue')
                }
                catch {
                    $ModStatus = "Error"
                    $ModError = $_.Exception.Message
                    Write-MaintenanceLog -Message "Module $($Module.Name) failed: $ModError" -Level ERROR
                }

                $ModDuration = (Get-Date) - $ModStartTime

                # Log to Database
                Add-MaintenanceHistory -Module $Module.Name -Task "Invoke-$($Module.Name)" -Result $ModStatus -Details $ModError -Duration $ModDuration.TotalSeconds

                # Memory cleanup between modules
                Optimize-MemoryUsage
            }
        }

        # Calculate total duration
        $TotalDuration = (Get-Date) - $ScriptStartTime

        Write-MaintenanceLog -Message "========================================" -Level INFO
        Write-MaintenanceLog -Message "Windows Maintenance Script Completed" -Level SUCCESS
        Write-MaintenanceLog -Message "Total Duration: $($TotalDuration.ToString('hh\:mm\:ss'))" -Level INFO
        Write-MaintenanceLog -Message "========================================" -Level INFO

        # Send Email Notification
        if ($Config.SmtpConfig) {
            $LastReport = Get-ChildItem -Path $Config.ReportsPath -Filter "system_report_*.txt" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($LastReport) {
                Send-MaintenanceEmail -ReportPath $LastReport.FullName -SmtpConfig $Config.SmtpConfig
            }
        }

        # Cloud Reporting Upload
        if ($Config.CloudConfig) {
            $LastReport = Get-ChildItem -Path $Config.ReportsPath -Filter "system_report_*.txt" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($LastReport) {
                Export-MaintenanceReportToCloud -ReportPath $LastReport.FullName -CloudConfig $Config.CloudConfig
            }
        }
    }
    catch {
        Write-MaintenanceLog -Message "CRITICAL ERROR: $($_.Exception.Message)" -Level ERROR
        throw
    }
}

# Export public functions
Export-ModuleMember -Function *
