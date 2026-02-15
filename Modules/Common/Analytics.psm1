<#
.SYNOPSIS
    Predictive Analytics module for Windows Maintenance Framework.

.DESCRIPTION
    Analyzes historical data from the maintenance database to identify trends,
    predict resource exhaustion, and detect recurring system issues.
#>

#Requires -Version 5.1

Import-Module "$PSScriptRoot\Logging.psm1" -Force
Import-Module "$PSScriptRoot\Database.psm1" -Force

<#
.SYNOPSIS
    Retrieves system performance trends from the database.
#>
function Get-SystemTrend {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    try {
        $Trends = @{
            DiskGrowthRateGBPerWeek = 0
            EstimatedDaysToFull = 0
            SuccessRatePercent = 0
            RecurringFailures = @()
        }

        # 1. Calculate Success Rate (Last 30 days)
        $History = Invoke-SQLiteQuery -Query "SELECT Result FROM MaintenanceHistory WHERE Timestamp > datetime('now', '-30 days')"
        if ($History) {
            $Total = $History.Count
            $Success = ($History | Where-Object { $_.Result -eq 'Success' }).Count
            $Trends.SuccessRatePercent = [math]::Round(($Success / $Total) * 100, 1)
        }

        # 2. Identify Recurring Failures
        $Failures = Invoke-SQLiteQuery -Query @"
            SELECT TaskName, COUNT(*) as FailCount
            FROM MaintenanceHistory
            WHERE Result != 'Success'
            GROUP BY TaskName
            HAVING FailCount > 2
"@
        if ($Failures) { $Trends.RecurringFailures = $Failures }

        # 3. Disk Growth Prediction (Requires SystemMetrics table data)
        # Note: This assumes Invoke-WindowsMaintenance logs free space to SystemMetrics
        $DiskMetrics = Invoke-SQLiteQuery -Query @"
            SELECT MetricValue, Timestamp
            FROM SystemMetrics
            WHERE MetricName = 'SystemDriveFreeGB'
            ORDER BY Timestamp ASC
"@
        if ($DiskMetrics.Count -ge 2) {
            $First = $DiskMetrics[0]
            $Last = $DiskMetrics[-1]
            $Days = ((Get-Date $Last.Timestamp) - (Get-Date $First.Timestamp)).TotalDays

            if ($Days -gt 0) {
                $Delta = $First.MetricValue - $Last.MetricValue # Positive means space is decreasing
                $GrowthPerDay = $Delta / $Days
                $Trends.DiskGrowthRateGBPerWeek = [math]::Round($GrowthPerDay * 7, 2)

                if ($GrowthPerDay -gt 0) {
                    $Trends.EstimatedDaysToFull = [math]::Round($Last.MetricValue / $GrowthPerDay, 0)
                }
            }
        }

        return $Trends
    }
    catch {
        Write-MaintenanceLog -Message "Analytics processing failed: $($_.Exception.Message)" -Level WARNING
        return $null
    }
}

Export-ModuleMember -Function Get-SystemTrend
