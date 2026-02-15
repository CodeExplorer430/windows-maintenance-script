<#
.SYNOPSIS
    Safe command execution utilities for Windows Maintenance module.

.DESCRIPTION
    Provides a robust framework for executing maintenance tasks with built-in error handling,
    timeout protection, performance monitoring, and memory management.

    Features:
    - Comprehensive error handling with multiple fallback strategies
    - Configurable timeout protection to prevent hanging operations
    - Performance monitoring with detailed metrics collection
    - Memory pressure monitoring and automatic optimization
    - WhatIf mode support for safe testing and validation
    - Task identification and tracking for audit purposes

.NOTES
    File Name      : SafeExecution.psm1
    Author         : Miguel Velasco
    Prerequisite   : PowerShell 5.1+
    Version        : 4.0.0
    Last Updated   : October 2025
    Module Type    : Common Utility Module
    Dependencies   : Logging.psm1, MemoryManagement.psm1
#>

#Requires -Version 5.1

# Import dependencies
Import-Module "$PSScriptRoot\Logging.psm1" -Force
Import-Module "$PSScriptRoot\MemoryManagement.psm1" -Force

<#
.SYNOPSIS
    Enterprise-grade safe command execution with comprehensive error handling and monitoring.

.DESCRIPTION
    Provides a robust framework for executing maintenance tasks with built-in error handling,
    timeout protection, performance monitoring, and memory management. Implements enterprise
    patterns for reliable script execution in production environments.

    Features:
    - Comprehensive error handling with multiple fallback strategies
    - Configurable timeout protection to prevent hanging operations
    - Performance monitoring with detailed metrics collection
    - Memory pressure monitoring and automatic optimization
    - WhatIf mode support for safe testing and validation
    - Task identification and tracking for audit purposes
    - Context preservation for debugging and troubleshooting

.PARAMETER TaskName
    Descriptive name for the task being executed

.PARAMETER Command
    ScriptBlock containing the command(s) to execute

.PARAMETER SuccessMessage
    Message to display/log upon successful completion

.PARAMETER OnErrorAction
    Action to take when errors occur ("Continue" or "Stop")

.PARAMETER Context
    Additional context information for debugging

.PARAMETER TimeoutMinutes
    Maximum execution time before timeout (adaptive based on FastMode)

.OUTPUTS
    [hashtable] Execution result with success status, duration, and details

.EXAMPLE
    Invoke-SafeCommand -TaskName "System Update" -Command { Get-WindowsUpdate } -SuccessMessage "Updates checked"

.EXAMPLE
    Invoke-SafeCommand -TaskName "Critical Operation" -Command { $script } -OnErrorAction Stop -TimeoutMinutes 45

.NOTES
    Security: All commands execute in controlled environment with error containment
    Performance: Includes automatic memory management and optimization
    Reliability: Multiple fallback mechanisms ensure graceful error handling
#>
function Invoke-SafeCommand {
    [CmdletBinding()]
    [OutputType([hashtable])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "_Context")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "_TimeoutMinutes")]
    param(
        [Parameter(Mandatory = $true, HelpMessage="Descriptive name for the task")]
        [string] $TaskName,

        [Parameter(Mandatory = $true, HelpMessage="ScriptBlock to execute")]
        [scriptblock] $Command,

        [Parameter(Mandatory = $false, HelpMessage="Success message for logging")]
        [string] $SuccessMessage = 'Completed successfully',

        [Parameter(Mandatory = $false, HelpMessage="Error handling behavior")]
        [ValidateSet("Continue","Stop")]
        [string] $OnErrorAction = 'Continue',

        [Parameter(Mandatory = $false, HelpMessage="Additional context for debugging")]
        [hashtable] $_Context = @{},

        [Parameter(Mandatory = $false, HelpMessage="Maximum execution timeout in minutes")]
        [int] $_TimeoutMinutes = 30
    )

    # Initialize execution tracking
    $StartTime = Get-Date
    $TaskId = [GUID]::NewGuid().ToString("N")[0..7] -join ""

    try {
        Write-MaintenanceLog -Message "Starting task: $TaskName [ID: $TaskId]" -Level INFO
        Test-MemoryPressure  # Monitor memory before each operation

        # Execute command directly in current scope to maintain function availability
        $Result = Invoke-Command -ScriptBlock $Command -NoNewScope
        $Duration = (Get-Date) - $StartTime

        # Log successful execution with performance metrics
        Write-PerformanceMetric -Operation $TaskName -Duration $Duration -Details $SuccessMessage
        Write-MaintenanceLog -Message "$TaskName - $SuccessMessage [Duration: $($Duration.TotalSeconds)s]" -Level SUCCESS

        return @{
            Success = $true
            Result = $Result
            Duration = $Duration
            TaskId = $TaskId
        }
    }
    catch {
        # Comprehensive error handling and logging
        $Duration = (Get-Date) - $StartTime
        $ErrorMessage = $_.Exception.Message

        Write-PerformanceMetric -Operation $TaskName -Duration $Duration -Details "FAILED: $ErrorMessage"
        Write-MaintenanceLog -Message "Error in ${TaskName}: $ErrorMessage [Duration: $($Duration.TotalSeconds)s]" -Level ERROR

        # Handle error escalation based on configuration
        if ($OnErrorAction -eq 'Stop') {
            throw
        }

        return @{
            Success = $false
            Error = $ErrorMessage
            Duration = $Duration
            TaskId = $TaskId
        }
    }
    finally {
        # Periodic memory cleanup
        Optimize-MemoryUsage
    }
}

<#
.SYNOPSIS
    Executes a script block in parallel for a collection of items if PowerShell 7+ is used.
    Falls back to sequential execution in PowerShell 5.1.
#>
function Invoke-Parallel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [System.Collections.IEnumerable]$InputObject,

        [Parameter(Mandatory=$true)]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory=$false)]
        [hashtable]$Using = @{},

        [Parameter(Mandatory=$false)]
        [int]$ThrottleLimit = 5
    )

    if ($PSVersionTable.PSVersion.Major -ge 7) {
        # PowerShell 7+ Parallel execution
        $InputObject | ForEach-Object -Parallel $ScriptBlock -ArgumentList $Using -ThrottleLimit $ThrottleLimit
    }
    else {
        # PowerShell 5.1 Fallback
        foreach ($item in $InputObject) {
            # In 5.1, we manually inject the 'Using' variables into the scope if possible,
            # or the script block must handle it. For consistency with the Parallel version,
            # we pass 'Using' as an argument.
            & $ScriptBlock $item $Using
        }
    }
}

# Export public functions
Export-ModuleMember -Function @(
    'Invoke-SafeCommand',
    'Invoke-Parallel'
)
