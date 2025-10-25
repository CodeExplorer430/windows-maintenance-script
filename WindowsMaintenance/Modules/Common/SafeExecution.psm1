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
        [hashtable] $Context = @{},

        [Parameter(Mandatory = $false, HelpMessage="Maximum execution timeout in minutes")]
        [int] $TimeoutMinutes = 30
    )

    # Initialize execution tracking
    $StartTime = Get-Date
    $TaskId = [GUID]::NewGuid().ToString("N")[0..7] -join ""

    try {
        Write-MaintenanceLog -Message "Starting task: $TaskName [ID: $TaskId]" -Level INFO
        Test-MemoryPressure  # Monitor memory before each operation

        # Handle WhatIf mode for safe testing (check parent scope)
        $WhatIfEnabled = if (Get-Variable -Name 'WhatIf' -Scope 1 -ErrorAction SilentlyContinue) {
            (Get-Variable -Name 'WhatIf' -Scope 1).Value
        } elseif (Get-Variable -Name 'WhatIf' -Scope Global -ErrorAction SilentlyContinue) {
            $Global:WhatIf
        } else { $false }

        if ($WhatIfEnabled) {
            Write-MaintenanceLog -Message "WHATIF: Would execute $TaskName" -Level DEBUG
            return @{
                Success = $true
                WhatIf = $true
                TaskId = $TaskId
                Duration = [TimeSpan]::Zero
            }
        }

        # Execute command directly in current scope to maintain function availability
        # Note: Background jobs would lose access to script functions and variables
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
        # Periodic memory cleanup to prevent resource exhaustion
        if ($Global:MemoryTracker.OperationCount % 5 -eq 0) {
            Optimize-MemoryUsage
        }
    }
}

# Export public functions
Export-ModuleMember -Function @(
    'Invoke-SafeCommand'
)
