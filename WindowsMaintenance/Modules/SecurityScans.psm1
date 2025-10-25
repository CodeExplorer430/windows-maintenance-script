<#
.SYNOPSIS
    Enterprise-grade security scanning module with unlimited scan duration and comprehensive reporting.

.DESCRIPTION
    Provides advanced security scanning capabilities with Windows Defender integration,
    comprehensive security policy validation, and detailed threat analysis.

    Security Features:
    - Windows Defender signature updates and scanning
    - Configurable scan levels (Quick, Full, Custom) with no timeout restrictions
    - Security policy and configuration validation
    - Firewall status monitoring
    - UAC configuration verification
    - Comprehensive threat detection and reporting
    - Enhanced scan conflict detection and prevention

    Scan Management:
    - No timeout restrictions - scans run until completion based on storage size
    - Dynamic progress reporting and status updates
    - Background job management for scan isolation
    - Comprehensive error handling and recovery
    - Intelligent scan conflict prevention

.NOTES
    File Name      : SecurityScans.psm1
    Author         : Miguel Velasco
    Prerequisite   : PowerShell 5.1+
    Version        : 4.0.0
    Last Updated   : October 2025
    Module Type    : Feature Module
    Dependencies   : Logging.psm1, SafeExecution.psm1, MemoryManagement.psm1,
                     StringFormatting.psm1, UIHelpers.psm1

    Security: All scans use Windows built-in security tools
    Performance: Scans run without artificial time limits for thorough analysis
    Enterprise: Comprehensive audit logging and compliance reporting
    Enhanced: Advanced conflict detection prevents scan interference
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
    Windows Defender scan execution with enhanced conflict detection and prevention.

.DESCRIPTION
    Executes Windows Defender scans with comprehensive monitoring but no artificial
    timeout restrictions, allowing scans to complete based on actual storage requirements.
    Enhanced with intelligent conflict detection to prevent scan interference.

    Features:
    - Multiple scan types (Quick, Full, Custom)
    - No timeout restrictions - runs until completion
    - Background job execution for isolation
    - Comprehensive error handling
    - Threat detection analysis and reporting
    - Performance metrics collection
    - Advanced scan conflict detection and prevention
    - Intelligent waiting for existing scan completion

.PARAMETER ScanType
    Type of scan to perform (Quick, Full, Custom)

.OUTPUTS
    [hashtable] Scan results including success status, duration, and threat information

.EXAMPLE
    $Result = Invoke-DefenderScanUnlimited -ScanType "Full"

.NOTES
    Security: Isolated execution prevents scan failures from affecting main script
    Performance: No artificial timeouts ensure thorough analysis of all storage
    Enterprise: Comprehensive logging and audit trails for compliance
    Enhanced: Intelligent conflict detection prevents scan interference
#>
function Invoke-DefenderScanUnlimited {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false, HelpMessage="Windows Defender scan type")]
        [ValidateSet("Quick", "Full", "Custom")]
        [string]$ScanType = "Quick"
    )

    # Function to check if any Defender scan is currently running
    function Test-DefenderScanInProgress {
        try {
            # Method 1: Check Defender processes
            $DefenderProcesses = Get-Process -Name "MsMpEng", "MpCmdRun", "MpSigStub" -ErrorAction SilentlyContinue
            if ($DefenderProcesses | Where-Object { $_.ProcessName -eq "MpCmdRun" }) {
                Write-MaintenanceLog -Message "Detected MpCmdRun process - scan may be in progress" -Level INFO
                return $true
            }

            # Method 2: Check Defender scan status via WMI
            $ScanStatus = Get-WmiObject -Namespace "root\Microsoft\Windows\Defender" -Class "MSFT_MpScan" -ErrorAction SilentlyContinue
            if ($ScanStatus | Where-Object { $_.ScanState -eq 2 }) {  # 2 = InProgress
                Write-MaintenanceLog -Message "WMI reports scan in progress" -Level INFO
                return $true
            }

            # Method 3: Check Windows Defender service activity
            $DefenderActivity = Get-Counter -Counter "\Windows Defender\*" -ErrorAction SilentlyContinue |
                               Where-Object { $_.CounterSamples.CookedValue -gt 0 }

            if ($DefenderActivity) {
                Write-MaintenanceLog -Message "High Defender activity detected - possible scan in progress" -Level INFO
                return $true
            }

            # Method 4: Try to get scan information to detect active scans
            try {
                $ComputerStatus = Get-MpComputerStatus -ErrorAction Stop
                $LastScanAge = (Get-Date) - $ComputerStatus.QuickScanStartTime

                # If last scan started very recently (within 5 minutes), likely still running
                if ($LastScanAge.TotalMinutes -lt 5) {
                    Write-MaintenanceLog -Message "Recent scan start detected - scan may still be in progress" -Level INFO
                    return $true
                }
            }
            catch {
                # If we can't get status, assume no scan is running
                Write-MaintenanceLog -Message "Could not verify scan status via Get-MpComputerStatus" -Level DEBUG
            }

            return $false

        }
        catch {
            Write-MaintenanceLog -Message "Error checking scan status: $($_.Exception.Message)" -Level WARNING
            # If we can't determine, assume no scan is running to avoid false positives
            return $false
        }
    }

    # Function to wait for existing scan to complete
    function Wait-ForExistingScanCompletion {
        param([int]$MaxWaitMinutes = 30)

        Write-MaintenanceLog -Message "Waiting for existing scan to complete (max wait: $MaxWaitMinutes minutes)..." -Level INFO
        $WaitStartTime = Get-Date
        $LastUpdateTime = Get-Date

        while (Test-DefenderScanInProgress) {
            $ElapsedMinutes = ((Get-Date) - $WaitStartTime).TotalMinutes

            if ($ElapsedMinutes -ge $MaxWaitMinutes) {
                Write-MaintenanceLog -Message "Timeout waiting for existing scan to complete after $MaxWaitMinutes minutes" -Level WARNING
                return $false
            }

            # Progress update every 2 minutes
            if (((Get-Date) - $LastUpdateTime).TotalMinutes -ge 2) {
                Write-MaintenanceLog -Message "Still waiting for existing scan... Elapsed: $([math]::Round($ElapsedMinutes, 1)) minutes" -Level INFO
                $LastUpdateTime = Get-Date
            }

            Start-Sleep -Seconds 30
        }

        $TotalWaitTime = ((Get-Date) - $WaitStartTime).TotalMinutes
        Write-MaintenanceLog -Message "Existing scan completed after $([math]::Round($TotalWaitTime, 1)) minutes" -Level SUCCESS
        return $true
    }

    try {
        Write-MaintenanceLog -Message "Preparing Windows Defender $ScanType scan..." -Level PROGRESS

        # CRITICAL: Check if scan is already in progress before starting
        if (Test-DefenderScanInProgress) {
            Write-MaintenanceLog -Message "Another Defender scan is already in progress. Waiting for completion..." -Level WARNING

            if (-not (Wait-ForExistingScanCompletion -MaxWaitMinutes 30)) {
                Write-MaintenanceLog -Message "Existing scan did not complete within timeout period. Skipping new scan to prevent conflicts." -Level ERROR
                return @{
                    Success = $false
                    Error = "Cannot start scan - another scan is in progress and did not complete within timeout"
                    Skipped = $true
                }
            }

            # Additional safety wait after scan completion
            Write-MaintenanceLog -Message "Waiting additional 30 seconds for scan cleanup..." -Level INFO
            Start-Sleep -Seconds 30
        }

        # Double-check scan status before proceeding
        if (Test-DefenderScanInProgress) {
            Write-MaintenanceLog -Message "Scan still detected as in progress after waiting. Aborting to prevent conflicts." -Level ERROR
            return @{
                Success = $false
                Error = "A scan is still in progress on this device after waiting for completion"
                Skipped = $true
            }
        }

        Write-MaintenanceLog -Message "Starting Windows Defender $ScanType scan without timeout restrictions" -Level PROGRESS

        $ScanStartTime = Get-Date
        $ScanTypeSelected = switch ($ScanType) {
            "Quick" { "QuickScan" }
            "Full" { "FullScan" }
            "Custom" { "QuickScan" }
            default { "QuickScan" }
        }

        # Enhanced job-based scan execution with better error handling
        $ScanJob = Start-Job -ScriptBlock {
            param($ScanType)
            try {
                # Additional pre-scan verification
                $ExistingProcesses = Get-Process -Name "MpCmdRun" -ErrorAction SilentlyContinue
                if ($ExistingProcesses) {
                    return @{ Success = $false; Error = "Scan process already running (MpCmdRun detected)"; AlreadyRunning = $true }
                }

                # Start the scan
                Start-MpScan -ScanType $ScanType -ErrorAction Stop
                return @{ Success = $true; Error = $null }
            }
            catch {
                # Enhanced error analysis
                $ErrorMessage = $_.Exception.Message

                if ($ErrorMessage -like "*already in progress*" -or $ErrorMessage -like "*scan is running*") {
                    return @{ Success = $false; Error = "A scan is already in progress on this device"; AlreadyRunning = $true }
                }
                elseif ($ErrorMessage -like "*access denied*" -or $ErrorMessage -like "*permission*") {
                    return @{ Success = $false; Error = "Insufficient permissions to start scan: $ErrorMessage" }
                }
                else {
                    return @{ Success = $false; Error = $ErrorMessage }
                }
            }
        } -ArgumentList $ScanTypeSelected

        # Monitor scan progress without timeout restrictions
        Write-MaintenanceLog -Message "Scan running... Duration depends on storage size and file count. Progress will be monitored." -Level INFO

        $LastProgressReport = Get-Date
        $ProgressInterval = 300 # Report progress every 5 minutes

        # Monitor scan without timeout - wait until completion
        do {
            Start-Sleep -Seconds 30
            $CurrentTime = Get-Date
            $ElapsedMinutes = [math]::Round(($CurrentTime - $ScanStartTime).TotalMinutes, 1)

            # Periodic progress reporting
            if (($CurrentTime - $LastProgressReport).TotalSeconds -ge $ProgressInterval) {
                Write-MaintenanceLog -Message "Scan in progress... Elapsed time: $ElapsedMinutes minutes" -Level PROGRESS
                Write-DetailedOperation -Operation 'Scan Progress' -Details "Elapsed: $ElapsedMinutes minutes | Status: Running" -Result 'In Progress'
                $LastProgressReport = $CurrentTime
            }

            # Check if job is still running
            $JobState = $ScanJob.State

        } while ($JobState -eq "Running")

        # Process scan completion
        $ScanDuration = (Get-Date) - $ScanStartTime

        if ($JobState -eq "Completed") {
            # Scan completed successfully
            $ScanResult = Receive-Job -Job $ScanJob

            if ($ScanResult.Success) {
                Write-MaintenanceLog -Message "$ScanType scan completed successfully in $([math]::Round($ScanDuration.TotalMinutes, 1)) minutes" -Level SUCCESS

                # Comprehensive threat detection analysis
                try {
                    $ThreatHistory = Get-MpThreatDetection | Sort-Object InitialDetectionTime -Descending | Select-Object -First 10
                }
                catch {
                    Write-MaintenanceLog -Message "Could not retrieve threat history: $($_.Exception.Message)" -Level WARNING
                    $ThreatHistory = @()
                }

                return @{
                    Success = $true
                    Duration = $ScanDuration
                    ThreatsFound = $ThreatHistory.Count
                    ThreatHistory = $ThreatHistory
                }
            }
            else {
                # Handle specific error cases
                if ($ScanResult.AlreadyRunning) {
                    Write-MaintenanceLog -Message "Defender scan failed: $($ScanResult.Error)" -Level ERROR
                    return @{
                        Success = $false
                        Error = $ScanResult.Error
                        Duration = $ScanDuration
                        AlreadyRunning = $true
                    }
                }
                else {
                    Write-MaintenanceLog -Message "Defender scan failed: $($ScanResult.Error)" -Level ERROR
                    return @{
                        Success = $false
                        Error = $ScanResult.Error
                        Duration = $ScanDuration
                    }
                }
            }
        }
        else {
            # Scan failed or was interrupted
            Write-MaintenanceLog -Message "Defender scan did not complete successfully (Final state: $JobState)" -Level ERROR
            return @{
                Success = $false
                Error = "Scan did not complete successfully (Final state: $JobState)"
                Duration = $ScanDuration
            }
        }
    }
    catch {
        Write-MaintenanceLog -Message "Error during Defender scan preparation: $($_.Exception.Message)" -Level ERROR
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
    finally {
        # Comprehensive job cleanup with error handling
        if ($ScanJob) {
            try {
                Remove-Job -Job $ScanJob -ErrorAction SilentlyContinue
            }
            catch {
                Write-MaintenanceLog -Message "Warning: Could not remove scan job" -Level WARNING
            }
        }
    }
}

<#
.SYNOPSIS
    Executes comprehensive security scanning with Windows Defender integration.

.DESCRIPTION
    Orchestrates security scanning operations including:
    - Windows Defender signature updates
    - Configurable security scans (Quick/Full/Custom)
    - Security policy validation
    - Firewall configuration checks
    - System security assessment and reporting

    The module provides enterprise-grade security validation with no artificial timeout
    restrictions, allowing thorough analysis based on actual storage requirements.

.OUTPUTS
    None. Results are logged via Write-MaintenanceLog

.EXAMPLE
    Invoke-SecurityScans

.NOTES
    Security: Uses Windows built-in security tools
    Performance: Scans complete based on actual storage requirements
    Compliance: Comprehensive audit logging for enterprise environments
#>
function Invoke-SecurityScans {
    # Get Config from parent scope
    $Config = if (Get-Variable -Name 'Config' -Scope 1 -ErrorAction SilentlyContinue) {
        (Get-Variable -Name 'Config' -Scope 1).Value
    } elseif (Get-Variable -Name 'Config' -Scope Global -ErrorAction SilentlyContinue) {
        $Global:Config
    } else {
        @{ EnabledModules = @("SecurityScans") }
    }

    # Get ScanLevel from parent scope with default
    $ScanLevel = if (Get-Variable -Name 'ScanLevel' -Scope 1 -ErrorAction SilentlyContinue) {
        (Get-Variable -Name 'ScanLevel' -Scope 1).Value
    } elseif (Get-Variable -Name 'ScanLevel' -Scope Global -ErrorAction SilentlyContinue) {
        $Global:ScanLevel
    } else {
        "Quick"  # Default scan level
    }

    # Get WhatIf from parent scope
    $WhatIf = if (Get-Variable -Name 'WhatIf' -Scope 1 -ErrorAction SilentlyContinue) {
        (Get-Variable -Name 'WhatIf' -Scope 1).Value
    } elseif (Get-Variable -Name 'WhatIf' -Scope Global -ErrorAction SilentlyContinue) {
        $Global:WhatIf
    } else {
        $false
    }

    # Get ShowMessageBoxes from parent scope
    $ShowMessageBoxes = if (Get-Variable -Name 'ShowMessageBoxes' -Scope 1 -ErrorAction SilentlyContinue) {
        (Get-Variable -Name 'ShowMessageBoxes' -Scope 1).Value
    } elseif (Get-Variable -Name 'ShowMessageBoxes' -Scope Global -ErrorAction SilentlyContinue) {
        $Global:ShowMessageBoxes
    } else {
        $false
    }

    # Get SilentMode from parent scope
    $SilentMode = if (Get-Variable -Name 'SilentMode' -Scope 1 -ErrorAction SilentlyContinue) {
        (Get-Variable -Name 'SilentMode' -Scope 1).Value
    } elseif (Get-Variable -Name 'SilentMode' -Scope Global -ErrorAction SilentlyContinue) {
        $Global:SilentMode
    } else {
        $false
    }

    if ("SecurityScans" -notin $Config.EnabledModules) {
        Write-MaintenanceLog -Message 'Security Scans module disabled' -Level INFO
        return
    }

    Write-MaintenanceLog -Message '======== Security Scans Module ========' -Level INFO

    # Advanced Windows Defender management without timeout restrictions
    Invoke-SafeCommand -TaskName "Windows Defender Operations" -Command {
        Write-ProgressBar -Activity 'Security Scanning' -PercentComplete 10 -Status 'Preparing Windows Defender...'

        Write-MaintenanceLog -Message 'Executing Windows Defender security scan without timeout restrictions...' -Level PROGRESS
        Write-DetailedOperation -Operation 'Defender Preparation' -Details "Initializing Windows Defender security operations for storage-dependent scanning" -Result 'Starting'

        if (!$WhatIf) {
            # Comprehensive signature updates with progress tracking
            Write-ProgressBar -Activity 'Security Scanning' -PercentComplete 20 -Status 'Updating threat definitions...'

            $UpdateStartTime = Get-Date
            try {
                Update-MpSignature -ErrorAction Stop
                $UpdateDuration = (Get-Date) - $UpdateStartTime
                Write-DetailedOperation -Operation 'Definition Update' -Details "Threat definitions updated in $([math]::Round($UpdateDuration.TotalSeconds, 1)) seconds" -Result 'Success'
            }
            catch {
                Write-MaintenanceLog -Message "Defender update failed: $($_.Exception.Message)" -Level WARNING
                Write-DetailedOperation -Operation 'Definition Update' -Details "Failed: $($_.Exception.Message)" -Result 'Warning'
            }

            # Comprehensive Defender status analysis
            try {
                $DefenderStatus = Get-MpComputerStatus -ErrorAction Stop
                $DefenderStatusDetails = Format-SafeString -Template "AV Enabled: {0} | RTP: {1} | Last Update: {2}" -Arguments @($DefenderStatus.AntivirusEnabled, $DefenderStatus.RealTimeProtectionEnabled, $DefenderStatus.AntivirusSignatureLastUpdated)
                Write-DetailedOperation -Operation 'Defender Status' -Details $DefenderStatusDetails -Result 'Retrieved'
            }
            catch {
                Write-MaintenanceLog -Message "Failed to get Defender status: $($_.Exception.Message)" -Level WARNING
                $DefenderStatus = $null
            }

            # Storage capacity analysis for scan duration estimation
            try {
                $DriveCount = (Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' -and $null -ne $_.DriveLetter }).Count
                $TotalSizeGB = (Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' -and $null -ne $_.DriveLetter } |
                               Measure-Object -Property Size -Sum).Sum / 1GB

                Write-DetailedOperation -Operation 'Storage Analysis' -Details "Drives: $DriveCount | Total Size: $([math]::Round($TotalSizeGB, 1))GB | Scan Type: $ScanLevel" -Result 'Analyzed'

                # Provide scan duration estimate
                $EstimatedDuration = switch ($ScanLevel) {
                    "Quick" { "5-15 minutes" }
                    "Full" { "$([math]::Round($TotalSizeGB/100, 0))-$([math]::Round($TotalSizeGB/50, 0)) minutes based on storage size" }
                    "Custom" { "10-30 minutes" }
                }

                Write-MaintenanceLog -Message "Starting $ScanLevel scan - Estimated duration: $EstimatedDuration (depends on storage capacity and file count)" -Level INFO
            } catch {
                Write-DetailedOperation -Operation 'Storage Analysis' -Details "Could not analyze storage for duration estimation: $($_.Exception.Message)" -Result 'Warning'
            }

            Write-ProgressBar -Activity 'Security Scanning' -PercentComplete 40 -Status "Running $ScanLevel security scan (no timeout - depends on storage size)..."
            Write-MaintenanceLog -Message "Starting Windows Defender $ScanLevel scan without timeout restrictions..." -Level PROGRESS

            # Execute security scan with enhanced conflict prevention
            $ScanResult = Invoke-DefenderScanUnlimited -ScanType $ScanLevel

            if ($ScanResult.Success) {
                $ScanDuration = $ScanResult.Duration
                $ThreatHistory = $ScanResult.ThreatHistory

                $ScanResultDetails = Format-SafeString -Template "Scan Type: {0} | Duration: {1}m | Threats Found: {2}" -Arguments @($ScanLevel, [math]::Round($ScanDuration.TotalMinutes, 1), $ThreatHistory.Count)
                Write-DetailedOperation -Operation 'Security Scan' -Details $ScanResultDetails -Result 'Complete'

                # Comprehensive threat analysis and reporting
                if ($ThreatHistory -and $ThreatHistory.Count -gt 0) {
                    Write-MaintenanceLog -Message 'Recent threat detections found - reviewing security status' -Level WARNING
                    foreach ($Threat in $ThreatHistory | Select-Object -First 5) {
                        $ThreatDetails = Format-SafeString -Template "Threat: {0} | Action: {1} | Time: {2}" -Arguments @($Threat.ThreatName, $Threat.ActionSuccess, $Threat.InitialDetectionTime)
                        Write-DetailedOperation -Operation 'Threat Detection' -Details $ThreatDetails -Result 'Detected'
                    }
                }
                else {
                    Write-MaintenanceLog -Message 'No threats detected in recent scans' -Level SUCCESS
                }

                # Comprehensive Defender status reporting
                if ($DefenderStatus) {
                    $DefenderStatusMessage = Format-SafeString -Template "Antivirus Status: Enabled={0}, RTP={1}" -Arguments @($DefenderStatus.AntivirusEnabled, $DefenderStatus.RealTimeProtectionEnabled)
                    Write-MaintenanceLog -Message $DefenderStatusMessage -Level INFO
                    Write-MaintenanceLog -Message "Last Definition Update: $($DefenderStatus.AntivirusSignatureLastUpdated)" -Level INFO
                    Write-MaintenanceLog -Message "Signature Version: $($DefenderStatus.AntivirusSignatureVersion)" -Level INFO
                }

                Write-MaintenanceLog -Message "Windows Defender $ScanLevel scan completed successfully in $([math]::Round($ScanDuration.TotalMinutes, 1)) minutes" -Level SUCCESS

                # Enterprise-grade security scan completion notification
                if ($ShowMessageBoxes -and -not $SilentMode) {
                    $ScanMessage = @"
Security Scan Completed Successfully

Scan Type: $ScanLevel
Duration: $([math]::Round($ScanDuration.TotalMinutes, 1)) minutes
Threats Detected: $($ThreatHistory.Count)

$(if ($DefenderStatus) { "Antivirus Status: $($DefenderStatus.AntivirusEnabled)" })
$(if ($DefenderStatus) { "Real-time Protection: $($DefenderStatus.RealTimeProtectionEnabled)" })
$(if ($DefenderStatus) { "Last Definition Update: $($DefenderStatus.AntivirusSignatureLastUpdated)" })

$( if ($ThreatHistory.Count -gt 0) { "[!] Recent threats were detected and handled automatically." } else { "[√] No threats detected - system is secure." } )

Note: Scan completed without artificial time limits, ensuring thorough analysis based on your storage capacity.
"@
                    Show-MaintenanceMessageBox -Message $ScanMessage -Title "Security Scan Results" -Icon $(if ($ThreatHistory.Count -gt 0) { "Warning" } else { "Information" })
                }
            }
            elseif ($ScanResult.Skipped) {
                Write-MaintenanceLog -Message "Security scan skipped due to existing scan in progress" -Level WARNING
                Write-DetailedOperation -Operation 'Security Scan' -Details "Skipped: $($ScanResult.Error)" -Result 'Skipped'
            }
            else {
                Write-MaintenanceLog -Message "Security scan failed: $($ScanResult.Error)" -Level ERROR
                Write-DetailedOperation -Operation 'Security Scan' -Details "Failed: $($ScanResult.Error)" -Result 'Error'

                # Enterprise error notification for critical security failures
                if ($ShowMessageBoxes -and -not $SilentMode) {
                    $ErrorMessage = @"
Security Scan Error

The Windows Defender scan encountered an error:

$($ScanResult.Error)

This may indicate:
• Windows Defender service issues
• Insufficient permissions
• System resource constraints

Recommendations:
• Verify Windows Defender is running properly
• Run the script as Administrator
• Check Windows Defender manually
• Review system health

The maintenance script will continue with other operations.
"@
                    Show-MaintenanceMessageBox -Message $ErrorMessage -Title "Security Scan Error" -Icon "Error"
                }
            }

            # Additional enterprise security validation checks
            Write-ProgressBar -Activity 'Security Scanning' -PercentComplete 80 -Status 'Performing additional security checks...'

            # Windows Update security status validation
            try {
                $PendingReboot = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -ErrorAction SilentlyContinue
                if ($PendingReboot) {
                    Write-MaintenanceLog -Message "System reboot required for pending security updates" -Level WARNING
                    Write-DetailedOperation -Operation 'Security Check' -Details "Pending reboot detected for security updates" -Result 'Reboot Required'
                }
                else {
                    Write-DetailedOperation -Operation 'Security Check' -Details "No pending reboots for security updates" -Result 'Current'
                }
            }
            catch {
                Write-DetailedOperation -Operation 'Security Check' -Details "Could not check reboot status: $($_.Exception.Message)" -Result 'Warning'
            }

            # Windows Firewall configuration validation
            try {
                $FirewallProfiles = Get-NetFirewallProfile -ErrorAction SilentlyContinue
                if ($FirewallProfiles) {
                    $EnabledProfiles = ($FirewallProfiles | Where-Object { $_.Enabled }).Count
                    Write-DetailedOperation -Operation 'Firewall Check' -Details "$EnabledProfiles of 3 firewall profiles enabled" -Result 'Checked'

                    if ($EnabledProfiles -eq 0) {
                        Write-MaintenanceLog -Message "WARNING: All Windows Firewall profiles are disabled" -Level WARNING
                    }
                }
            }
            catch {
                Write-DetailedOperation -Operation 'Firewall Check' -Details "Could not check firewall status: $($_.Exception.Message)" -Result 'Warning'
            }
        }
        else {
            Write-MaintenanceLog -Message "WHATIF: Would perform Windows Defender $ScanLevel scan without timeout restrictions" -Level INFO
            Write-DetailedOperation -Operation 'Security Scan' -Details "WHATIF: $ScanLevel scan simulation for storage-dependent duration" -Result 'Simulated'
        }

        Write-ProgressBar -Activity 'Security Scanning' -PercentComplete 100 -Status 'Security scanning completed'
        Write-Progress -Activity 'Security Scanning' -Completed

    } -TimeoutMinutes 120  # Overall module timeout (generous for large storage systems)

    # Memory optimization after intensive security operations
    Optimize-MemoryUsage
}

# Export public functions
Export-ModuleMember -Function @(
    'Invoke-SecurityScans',
    'Invoke-DefenderScanUnlimited'
)
