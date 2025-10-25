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
    [CmdletBinding()]
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
        # Check for WhatIf mode from parent scope
        $WhatIfEnabled = if (Get-Variable -Name 'WhatIf' -Scope 1 -ErrorAction SilentlyContinue) {
            (Get-Variable -Name 'WhatIf' -Scope 1).Value
        } elseif (Get-Variable -Name 'WhatIf' -Scope Global -ErrorAction SilentlyContinue) {
            $Global:WhatIf
        } else { $false }

        if ($WhatIfEnabled) {
            Write-MaintenanceLog -Message "[WHATIF] Would execute: $Command $Arguments" -Level INFO
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
            Write-Host "`n  ========== $ActivityName - Real-Time Output ==========" -ForegroundColor Cyan
            Write-Host "  Command: $Command $Arguments" -ForegroundColor Gray
            Write-Host "  ======================================================`n" -ForegroundColor Cyan
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
            param($EventSender, $EventArguments)
            if ($EventArguments.Data) {
                # Display in real-time if enabled
                if ($ShowRealTimeOutput) {
                    Write-Host "  $($EventArguments.Data)" -ForegroundColor White
                }
                [void]$OutputBuilder.AppendLine($EventArguments.Data)
            }
        }

        $ErrorDataReceived = {
            param($EventSender, $EventArguments)
            if ($EventArguments.Data) {
                # Display errors in real-time with color coding
                if ($ShowRealTimeOutput) {
                    if ($EventArguments.Data -match "error|failed|exception") {
                        Write-Host "  $($EventArguments.Data)" -ForegroundColor Red
                    }
                    elseif ($EventArguments.Data -match "warning|warn") {
                        Write-Host "  $($EventArguments.Data)" -ForegroundColor Yellow
                    }
                    else {
                        Write-Host "  $($EventArguments.Data)" -ForegroundColor Gray
                    }
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
                Write-Host "`n  [TIMEOUT] Operation exceeded $TimeoutMinutes minutes" -ForegroundColor Red
                Write-Host "  ======================================================`n" -ForegroundColor Cyan
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
                Write-Host "`n  ========== Completion Summary ==========" -ForegroundColor Cyan
                Write-Host "  Exit Code: $($Result.ExitCode)" -ForegroundColor $(if ($Result.Success) { "Green" } else { "Red" })
                Write-Host "  Duration: $($Result.Duration.TotalMinutes.ToString('F2')) minutes" -ForegroundColor Gray
                Write-Host "  ======================================`n" -ForegroundColor Cyan
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
            Write-Host "`n  [ERROR] $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "  ======================================================`n" -ForegroundColor Cyan
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
    param(
        [Parameter(Mandatory=$true)]
        [string]$Title,

        [Parameter(Mandatory=$false)]
        [string]$SubTitle = ""
    )

    $Width = 70
    $Border = "=" * $Width

    Write-Host "`n$Border" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor White -NoNewline
    if ($SubTitle) {
        Write-Host " - $SubTitle" -ForegroundColor Gray
    }
    else {
        Write-Host ""
    }
    Write-Host "$Border" -ForegroundColor Cyan
}

<#
.SYNOPSIS
    Displays package update information in a formatted table.

.DESCRIPTION
    Shows package information in an easy-to-read format before updates begin.
    FIXED: Resolved parameter binding ambiguity with format operator.

.PARAMETER Packages
    Array of package objects with Name, CurrentVersion, NewVersion

.PARAMETER PackageManager
    Name of package manager (WinGet, Chocolatey, etc.)

.EXAMPLE
    Show-PackageUpdateTable -Packages $PackageList -PackageManager "WinGet"

.NOTES
    UX: Provides clear overview of what will be updated
    FIX: Separated format operation to prevent parameter binding conflicts
#>
function Show-PackageUpdateTable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [array]$Packages,

        [Parameter(Mandatory=$true)]
        [string]$PackageManager
    )

    if ($Packages.Count -eq 0) {
        Write-Host "`n  No packages to update" -ForegroundColor Gray
        return
    }

    Write-Host "`n  Packages to update ($($Packages.Count)):" -ForegroundColor Yellow
    Write-Host "  $("-" * 68)" -ForegroundColor Gray

    # FIX: Separate the format operation from the Write-Host call
    $HeaderText = "  {0,-30} {1,-15} {2,-15}" -f "Package", "Current", "New"
    Write-Host $HeaderText -ForegroundColor Cyan

    Write-Host "  $("-" * 68)" -ForegroundColor Gray

    foreach ($Package in $Packages | Select-Object -First 10) {
        $Name = if ($Package.Name.Length -gt 28) {
            $Package.Name.Substring(0, 25) + "..."
        } else {
            $Package.Name
        }

        # FIX: Separate format operation here too for consistency
        $PackageText = "  {0,-30} {1,-15} {2,-15}" -f $Name, $Package.CurrentVersion, $Package.NewVersion
        Write-Host $PackageText -ForegroundColor White
    }

    if ($Packages.Count -gt 10) {
        Write-Host "  ... and $($Packages.Count - 10) more packages" -ForegroundColor Gray
    }

    Write-Host "  $("-" * 68)" -ForegroundColor Gray
    Write-Host ""
}

# Export public functions
Export-ModuleMember -Function @(
    'Invoke-CommandWithRealTimeOutput',
    'Show-SectionHeader',
    'Show-PackageUpdateTable'
)
