<#
.SYNOPSIS
    Enterprise-grade logging system for the Windows Maintenance module.

.DESCRIPTION
    Implements comprehensive logging functionality with support for multiple log levels,
    file outputs, console display, and enterprise auditing requirements.
#>

#Requires -Version 5.1

# Import dependencies
Import-Module "$PSScriptRoot\StringFormatting.psm1" -Force

# Script-scoped logging state (Internal)
$script:LogFile = $null
$script:ErrorLog = $null
$script:PerformanceLog = $null
$script:DetailedLog = $null
$script:OperationsLog = $null
$script:EnableVerbose = $false
$script:DetailedOutput = $false
$script:SilentMode = $false

# Initialize counters
$script:MaintenanceCounters = @{
    ErrorCount = 0
    WarningCount = 0
    SuccessCount = 0
    ModulesExecuted = 0
    ModulesFailed = 0
    SkippedOperations = 0
    DriveOptimizations = 0
}

<#
.SYNOPSIS
    Configures the logging system state.
#>
function Set-LoggingConfig {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [string]$LogFile,
        [string]$ErrorLog,
        [string]$PerformanceLog,
        [string]$DetailedLog,
        [string]$OperationsLog,
        [switch]$EnableVerbose,
        [switch]$DetailedOutput,
        [switch]$SilentMode,
        [switch]$EnableEventLog
    )
    if ($PSCmdlet.ShouldProcess("Logging Configuration", "Update internal logging state")) {
        if ($LogFile) { $script:LogFile = $LogFile }
        if ($ErrorLog) { $script:ErrorLog = $ErrorLog }
        if ($PerformanceLog) { $script:PerformanceLog = $PerformanceLog }
        if ($DetailedLog) { $script:DetailedLog = $DetailedLog }
        if ($OperationsLog) { $script:OperationsLog = $OperationsLog }
        $script:EnableVerbose = $EnableVerbose
        $script:DetailedOutput = $DetailedOutput
        $script:SilentMode = $SilentMode
        $script:EventLogEnabled = $EnableEventLog
    }
}

<#
.SYNOPSIS
    Retrieves the current maintenance counters.
#>
function Get-MaintenanceCounter {
    return $script:MaintenanceCounters
}

<#
.SYNOPSIS
    Enterprise-grade logging system with multiple output channels and security features.
#>
function Write-MaintenanceLog {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Message,

        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO","WARNING","ERROR","SUCCESS","DEBUG","PROGRESS","DETAIL","SKIP")]
        [string] $Level = "INFO",

        [Parameter(Mandatory=$false)]
        [switch] $NoConsole,

        [Parameter(Mandatory=$false)]
        [switch] $NoTimestamp,

        [Parameter(Mandatory=$false)]
        [switch] $LogToEventLog
    )

    try {
        # Update maintenance counters
        switch ($Level) {
            "ERROR" { $script:MaintenanceCounters.ErrorCount++ }
            "WARNING" { $script:MaintenanceCounters.WarningCount++ }
            "SUCCESS" { $script:MaintenanceCounters.SuccessCount++ }
            "SKIP" { $script:MaintenanceCounters.SkippedOperations++ }
        }

        # Build timestamped message
        $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $LogMessage = if ($NoTimestamp) {
            "[$Level] $Message"
        } else {
            "[$Timestamp] [$Level] $Message"
        }

        # Windows Event Log Integration
        if ($LogToEventLog -or $script:EventLogEnabled) {
            $EventSource = "WindowsMaintenance"
            $EventLogName = "Application"

            # Auto-register source (Requires Admin)
            if (-not ([System.Diagnostics.EventLog]::SourceExists($EventSource))) {
                try {
                    New-EventLog -LogName $EventLogName -Source $EventSource -ErrorAction SilentlyContinue
                } catch {
                    Write-Debug "Event log registration skipped (expected if non-admin): $($_.Exception.Message)"
                }
            }

            if ([System.Diagnostics.EventLog]::SourceExists($EventSource)) {
                $EntryType = switch ($Level) {
                    "ERROR" { "Error" }
                    "WARNING" { "Warning" }
                    "SUCCESS" { "Information" }
                    default { "Information" }
                }
                # Limit message length for Event Log
                $SafeMessage = if ($Message.Length -gt 30000) { $Message.Substring(0, 30000) + "..." } else { $Message }
                Write-EventLog -LogName $EventLogName -Source $EventSource -EntryType $EntryType -EventId 100 -Message $SafeMessage -ErrorAction SilentlyContinue
            }
        }

        # Determine appropriate log files
        $LogFiles = @()
        if ($script:LogFile) { $LogFiles += $script:LogFile }
        if ($Level -eq "ERROR" -and $script:ErrorLog) { $LogFiles += $script:ErrorLog }
        if ($Level -in @("PROGRESS","SUCCESS","ERROR","WARNING","SKIP") -and $script:OperationsLog) {
            $LogFiles += $script:OperationsLog
        }
        if ($Level -eq "DETAIL" -and $script:DetailedOutput -and $script:DetailedLog) {
            $LogFiles += $script:DetailedLog
        }

        # Write to log files
        foreach ($Log in $LogFiles) {
            if ($Log) {
                try {
                    Add-Content -Path $Log -Value $LogMessage -ErrorAction Stop
                }
                catch {
                    # Fallback to backup log location
                    $BackupLog = "$env:TEMP\maintenance_backup_$(Get-Date -Format 'yyyyMMdd').log"
                    try {
                        Add-Content -Path $BackupLog -Value "BACKUP LOG: $LogMessage" -ErrorAction Stop
                    }
                    catch {
                        Write-Output "LOGGING FAILED: $LogMessage"
                    }
                }
            }
        }

        # Console output via Write-Information (standard for PS 5.0+)
        if (-not $NoConsole) {
            $Color = switch ($Level) {
                "ERROR"    { "Red" }
                "WARNING"  { "Yellow" }
                "SUCCESS"  { "Green" }
                "PROGRESS" { "Cyan" }
                "DEBUG"    { "Magenta" }
                "DETAIL"   { "DarkCyan" }
                "SKIP"     { "DarkYellow" }
                default    { "White" }
            }

            $Display = $true
            if ($Level -eq "DEBUG" -and -not $script:EnableVerbose) { $Display = $false }
            if ($Level -eq "DETAIL" -and -not $script:DetailedOutput) { $Display = $false }

            if ($Display) {
                $Tag = "Level:$Level"
                $ColorTag = "Color:$Color"
                # Modern recommendation: Write-Information with tags
                Write-Information -MessageData $Message -Tags $Tag, $ColorTag

                # Note: To see these in standard console without Host UI support,
                # the caller must set $InformationPreference = 'Continue'
            }

            if ($Level -eq "ERROR") {
                Write-Error $Message -ErrorAction SilentlyContinue
            }
        }
    }
    catch {
        $FallbackMessage = "[$Level] $Message [LOGGING ERROR: $($_.Exception.Message)]"
        Write-Output $FallbackMessage
    }
}

<#
.SYNOPSIS
    Enhanced progress reporting.
#>
function Write-ProgressBar {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string] $Activity,

        [Parameter(Mandatory=$true)]
        [string] $Status,

        [Parameter(Mandatory=$true)]
        [int]    $PercentComplete,

        [Parameter(Mandatory=$false)]
        [string] $Details = "",

        [Parameter(Mandatory=$false)]
        [string] $ThroughputInfo = ""
    )

    try {
        # Visual progress bar
        Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete

        if (-not $script:SilentMode) {
            $SafeStatus = if ($Status.Length -gt 45) { $Status.Substring(0, 42) + "..." } else { $Status.PadRight(45) }
            $ProgressText = "[$($PercentComplete.ToString().PadLeft(3))%] | ${Activity}: $SafeStatus"

            Write-Information -MessageData $ProgressText -Tags "Progress:$PercentComplete", "Activity:$Activity"
        }

        $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
        $ProgressMessage = Format-SafeString -Template "{0} - {1} ({2}% complete)" -Arguments @($Activity, $Status, $PercentComplete)
        $MetricEntry = "[$Timestamp] PERF: $Activity - $PercentComplete% complete $Details $ThroughputInfo"

        if ($script:PerformanceLog) {
            Add-Content -Path $script:PerformanceLog -Value $MetricEntry -ErrorAction SilentlyContinue
        }

        Write-MaintenanceLog -Message $ProgressMessage -Level PROGRESS -NoConsole
    }
    catch {
        Write-Error "Progress reporting failed: $($_.Exception.Message)" -ErrorAction SilentlyContinue
    }
}

<#
.SYNOPSIS
    Performance metrics logging.
#>
function Write-PerformanceMetric {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]   $Operation,

        [Parameter(Mandatory = $true)]
        [timespan] $Duration,

        [Parameter(Mandatory=$false)]
        [string]   $Details       = "",

        [Parameter(Mandatory=$false)]
        [long]     $DataProcessed = 0,

        [Parameter(Mandatory=$false)]
        [string]   $Unit          = "bytes"
    )

    try {
        if ([string]::IsNullOrWhiteSpace($Operation)) { return }

        $Timestamp   = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $DurationSec = [math]::Round($Duration.TotalSeconds, 2)
        $FormattedDetails = $Details -replace '[`\r\n\t]', ' ' -replace '\s+', ' '

        $ThroughputInfo = ""
        if ($DataProcessed -gt 0 -and $Duration.TotalSeconds -gt 0) {
            $Rate = [math]::Round($DataProcessed / $Duration.TotalSeconds, 2)
            $ThroughputInfo = " | Throughput: $Rate $Unit/sec"
        }

        $MetricEntry = "[$Timestamp] PERF: $Operation | Duration: ${DurationSec}s | Details: $FormattedDetails$ThroughputInfo"

        if ($script:PerformanceLog) {
            Add-Content -Path $script:PerformanceLog -Value $MetricEntry -ErrorAction SilentlyContinue
        }
    }
    catch {
        Write-Error "Progress reporting failed: $($_.Exception.Message)" -ErrorAction SilentlyContinue
    }
}

<#
.SYNOPSIS
    Detailed operation logging.
#>
function Write-DetailedOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Operation,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string] $Details,

        [Parameter(Mandatory=$false)]
        [string] $Result = 'Completed'
    )

    $SafeDetails = if ([string]::IsNullOrWhiteSpace($Details)) { "No details" } else { $Details }
    $DetailMessage = "OPERATION: $Operation - DETAILS: $SafeDetails - RESULT: $Result"
    Write-MaintenanceLog -Message $DetailMessage -Level DETAIL
}

# Export public functions
Export-ModuleMember -Function @(
    'Write-MaintenanceLog',
    'Write-ProgressBar',
    'Write-PerformanceMetric',
    'Write-DetailedOperation',
    'Set-LoggingConfig',
    'Get-MaintenanceCounter'
)
