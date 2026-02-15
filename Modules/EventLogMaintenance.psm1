<#
.SYNOPSIS
    Event Log Maintenance Module

.DESCRIPTION
    Provides enterprise-grade event log management, analysis, and optimization.
#>

#Requires -Version 5.1

# Import dependencies
$CommonPath = Join-Path $PSScriptRoot "Common"
Import-Module "$CommonPath\Logging.psm1" -Force
Import-Module "$CommonPath\SafeExecution.psm1" -Force

<#
.SYNOPSIS
    Main event log management orchestration function.
#>
function Invoke-EventLogManagement {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Config
    )

    if ("EventLogManagement" -notin $Config.EnabledModules) {
        Write-MaintenanceLog -Message 'Event Log Management module disabled' -Level INFO
        return
    }

    Write-MaintenanceLog -Message '======== Event Log Management Module ========' -Level INFO

    Invoke-SafeCommand -TaskName "Intelligent Event Log Optimization" -Command {
        Write-ProgressBar -Activity 'Event Log Optimization' -PercentComplete 10 -Status 'Analyzing event logs...'

        $LargeLogs = Get-WinEvent -ListLog * -ErrorAction SilentlyContinue |
                    Where-Object { $_.FileSize -gt ($Config.MaxEventLogSizeMB * 1MB) }

        if ($LargeLogs) {
            foreach ($Log in $LargeLogs) {
                if ($PSCmdlet.ShouldProcess($Log.LogName, "Clear and Archive Event Log")) {
                    $ArchiveDir = Join-Path $Config.ReportsPath "EventLogArchives"
                    if (!(Test-Path $ArchiveDir)) { New-Item -ItemType Directory -Force -Path $ArchiveDir | Out-Null }

                    $SafeLogName = $Log.LogName -replace '[\/:*?"<>|]', '_'
                    $ArchiveFile = Join-Path $ArchiveDir "${SafeLogName}_$(Get-Date -Format 'yyyyMMdd').evtx"

                    # Archive
                    & wevtutil export-log "$($Log.LogName)" "$ArchiveFile" /overwrite:true 2>&1 | Out-Null
                    # Clear
                    & wevtutil clear-log "$($Log.LogName)" 2>&1 | Out-Null

                    Write-MaintenanceLog -Message "Optimized: $($Log.LogName)" -Level SUCCESS
                }
            }
        } else {
            Write-MaintenanceLog -Message "All event logs within size limits" -Level INFO
        }
    }
}

# Export public functions
Export-ModuleMember -Function @(
    'Invoke-EventLogManagement'
)
