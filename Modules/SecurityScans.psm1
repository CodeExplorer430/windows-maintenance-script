<#
.SYNOPSIS
    Enterprise-grade security scanning module.

.DESCRIPTION
    Provides advanced security scanning capabilities with Windows Defender integration.
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
    Executes comprehensive security scanning.
#>
function Invoke-SecurityScan {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Config
    )

    if ("SecurityScans" -notin $Config.EnabledModules) {
        Write-MaintenanceLog -Message 'Security Scans module disabled' -Level INFO
        return
    }

    Write-MaintenanceLog -Message '======== Security Scans Module ========' -Level INFO

    # Advanced Windows Defender Management
    Invoke-SafeCommand -TaskName "Windows Defender Operations" -Command {
        Write-ProgressBar -Activity 'Security Scanning' -PercentComplete 10 -Status 'Preparing Windows Defender...'

        $ScanLevel = $Config.SecurityScans.ScanLevel
        if (-not $ScanLevel) { $ScanLevel = "Quick" }

        if ($PSCmdlet.ShouldProcess("System", "Perform Windows Defender $ScanLevel Scan")) {
            # Update definitions
            Write-ProgressBar -Activity 'Security Scanning' -PercentComplete 20 -Status 'Updating threat definitions...'
            try {
                Update-MpSignature -ErrorAction Stop
                Write-MaintenanceLog -Message "Threat definitions updated" -Level SUCCESS
            } catch {
                Write-MaintenanceLog -Message "Defender update failed: $($_.Exception.Message)" -Level WARNING
            }

            # Run Scan
            Write-ProgressBar -Activity 'Security Scanning' -PercentComplete 40 -Status "Running $ScanLevel security scan..."
            $ScanResult = Invoke-DefenderScan -ScanType $ScanLevel

            if ($ScanResult.Success) {
                Write-MaintenanceLog -Message "$ScanLevel scan completed successfully" -Level SUCCESS

                # Check for threats
                $Threats = Get-MpThreatDetection | Where-Object { $_.InitialDetectionTime -gt $ScanResult.StartTime }
                $ThreatCount = if ($Threats) { $Threats.Count } else { 0 }

                # Log to Database
                if (Get-Command Invoke-SQLiteQuery -ErrorAction SilentlyContinue) {
                    Invoke-SQLiteQuery -Query "INSERT INTO SystemMetrics (MetricName, MetricValue, Unit) VALUES ('SecurityThreatsDetected', $ThreatCount, 'Count');"
                }

                if ($ThreatCount -gt 0) {
                    Write-MaintenanceLog -Message "WARNING: $ThreatCount threats detected during scan!" -Level WARNING
                }
            }
        }

        # System Security Checks
        Write-ProgressBar -Activity 'Security Scanning' -PercentComplete 80 -Status 'Performing additional security checks...'

        # Firewall
        try {
            $Profiles = Get-NetFirewallProfile -ErrorAction SilentlyContinue
            foreach ($P in $Profiles) {
                if ($P.Enabled -ne 'True') {
                    Write-MaintenanceLog -Message "WARNING: Firewall profile $($P.Name) is disabled" -Level WARNING
                }
            }
        } catch {
            Write-MaintenanceLog -Message "Security check failed: $($_.Exception.Message)" -Level WARNING
        }

        # BitLocker
        try {
            $BL = Get-BitLockerVolume -ErrorAction SilentlyContinue
            foreach ($V in $BL) {
                if ($V.ProtectionStatus -eq 'Off') {
                    Write-MaintenanceLog -Message "INFO: BitLocker is OFF for drive $($V.MountPoint)" -Level INFO
                }
            }
        } catch {
            Write-MaintenanceLog -Message "Security check failed: $($_.Exception.Message)" -Level WARNING
        }

        Write-ProgressBar -Activity 'Security Scanning' -PercentComplete 100 -Status 'Security scanning completed'
    }
}

function Invoke-DefenderScan {
    param([string]$ScanType = "Quick")

    $StartTime = Get-Date
    Write-DetailedOperation -Operation 'Security Scan' -Details "Initiating Windows Defender $ScanType Scan" -Result 'Starting'
    $Job = Start-Job -ScriptBlock {        $Type = $using:ScanType
        try {
            Start-MpScan -ScanType "$($Type)Scan" -ErrorAction Stop
            return @{ Success = $true }
        } catch {
            return @{ Success = $false; Error = $_.Exception.Message }
        }
    }

    # Wait for completion (no timeout as requested by original logic)
    $Job | Wait-Job | Out-Null

    $Res = Receive-Job -Job $Job
    Remove-Job -Job $Job -Force

    if ($Res) {
        $Res.StartTime = $StartTime
    }
    return $Res
}

# Export public functions
Export-ModuleMember -Function @(
    'Invoke-SecurityScan'
)
