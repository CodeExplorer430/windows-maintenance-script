<#
.SYNOPSIS
    Advanced system performance optimization module.

.DESCRIPTION
    Provides enterprise-grade performance optimization including event log management,
    startup item analysis, and system resource monitoring.
#>

#Requires -Version 5.1

# Import dependencies
Import-Module "$PSScriptRoot\Common\Logging.psm1" -Force
Import-Module "$PSScriptRoot\Common\SafeExecution.psm1" -Force
Import-Module "$PSScriptRoot\Common\MemoryManagement.psm1" -Force
Import-Module "$PSScriptRoot\Common\StringFormatting.psm1" -Force
Import-Module "$PSScriptRoot\Common\UIHelpers.psm1" -Force

<#
.SYNOPSIS
    Main performance optimization orchestration function.
#>
function Invoke-PerformanceOptimization {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Config
    )

    if ("PerformanceOptimization" -notin $Config.EnabledModules) {
        Write-MaintenanceLog -Message 'Performance Optimization module disabled' -Level INFO
        return
    }

    Write-MaintenanceLog -Message '======== Performance Optimization Module ========' -Level INFO

    # Proactive memory optimization
    Optimize-MemoryUsage -Force

    # Event Log Analysis
    Invoke-SafeCommand -TaskName "Advanced Event Log Management" -Command {
        Write-ProgressBar -Activity 'Event Log Management' -PercentComplete 10 -Status 'Analyzing event logs...'

        $Cutoff = (Get-Date).AddDays(-1)
        $Logs = Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | Where-Object { $_.RecordCount -gt 0 }

        foreach ($Log in $Logs) {
            try {
                $ErrorCount = (Get-WinEvent -FilterHashtable @{LogName=$Log.LogName; Level=2; StartTime=$Cutoff} -ErrorAction SilentlyContinue).Count
                if ($ErrorCount -gt 50) {
                    Write-MaintenanceLog -Message "High error volume in $($Log.LogName): $ErrorCount errors in 24h" -Level WARNING
                }
            } catch {
                Write-Debug "Error analyzing event log $($Log.LogName): $($_.Exception.Message)"
            }
        }
    } | Out-Null

    # Startup Performance
    Invoke-SafeCommand -TaskName 'Advanced Startup Performance Analysis' -Command {
        Write-ProgressBar -Activity 'Startup Analysis' -PercentComplete 10 -Status 'Gathering startup configuration...'

        $StartupItems = Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue
        foreach ($Item in $StartupItems) {
            Write-MaintenanceLog -Message "Startup Item: $($Item.Name) [$($Item.Command)]" -Level DETAIL
        }
    } | Out-Null

    # Startup Cleanup
    Invoke-SafeCommand -TaskName "Invalid Startup Items Cleanup" -Command {
        $Res = Remove-InvalidStartupItem -WhatIf:$PSCmdlet.MyInvocation.BoundParameters['WhatIf']
        Write-MaintenanceLog -Message "Startup cleanup removed $($Res.RemovedCount) items" -Level SUCCESS
    } | Out-Null

    # Resource Analysis
    Invoke-SafeCommand -TaskName "System Resource Analysis" -Command {
        Write-ProgressBar -Activity 'Resource Analysis' -PercentComplete 10 -Status 'Gathering performance metrics...'

        $OS = Get-CimInstance -ClassName Win32_OperatingSystem
        $TotalMem = [math]::Round($OS.TotalVisibleMemorySize / 1MB, 2)
        $FreeMem = [math]::Round($OS.FreePhysicalMemory / 1MB, 2)
        $UsedPercent = [math]::Round((($TotalMem - $FreeMem) / $TotalMem) * 100, 1)

        $CPU = Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average | Select-Object -ExpandProperty Average

        Write-MaintenanceLog -Message "CPU Load: $CPU%" -Level INFO
        Write-MaintenanceLog -Message "Memory Usage: $UsedPercent% ($([math]::Round(($TotalMem - $FreeMem), 2))GB / ${TotalMem}GB)" -Level INFO

        # Log to Database
        if (Get-Command Invoke-SQLiteQuery -ErrorAction SilentlyContinue) {
            Invoke-SQLiteQuery -Query "INSERT INTO SystemMetrics (MetricName, MetricValue, Unit) VALUES ('CPUUsagePercent', $CPU, '%');"
            Invoke-SQLiteQuery -Query "INSERT INTO SystemMetrics (MetricName, MetricValue, Unit) VALUES ('MemoryUsagePercent', $UsedPercent, '%');"
        }

        if ($CPU -gt 80) { Write-MaintenanceLog -Message "High CPU usage detected" -Level WARNING }
        if ($UsedPercent -gt 85) { Write-MaintenanceLog -Message "High memory pressure detected" -Level WARNING }
    } | Out-Null

    # Final cleanup
    Optimize-MemoryUsage
}

function Remove-InvalidStartupItem {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([hashtable])]
    param()

    $Removed = 0
    $Paths = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run', 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run')

    foreach ($P in $Paths) {
        if (Test-Path $P) {
            $Props = Get-ItemProperty $P
            $Items = $Props | Get-Member -MemberType NoteProperty | Where-Object { $_.Name -notmatch '^PS' }
            foreach ($I in $Items) {
                $Val = $Props.$($I.Name)
                # Simple validation: extract path and test
                $Path = ($Val -split ' ')[0].Trim('"')
                if ($Path -and -not (Test-Path $Path -ErrorAction SilentlyContinue)) {
                    if ($PSCmdlet.ShouldProcess("Registry Key $($P)", "Remove invalid startup item: $($I.Name) -> $Path")) {
                        Remove-ItemProperty -Path $P -Name $I.Name -ErrorAction SilentlyContinue
                        $Removed++
                    }
                }
            }
        }
    }
    return @{ RemovedCount = $Removed }
}

# Export public functions
Export-ModuleMember -Function @(
    'Invoke-PerformanceOptimization'
)
