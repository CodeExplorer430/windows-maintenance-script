<#
.SYNOPSIS
    Memory management and optimization utilities for Windows Maintenance module.

.DESCRIPTION
    Implements intelligent memory management with adaptive thresholds based on
    system memory configuration. Prevents memory leaks during long-running operations.

    Features:
    - Dynamic memory threshold calculation based on system RAM
    - Multiple garbage collection strategies (standard and aggressive)
    - Memory growth tracking and baseline management
    - Configurable optimization intervals

.NOTES
    File Name      : MemoryManagement.psm1
    Author         : Miguel Velasco
    Prerequisite   : PowerShell 5.1+
    Version        : 4.0.0
    Last Updated   : October 2025
    Module Type    : Common Utility Module
    Dependencies   : Logging.psm1, SystemDetection.psm1
#>

#Requires -Version 5.1

# Import dependencies
Import-Module "$PSScriptRoot\Logging.psm1" -Force
Import-Module "$PSScriptRoot\SystemDetection.psm1" -Force

# Initialize global memory tracker if it doesn't exist
if (-not $Global:MemoryTracker) {
    $Global:MemoryTracker = @{
        CheckInterval = 15                                          # Memory check frequency (operations)
        OperationCount = 0                                          # Counter for operations processed
        InitialMemory = [System.GC]::GetTotalMemory($false)        # Baseline memory usage
        MemoryThresholdMB = 500                                     # Standard memory growth threshold
        ForceCleanupThresholdMB = 1000                             # Critical memory threshold
        OptimizationCount = 0                                       # Number of optimizations performed
        LastCleanup = Get-Date                                      # Timestamp of last cleanup
    }
}

<#
.SYNOPSIS
    Optimizes PowerShell memory usage during maintenance operations.

.DESCRIPTION
    Implements intelligent memory management with adaptive thresholds based on
    system memory configuration. Prevents memory leaks during long-running operations.

    Features:
    - Dynamic memory threshold calculation based on system RAM
    - Multiple garbage collection strategies (standard and aggressive)
    - Memory growth tracking and baseline management
    - Configurable optimization intervals

.PARAMETER Force
    Forces immediate memory optimization regardless of thresholds.

.PARAMETER Aggressive
    Enables aggressive garbage collection for memory-intensive operations.

.OUTPUTS
    [double] Amount of memory freed in megabytes.

.EXAMPLE
    Optimize-MemoryUsage
    Performs standard memory optimization if thresholds are exceeded.

.EXAMPLE
    Optimize-MemoryUsage -Force -Aggressive
    Forces aggressive memory cleanup immediately.

.NOTES
    Performance: Aggressive mode should be used sparingly as it may cause temporary delays
    Security: No sensitive data is exposed during memory operations
#>
function Optimize-MemoryUsage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false, HelpMessage="Force immediate optimization")]
        [switch]$Force,

        [Parameter(Mandatory=$false, HelpMessage="Enable aggressive garbage collection")]
        [switch]$Aggressive
    )

    try {
        # Capture current memory state for analysis
        $MemBefore = [System.GC]::GetTotalMemory($false)
        $MemBeforeMB = [math]::Round($MemBefore / 1MB, 2)
        $MemoryGrowthMB = [math]::Round(($MemBefore - $Global:MemoryTracker.InitialMemory) / 1MB, 2)

        # Determine if optimization should be performed based on multiple criteria
        $ShouldOptimize = $Force -or
                         $Aggressive -or
                         $MemoryGrowthMB -gt $Global:MemoryTracker.MemoryThresholdMB -or
                         ((Get-Date) - $Global:MemoryTracker.LastCleanup).TotalMinutes -gt 5

        if ($ShouldOptimize) {
            Write-MaintenanceLog -Message "Memory optimization triggered: Current growth ${MemoryGrowthMB}MB" -Level DEBUG

            # Clean up large variables that may be holding references
            if (Get-Variable -Name "LargeDataResults" -Scope Global -ErrorAction SilentlyContinue) {
                Remove-Variable -Name "LargeDataResults" -Scope Global -Force
            }

            # Perform garbage collection sequence
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            [System.GC]::Collect()

            # Aggressive cleanup for memory-intensive operations
            if ($Aggressive) {
                [System.GC]::Collect(2, [System.GCCollectionMode]::Forced)
                [System.GC]::WaitForPendingFinalizers()
                [System.GC]::Collect()
            }

            # Calculate optimization results
            $MemAfter = [System.GC]::GetTotalMemory($true)
            $MemAfterMB = [math]::Round($MemAfter / 1MB, 2)
            $MemFreedMB = [math]::Round(($MemBefore - $MemAfter) / 1MB, 2)

            # Update tracking counters
            $Global:MemoryTracker.OptimizationCount++
            $Global:MemoryTracker.LastCleanup = Get-Date

            Write-MaintenanceLog -Message "Memory optimized: ${MemBeforeMB}MB -> ${MemAfterMB}MB (freed ${MemFreedMB}MB)" -Level INFO

            # Update baseline if significant cleanup was achieved
            if ($MemFreedMB -gt 50) {
                $Global:MemoryTracker.InitialMemory = $MemAfter
            }

            return $MemFreedMB
        }

        return 0
    }
    catch {
        Write-MaintenanceLog -Message "Memory optimization failed: $($_.Exception.Message)" -Level WARNING
        return 0
    }
}

<#
.SYNOPSIS
    Monitors memory pressure and triggers optimization when necessary.

.DESCRIPTION
    Implements intelligent memory pressure monitoring with adaptive thresholds
    based on system configuration and operation count. Automatically triggers
    memory optimization to prevent resource exhaustion.

    Features:
    - Dynamic threshold adjustment based on system memory
    - Operation count-based optimization scheduling
    - Critical memory pressure detection
    - Adaptive check frequency based on operation history

.NOTES
    Performance: Check frequency is automatically adjusted to balance monitoring overhead
    Security: No sensitive information is logged during memory monitoring
#>
function Test-MemoryPressure {
    [CmdletBinding()]
    param()

    $Global:MemoryTracker.OperationCount++

    # Adjust check frequency based on operation count for performance optimization
    $CheckFrequency = if ($Global:MemoryTracker.OperationCount -lt 50) { 10 } else { 15 }

    if ($Global:MemoryTracker.OperationCount % $CheckFrequency -eq 0) {
        $CurrentMemory = [System.GC]::GetTotalMemory($false)
        $MemoryGrowthMB = [math]::Round(($CurrentMemory - $Global:MemoryTracker.InitialMemory) / 1MB, 2)

        # Calculate dynamic thresholds based on total system memory
        $SystemMemoryGB = Get-SystemMemoryInfo
        $DynamicThreshold = if ($SystemMemoryGB -gt 16) { 800 } elseif ($SystemMemoryGB -gt 8) { 600 } else { 400 }
        $ForceThreshold = $DynamicThreshold * 1.5

        # Trigger optimization based on memory pressure level
        if ($MemoryGrowthMB -gt $ForceThreshold) {
            Write-MaintenanceLog -Message "Critical memory pressure detected: ${MemoryGrowthMB}MB growth - forcing aggressive cleanup" -Level WARNING
            Optimize-MemoryUsage -Force -Aggressive
        }
        elseif ($MemoryGrowthMB -gt $DynamicThreshold) {
            Optimize-MemoryUsage
        }
    }

    # Periodic cleanup with adaptive intervals
    $CleanupInterval = if ($Global:MemoryTracker.OptimizationCount -gt 5) { 8 } else { 5 }
    if ($Global:MemoryTracker.OperationCount % $CleanupInterval -eq 0) {
        Optimize-MemoryUsage
    }
}

# Export public functions
Export-ModuleMember -Function @(
    'Optimize-MemoryUsage',
    'Test-MemoryPressure'
)
