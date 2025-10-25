<#
.SYNOPSIS
    Windows Maintenance Script - Modular PowerShell Maintenance Framework

.DESCRIPTION
    Comprehensive Windows maintenance and optimization framework with modular architecture.
    Provides automated maintenance across multiple system areas including updates, disk
    management, security, performance optimization, system health, and developer tools.

    Key Features:
    - Modular architecture for maintainability and extensibility
    - Comprehensive logging and reporting
    - WhatIf mode for safe testing
    - Enterprise-grade error handling
    - Performance-optimized execution
    - Configurable via JSON

.NOTES
    File Name      : WindowsMaintenance.psm1
    Author         : Miguel Velasco
    Prerequisite   : PowerShell 5.1+, Administrator privileges
    Version        : 4.0.0
    Last Updated   : October 2025
    Module Type    : Root Module (Orchestrator)

    Security: Requires administrator privileges for system-level operations
    Performance: Memory management and resource optimization throughout
    Enterprise: Comprehensive audit logging and compliance reporting
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator

# Module root path
$ModuleRoot = $PSScriptRoot

# Import Common modules
Write-Verbose "Loading common modules..."
Import-Module "$ModuleRoot\Modules\Common\Logging.psm1" -Force
Import-Module "$ModuleRoot\Modules\Common\StringFormatting.psm1" -Force
Import-Module "$ModuleRoot\Modules\Common\SystemDetection.psm1" -Force
Import-Module "$ModuleRoot\Modules\Common\MemoryManagement.psm1" -Force
Import-Module "$ModuleRoot\Modules\Common\SafeExecution.psm1" -Force
Import-Module "$ModuleRoot\Modules\Common\UIHelpers.psm1" -Force
Import-Module "$ModuleRoot\Modules\Common\RealTimeProgressOutput.psm1" -Force
Import-Module "$ModuleRoot\Modules\Common\DriveAnalysis.psm1" -Force

# Import Feature modules
Write-Verbose "Loading feature modules..."
Import-Module "$ModuleRoot\Modules\SystemUpdates.psm1" -Force
Import-Module "$ModuleRoot\Modules\DiskMaintenance.psm1" -Force
Import-Module "$ModuleRoot\Modules\SystemHealthRepair.psm1" -Force
Import-Module "$ModuleRoot\Modules\SecurityScans.psm1" -Force
Import-Module "$ModuleRoot\Modules\DeveloperMaintenance.psm1" -Force
Import-Module "$ModuleRoot\Modules\PerformanceOptimization.psm1" -Force

<#
.SYNOPSIS
    Main Windows Maintenance orchestration function.

.DESCRIPTION
    Orchestrates comprehensive Windows maintenance across all enabled modules.
    Executes maintenance operations in optimal order with comprehensive logging
    and error handling.

.PARAMETER ConfigPath
    Path to JSON configuration file

.PARAMETER WhatIf
    Simulation mode - shows what would be done without making changes

.PARAMETER Verbose
    Enable verbose logging

.PARAMETER SilentMode
    Suppress message boxes

.EXAMPLE
    Invoke-WindowsMaintenance -ConfigPath "C:\Config\maintenance.json"

.EXAMPLE
    Invoke-WindowsMaintenance -WhatIf

.NOTES
    Security: Requires administrator privileges
    Performance: Optimized execution order for efficiency
    Logging: Comprehensive audit trail generated
#>
function Invoke-WindowsMaintenance {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$false)]
        [string]$ConfigPath = "$ModuleRoot\Config\maintenance-config.json",

        [Parameter(Mandatory=$false)]
        [switch]$WhatIf = $false,

        [Parameter(Mandatory=$false)]
        [switch]$SilentMode = $false
    )

    # Script start time
    $ScriptStartTime = Get-Date

    try {
        # Load configuration
        if (Test-Path $ConfigPath) {
            Write-Verbose "Loading configuration from: $ConfigPath"
            $ConfigJson = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
            $Global:Config = @{}
            $ConfigJson.PSObject.Properties | ForEach-Object {
                $Global:Config[$_.Name] = $_.Value
            }
        }
        else {
            Write-Warning "Configuration file not found: $ConfigPath. Using defaults."
            $Global:Config = @{
                EnabledModules = @(
                    "SystemUpdates",
                    "DiskMaintenance",
                    "SystemHealthRepair",
                    "SecurityScans",
                    "DeveloperMaintenance",
                    "PerformanceOptimization"
                )
                LogsPath = "$env:TEMP\WindowsMaintenance\Logs"
                ReportsPath = "$env:TEMP\WindowsMaintenance\Reports"
                MaxEventLogSizeMB = 100
            }
        }

        # Set global flags
        $Global:WhatIf = $WhatIf
        $Global:SilentMode = $SilentMode
        $Global:ShowMessageBoxes = -not $SilentMode

        # Ensure directories exist
        if (-not (Test-Path $Global:Config.LogsPath)) {
            New-Item -Path $Global:Config.LogsPath -ItemType Directory -Force | Out-Null
        }
        if (-not (Test-Path $Global:Config.ReportsPath)) {
            New-Item -Path $Global:Config.ReportsPath -ItemType Directory -Force | Out-Null
        }

        # Initialize logging
        Write-MaintenanceLog -Message "========================================" -Level INFO
        Write-MaintenanceLog -Message "Windows Maintenance Script Started" -Level INFO
        Write-MaintenanceLog -Message "Version: 4.0.0" -Level INFO
        Write-MaintenanceLog -Message "Execution Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level INFO
        Write-MaintenanceLog -Message "WhatIf Mode: $WhatIf" -Level INFO
        Write-MaintenanceLog -Message "Silent Mode: $SilentMode" -Level INFO
        Write-MaintenanceLog -Message "========================================" -Level INFO

        # Execute maintenance modules in optimal order
        $ModuleExecutionOrder = @(
            @{ Name = "SystemUpdates"; Function = "Invoke-SystemUpdates" },
            @{ Name = "DiskMaintenance"; Function = "Invoke-DiskMaintenance" },
            @{ Name = "SystemHealthRepair"; Function = "Invoke-SystemHealthRepair" },
            @{ Name = "SecurityScans"; Function = "Invoke-SecurityScans" },
            @{ Name = "DeveloperMaintenance"; Function = "Invoke-DeveloperMaintenance" },
            @{ Name = "PerformanceOptimization"; Function = "Invoke-PerformanceOptimization" }
        )

        foreach ($Module in $ModuleExecutionOrder) {
            if ($Module.Name -in $Global:Config.EnabledModules) {
                Write-MaintenanceLog -Message "`nExecuting module: $($Module.Name)" -Level INFO

                try {
                    & $Module.Function
                }
                catch {
                    Write-MaintenanceLog -Message "Module $($Module.Name) failed: $($_.Exception.Message)" -Level ERROR
                    Write-MaintenanceLog -Message "Stack Trace: $($_.ScriptStackTrace)" -Level ERROR
                }

                # Memory cleanup between modules
                Optimize-MemoryUsage
            }
            else {
                Write-MaintenanceLog -Message "Module $($Module.Name) is disabled in configuration" -Level INFO
            }
        }

        # Calculate total execution time
        $ScriptEndTime = Get-Date
        $TotalDuration = $ScriptEndTime - $ScriptStartTime

        Write-MaintenanceLog -Message "========================================" -Level INFO
        Write-MaintenanceLog -Message "Windows Maintenance Script Completed" -Level SUCCESS
        Write-MaintenanceLog -Message "Total Duration: $($TotalDuration.ToString('hh\:mm\:ss'))" -Level INFO
        Write-MaintenanceLog -Message "Completion Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level INFO
        Write-MaintenanceLog -Message "========================================" -Level INFO

        # Final completion message
        if (-not $SilentMode) {
            $CompletionMessage = @"
Windows Maintenance Completed Successfully

Total Duration: $($TotalDuration.ToString('hh\:mm\:ss'))
Completion Time: $(Get-Date -Format 'HH:mm:ss')

Modules Executed: $($ModuleExecutionOrder.Count)
Logs: $($Global:Config.LogsPath)
Reports: $($Global:Config.ReportsPath)

Check the maintenance log for detailed results.
"@
            Show-MaintenanceMessageBox -Message $CompletionMessage -Title "Maintenance Complete" -Icon "Information"
        }
    }
    catch {
        Write-MaintenanceLog -Message "CRITICAL ERROR: $($_.Exception.Message)" -Level ERROR
        Write-MaintenanceLog -Message "Stack Trace: $($_.ScriptStackTrace)" -Level ERROR

        if (-not $SilentMode) {
            $ErrorMessage = @"
Critical Error in Maintenance Script

Error: $($_.Exception.Message)

The maintenance script encountered a critical error.
Please check the logs for details:
$($Global:Config.LogsPath)

Stack Trace:
$($_.ScriptStackTrace)
"@
            Show-MaintenanceMessageBox -Message $ErrorMessage -Title "Maintenance Error" -Icon "Error"
        }

        throw
    }
    finally {
        # Final cleanup
        Write-Verbose "Performing final cleanup..."
        Optimize-MemoryUsage -Mode Aggressive
    }
}

# Export public functions
Export-ModuleMember -Function @(
    'Invoke-WindowsMaintenance'
)
