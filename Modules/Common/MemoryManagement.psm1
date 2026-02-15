<#
.SYNOPSIS
    Memory management and optimization utilities for Windows Maintenance module.

.DESCRIPTION
    Implements intelligent memory management with adaptive thresholds.
#>

#Requires -Version 5.1

# Import dependencies
Import-Module "$PSScriptRoot\Logging.psm1" -Force
Import-Module "$PSScriptRoot\SystemDetection.psm1" -Force

# Internal script-scoped memory tracker
$script:CheckInterval = 15
$script:OperationCount = 0
$script:InitialMemory = [System.GC]::GetTotalMemory($false)
$script:LastCleanup = Get-Date
$script:OptimizationCount = 0

<#
.SYNOPSIS
    Optimizes PowerShell memory usage.
#>
function Optimize-MemoryUsage {
    [CmdletBinding()]
    [OutputType([double])]
    param(
        [switch]$Force,
        [switch]$Aggressive
    )

    try {
        $MemBefore = [System.GC]::GetTotalMemory($false)

        $ShouldOptimize = $Force -or $Aggressive -or ((Get-Date) - $script:LastCleanup).TotalMinutes -gt 10

        if ($ShouldOptimize) {
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()

            if ($Aggressive) {
                [System.GC]::Collect(2, [System.GCCollectionMode]::Forced)
            }

            $MemAfter = [System.GC]::GetTotalMemory($true)
            $script:LastCleanup = Get-Date
            $script:OptimizationCount++

            $FreedMB = [math]::Round(($MemBefore - $MemAfter) / 1MB, 2)
            if ($FreedMB -gt 10) {
                Write-MaintenanceLog -Message "Memory optimized: Freed ${FreedMB}MB" -Level DEBUG
            }
            return [double]$FreedMB
        }
        return [double]0
    }
    catch {
        return [double]0
    }
}

<#
.SYNOPSIS
    Monitors memory pressure.
#>
function Test-MemoryPressure {
    [CmdletBinding()]
    [OutputType([void])]
    param()

    $script:OperationCount++

    if ($script:OperationCount % 10 -eq 0) {
        $CurrentMemory = [System.GC]::GetTotalMemory($false)
        $GrowthMB = [math]::Round(($CurrentMemory - $script:InitialMemory) / 1MB, 2)

        if ($GrowthMB -gt 500) {
            Optimize-MemoryUsage -Force
        }
    }
}

# Export public functions
Export-ModuleMember -Function @(
    'Optimize-MemoryUsage',
    'Test-MemoryPressure'
)
