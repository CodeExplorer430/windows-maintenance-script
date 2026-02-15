<#
.SYNOPSIS
    Real-time progress output module for displaying live command execution.

.DESCRIPTION
    Provides enhanced progress display that shows actual command output in real-time
    while maintaining progress tracking. This gives users visibility into what's
    happening during long-running operations like package updates.

    Features:
    - Real-time command output streaming
    - Progress bar integration
    - Timeout protection
    - Visual section headers
    - Package update tables
    - Color-coded output

.NOTES
    File Name      : RealTimeProgressOutput.psm1
    Author         : Miguel Velasco
    Prerequisite   : PowerShell 5.1+
    Version        : 4.0.0
    Last Updated   : October 2025
    Module Type    : Common Utility Module
    Dependencies   : Logging.psm1
#>

#Requires -Version 5.1

# Import dependencies
Import-Module "$PSScriptRoot\Logging.psm1" -Force

<#
.SYNOPSIS
    Executes a command with real-time output display and progress tracking.

.DESCRIPTION
    Runs commands and streams their output directly to the console in real-time,
    while maintaining progress bar updates. This provides transparency for
    long-running operations like package updates.

.PARAMETER Command
    The command to execute (executable path)

.PARAMETER Arguments
    Command line arguments

.PARAMETER ActivityName
    Name to display in progress bar

.PARAMETER StatusMessage
    Initial status message

.PARAMETER WorkingDirectory
    Working directory for command execution

.PARAMETER ShowRealTimeOutput
    Enable real-time output streaming (default: true)

.PARAMETER TimeoutMinutes
    Command timeout in minutes (default: 30)

.OUTPUTS
    [hashtable] Execution results with exit code and output

.EXAMPLE
    Invoke-CommandWithRealTimeOutput -Command "winget" -Arguments "upgrade --all" -ActivityName "WinGet Updates" -StatusMessage "Updating packages..."

.NOTES
    Security: Output is streamed directly, errors are captured separately
    Performance: Real-time display may slow down for very verbose commands
    UX: Users see exactly what's happening, improving transparency
#>
function Invoke-CommandWithRealTimeOutput {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([hashtable])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "_EventSender")]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Command,

        [Parameter(Mandatory=$false)]
        [string]$Arguments = "",

        [Parameter(Mandatory=$true)]
        [string]$ActivityName,

        [Parameter(Mandatory=$false)]
        [string]$StatusMessage = "Executing command...",

        [Parameter(Mandatory=$false)]
        [string]$WorkingDirectory = $PWD,

        [Parameter(Mandatory=$false)]
        [bool]$ShowRealTimeOutput = $true,

        [Parameter(Mandatory=$false)]
        [int]$TimeoutMinutes = 30
    )

    $Result = @{
        Success = $false
        ExitCode = -1
        Output = ""
        Duration = [TimeSpan]::Zero
        TimedOut = $false
    }

    try {
        if (-not $PSCmdlet.ShouldProcess("$Command $Arguments", "Execute command with real-time output")) {
            $Result.Success = $true
            $Result.Output = "WhatIf mode - operation simulated"
            return $Result
        }

        $StartTime = Get-Date

        # Show initial progress
        Write-ProgressBar -Activity $ActivityName -PercentComplete 10 -Status $StatusMessage
        Write-MaintenanceLog -Message "Executing: $Command $Arguments" -Level PROGRESS

        if ($ShowRealTimeOutput) {
            # Visual separator for better readability
            Write-Information -MessageData "`n  ========== $ActivityName - Real-Time Output ==========" -Tags "Color:Cyan", "Level:PROGRESS"
            Write-Information -MessageData "  Command: $Command $Arguments" -Tags "Color:Gray", "Level:PROGRESS"
            Write-Information -MessageData "  ======================================================`n" -Tags "Color:Cyan", "Level:PROGRESS"
        }

        # Create process with real-time output streaming
        $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
        $ProcessInfo.FileName = $Command
        $ProcessInfo.Arguments = $Arguments
        $ProcessInfo.WorkingDirectory = $WorkingDirectory
        $ProcessInfo.UseShellExecute = $false
        $ProcessInfo.RedirectStandardOutput = $true
        $ProcessInfo.RedirectStandardError = $true
        $ProcessInfo.CreateNoWindow = $true

        $Process = New-Object System.Diagnostics.Process
        $Process.StartInfo = $ProcessInfo

        # StringBuilder for capturing full output
        $OutputBuilder = New-Object System.Text.StringBuilder
        $ErrorBuilder = New-Object System.Text.StringBuilder

        # Event handlers for real-time output
        $OutputDataReceived = {
            param($_EventSender, $EventArguments)
            if ($EventArguments.Data) {
                # Display in real-time if enabled
                if ($ShowRealTimeOutput) {
                    Write-Information -MessageData "  $($EventArguments.Data)" -Tags "Color:White", "Level:PROGRESS"
                }
                [void]$OutputBuilder.AppendLine($EventArguments.Data)
            }
        }

        $ErrorDataReceived = {
            param($_EventSender, $EventArguments)
            if ($EventArguments.Data) {
                # Display errors in real-time with color coding
                if ($ShowRealTimeOutput) {
                    $Color = if ($EventArguments.Data -match "error|failed|exception") { "Red" }
                             elseif ($EventArguments.Data -match "warning|warn") { "Yellow" }
                             else { "Gray" }
                    Write-Information -MessageData "  $($EventArguments.Data)" -Tags "Color:$Color", "Level:PROGRESS"
                }
                [void]$ErrorBuilder.AppendLine($EventArguments.Data)
            }
        }

        # Register event handlers
        Register-ObjectEvent -InputObject $Process -EventName OutputDataReceived -Action $OutputDataReceived | Out-Null
        Register-ObjectEvent -InputObject $Process -EventName ErrorDataReceived -Action $ErrorDataReceived | Out-Null

        # Start process and begin reading output
        $Process.Start() | Out-Null
        $Process.BeginOutputReadLine()
        $Process.BeginErrorReadLine()

        # Update progress while waiting
        $ProgressPercent = 10
        $TimeoutSeconds = $TimeoutMinutes * 60
        $Elapsed = 0
        $UpdateInterval = 2  # Update every 2 seconds

        while (-not $Process.HasExited -and $Elapsed -lt $TimeoutSeconds) {
            Start-Sleep -Seconds $UpdateInterval
            $Elapsed += $UpdateInterval

            # Calculate progress (10% to 90% based on elapsed time)
            $ProgressPercent = [math]::Min(10 + (($Elapsed / $TimeoutSeconds) * 80), 90)
            Write-ProgressBar -Activity $ActivityName -PercentComplete $ProgressPercent -Status "$StatusMessage (Running: $([math]::Round($Elapsed / 60, 1))m)"
        }

        # Check for timeout
        if (-not $Process.HasExited) {
            $Process.Kill()
            $Result.TimedOut = $true
            Write-MaintenanceLog -Message "$ActivityName timed out after $TimeoutMinutes minutes" -Level ERROR

            if ($ShowRealTimeOutput) {
                Write-Information -MessageData "`n  [TIMEOUT] Operation exceeded $TimeoutMinutes minutes" -Tags "Color:Red", "Level:ERROR"
                Write-Information -MessageData "  ======================================================`n" -Tags "Color:Cyan", "Level:ERROR"
            }
        }
        else {
            # Wait a moment for output buffers to flush
            Start-Sleep -Milliseconds 500

            # Capture results
            $Result.ExitCode = $Process.ExitCode
            $Result.Output = $OutputBuilder.ToString()
            $Result.Duration = (Get-Date) - $StartTime
            $Result.Success = ($Process.ExitCode -eq 0)

            # Show completion
            Write-ProgressBar -Activity $ActivityName -PercentComplete 100 -Status "Completed"

            if ($ShowRealTimeOutput) {
                Write-Information -MessageData "`n  ========== Completion Summary ==========" -Tags "Color:Cyan", "Level:SUCCESS"
                $SummaryColor = if ($Result.Success) { "Green" } else { "Red" }
                Write-Information -MessageData "  Exit Code: $($Result.ExitCode)" -Tags "Color:$SummaryColor", "Level:SUCCESS"
                Write-Information -MessageData "  Duration: $($Result.Duration.TotalMinutes.ToString('F2')) minutes" -Tags "Color:Gray", "Level:SUCCESS"
                Write-Information -MessageData "  ======================================`n" -Tags "Color:Cyan", "Level:SUCCESS"
            }

            # Log results
            $LogLevel = if ($Result.Success) { "SUCCESS" } else { "WARNING" }
            Write-MaintenanceLog -Message "$ActivityName completed with exit code $($Result.ExitCode) (Duration: $($Result.Duration.TotalSeconds)s)" -Level $LogLevel
        }

        # Unregister event handlers
        Get-EventSubscriber | Where-Object { $_.SourceObject -eq $Process } | Unregister-Event

        # Clean up
        $Process.Dispose()

        # Complete progress
        Write-Progress -Activity $ActivityName -Completed

        return $Result
    }
    catch {
        $Result.Output = "Exception: $($_.Exception.Message)"
        Write-MaintenanceLog -Message "$ActivityName failed: $($_.Exception.Message)" -Level ERROR

        if ($ShowRealTimeOutput) {
            Write-Information -MessageData "`n  [ERROR] $($_.Exception.Message)" -Tags "Color:Red", "Level:ERROR"
            Write-Information -MessageData "  ======================================================`n" -Tags "Color:Cyan", "Level:ERROR"
        }

        return $Result
    }
}

<#
.SYNOPSIS
    Displays a section header for better visual organization.

.DESCRIPTION
    Creates visually distinct section headers for long-running operations
    to improve readability and user experience.

.PARAMETER Title
    Section title to display

.PARAMETER SubTitle
    Optional subtitle with additional context

.EXAMPLE
    Show-SectionHeader -Title "WinGet Package Updates" -SubTitle "Updating all outdated packages"

.NOTES
    UX: Improves visual organization and user understanding
#>
function Show-SectionHeader {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Title,

        [Parameter(Mandatory=$false)]
        [string]$SubTitle = ""
    )

    $Width = 70
    $Border = "=" * $Width

    Write-Information -MessageData "`n$Border" -Tags "Color:Cyan", "Level:INFO"
    if ($SubTitle) {
        Write-Information -MessageData "  $Title - $SubTitle" -Tags "Color:White", "Level:INFO"
    }
    else {
        Write-Information -MessageData "  $Title" -Tags "Color:White", "Level:INFO"
    }
    Write-Information -MessageData "$Border" -Tags "Color:Cyan", "Level:INFO"
}

<#
.SYNOPSIS
    Displays package update information in a formatted table.

.DESCRIPTION
    Shows package information in an easy-to-read format before updates begin.
    FIXED: Resolved parameter binding ambiguity with format operator.

.PARAMETER Packages
    Array of package objects with Name, CurrentVersion, NewVersion

.PARAMETER _PackageManager
    Name of package manager (WinGet, Chocolatey, etc.) - Intentionally unused in current display logic.

.EXAMPLE
    Show-PackageUpdateTable -Packages $PackageList -_PackageManager "WinGet"

.NOTES
    UX: Provides clear overview of what will be updated
    FIX: Separated format operation to prevent parameter binding conflicts
#>
function Show-PackageUpdateTable {
    [CmdletBinding()]
    [OutputType([void])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "_PackageManager")]
    param(
        [Parameter(Mandatory=$true)]
        [array]$Packages,

        [Parameter(Mandatory=$true)]
        [string]$_PackageManager
    )

    if ($Packages.Count -eq 0) {
        Write-Information -MessageData "`n  No packages to update" -Tags "Color:Gray", "Level:INFO"
        return
    }

    Write-Information -MessageData "`n  Packages to update ($($Packages.Count)):" -Tags "Color:Yellow", "Level:INFO"
    Write-Information -MessageData "  $("-" * 68)" -Tags "Color:Gray", "Level:INFO"

    # FIX: Separate the format operation from the Write-Host call
    $HeaderText = "  {0,-30} {1,-15} {2,-15}" -f "Package", "Current", "New"
    Write-Information -MessageData $HeaderText -Tags "Color:Cyan", "Level:INFO"

    Write-Information -MessageData "  $("-" * 68)" -Tags "Color:Gray", "Level:INFO"

    foreach ($Package in $Packages | Select-Object -First 10) {
        $Name = if ($Package.Name.Length -gt 28) {
            $Package.Name.Substring(0, 25) + "..."
        } else {
            $Package.Name
        }

        # FIX: Separate format operation here too for consistency
        $PackageText = "  {0,-30} {1,-15} {2,-15}" -f $Name, $Package.CurrentVersion, $Package.NewVersion
        Write-Information -MessageData $PackageText -Tags "Color:White", "Level:INFO"
    }

    if ($Packages.Count -gt 10) {
        Write-Information -MessageData "  ... and $($Packages.Count - 10) more packages" -Tags "Color:Gray", "Level:INFO"
    }

    Write-Information -MessageData "  $("-" * 68)" -Tags "Color:Gray", "Level:INFO"
    Write-Information -MessageData "" -Tags "Level:INFO"
}

# Export public functions
Export-ModuleMember -Function @(
    'Invoke-CommandWithRealTimeOutput',
    'Show-SectionHeader',
    'Show-PackageUpdateTable'
)
