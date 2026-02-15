<#
.SYNOPSIS
    Comprehensive system health diagnostics and repair module with DISM, SFC, and CHKDSK support.

.DESCRIPTION
    Provides enterprise-grade system health diagnostics and automated repair capabilities.
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
#>
function Invoke-SystemHealthRepair {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Config
    )

    if ("SystemHealthRepair" -notin $Config.EnabledModules) {
        Write-MaintenanceLog -Message 'System Health & Repair module disabled' -Level INFO
        return
    }

    Write-MaintenanceLog -Message '======== System Health & Repair Module ========' -Level INFO

    # Proactive memory optimization
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
            $DISMScanResult = Invoke-DISMOperation -Operation "ScanHealth" -TimeoutMinutes 15 -WhatIf:$WhatIfPreference
            $HealthResults.DISMScanHealth = $DISMScanResult

            if ($DISMScanResult.Success) {
                Write-MaintenanceLog -Message "DISM ScanHealth completed successfully" -Level SUCCESS
            } else {
                Write-MaintenanceLog -Message "DISM ScanHealth detected issues" -Level WARNING
                $HealthResults.Errors += "DISM ScanHealth: Issues detected"
            }
        } catch {
            Write-MaintenanceLog -Message "DISM ScanHealth failed: $($_.Exception.Message)" -Level ERROR
        }

        # Stage 2: DISM Component Store Cleanup
        Write-ProgressBar -Activity 'System Health Check' -PercentComplete 40 -Status 'DISM: Cleaning up component store...'
        Write-MaintenanceLog -Message 'Performing DISM component store cleanup...' -Level PROGRESS
        try {
            $DISMCleanupResult = Invoke-DISMOperation -Operation "StartComponentCleanup" -TimeoutMinutes 30 -WhatIf:$WhatIfPreference
            if ($DISMCleanupResult.Success) {
                Write-MaintenanceLog -Message "Component store cleanup completed successfully" -Level SUCCESS
                $HealthResults.RepairActions += "DISM Component Store Cleanup Performed"
            }
        } catch {
            Write-MaintenanceLog -Message "Component store cleanup failed: $($_.Exception.Message)" -Level WARNING
        }

        # Stage 3: System File Checker (SFC) Scan
        Write-ProgressBar -Activity 'System Health Check' -PercentComplete 60 -Status 'Running System File Checker...'
        Write-MaintenanceLog -Message 'Starting System File Checker (SFC) scan...' -Level PROGRESS

        try {
            $SFCResult = Invoke-SFCOperation -TimeoutMinutes 20 -WhatIf:$WhatIfPreference
            $HealthResults.SFCScan = $SFCResult

            if ($SFCResult.Success) {
                if ($SFCResult.Output -match "did not find any integrity violations") {
                    Write-MaintenanceLog -Message "SFC scan completed - no integrity violations found" -Level SUCCESS
                }
                elseif ($SFCResult.Output -match "found corrupt files and successfully repaired them") {
                    Write-MaintenanceLog -Message "SFC scan found and repaired corrupt files" -Level SUCCESS
                    $HealthResults.RepairActions += "System Files Repaired by SFC"
                }
            }
        } catch {
            Write-MaintenanceLog -Message "SFC scan failed: $($_.Exception.Message)" -Level ERROR
        }

        # Stage 4: Check Disk (CHKDSK) Scheduling
        Write-ProgressBar -Activity 'System Health Check' -PercentComplete 85 -Status 'Checking disk health...'
        Write-MaintenanceLog -Message 'Evaluating disk health status...' -Level PROGRESS

        try {
            $CHKDSKResult = Test-DiskHealth -WhatIf:$WhatIfPreference
            if ($CHKDSKResult.ScheduleRequired) {
                Write-MaintenanceLog -Message "Disk errors detected - CHKDSK scheduled for next restart" -Level WARNING
                $HealthResults.CHKDSKScheduled = $true
                $HealthResults.RepairActions += "CHKDSK Scheduled"
            } else {
                Write-MaintenanceLog -Message "Disk health check completed - no issues detected" -Level SUCCESS
            }
        } catch {
            Write-MaintenanceLog -Message "Disk health check failed: $($_.Exception.Message)" -Level WARNING
        }

        # Generate report
        New-SystemHealthReport -Results $HealthResults -Config $Config

        Write-ProgressBar -Activity 'System Health Check' -PercentComplete 100 -Status 'Health diagnostics completed'
        Write-Progress -Activity 'System Health Check' -Completed
    }
}

<#
.SYNOPSIS
    Executes DISM operations for Windows image maintenance.
#>
function Invoke-DISMOperation {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("ScanHealth", "CheckHealth", "RestoreHealth", "StartComponentCleanup")]
        [string]$Operation,
        [int]$TimeoutMinutes = 30
    )

    if ($PSCmdlet.ShouldProcess("Windows Image", "DISM /$Operation")) {
        $DISMArgs = "/Online /Cleanup-Image /$Operation"
        $DISMResult = Invoke-CommandWithRealTimeOutput `
            -Command "DISM.exe" `
            -Arguments $DISMArgs `
            -ActivityName "DISM $Operation" `
            -StatusMessage "Processing..." `
            -ShowRealTimeOutput $true `
            -TimeoutMinutes $TimeoutMinutes
        return $DISMResult
    }
    return @{ Success = $true; Output = "Simulated" }
}

<#
.SYNOPSIS
    Executes System File Checker (SFC) for system file integrity.
#>
function Invoke-SFCOperation {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([hashtable])]
    param(
        [int]$TimeoutMinutes = 30
    )

    if ($PSCmdlet.ShouldProcess("System Files", "SFC /scannow")) {
        $SFCResult = Invoke-CommandWithRealTimeOutput `
            -Command "sfc.exe" `
            -Arguments "/scannow" `
            -ActivityName "SFC Scan" `
            -StatusMessage "Verifying system files..." `
            -ShowRealTimeOutput $true `
            -TimeoutMinutes $TimeoutMinutes
        return $SFCResult
    }
    return @{ Success = $true; Output = "Simulated" }
}

<#
.SYNOPSIS
    Tests disk health and schedules CHKDSK if necessary.
#>
function Test-DiskHealth {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([hashtable])]
    param()

    $Result = @{ ScheduleRequired = $false; Drive = $env:SystemDrive }

    # Check dirty bit
    $FsutilOutput = & fsutil dirty query $env:SystemDrive 2>&1
    if ($FsutilOutput -match "is dirty" -or $FsutilOutput -match "is set") {
        if ($PSCmdlet.ShouldProcess($env:SystemDrive, "Schedule CHKDSK /F /R")) {
            Write-Output Y | chkdsk $env:SystemDrive /F /R | Out-Null
            $Result.ScheduleRequired = $true
        }
    }
    return $Result
}

<#
.SYNOPSIS
    Generates a system health report file.
#>
function New-SystemHealthReport {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([string])]
    param($Results, $Config)
    if ($PSCmdlet.ShouldProcess("Health Report File", "Create report in $($Config.ReportsPath)")) {
        $ReportPath = Join-Path $Config.ReportsPath "health_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
        "SYSTEM HEALTH REPORT`n$($Results | Out-String)" | Out-File $ReportPath
        return $ReportPath
    }
    return "SimulatedPath"
}
# Export public functions
Export-ModuleMember -Function @(
    'Invoke-SystemHealthRepair',
    'Invoke-DISMOperation',
    'Invoke-SFCOperation',
    'Test-DiskHealth',
    'New-SystemHealthReport'
)
