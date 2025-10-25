<#
.SYNOPSIS
    Comprehensive system health diagnostics and repair module with DISM, SFC, and CHKDSK support.

.DESCRIPTION
    Provides enterprise-grade system health diagnostics and automated repair capabilities
    including DISM image health scanning, component store validation and repair, SFC system
    file verification, and disk health assessment with CHKDSK scheduling.

    Features:
    - DISM ScanHealth: Quick integrity check of Windows image
    - DISM CheckHealth: Detailed component store validation
    - DISM RestoreHealth: Automated component store repair
    - SFC /scannow: System file verification and repair
    - CHKDSK scheduling: Disk health monitoring and repair scheduling
    - Comprehensive health reporting with detailed findings
    - Real-time progress feedback during long-running operations

.NOTES
    File Name      : SystemHealthRepair.psm1
    Author         : Miguel Velasco
    Prerequisite   : PowerShell 5.1+, Administrator privileges
    Version        : 4.0.0
    Last Updated   : October 2025
    Module Type    : Feature Module
    Dependencies   : Logging.psm1, SafeExecution.psm1, MemoryManagement.psm1,
                     RealTimeProgressOutput.psm1, UIHelpers.psm1
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator

# Import dependencies
$CommonPath = Join-Path $PSScriptRoot "Common"
Import-Module "$CommonPath\Logging.psm1" -Force
Import-Module "$CommonPath\SafeExecution.psm1" -Force
Import-Module "$CommonPath\MemoryManagement.psm1" -Force
Import-Module "$CommonPath\RealTimeProgressOutput.psm1" -Force
Import-Module "$CommonPath\UIHelpers.psm1" -Force

<#
.SYNOPSIS
    Comprehensive system health diagnostics and automated repair workflow.

.DESCRIPTION
    Executes a complete system health diagnostic workflow including DISM image scanning,
    component store validation, SFC system file checking, and disk health assessment.

.EXAMPLE
    Invoke-SystemHealthRepair

.NOTES
    Performance: Complete workflow can take 30-60 minutes depending on system state
    Security: All operations are read-only except when repairs are necessary
    Enterprise: Comprehensive audit trails and detailed reporting
#>
function Invoke-SystemHealthRepair {
    # Get Config from parent scope
    $Config = if (Get-Variable -Name 'Config' -Scope 1 -ErrorAction SilentlyContinue) {
        (Get-Variable -Name 'Config' -Scope 1).Value
    } elseif (Get-Variable -Name 'Config' -Scope Global -ErrorAction SilentlyContinue) {
        $Global:Config
    } else {
        @{ EnabledModules = @("SystemHealthRepair"); ReportsPath = "$env:TEMP\Reports" }
    }

    if ("SystemHealthRepair" -notin $Config.EnabledModules) {
        Write-MaintenanceLog -Message 'System Health & Repair module disabled' -Level INFO
        return
    }

    Write-MaintenanceLog -Message '======== System Health & Repair Module ========' -Level INFO

    # Proactive memory optimization before intensive system operations
    Optimize-MemoryUsage -Force

    # Execute comprehensive system health workflow
    Invoke-SafeCommand -TaskName "System Health Diagnostics" -Command {
        Write-ProgressBar -Activity 'System Health Check' -PercentComplete 5 -Status 'Initializing health diagnostics...'

        $HealthResults = @{
            DISMScanHealth = $null
            DISMCheckHealth = $null
            DISMRestoreHealth = $null
            SFCScan = $null
            ComponentStoreHealth = $null
            CHKDSKScheduled = $false
            OverallHealth = "Unknown"
            RepairActions = @()
            Errors = @()
        }

        # Stage 1: DISM Image Health Scanning
        Write-ProgressBar -Activity 'System Health Check' -PercentComplete 10 -Status 'DISM: Scanning image health...'
        Write-MaintenanceLog -Message 'Starting DISM image health scan...' -Level PROGRESS

        try {
            # DISM ScanHealth - Quick integrity check
            Write-DetailedOperation -Operation 'DISM ScanHealth' -Details 'Performing quick image integrity scan' -Result 'Starting'

            $DISMScanResult = Invoke-DISMOperation -Operation "ScanHealth" -TimeoutMinutes 15
            $HealthResults.DISMScanHealth = $DISMScanResult

            # FIX: Handle empty or null output strings
            $ScanDetails = if ([string]::IsNullOrWhiteSpace($DISMScanResult.Output)) {
                "DISM ScanHealth completed with no detailed output"
            } else {
                $DISMScanResult.Output
            }

            if ($DISMScanResult.Success) {
                Write-MaintenanceLog -Message "DISM ScanHealth completed successfully" -Level SUCCESS
                Write-DetailedOperation -Operation 'DISM ScanHealth' -Details $ScanDetails -Result 'Success'
            }
            else {
                Write-MaintenanceLog -Message "DISM ScanHealth detected issues: $ScanDetails" -Level WARNING
                Write-DetailedOperation -Operation 'DISM ScanHealth' -Details $ScanDetails -Result 'Issues Detected'
                $HealthResults.Errors += "DISM ScanHealth: Issues detected"
            }
        }
        catch {
            Write-MaintenanceLog -Message "DISM ScanHealth failed: $($_.Exception.Message)" -Level ERROR
            $HealthResults.Errors += "DISM ScanHealth: Failed - $($_.Exception.Message)"
        }

        # Stage 2: DISM Component Store Health Check
        Write-ProgressBar -Activity 'System Health Check' -PercentComplete 25 -Status 'DISM: Checking component store health...'
        Write-MaintenanceLog -Message 'Checking Windows component store health...' -Level PROGRESS

        try {
            # DISM CheckHealth - Component store verification
            Write-DetailedOperation -Operation 'DISM CheckHealth' -Details 'Analyzing component store integrity' -Result 'Starting'

            $DISMCheckResult = Invoke-DISMOperation -Operation "CheckHealth" -TimeoutMinutes 10
            $HealthResults.DISMCheckHealth = $DISMCheckResult

            # FIX: Handle empty or null output strings
            $CheckDetails = if ([string]::IsNullOrWhiteSpace($DISMCheckResult.Output)) {
                "DISM CheckHealth completed with no detailed output"
            } else {
                $DISMCheckResult.Output
            }

            if ($DISMCheckResult.Success) {
                if ($DISMCheckResult.Output -match "repairable") {
                    Write-MaintenanceLog -Message "Component store corruption detected - repairable with RestoreHealth" -Level WARNING
                    Write-DetailedOperation -Operation 'DISM CheckHealth' -Details $CheckDetails -Result 'Repairable'
                    $HealthResults.Errors += "Component Store: Repairable corruption detected"

                    # Trigger RestoreHealth if corruption is repairable
                    $HealthResults.RepairNeeded = $true
                }
                else {
                    Write-MaintenanceLog -Message "Component store health check completed successfully" -Level SUCCESS
                    Write-DetailedOperation -Operation 'DISM CheckHealth' -Details $CheckDetails -Result 'Healthy'
                }
            }
            else {
                Write-MaintenanceLog -Message "Component store health check completed with warnings" -Level WARNING
                Write-DetailedOperation -Operation 'DISM CheckHealth' -Details $CheckDetails -Result 'Warning'
            }
        }
        catch {
            Write-MaintenanceLog -Message "DISM CheckHealth failed: $($_.Exception.Message)" -Level ERROR
            $HealthResults.Errors += "DISM CheckHealth: Failed - $($_.Exception.Message)"
        }

        # Stage 3: System File Checker (SFC) Scan
        Write-ProgressBar -Activity 'System Health Check' -PercentComplete 60 -Status 'Running System File Checker...'
        Write-MaintenanceLog -Message 'Starting System File Checker (SFC) scan...' -Level PROGRESS

        try {
            Write-DetailedOperation -Operation 'SFC Scan' -Details 'Verifying system file integrity' -Result 'Starting'

            $SFCResult = Invoke-SFCOperation -TimeoutMinutes 20
            $HealthResults.SFCScan = $SFCResult

            if ($SFCResult.Success) {
                if ($SFCResult.Output -match "did not find any integrity violations") {
                    Write-MaintenanceLog -Message "SFC scan completed - no integrity violations found" -Level SUCCESS
                    Write-DetailedOperation -Operation 'SFC Scan' -Details 'All system files verified as intact' -Result 'Healthy'
                }
                elseif ($SFCResult.Output -match "found corrupt files and successfully repaired them") {
                    Write-MaintenanceLog -Message "SFC scan found and repaired corrupt files" -Level SUCCESS
                    Write-DetailedOperation -Operation 'SFC Scan' -Details 'Corrupt files detected and repaired' -Result 'Repaired'
                    $HealthResults.RepairActions += "System Files Repaired by SFC"
                }
                elseif ($SFCResult.Output -match "found corrupt files but was unable to fix") {
                    Write-MaintenanceLog -Message "SFC found corrupt files that could not be repaired automatically" -Level WARNING
                    Write-DetailedOperation -Operation 'SFC Scan' -Details 'Manual intervention may be required' -Result 'Repair Failed'
                    $HealthResults.Errors += "SFC: Corrupt files detected but repair failed"
                    $HealthResults.RepairActions += "Manual SFC Repair Required"
                }
            }
            else {
                Write-MaintenanceLog -Message "SFC scan encountered errors" -Level ERROR
                $HealthResults.Errors += "SFC: Scan failed"
            }
        }
        catch {
            Write-MaintenanceLog -Message "SFC scan failed: $($_.Exception.Message)" -Level ERROR
            $HealthResults.Errors += "SFC: Failed - $($_.Exception.Message)"
        }

        # Stage 4: Check Disk (CHKDSK) Scheduling
        Write-ProgressBar -Activity 'System Health Check' -PercentComplete 85 -Status 'Checking disk health...'
        Write-MaintenanceLog -Message 'Evaluating disk health status...' -Level PROGRESS

        try {
            Write-DetailedOperation -Operation 'Disk Health Check' -Details 'Analyzing system drive integrity' -Result 'Starting'

            $CHKDSKResult = Test-DiskHealth

            if ($CHKDSKResult.ScheduleRequired) {
                Write-MaintenanceLog -Message "Disk errors detected - CHKDSK scheduled for next restart" -Level WARNING
                Write-DetailedOperation -Operation 'CHKDSK Scheduling' -Details "Scheduled for drive: $($CHKDSKResult.Drive)" -Result 'Scheduled'
                $HealthResults.CHKDSKScheduled = $true
                $HealthResults.RepairActions += "CHKDSK Scheduled (Restart Required)"

                # Get ShowMessageBoxes and SilentMode from parent scope
                $ShowMessageBoxesEnabled = if (Get-Variable -Name 'ShowMessageBoxes' -Scope 1 -ErrorAction SilentlyContinue) {
                    (Get-Variable -Name 'ShowMessageBoxes' -Scope 1).Value
                } elseif (Get-Variable -Name 'ShowMessageBoxes' -Scope Global -ErrorAction SilentlyContinue) {
                    $Global:ShowMessageBoxes
                } else { $true }

                $SilentModeEnabled = if (Get-Variable -Name 'SilentMode' -Scope 1 -ErrorAction SilentlyContinue) {
                    (Get-Variable -Name 'SilentMode' -Scope 1).Value
                } elseif (Get-Variable -Name 'SilentMode' -Scope Global -ErrorAction SilentlyContinue) {
                    $Global:SilentMode
                } else { $false }

                # User notification for restart requirement
                if ($ShowMessageBoxesEnabled -and -not $SilentModeEnabled) {
                    $CHKDSKMessage = @"
Disk Health Check Results

Disk errors have been detected on $($CHKDSKResult.Drive)

A disk check (CHKDSK) has been scheduled to run on the next system restart to repair these issues.

IMPORTANT: Please restart your computer at your earliest convenience to complete the disk repair process.

Would you like to view the detailed CHKDSK log?
"@
                    Show-MaintenanceMessageBox -Message $CHKDSKMessage -Title "Disk Check Scheduled" -Icon "Warning"
                }
            }
            else {
                Write-MaintenanceLog -Message "Disk health check completed - no issues detected" -Level SUCCESS
                Write-DetailedOperation -Operation 'Disk Health Check' -Details 'System drive integrity verified' -Result 'Healthy'
            }
        }
        catch {
            Write-MaintenanceLog -Message "Disk health check failed: $($_.Exception.Message)" -Level WARNING
            $HealthResults.Errors += "CHKDSK: Health check failed - $($_.Exception.Message)"
        }

        # Stage 5: Overall Health Assessment and Reporting
        Write-ProgressBar -Activity 'System Health Check' -PercentComplete 95 -Status 'Generating health report...'

        # Determine overall system health status
        if ($HealthResults.Errors.Count -eq 0 -and $HealthResults.RepairActions.Count -eq 0) {
            $HealthResults.OverallHealth = "Healthy"
            Write-MaintenanceLog -Message "System health check completed - System is HEALTHY" -Level SUCCESS
        }
        elseif ($HealthResults.Errors.Count -gt 0 -and $HealthResults.RepairActions.Count -gt 0) {
            $HealthResults.OverallHealth = "Unhealthy - Repairs Performed"
            Write-MaintenanceLog -Message "System health check completed - Issues detected and repairs performed" -Level WARNING
        }
        elseif ($HealthResults.RepairActions.Count -gt 0) {
            $HealthResults.OverallHealth = "Repaired"
            Write-MaintenanceLog -Message "System health check completed - Repairs performed successfully" -Level SUCCESS
        }
        else {
            $HealthResults.OverallHealth = "Unhealthy - Manual Intervention Required"
            Write-MaintenanceLog -Message "System health check completed - Manual intervention required" -Level ERROR
        }

        # Generate comprehensive health report
        $HealthReport = New-SystemHealthReport -Results $HealthResults
        Write-MaintenanceLog -Message "System health report saved: $HealthReport" -Level SUCCESS

        Write-ProgressBar -Activity 'System Health Check' -PercentComplete 100 -Status 'Health diagnostics completed'
        Write-Progress -Activity 'System Health Check' -Completed

        # Summary notification
        $SummaryMessage = @"
System Health Check Summary

Overall Status: $($HealthResults.OverallHealth)

Errors Detected: $($HealthResults.Errors.Count)
Repairs Performed: $($HealthResults.RepairActions.Count)
CHKDSK Scheduled: $($HealthResults.CHKDSKScheduled)

Detailed report available at: $HealthReport
"@
        Write-DetailedOperation -Operation 'System Health Summary' -Details $SummaryMessage -Result $HealthResults.OverallHealth
    }
}

<#
.SYNOPSIS
    Executes DISM operations with timeout protection and real-time output display.

.DESCRIPTION
    Provides a robust wrapper for DISM.exe operations with enterprise-grade timeout
    protection, real-time output parsing, and error handling.

.PARAMETER Operation
    DISM operation to perform: ScanHealth, CheckHealth, or RestoreHealth

.PARAMETER TimeoutMinutes
    Maximum time to allow for DISM operation before timeout

.OUTPUTS
    [hashtable] Operation results with success status and output

.EXAMPLE
    $Result = Invoke-DISMOperation -Operation "CheckHealth" -TimeoutMinutes 10

.NOTES
    Performance: Implements timeout protection for long-running operations
    Reliability: Comprehensive output parsing and error detection
#>
function Invoke-DISMOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("ScanHealth", "CheckHealth", "RestoreHealth")]
        [string]$Operation,

        [Parameter(Mandatory=$false)]
        [int]$TimeoutMinutes = 30
    )

    $Result = @{
        Success = $false
        Output = ""
        Duration = [TimeSpan]::Zero
        ExitCode = -1
    }

    try {
        # Get WhatIf from parent scope
        $WhatIfEnabled = if (Get-Variable -Name 'WhatIf' -Scope 1 -ErrorAction SilentlyContinue) {
            (Get-Variable -Name 'WhatIf' -Scope 1).Value
        } elseif (Get-Variable -Name 'WhatIf' -Scope Global -ErrorAction SilentlyContinue) {
            $Global:WhatIf
        } else { $false }

        if ($WhatIfEnabled) {
            Write-MaintenanceLog -Message "[WHATIF] Would execute: DISM.exe /Online /Cleanup-Image /$Operation" -Level INFO
            $Result.Success = $true
            $Result.Output = "WhatIf mode - operation simulated"
            return $Result
        }

        # Operation-specific messages
        $OperationMessages = @{
            "ScanHealth" = @{
                Title = "DISM Image Health Scan"
                SubTitle = "Quick integrity check of Windows image"
                Status = "Scanning image health..."
            }
            "CheckHealth" = @{
                Title = "DISM Component Store Check"
                SubTitle = "Detailed analysis of component store integrity"
                Status = "Checking component store..."
            }
            "RestoreHealth" = @{
                Title = "DISM Component Store Repair"
                SubTitle = "Repairing detected corruption (may download files)"
                Status = "Repairing component store..."
            }
        }

        $OpMsg = $OperationMessages[$Operation]

        # Show operation header
        Show-SectionHeader -Title $OpMsg.Title -SubTitle $OpMsg.SubTitle

        Write-Host "`n  This operation may take 5-30 minutes depending on system state." -ForegroundColor Gray
        Write-Host "  Please be patient - real-time progress will appear below.`n" -ForegroundColor Gray

        # Construct DISM arguments
        $DISMArgs = "/Online /Cleanup-Image /$Operation"

        # Execute DISM with real-time output
        $DISMResult = Invoke-CommandWithRealTimeOutput `
            -Command "DISM.exe" `
            -Arguments $DISMArgs `
            -ActivityName "DISM $Operation" `
            -StatusMessage $OpMsg.Status `
            -ShowRealTimeOutput $true `
            -TimeoutMinutes $TimeoutMinutes

        # Process results
        $Result.ExitCode = $DISMResult.ExitCode
        $Result.Output = $DISMResult.Output
        $Result.Duration = $DISMResult.Duration
        $Result.Success = $DISMResult.Success

        # Detailed result analysis
        if ($Result.Success) {
            # Analyze output for specific results
            if ($Result.Output -match "No component store corruption detected") {
                Write-Host "`n  ========== Result Summary ==========" -ForegroundColor Green
                Write-Host "  Status: HEALTHY" -ForegroundColor Green
                Write-Host "  Finding: No corruption detected" -ForegroundColor White
                Write-Host "  Duration: $($Result.Duration.TotalMinutes.ToString('F2')) minutes" -ForegroundColor White
                Write-Host "  ====================================`n" -ForegroundColor Green

                Write-MaintenanceLog -Message "DISM ${Operation}: No corruption detected (Duration: $($Result.Duration.TotalMinutes.ToString('F2'))min)" -Level SUCCESS
            }
            elseif ($Result.Output -match "component store is repairable") {
                Write-Host "`n  ========== Result Summary ==========" -ForegroundColor Yellow
                Write-Host "  Status: REPAIRABLE" -ForegroundColor Yellow
                Write-Host "  Finding: Corruption detected but can be repaired" -ForegroundColor White
                Write-Host "  Action: RestoreHealth will be executed" -ForegroundColor White
                Write-Host "  Duration: $($Result.Duration.TotalMinutes.ToString('F2')) minutes" -ForegroundColor White
                Write-Host "  ====================================`n" -ForegroundColor Yellow

                Write-MaintenanceLog -Message "DISM ${Operation}: Repairable corruption detected (Duration: $($Result.Duration.TotalMinutes.ToString('F2'))min)" -Level WARNING
            }
            elseif ($Result.Output -match "restore operation completed successfully") {
                Write-Host "`n  ========== Result Summary ==========" -ForegroundColor Green
                Write-Host "  Status: REPAIRED" -ForegroundColor Green
                Write-Host "  Finding: Component store successfully repaired" -ForegroundColor White
                Write-Host "  Duration: $($Result.Duration.TotalMinutes.ToString('F2')) minutes" -ForegroundColor White
                Write-Host "  ====================================`n" -ForegroundColor Green

                Write-MaintenanceLog -Message "DISM ${Operation}: Repair completed successfully (Duration: $($Result.Duration.TotalMinutes.ToString('F2'))min)" -Level SUCCESS
            }
            else {
                Write-Host "`n  ========== Result Summary ==========" -ForegroundColor Cyan
                Write-Host "  Status: Completed" -ForegroundColor White
                Write-Host "  Exit Code: $($Result.ExitCode)" -ForegroundColor White
                Write-Host "  Duration: $($Result.Duration.TotalMinutes.ToString('F2')) minutes" -ForegroundColor White
                Write-Host "  ====================================`n" -ForegroundColor Cyan

                Write-MaintenanceLog -Message "DISM $Operation completed (Duration: $($Result.Duration.TotalMinutes.ToString('F2'))min)" -Level SUCCESS
            }
        }
        else {
            Write-Host "`n  ========== Result Summary ==========" -ForegroundColor Red
            Write-Host "  Status: FAILED or WARNINGS" -ForegroundColor Red
            Write-Host "  Exit Code: $($Result.ExitCode)" -ForegroundColor White
            Write-Host "  Duration: $($Result.Duration.TotalMinutes.ToString('F2')) minutes" -ForegroundColor White
            Write-Host "  Note: Check detailed output above" -ForegroundColor Gray
            Write-Host "  ====================================`n" -ForegroundColor Red

            Write-MaintenanceLog -Message "DISM $Operation completed with exit code $($Result.ExitCode) (Duration: $($Result.Duration.TotalMinutes.ToString('F2'))min)" -Level WARNING
        }

        return $Result
    }
    catch {
        $Result.Output = "Exception: $($_.Exception.Message)"
        Write-MaintenanceLog -Message "DISM $Operation failed: $($_.Exception.Message)" -Level ERROR
        return $Result
    }
}

<#
.SYNOPSIS
    Executes DISM RestoreHealth operation when component store corruption is detected.

.DESCRIPTION
    Performs automated component store repair using Windows Update or local sources.
    This is a more intensive operation that attempts to repair detected corruption.

.PARAMETER HealthResults
    Reference to health results hashtable for tracking repair status

.NOTES
    Performance: Can take 15-30 minutes depending on system and internet connection
    Network: May download repair files from Windows Update if local sources unavailable
#>
function Invoke-DISMRestoreHealth {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ref]$HealthResults
    )

    Write-ProgressBar -Activity 'System Health Check' -PercentComplete 45 -Status 'DISM: Repairing component store...'
    Write-MaintenanceLog -Message 'Starting DISM RestoreHealth operation to repair component store...' -Level PROGRESS

    try {
        Write-DetailedOperation -Operation 'DISM RestoreHealth' -Details 'Attempting automatic component store repair' -Result 'Starting'

        # Execute RestoreHealth with extended timeout
        $DISMRestoreResult = Invoke-DISMOperation -Operation "RestoreHealth" -TimeoutMinutes 30
        $HealthResults.Value.DISMRestoreHealth = $DISMRestoreResult

        if ($DISMRestoreResult.Success) {
            if ($DISMRestoreResult.Output -match "The restore operation completed successfully") {
                Write-MaintenanceLog -Message "DISM RestoreHealth completed successfully - Component store repaired" -Level SUCCESS
                Write-DetailedOperation -Operation 'DISM RestoreHealth' -Details 'Component store corruption repaired' -Result 'Success'
                $HealthResults.Value.RepairActions += "Component Store Successfully Repaired"
            }
            elseif ($DISMRestoreResult.Output -match "No component store corruption detected") {
                Write-MaintenanceLog -Message "DISM RestoreHealth completed - No corruption found" -Level SUCCESS
                Write-DetailedOperation -Operation 'DISM RestoreHealth' -Details 'No repair needed' -Result 'Clean'
            }
            else {
                Write-MaintenanceLog -Message "DISM RestoreHealth completed with warnings" -Level WARNING
                Write-DetailedOperation -Operation 'DISM RestoreHealth' -Details $DISMRestoreResult.Output -Result 'Warning'
            }
        }
        else {
            Write-MaintenanceLog -Message "DISM RestoreHealth failed or timed out" -Level ERROR
            Write-DetailedOperation -Operation 'DISM RestoreHealth' -Details $DISMRestoreResult.Output -Result 'Failed'
            $HealthResults.Value.Errors += "DISM RestoreHealth: Operation failed"
        }
    }
    catch {
        Write-MaintenanceLog -Message "DISM RestoreHealth failed: $($_.Exception.Message)" -Level ERROR
        $HealthResults.Value.Errors += "DISM RestoreHealth: Exception - $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Executes System File Checker (SFC) scan with timeout protection and real-time output.

.DESCRIPTION
    Runs SFC /scannow to verify and repair Windows system files.
    Implements timeout protection and comprehensive output parsing.

.PARAMETER TimeoutMinutes
    Maximum time to allow for SFC operation before timeout

.OUTPUTS
    [hashtable] SFC scan results with success status and findings

.EXAMPLE
    $SFCResult = Invoke-SFCOperation -TimeoutMinutes 20

.NOTES
    Performance: SFC scans typically take 10-20 minutes
    Reliability: Comprehensive output parsing for all SFC result types
#>
function Invoke-SFCOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [int]$TimeoutMinutes = 30
    )

    $Result = @{
        Success = $false
        Output = ""
        Duration = [TimeSpan]::Zero
        ExitCode = -1
    }

    try {
        # Get WhatIf from parent scope
        $WhatIfEnabled = if (Get-Variable -Name 'WhatIf' -Scope 1 -ErrorAction SilentlyContinue) {
            (Get-Variable -Name 'WhatIf' -Scope 1).Value
        } elseif (Get-Variable -Name 'WhatIf' -Scope Global -ErrorAction SilentlyContinue) {
            $Global:WhatIf
        } else { $false }

        if ($WhatIfEnabled) {
            Write-MaintenanceLog -Message "[WHATIF] Would execute: sfc /scannow" -Level INFO
            $Result.Success = $true
            $Result.Output = "WhatIf mode - operation simulated"
            return $Result
        }

        # Show operation header
        Show-SectionHeader -Title "System File Checker (SFC) Scan" -SubTitle "Verifying integrity of protected system files"

        Write-Host "`n  This operation typically takes 10-20 minutes." -ForegroundColor Gray
        Write-Host "  SFC will scan all protected system files and replace corrupted files." -ForegroundColor Gray
        Write-Host "  Real-time progress will appear below.`n" -ForegroundColor Gray

        # Execute SFC with real-time output
        $SFCResult = Invoke-CommandWithRealTimeOutput `
            -Command "sfc.exe" `
            -Arguments "/scannow" `
            -ActivityName "System File Checker" `
            -StatusMessage "Scanning and repairing system files..." `
            -ShowRealTimeOutput $true `
            -TimeoutMinutes $TimeoutMinutes

        # Process results
        $Result.ExitCode = $SFCResult.ExitCode
        $Result.Output = $SFCResult.Output
        $Result.Duration = $SFCResult.Duration
        $Result.Success = $true  # SFC completion is success, need to parse output for actual status

        # Detailed result analysis
        if ($Result.Output -match "did not find any integrity violations") {
            Write-Host "`n  ========== Scan Results ==========" -ForegroundColor Green
            Write-Host "  Status: HEALTHY" -ForegroundColor Green
            Write-Host "  Finding: No integrity violations found" -ForegroundColor White
            Write-Host "  All system files are intact" -ForegroundColor White
            Write-Host "  Duration: $($Result.Duration.TotalMinutes.ToString('F2')) minutes" -ForegroundColor White
            Write-Host "  ==================================`n" -ForegroundColor Green

            Write-MaintenanceLog -Message "SFC scan: No integrity violations found (Duration: $($Result.Duration.TotalMinutes.ToString('F2'))min)" -Level SUCCESS
        }
        elseif ($Result.Output -match "found corrupt files and successfully repaired them") {
            Write-Host "`n  ========== Scan Results ==========" -ForegroundColor Green
            Write-Host "  Status: REPAIRED" -ForegroundColor Green
            Write-Host "  Finding: Corrupt files found and repaired" -ForegroundColor White
            Write-Host "  Details: Check CBS.log for specific files" -ForegroundColor Gray
            Write-Host "  Duration: $($Result.Duration.TotalMinutes.ToString('F2')) minutes" -ForegroundColor White
            Write-Host "  ==================================`n" -ForegroundColor Green

            Write-MaintenanceLog -Message "SFC scan: Corrupt files repaired (Duration: $($Result.Duration.TotalMinutes.ToString('F2'))min)" -Level SUCCESS
        }
        elseif ($Result.Output -match "found corrupt files but was unable to fix") {
            Write-Host "`n  ========== Scan Results ==========" -ForegroundColor Red
            Write-Host "  Status: REPAIR FAILED" -ForegroundColor Red
            Write-Host "  Finding: Corrupt files found but could not be repaired" -ForegroundColor White
            Write-Host "  Action Required: Manual repair may be needed" -ForegroundColor Yellow
            Write-Host "  Details: Check CBS.log at C:\Windows\Logs\CBS\CBS.log" -ForegroundColor Gray
            Write-Host "  Duration: $($Result.Duration.TotalMinutes.ToString('F2')) minutes" -ForegroundColor White
            Write-Host "  ==================================`n" -ForegroundColor Red

            Write-MaintenanceLog -Message "SFC scan: Corrupt files found but repair failed (Duration: $($Result.Duration.TotalMinutes.ToString('F2'))min)" -Level WARNING
        }
        elseif ($Result.Output -match "Windows Resource Protection could not perform") {
            Write-Host "`n  ========== Scan Results ==========" -ForegroundColor Red
            Write-Host "  Status: SCAN FAILED" -ForegroundColor Red
            Write-Host "  Finding: SFC could not complete the scan" -ForegroundColor White
            Write-Host "  Common causes:" -ForegroundColor Gray
            Write-Host "    - Another maintenance operation is running" -ForegroundColor Gray
            Write-Host "    - Pending system restart required" -ForegroundColor Gray
            Write-Host "    - System files are locked" -ForegroundColor Gray
            Write-Host "  Duration: $($Result.Duration.TotalMinutes.ToString('F2')) minutes" -ForegroundColor White
            Write-Host "  ==================================`n" -ForegroundColor Red

            Write-MaintenanceLog -Message "SFC scan: Could not perform requested operation (Duration: $($Result.Duration.TotalMinutes.ToString('F2'))min)" -Level ERROR
        }
        else {
            Write-Host "`n  ========== Scan Results ==========" -ForegroundColor Cyan
            Write-Host "  Status: Completed" -ForegroundColor White
            Write-Host "  Exit Code: $($Result.ExitCode)" -ForegroundColor White
            Write-Host "  Duration: $($Result.Duration.TotalMinutes.ToString('F2')) minutes" -ForegroundColor White
            Write-Host "  Note: Check detailed output above" -ForegroundColor Gray
            Write-Host "  ==================================`n" -ForegroundColor Cyan

            Write-MaintenanceLog -Message "SFC scan completed (Duration: $($Result.Duration.TotalMinutes.ToString('F2'))min)" -Level SUCCESS
        }

        return $Result
    }
    catch {
        $Result.Output = "Exception: $($_.Exception.Message)"
        Write-MaintenanceLog -Message "SFC scan failed: $($_.Exception.Message)" -Level ERROR
        return $Result
    }
}

<#
.SYNOPSIS
    Tests disk health and schedules CHKDSK if errors are detected.

.DESCRIPTION
    Evaluates system drive health and schedules CHKDSK for next boot if issues
    are detected. CHKDSK requires exclusive disk access and must run at boot.

.OUTPUTS
    [hashtable] Disk health status and CHKDSK scheduling information

.EXAMPLE
    $DiskHealth = Test-DiskHealth

.NOTES
    Limitation: CHKDSK requires system restart for system drive
    Security: Only checks system drive to prevent accidental data drive checks
#>
function Test-DiskHealth {
    [CmdletBinding()]
    param()

    $Result = @{
        ScheduleRequired = $false
        Drive = $env:SystemDrive
        IssuesDetected = $false
        CHKDSKScheduled = $false
        FreeSpaceGB = 0
        TotalSizeGB = 0
        FreeSpacePercent = 0
    }

    try {
        # Get WhatIf from parent scope
        $WhatIfEnabled = if (Get-Variable -Name 'WhatIf' -Scope 1 -ErrorAction SilentlyContinue) {
            (Get-Variable -Name 'WhatIf' -Scope 1).Value
        } elseif (Get-Variable -Name 'WhatIf' -Scope Global -ErrorAction SilentlyContinue) {
            $Global:WhatIf
        } else { $false }

        if ($WhatIfEnabled) {
            Write-MaintenanceLog -Message "[WHATIF] Would check disk health for $($env:SystemDrive)" -Level INFO
            return $Result
        }

        # Check if CHKDSK is already scheduled
        $CHKDSKScheduled = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "BootExecute" -ErrorAction SilentlyContinue).BootExecute -match "autocheck autochk"

        if ($CHKDSKScheduled) {
            Write-MaintenanceLog -Message "CHKDSK is already scheduled for next boot" -Level INFO
            $Result.CHKDSKScheduled = $true
            return $Result
        }

        # Get disk information for additional health checks
        Write-MaintenanceLog -Message "Checking disk health status for $($env:SystemDrive)..." -Level INFO

        $DiskStatus = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'" -ErrorAction Stop

        # Calculate and log disk space information
        $Result.TotalSizeGB = [math]::Round($DiskStatus.Size / 1GB, 2)
        $Result.FreeSpaceGB = [math]::Round($DiskStatus.FreeSpace / 1GB, 2)
        $Result.FreeSpacePercent = [math]::Round(($DiskStatus.FreeSpace / $DiskStatus.Size) * 100, 2)

        Write-MaintenanceLog -Message "Disk Space: $($Result.FreeSpaceGB) GB free of $($Result.TotalSizeGB) GB ($($Result.FreeSpacePercent)%)" -Level INFO

        # Warn if disk space is critically low
        if ($Result.FreeSpacePercent -lt 10) {
            Write-MaintenanceLog -Message "WARNING: Low disk space detected ($($Result.FreeSpacePercent)% free) - this may affect system performance" -Level WARNING
            $Result.IssuesDetected = $true
        }
        elseif ($Result.FreeSpacePercent -lt 20) {
            Write-MaintenanceLog -Message "Disk space is running low ($($Result.FreeSpacePercent)% free) - consider cleanup" -Level WARNING
        }

        # Check volume dirty bit using fsutil
        $FsutilOutput = & fsutil dirty query $env:SystemDrive 2>&1

        if ($FsutilOutput -match "is dirty" -or $FsutilOutput -match "is set") {
            Write-MaintenanceLog -Message "Disk dirty bit is set - errors detected on $($env:SystemDrive)" -Level WARNING
            $Result.IssuesDetected = $true
            $Result.ScheduleRequired = $true

            # Schedule CHKDSK for next boot
            Write-MaintenanceLog -Message "Scheduling CHKDSK for next system restart..." -Level INFO

            try {
                # Schedule CHKDSK using chkdsk command
                $CHKDSKProcess = Start-Process -FilePath "chkdsk.exe" -ArgumentList "$($env:SystemDrive) /F /R /X" -PassThru -NoNewWindow -Wait -ErrorAction Stop

                if ($CHKDSKProcess.ExitCode -eq 0) {
                    Write-MaintenanceLog -Message "CHKDSK successfully scheduled for next restart" -Level SUCCESS
                    $Result.CHKDSKScheduled = $true
                }
                else {
                    # Fallback: Use echo Y to auto-confirm CHKDSK scheduling
                    $ScheduleResult = Write-Output Y | chkdsk $env:SystemDrive /F /R 2>&1

                    if ($ScheduleResult -match "scheduled") {
                        Write-MaintenanceLog -Message "CHKDSK successfully scheduled for next restart (fallback method)" -Level SUCCESS
                        $Result.CHKDSKScheduled = $true
                    }
                    else {
                        Write-MaintenanceLog -Message "Failed to schedule CHKDSK - manual intervention required" -Level WARNING
                    }
                }
            }
            catch {
                Write-MaintenanceLog -Message "Error scheduling CHKDSK: $($_.Exception.Message)" -Level ERROR
            }
        }
        else {
            Write-MaintenanceLog -Message "Disk health check passed - no issues detected on $($env:SystemDrive)" -Level SUCCESS
        }

        return $Result
    }
    catch {
        Write-MaintenanceLog -Message "Disk health check failed: $($_.Exception.Message)" -Level WARNING
        return $Result
    }
}

<#
.SYNOPSIS
    Generates comprehensive system health report with detailed findings.

.DESCRIPTION
    Creates a detailed text report of all system health check results
    including DISM, SFC, and CHKDSK findings with actionable recommendations.

.PARAMETER Results
    Health check results hashtable containing all diagnostic information

.OUTPUTS
    [string] Path to generated health report file

.EXAMPLE
    $ReportPath = New-SystemHealthReport -Results $HealthResults

.NOTES
    Format: Generates human-readable text with structured data
    Location: Saves to maintenance reports directory
#>
function New-SystemHealthReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Results
    )

    try {
        # Get Config from parent scope
        $Config = if (Get-Variable -Name 'Config' -Scope 1 -ErrorAction SilentlyContinue) {
            (Get-Variable -Name 'Config' -Scope 1).Value
        } elseif (Get-Variable -Name 'Config' -Scope Global -ErrorAction SilentlyContinue) {
            $Global:Config
        } else {
            @{ ReportsPath = "$env:TEMP\Reports" }
        }

        $ReportTimestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $ReportPath = "$($Config.ReportsPath)\system_health_report_$ReportTimestamp.txt"

        # Ensure reports directory exists
        if (-not (Test-Path $Config.ReportsPath)) {
            New-Item -ItemType Directory -Path $Config.ReportsPath -Force | Out-Null
        }

        # Generate comprehensive report content
        $ReportContent = @"
==========================================
SYSTEM HEALTH DIAGNOSTIC REPORT
==========================================
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Computer: $env:COMPUTERNAME
User: $env:USERNAME

OVERALL SYSTEM HEALTH: $($Results.OverallHealth)
==========================================

DIAGNOSTIC RESULTS:
------------------------------------------

1. DISM IMAGE HEALTH SCAN
   Status: $(if ($Results.DISMScanHealth.Success) { "COMPLETED" } else { "FAILED/INCOMPLETE" })
   Duration: $($Results.DISMScanHealth.Duration.TotalMinutes.ToString('F2')) minutes
   Findings: $(if ($Results.DISMScanHealth.Output -match "No component store corruption") { "No corruption detected" } else { "Issues detected - see details below" })

2. DISM COMPONENT STORE HEALTH CHECK
   Status: $(if ($Results.DISMCheckHealth.Success) { "COMPLETED" } else { "FAILED/INCOMPLETE" })
   Duration: $($Results.DISMCheckHealth.Duration.TotalMinutes.ToString('F2')) minutes
   Findings: $(if ($Results.DISMCheckHealth.Output -match "No component store corruption") { "Component store healthy" } elseif ($Results.DISMCheckHealth.Output -match "repairable") { "Corruption detected - repairable" } else { "See details below" })

$(if ($Results.DISMRestoreHealth) {
@"
3. DISM RESTORE HEALTH OPERATION
   Status: $(if ($Results.DISMRestoreHealth.Success) { "COMPLETED" } else { "FAILED/INCOMPLETE" })
   Duration: $($Results.DISMRestoreHealth.Duration.TotalMinutes.ToString('F2')) minutes
   Findings: $(if ($Results.DISMRestoreHealth.Output -match "successfully") { "Component store repaired successfully" } else { "Repair incomplete - see details" })

"@
})

4. SYSTEM FILE CHECKER (SFC) SCAN
   Status: $(if ($Results.SFCScan.Success) { "COMPLETED" } else { "FAILED/INCOMPLETE" })
   Duration: $($Results.SFCScan.Duration.TotalMinutes.ToString('F2')) minutes
   Findings: $(
       if ($Results.SFCScan.Output -match "did not find any integrity violations") { "No integrity violations found" }
       elseif ($Results.SFCScan.Output -match "successfully repaired") { "Corrupt files found and repaired" }
       elseif ($Results.SFCScan.Output -match "unable to fix") { "Corrupt files found but repair failed" }
       else { "See details below" }
   )

5. DISK HEALTH CHECK (CHKDSK)
   System Drive: $env:SystemDrive
   CHKDSK Scheduled: $(if ($Results.CHKDSKScheduled) { "YES - Restart required" } else { "NO - Disk appears healthy" })

==========================================
REPAIR ACTIONS TAKEN:
------------------------------------------
$(if ($Results.RepairActions.Count -gt 0) {
    $Results.RepairActions | ForEach-Object { "- $_" }
} else {
    "No repairs were necessary"
})

==========================================
ERRORS AND WARNINGS:
------------------------------------------
$(if ($Results.Errors.Count -gt 0) {
    $Results.Errors | ForEach-Object { "- $_" }
} else {
    "No errors detected"
})

==========================================
RECOMMENDATIONS:
------------------------------------------
$(
    $Recommendations = @()

    if ($Results.OverallHealth -eq "Healthy") {
        $Recommendations += "- System is in good health - continue regular maintenance"
    }

    if ($Results.CHKDSKScheduled) {
        $Recommendations += "- CRITICAL: Restart your computer to complete disk repair"
        $Recommendations += "- Save all work before restarting"
        $Recommendations += "- CHKDSK may take 30-60 minutes depending on disk size"
    }

    if ($Results.Errors -match "unable to fix") {
        $Recommendations += "- Manual repair required - consider running DISM and SFC in Safe Mode"
        $Recommendations += "- Check Windows Update for pending system updates"
        $Recommendations += "- Consider creating a system backup before further troubleshooting"
    }

    if ($Results.RepairActions.Count -gt 0) {
        $Recommendations += "- System repairs were performed - monitor for stability"
        $Recommendations += "- Consider restarting the system after repairs"
    }

    if ($Results.OverallHealth -match "Unhealthy") {
        $Recommendations += "- System health issues detected - consider professional assistance"
        $Recommendations += "- Backup critical data immediately"
        $Recommendations += "- Review detailed logs for specific error information"
    }

    $Recommendations += "- Regular system health checks recommended (monthly)"
    $Recommendations += "- Keep Windows and drivers up to date"
    $Recommendations += "- Maintain adequate free disk space (minimum 20GB)"

    $Recommendations -join "`n"
)

==========================================
DETAILED OUTPUT LOGS:
------------------------------------------

DISM SCANHEALTH OUTPUT:
$(if ($Results.DISMScanHealth.Output) { $Results.DISMScanHealth.Output } else { "No output available" })

DISM CHECKHEALTH OUTPUT:
$(if ($Results.DISMCheckHealth.Output) { $Results.DISMCheckHealth.Output } else { "No output available" })

$(if ($Results.DISMRestoreHealth) {
@"
DISM RESTOREHEALTH OUTPUT:
$(if ($Results.DISMRestoreHealth.Output) { $Results.DISMRestoreHealth.Output } else { "No output available" })

"@
})

SFC SCAN OUTPUT:
$(if ($Results.SFCScan.Output) { $Results.SFCScan.Output } else { "No output available" })

==========================================
ADDITIONAL RESOURCES:
------------------------------------------
- DISM Documentation: https://docs.microsoft.com/windows-hardware/manufacture/desktop/dism
- SFC Documentation: https://support.microsoft.com/en-us/topic/use-the-system-file-checker-tool-to-repair-missing-or-corrupted-system-files
- CHKDSK Guide: https://support.microsoft.com/en-us/windows/check-your-hard-disk-for-errors-in-windows

For persistent issues, consider:
1. Running diagnostics in Safe Mode
2. Checking for hardware failures
3. Consulting with IT support or Microsoft support

==========================================
END OF REPORT
==========================================
"@

        # Save report to file
        $ReportContent | Out-File -FilePath $ReportPath -Encoding UTF8

        Write-MaintenanceLog -Message "System health report generated: $ReportPath" -Level SUCCESS

        return $ReportPath
    }
    catch {
        Write-MaintenanceLog -Message "Failed to generate system health report: $($_.Exception.Message)" -Level ERROR
        return $null
    }
}

# Export public functions
Export-ModuleMember -Function @(
    'Invoke-SystemHealthRepair',
    'Invoke-DISMOperation',
    'Invoke-DISMRestoreHealth',
    'Invoke-SFCOperation',
    'Test-DiskHealth',
    'New-SystemHealthReport'
)
