<#
.SYNOPSIS
    System Reporting Module

.DESCRIPTION
    Generates comprehensive system reports and finalizes maintenance logging.
#>

#Requires -Version 5.1

# Import dependencies
$CommonPath = Join-Path $PSScriptRoot "Common"
Import-Module "$CommonPath\Logging.psm1" -Force
Import-Module "$CommonPath\SafeExecution.psm1" -Force
Import-Module "$CommonPath\MemoryManagement.psm1" -Force

<#
.SYNOPSIS
    Executes system reporting.
#>
function Invoke-SystemReporting {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Config
    )

    if ("SystemReporting" -notin $Config.EnabledModules) { return }

    Write-MaintenanceLog -Message '======== System Reporting Module ========' -Level INFO

    Invoke-SafeCommand -TaskName "System Report Generation" -Command {
        $ReportFile = Join-Path $Config.ReportsPath "system_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

        # Gather Hardware Health
        $Battery = Get-BatteryHealth
        $Storage = Get-StorageHealth
        $Enterprise = Get-EnterpriseContext

        $ReportContent = @"
SYSTEM MAINTENANCE REPORT
Generated: $(Get-Date)
Computer: $env:COMPUTERNAME
User: $env:USERNAME

ENTERPRISE CONTEXT:
------------------
Domain Status: $($Enterprise.DomainStatus)
VPN Connected: $($Enterprise.VPNConnected)

HARDWARE HEALTH:
----------------
Battery Status: $(if ($Battery) { "$($Battery.Status) ($($Battery.EstimatedChargeRemaining)%)" } else { "N/A (Desktop)" })
Storage Health:
$($Storage | Format-Table -AutoSize | Out-String)
"@

        if ($PSCmdlet.ShouldProcess($ReportFile, "Write System Report")) {
            $ReportContent | Out-File -FilePath $ReportFile
            Write-MaintenanceLog -Message "System report generated: $ReportFile" -Level SUCCESS
        }
    }

    # Finalization
    Optimize-MemoryUsage -Force
    Write-MaintenanceLog -Message "Maintenance session completed." -Level SUCCESS
}

# Export public functions
Export-ModuleMember -Function @(
    'Invoke-SystemReporting'
)
