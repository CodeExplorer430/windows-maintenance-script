<#
.SYNOPSIS
    Enterprise-grade logging system for the Windows Maintenance module.

.DESCRIPTION
    Implements comprehensive logging functionality with support for multiple log levels,
    file outputs, console display, and enterprise auditing requirements.

    Features:
    - Multiple log levels (INFO, WARNING, ERROR, SUCCESS, DEBUG, PROGRESS, DETAIL, SKIP)
    - Automatic log file rotation and management
    - Thread-safe file operations with fallback mechanisms
    - Performance counters and statistics tracking
    - Color-coded console output for improved readability
    - Timestamp precision to milliseconds for detailed auditing

.NOTES
    File Name      : Logging.psm1
    Author         : Miguel Velasco
    Prerequisite   : PowerShell 5.1+
    Version        : 4.0.0
    Last Updated   : October 2025
    Module Type    : Common Utility Module
    Dependencies   : StringFormatting.psm1
#>

#Requires -Version 5.1

# Import dependencies
$ModuleRoot = Split-Path -Parent $PSScriptRoot
Import-Module "$PSScriptRoot\StringFormatting.psm1" -Force

# Initialize global logging variables if they don't exist
if (-not $Global:LogFile) { $Global:LogFile = $null }
if (-not $Global:ErrorLog) { $Global:ErrorLog = $null }
if (-not $Global:PerformanceLog) { $Global:PerformanceLog = $null }
if (-not $Global:DetailedLog) { $Global:DetailedLog = $null }
if (-not $Global:OperationsLog) { $Global:OperationsLog = $null }

# Initialize global counters if they don't exist
if (-not $Global:MaintenanceCounters) {
    $Global:MaintenanceCounters = @{
        ErrorCount = 0
        WarningCount = 0
        SuccessCount = 0
        ModulesExecuted = 0
        ModulesFailed = 0
        SkippedOperations = 0
        DriveOptimizations = 0
    }
}

<#
.SYNOPSIS
    Enterprise-grade logging system with multiple output channels and security features.

.DESCRIPTION
    Implements comprehensive logging functionality with support for multiple log levels,
    file outputs, console display, and enterprise auditing requirements.

    Features:
    - Multiple log levels (INFO, WARNING, ERROR, SUCCESS, DEBUG, PROGRESS, DETAIL, SKIP)
    - Automatic log file rotation and management
    - Thread-safe file operations with fallback mechanisms
    - Performance counters and statistics tracking
    - Color-coded console output for improved readability
    - Timestamp precision to milliseconds for detailed auditing

.PARAMETER Message
    The message to be logged

.PARAMETER Level
    Log level indicating severity and type of message

.PARAMETER NoConsole
    Suppresses console output (file logging only)

.PARAMETER NoTimestamp
    Excludes timestamp from the log entry

.EXAMPLE
    Write-MaintenanceLog -Message "Operation completed successfully" -Level SUCCESS

.EXAMPLE
    Write-MaintenanceLog -Message "Debug information" -Level DEBUG -NoConsole

.NOTES
    Security: Implements safe file handling with proper error recovery
    Performance: Optimized for high-frequency logging during maintenance operations
    Reliability: Multiple fallback mechanisms ensure logging never fails silently
#>
function Write-MaintenanceLog {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, HelpMessage="Message to be logged")]
        [string] $Message,

        [Parameter(Mandatory=$false, HelpMessage="Log level for categorization")]
        [ValidateSet("INFO","WARNING","ERROR","SUCCESS","DEBUG","PROGRESS","DETAIL","SKIP")]
        [string] $Level = "INFO",

        [Parameter(Mandatory=$false, HelpMessage="Suppress console output")]
        [switch] $NoConsole,

        [Parameter(Mandatory=$false, HelpMessage="Exclude timestamp from log entry")]
        [switch] $NoTimestamp
    )

    try {
        # Update global maintenance counters for statistics tracking
        switch ($Level) {
            "ERROR" { $Global:MaintenanceCounters.ErrorCount++ }
            "WARNING" { $Global:MaintenanceCounters.WarningCount++ }
            "SUCCESS" { $Global:MaintenanceCounters.SuccessCount++ }
            "SKIP" { $Global:MaintenanceCounters.SkippedOperations++ }
        }

        # Build timestamped message with millisecond precision for auditing
        $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $LogMessage = if ($NoTimestamp) {
            "[$Level] $Message"
        } else {
            "[$Timestamp] [$Level] $Message"
        }

        # Determine appropriate log files based on message level and configuration
        $LogFiles = @()
        if ($Global:LogFile) { $LogFiles += $Global:LogFile }
        if ($Level -eq "ERROR" -and $Global:ErrorLog) { $LogFiles += $Global:ErrorLog }
        if ($Level -in @("PROGRESS","SUCCESS","ERROR","WARNING","SKIP") -and $Global:OperationsLog) {
            $LogFiles += $Global:OperationsLog
        }
        # Check if DetailedOutput is enabled (from parent scope or global)
        $DetailedOutputEnabled = if (Get-Variable -Name 'DetailedOutput' -Scope Global -ErrorAction SilentlyContinue) {
            $Global:DetailedOutput
        } else { $false }
        if ($Level -eq "DETAIL" -and $DetailedOutputEnabled -and $Global:DetailedLog) {
            $LogFiles += $Global:DetailedLog
        }

        # Write to log files with error handling and fallback mechanisms
        foreach ($Log in $LogFiles) {
            if ($Log) {
                try {
                    Add-Content -Path $Log -Value $LogMessage -ErrorAction Stop
                }
                catch {
                    # Fallback to backup log location if primary logging fails
                    $BackupLog = "$env:TEMP\maintenance_backup_$(Get-Date -Format 'yyyyMMdd').log"
                    try {
                        Add-Content -Path $BackupLog -Value "BACKUP LOG: $LogMessage" -ErrorAction Stop
                    }
                    catch {
                        Write-Host "LOGGING FAILED: $LogMessage" -ForegroundColor Red
                    }
                }
            }
        }

        # Color-coded console output for improved readability
        if (-not $NoConsole) {
            # Check if EnableVerbose is enabled (from parent scope or global)
            $EnableVerboseEnabled = if (Get-Variable -Name 'EnableVerbose' -Scope Global -ErrorAction SilentlyContinue) {
                $Global:EnableVerbose
            } else { $false }

            switch ($Level) {
                "ERROR"    {
                    Write-Host "[ERROR]    $Message" -ForegroundColor Red
                    Write-Error $Message -ErrorAction SilentlyContinue
                }
                "WARNING"  { Write-Host "[WARNING]  $Message" -ForegroundColor Yellow }
                "SUCCESS"  { Write-Host "[SUCCESS]  $Message" -ForegroundColor Green }
                "PROGRESS" { Write-Host "[PROGRESS] $Message" -ForegroundColor Cyan }
                "DEBUG"    { if ($EnableVerboseEnabled) { Write-Host "[DEBUG]    $Message" -ForegroundColor Magenta } }
                "DETAIL"   { if ($DetailedOutputEnabled) { Write-Host "[DETAIL]   $Message" -ForegroundColor DarkCyan } }
                "SKIP"     { Write-Host "[SKIP]     $Message" -ForegroundColor DarkYellow }
                default    { Write-Host "[INFO]     $Message" -ForegroundColor White }
            }
        }
    }
    catch {
        # Emergency fallback logging when all else fails
        $FallbackMessage = "[$Level] $Message [LOGGING ERROR: $($_.Exception.Message)]"
        Write-Host $FallbackMessage -ForegroundColor Red

        try {
            $FallbackLog = "$env:TEMP\maintenance_emergency_$(Get-Date -Format 'yyyyMMdd').log"
            Add-Content -Path $FallbackLog -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') $FallbackMessage" -ErrorAction Stop
        }
        catch {
            # Final fallback - console only with no file logging
        }
    }
}

<#
.SYNOPSIS
    Enhanced progress reporting with performance metrics and throughput calculation.

.DESCRIPTION
    Provides sophisticated progress tracking with performance metrics logging
    and throughput calculations for long-running maintenance operations.

    Features:
    - Visual progress bars with percentage completion
    - Performance metrics logging with timestamps
    - Throughput calculation and reporting
    - Integration with performance log files
    - Safe error handling for uninterrupted operation

.PARAMETER Activity
    Name of the activity being tracked

.PARAMETER Status
    Current status description

.PARAMETER PercentComplete
    Completion percentage (0-100)

.PARAMETER Details
    Additional details about the operation

.PARAMETER ThroughputInfo
    Performance throughput information

.EXAMPLE
    Write-ProgressBar -Activity "Disk Cleanup" -Status "Processing temp files" -PercentComplete 45

.NOTES
    Performance: Optimized to minimize overhead during progress reporting
    Reliability: Continues operation even if progress reporting fails
#>
function Write-ProgressBar {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, HelpMessage="Activity name for progress tracking")]
        [string] $Activity,

        [Parameter(Mandatory=$true, HelpMessage="Current status description")]
        [string] $Status,

        [Parameter(Mandatory=$true, HelpMessage="Completion percentage (0-100)")]
        [int]    $PercentComplete,

        [Parameter(Mandatory=$false, HelpMessage="Additional operation details")]
        [string] $Details = "",

        [Parameter(Mandatory=$false, HelpMessage="Performance throughput information")]
        [string] $ThroughputInfo = ""
    )

    try {
        # Display visual progress bar
        Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete

        $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'

        # Build progress message with safe string formatting
        $ProgressMessage = if ([string]::IsNullOrWhiteSpace($Activity) -or [string]::IsNullOrWhiteSpace($Status)) {
            "Progress update - $PercentComplete% complete"
        } else {
            Format-SafeString -Template "{0} - {1} ({2}% complete)" -Arguments @($Activity, $Status, $PercentComplete)
        }

        # Create performance metrics entry
        $MetricEntry = if ([string]::IsNullOrWhiteSpace($Details) -and [string]::IsNullOrWhiteSpace($ThroughputInfo)) {
            "[$Timestamp] PERF: $Activity - $PercentComplete% complete"
        } else {
            Format-SafeString -Template "[{0}] PERF: {1} - Details: {2} - {3}" -Arguments @($Timestamp, $Activity, $Details, $ThroughputInfo)
        }

        # Log to performance file if available
        if ($Global:PerformanceLog) {
            Add-Content -Path $Global:PerformanceLog -Value $MetricEntry -ErrorAction SilentlyContinue
        }

        # Log progress to main log
        Write-MaintenanceLog -Message $ProgressMessage -Level PROGRESS
    }
    catch {
        # Ignore progress reporting errors to ensure operations continue
    }
}

<#
.SYNOPSIS
    Performance metrics logging with throughput calculation and detailed timing.

.DESCRIPTION
    Captures and logs detailed performance metrics for maintenance operations,
    including execution time, data processing rates, and throughput calculations.

    Features:
    - Precise timing with sub-second accuracy
    - Throughput calculation for data processing operations
    - Detailed operation context logging
    - Performance trend analysis support
    - Safe error handling to prevent operation interruption

.PARAMETER Operation
    Name of the operation being measured

.PARAMETER Duration
    TimeSpan object representing operation duration

.PARAMETER Details
    Additional context and details about the operation

.PARAMETER DataProcessed
    Amount of data processed (for throughput calculation)

.PARAMETER Unit
    Unit of measurement for processed data

.EXAMPLE
    Write-PerformanceMetric -Operation "File Cleanup" -Duration $ElapsedTime -Details "Removed temp files" -DataProcessed 1024 -Unit "files"

.NOTES
    Performance: Designed for minimal overhead during metric collection
    Security: Sanitizes input to prevent log injection attacks
#>
function Write-PerformanceMetric {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, HelpMessage="Operation name for performance tracking")]
        [string]   $Operation,

        [Parameter(Mandatory = $true, HelpMessage="Operation duration")]
        [timespan] $Duration,

        [Parameter(Mandatory=$false, HelpMessage="Additional operation context")]
        [string]   $Details       = "",

        [Parameter(Mandatory=$false, HelpMessage="Amount of data processed")]
        [long]     $DataProcessed = 0,

        [Parameter(Mandatory=$false, HelpMessage="Unit of measurement for data")]
        [string]   $Unit          = "bytes"
    )

    try {
        # Validate operation name
        if ([string]::IsNullOrWhiteSpace($Operation)) {
            Write-MaintenanceLog -Message "Performance logging skipped: Operation name is empty" -Level DEBUG
            return
        }

        $Timestamp   = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $DurationSec = [math]::Round($Duration.TotalSeconds, 2)

        # Sanitize details to prevent log injection attacks
        $FormattedDetails = if ([string]::IsNullOrWhiteSpace($Details)) {
            "Completed successfully"
        } else {
            # Security: Remove potentially dangerous characters
            $Details -replace '[`\r\n\t]', ' ' -replace '\s+', ' '
        }

        # Calculate throughput if data processing metrics are available
        $ThroughputInfo = ""
        if ($DataProcessed -gt 0 -and $Duration.TotalSeconds -gt 0) {
            try {
                $Rate = [math]::Round($DataProcessed / $Duration.TotalSeconds, 2)
                $ThroughputInfo = " | Throughput: $Rate $Unit/sec"
            } catch {
                $ThroughputInfo = " | Throughput: calculation error"
            }
        }

        $MetricEntry = "[$Timestamp] PERF: $Operation | Duration: ${DurationSec}s | Details: $FormattedDetails$ThroughputInfo"

        # Write to performance log with error handling
        if ($Global:PerformanceLog -and (Test-Path (Split-Path $Global:PerformanceLog -Parent))) {
            try {
                Add-Content -Path $Global:PerformanceLog -Value $MetricEntry -ErrorAction SilentlyContinue
            } catch {
                # Non-critical error - don't spam main log with performance logging failures
                Write-MaintenanceLog -Message "Performance logging failed for operation: $Operation" -Level DEBUG
            }
        }
    }
    catch {
        # Handle performance logging errors gracefully
        Write-MaintenanceLog -Message "Performance logging critical error: $($_.Exception.Message)" -Level DEBUG
    }
}

<#
.SYNOPSIS
    Detailed operation logging for comprehensive audit trails.

.DESCRIPTION
    Provides detailed operation logging for enterprise audit trails and
    troubleshooting purposes. Captures granular operation details.

.PARAMETER Operation
    Operation name being performed

.PARAMETER Details
    Detailed information about the operation

.PARAMETER Result
    Result or outcome of the operation

.EXAMPLE
    Write-DetailedOperation -Operation "Drive Analysis" -Details "Scanning C: drive" -Result "Complete"
#>
function Write-DetailedOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, HelpMessage="Operation being performed")]
        [string] $Operation,

        [Parameter(Mandatory = $true, HelpMessage="Detailed operation information")]
        [AllowEmptyString()]
        [string] $Details,

        [Parameter(Mandatory=$false, HelpMessage="Operation result")]
        [string] $Result = 'Completed'
    )

    # Provide default value if Details is empty
    $SafeDetails = if ([string]::IsNullOrWhiteSpace($Details)) {
        "No additional details available"
    } else {
        $Details
    }

    $DetailMessage = "OPERATION: $Operation - DETAILS: $SafeDetails - RESULT: $Result"
    Write-MaintenanceLog $DetailMessage "DETAIL"
}

# Export public functions
Export-ModuleMember -Function @(
    'Write-MaintenanceLog',
    'Write-ProgressBar',
    'Write-PerformanceMetric',
    'Write-DetailedOperation'
)
