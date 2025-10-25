<#
.SYNOPSIS
    Comprehensive disk maintenance module with intelligent optimization and cleanup.

.DESCRIPTION
    Provides enterprise-grade disk maintenance including temporary file cleanup,
    intelligent drive optimization (TRIM for SSDs, defragmentation for HDDs),
    and comprehensive space analysis with detailed reporting.

    Maintenance Operations:
    - Temporary file cleanup with age-based retention policies
    - Intelligent drive optimization based on media type detection
    - Space usage analysis and reporting
    - Performance metrics collection and analysis
    - Windows Disk Cleanup utility automation
    - Emergency disk cleanup for critical low space conditions

    Cleanup Locations:
    - User and system temporary directories
    - Windows Update cache and distribution files
    - Internet Explorer and Edge cache files
    - System log files and CBS logs
    - Prefetch files (with retention policy)

.NOTES
    File Name      : DiskMaintenance.psm1
    Author         : Miguel Velasco
    Prerequisite   : PowerShell 5.1+
    Version        : 4.0.0
    Last Updated   : October 2025
    Module Type    : Feature Module
    Dependencies   : Logging.psm1, SafeExecution.psm1, MemoryManagement.psm1,
                     DriveAnalysis.psm1, StringFormatting.psm1, UIHelpers.psm1
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator

# Import dependencies
$CommonPath = Join-Path $PSScriptRoot "Common"
Import-Module "$CommonPath\Logging.psm1" -Force
Import-Module "$CommonPath\SafeExecution.psm1" -Force
Import-Module "$CommonPath\MemoryManagement.psm1" -Force
Import-Module "$CommonPath\DriveAnalysis.psm1" -Force
Import-Module "$CommonPath\StringFormatting.psm1" -Force
Import-Module "$CommonPath\UIHelpers.psm1" -Force

<#
.SYNOPSIS
    Comprehensive disk maintenance with intelligent optimization and cleanup.

.DESCRIPTION
    Main disk maintenance function that performs temporary file cleanup,
    Windows Disk Cleanup automation, and intelligent drive optimization.

.EXAMPLE
    Invoke-DiskMaintenance

.NOTES
    Security: Safe cleanup policies preserve important system files
    Performance: Optimization is tailored to drive type (SSD TRIM vs HDD defrag)
    Enterprise: Comprehensive audit trails and compliance reporting
#>
function Invoke-DiskMaintenance {
    # Get Config from parent scope
    $Config = if (Get-Variable -Name 'Config' -Scope 1 -ErrorAction SilentlyContinue) {
        (Get-Variable -Name 'Config' -Scope 1).Value
    } elseif (Get-Variable -Name 'Config' -Scope Global -ErrorAction SilentlyContinue) {
        $Global:Config
    } else {
        @{ EnabledModules = @("DiskMaintenance"); ReportsPath = "$env:TEMP\Reports" }
    }

    if ("DiskMaintenance" -notin $Config.EnabledModules) {
        Write-MaintenanceLog -Message 'Disk Maintenance module disabled' -Level INFO
        return
    }

    Write-MaintenanceLog -Message '======== Disk Maintenance Module ========' -Level INFO

    # Proactive memory optimization before intensive disk operations
    Optimize-MemoryUsage -Force

    # Comprehensive temporary file cleanup with detailed statistics
    Invoke-SafeCommand -TaskName "Temporary File Cleanup" -Command {
        Write-ProgressBar -Activity 'Disk Cleanup' -PercentComplete 10 -Status 'Scanning temporary locations...'

        # Enterprise-grade cleanup configuration with security-focused retention policies
        $TempFolders = @(
            @{ Path = $env:TEMP; Name = "User Temp"; Priority = "High" },
            @{ Path = "$env:SystemRoot\Temp"; Name = "System Temp"; Priority = "High" },
            @{ Path = "$env:SystemRoot\SoftwareDistribution\Download"; Name = "Windows Update Cache"; Priority = "Medium" },
            @{ Path = "$env:LOCALAPPDATA\Microsoft\Windows\INetCache"; Name = "Internet Cache"; Priority = "Low" },
            @{ Path = "$env:LOCALAPPDATA\Microsoft\Windows\WebCache"; Name = "Web Cache"; Priority = "Low" },
            @{ Path = "$env:SystemRoot\Logs\CBS"; Name = "Component Store Logs"; Priority = "Medium" },
            @{ Path = "$env:SystemRoot\Prefetch"; Name = "Prefetch Files"; Priority = "Low" }
        )

        $TotalCleaned = 0
        $TotalFiles = 0
        $CleanupResults = @()

        $FolderCount = 0
        foreach ($Folder in $TempFolders) {
            $FolderCount++
            $ProgressPercent = [math]::Round(($FolderCount / $TempFolders.Count) * 80 + 10)
            Write-ProgressBar -Activity 'Disk Cleanup' -PercentComplete $ProgressPercent -Status "Processing $($Folder.Name)..."

            if (Test-Path $Folder.Path) {
                Write-DetailedOperation -Operation 'Cleanup Analysis' -Details "Scanning $($Folder.Name) at $($Folder.Path)" -Result 'Scanning'

                try {
                    # Pre-cleanup analysis for metrics collection
                    $BeforeFiles = Get-ChildItem -Path $Folder.Path -Recurse -File -ErrorAction SilentlyContinue
                    $BeforeSize = ($BeforeFiles | Measure-Object -Property Length -Sum).Sum
                    $BeforeCount = $BeforeFiles.Count

                    # Intelligent age-based cleanup policies based on priority
                    $DaysOld = if ($Folder.Priority -eq "High") { 7 } elseif ($Folder.Priority -eq "Medium") { 14 } else { 30 }

                    $FilesToDelete = $BeforeFiles | Where-Object { $_.CreationTime -lt (Get-Date).AddDays(-$DaysOld) }

                    if ($FilesToDelete) {
                        $DeleteSize = ($FilesToDelete | Measure-Object -Property Length -Sum).Sum
                        $DeleteCount = $FilesToDelete.Count

                        $DeleteSizeMB = [math]::Round($DeleteSize/1MB, 2)
                        $AnalysisDetails = Format-SafeString -Template "{0}: Found {1} files older than {2} days ({3}MB)" -Arguments @($Folder.Name, $DeleteCount, $DaysOld, $DeleteSizeMB)
                        Write-DetailedOperation -Operation 'File Cleanup' -Details $AnalysisDetails -Result 'Processing'

                        # Get WhatIf from parent scope
                        $WhatIfEnabled = if (Get-Variable -Name 'WhatIf' -Scope 1 -ErrorAction SilentlyContinue) {
                            (Get-Variable -Name 'WhatIf' -Scope 1).Value
                        } elseif (Get-Variable -Name 'WhatIf' -Scope Global -ErrorAction SilentlyContinue) {
                            $Global:WhatIf
                        } else { $false }

                        if (!$WhatIfEnabled) {
                            $FilesToDelete | Remove-Item -Force -ErrorAction SilentlyContinue
                        }

                        # Post-cleanup analysis for accurate metrics
                        $AfterFiles = Get-ChildItem -Path $Folder.Path -Recurse -File -ErrorAction SilentlyContinue
                        $AfterSize = ($AfterFiles | Measure-Object -Property Length -Sum).Sum
                        $AfterCount = $AfterFiles.Count

                        $CleanedSize = $BeforeSize - $AfterSize
                        $CleanedCount = $BeforeCount - $AfterCount

                        $TotalCleaned += $CleanedSize
                        $TotalFiles += $CleanedCount

                        # Detailed cleanup result tracking
                        $CleanupResult = @{
                            Location = $Folder.Name
                            Path = $Folder.Path
                            Priority = $Folder.Priority
                            FilesRemoved = $CleanedCount
                            SpaceFreed = $CleanedSize
                            SpaceFreedMB = [math]::Round($CleanedSize / 1MB, 2)
                        }
                        $CleanupResults += $CleanupResult

                        if ($CleanedSize -gt 0) {
                            $CleanedMB = [math]::Round($CleanedSize / 1MB, 2)
                            $LogMessage = Format-SafeString -Template "Cleaned {0} MB ({1} files) from {2}" -Arguments @($CleanedMB, $CleanedCount, $Folder.Name)
                            Write-MaintenanceLog -Message $LogMessage -Level INFO

                            $DetailMessage = Format-SafeString -Template "{0}: Removed {1} files, freed {2}MB" -Arguments @($Folder.Name, $CleanedCount, $CleanedMB)
                            Write-DetailedOperation -Operation 'Cleanup Complete' -Details $DetailMessage -Result 'Success'
                        }
                    }
                    else {
                        Write-DetailedOperation -Operation 'Cleanup Analysis' -Details "$($Folder.Name): No files older than $DaysOld days found" -Result 'Clean'
                    }
                }
                catch {
                    Write-MaintenanceLog -Message "Error cleaning $($Folder.Name): $($_.Exception.Message)" -Level ERROR
                    Write-DetailedOperation -Operation 'Cleanup Error' -Details "$($Folder.Name): $($_.Exception.Message)" -Result 'Error'
                }
            }
            else {
                Write-DetailedOperation -Operation 'Cleanup Analysis' -Details "$($Folder.Name): Path not found - $($Folder.Path)" -Result 'Skipped'
            }
        }

        Write-ProgressBar -Activity 'Disk Cleanup' -PercentComplete 95 -Status 'Generating cleanup report...'

        # Enterprise-grade cleanup reporting with comprehensive metrics
        $TotalCleanedMB = [math]::Round($TotalCleaned / 1MB, 2)
        $TotalCleanedGB = [math]::Round($TotalCleaned / 1GB, 2)

        # Ensure reports directory exists
        if (-not (Test-Path $Config.ReportsPath)) {
            New-Item -Path $Config.ReportsPath -ItemType Directory -Force | Out-Null
        }

        $CleanupReport = Join-Path $Config.ReportsPath "cleanup_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

        # Build detailed results section with safe string operations
        $DetailedResults = ""
        if ($CleanupResults.Count -gt 0) {
            $DetailedResults = $CleanupResults | ForEach-Object {
                Format-SafeString -Template "{0}: {1} files, {2} MB" -Arguments @($_.Location, $_.FilesRemoved, $_.SpaceFreedMB)
            } | Out-String
        }

        # Comprehensive cleanup report generation
        $ReportContent = @"
DISK CLEANUP REPORT
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
===========================================

SUMMARY:
Total Files Removed: $TotalFiles
Total Space Freed: $TotalCleanedMB MB ($TotalCleanedGB GB)

DETAILED RESULTS:
$DetailedResults
===========================================
"@

        $ReportContent | Out-File -FilePath $CleanupReport

        # Safe cleanup summary with comprehensive metrics
        $CleanupMessage = Format-SafeString -Template "Total disk space recovered: {0} MB ({1} files removed)" -Arguments @($TotalCleanedMB, $TotalFiles)
        Write-MaintenanceLog -Message $CleanupMessage -Level SUCCESS

        $SummaryDetails = Format-SafeString -Template "Total cleanup: {0} MB across {1} locations | Report: {2}" -Arguments @($TotalCleanedMB, $CleanupResults.Count, $CleanupReport)
        Write-DetailedOperation -Operation 'Cleanup Summary' -Details $SummaryDetails -Result 'Complete'

        Write-ProgressBar -Activity 'Disk Cleanup' -PercentComplete 100 -Status 'Cleanup completed'
        Write-Progress -Activity 'Disk Cleanup' -Completed
    } -TimeoutMinutes 15

    # Enhanced Windows Disk Cleanup integration
    if ($Config.DiskCleanup.EnableWindowsCleanup) {
        Invoke-SafeCommand -TaskName "Windows Disk Cleanup Utility" -Command {
            Write-MaintenanceLog -Message 'Executing automated Windows Disk Cleanup...' -Level PROGRESS

            # Check for emergency cleanup conditions first
            if ($Config.DiskCleanup.AutoEmergencyCleanup) {
                $EmergencyResult = Invoke-EmergencyDiskCleanup -ThresholdGB $Config.DiskCleanup.EmergencyThresholdGB

                if ($EmergencyResult.Required) {
                    Write-MaintenanceLog -Message "Emergency cleanup completed - freed $($EmergencyResult.TotalFreedGB)GB" -Level SUCCESS
                    Write-DetailedOperation -Operation 'Emergency Disk Cleanup' -Details "Critical cleanup performed - freed $($EmergencyResult.TotalFreedGB)GB" -Result 'Completed'
                }
            }

            # Execute standard Windows Disk Cleanup
            $WindowsCleanupResult = Invoke-WindowsDiskCleanup `
                -StateFlag $Config.DiskCleanup.StateFlag `
                -IncludeRecycleBin $Config.DiskCleanup.IncludeRecycleBin `
                -TimeoutMinutes $Config.DiskCleanup.CleanupTimeout

            if ($WindowsCleanupResult.Success) {
                Write-MaintenanceLog -Message "Windows Disk Cleanup freed $($WindowsCleanupResult.SpaceFreedMB)MB across $($WindowsCleanupResult.CategoriesCleaned.Count) categories" -Level SUCCESS
                Write-DetailedOperation -Operation 'Windows Disk Cleanup' -Details "Freed: $($WindowsCleanupResult.SpaceFreedMB)MB | Categories: $($WindowsCleanupResult.CategoriesCleaned.Count) | Duration: $($WindowsCleanupResult.Duration.TotalMinutes.ToString('F2'))min" -Result 'Success'
            }
            else {
                Write-MaintenanceLog -Message "Windows Disk Cleanup completed with errors: $($WindowsCleanupResult.Errors -join ', ')" -Level WARNING
                Write-DetailedOperation -Operation 'Windows Disk Cleanup' -Details "Errors: $($WindowsCleanupResult.Errors.Count)" -Result 'Partial'
            }
        }
    }
    else {
        Write-MaintenanceLog -Message 'Windows Disk Cleanup utility disabled in configuration' -Level INFO
    }

    # Intelligent disk optimization with advanced drive filtering and type-specific optimization
    Invoke-SafeCommand -TaskName "Intelligent Disk Optimization" -Command {
        Write-ProgressBar -Activity 'Disk Optimization' -PercentComplete 10 -Status 'Analyzing drive configuration...'

        # Advanced volume filtering with comprehensive validation
        $Volumes = Get-Volume | Where-Object {
            $_.DriveType -eq 'Fixed' -and
            $null -ne $_.DriveLetter -and
            ![string]::IsNullOrWhiteSpace($_.DriveLetter) -and
            $_.DriveLetter -match '^[A-Z]$' -and
            $_.HealthStatus -eq 'Healthy'
        }

        Write-MaintenanceLog -Message "Found $($Volumes.Count) eligible drives for analysis" -Level INFO

        $DriveResults = @()
        $DriveCount = 0
        $OptimizedCount = 0
        $SkippedCount = 0

        # Get SkipExternalDrives from parent scope
        $SkipExternalDrivesEnabled = if (Get-Variable -Name 'SkipExternalDrives' -Scope 1 -ErrorAction SilentlyContinue) {
            (Get-Variable -Name 'SkipExternalDrives' -Scope 1).Value
        } elseif (Get-Variable -Name 'SkipExternalDrives' -Scope Global -ErrorAction SilentlyContinue) {
            $Global:SkipExternalDrives
        } else { $false }

        foreach ($Volume in $Volumes) {
            $DriveCount++
            $ProgressPercent = [math]::Round(($DriveCount / $Volumes.Count) * 80 + 10)

            Write-ProgressBar -Activity 'Disk Optimization' -PercentComplete $ProgressPercent -Status "Analyzing drive $($Volume.DriveLetter):"

            # Comprehensive drive analysis with caching support
            $DriveInfo = Get-DriveInfo -DriveLetter "$($Volume.DriveLetter):"

            # Validate drive analysis results
            if ($null -eq $DriveInfo) {
                $SkippedCount++
                $DriveResults += @{
                    Drive = $Volume.DriveLetter
                    Action = "Skipped"
                    Reason = "Invalid drive letter or drive not accessible"
                    Success = $true
                }
                continue
            }

            # Linux partition detection and safe skipping
            if ($DriveInfo.IsLinuxPartition) {
                Write-MaintenanceLog -Message "Skipping Linux partition on drive $($Volume.DriveLetter):" -Level SKIP
                $SkippedCount++
                $DriveResults += @{
                    Drive = $Volume.DriveLetter
                    Action = "Skipped"
                    Reason = "Linux partition"
                    Success = $true
                }
                continue
            }

            # External drive handling based on user preferences
            if ($DriveInfo.IsExternalDrive -and $SkipExternalDrivesEnabled) {
                Write-MaintenanceLog -Message "Skipping external drive $($Volume.DriveLetter): by user preference" -Level SKIP
                $SkippedCount++
                $DriveResults += @{
                    Drive = $Volume.DriveLetter
                    Action = "Skipped"
                    Reason = "External drive"
                    Success = $true
                }
                continue
            }

            # Custom skip reason handling
            if ($DriveInfo.SkipReason) {
                Write-MaintenanceLog -Message "Skipping drive $($Volume.DriveLetter): - $($DriveInfo.SkipReason)" -Level SKIP
                $SkippedCount++
                $DriveResults += @{
                    Drive = $Volume.DriveLetter
                    Action = "Skipped"
                    Reason = $DriveInfo.SkipReason
                    Success = $true
                }
                continue
            }

            # Execute optimization for eligible drives
            if ($DriveInfo.AnalysisSuccess -and $DriveInfo.CanOptimize) {
                Write-MaintenanceLog -Message "Processing drive $($DriveInfo.DriveLetter) ($($DriveInfo.DeviceType))" -Level INFO

                $OptimizationResult = Invoke-DriveOptimization -DriveInfo $DriveInfo

                if ($OptimizationResult.Success) {
                    $OptimizedCount++
                    if (Get-Variable -Name 'MaintenanceCounters' -Scope Global -ErrorAction SilentlyContinue) {
                        $Global:MaintenanceCounters.DriveOptimizations++
                    }
                }

                $DriveResults += $OptimizationResult
            }
            else {
                Write-MaintenanceLog -Message "Could not analyze or optimize drive $($Volume.DriveLetter): - skipping" -Level WARNING
                $SkippedCount++
                $DriveResults += @{
                    Drive = $Volume.DriveLetter
                    Action = "Failed"
                    Reason = "Analysis failed"
                    Success = $false
                }
            }

            # Memory management during optimization loop
            Test-MemoryPressure
        }

        # Generate comprehensive optimization report
        $OptimizationReportPath = New-OptimizationReport -DriveResults $DriveResults -OptimizedCount $OptimizedCount -SkippedCount $SkippedCount
        Write-MaintenanceLog -Message "Optimization report generated: $OptimizationReportPath" -Level SUCCESS

        Write-MaintenanceLog -Message "Disk optimization completed - Optimized: $OptimizedCount, Skipped: $SkippedCount, Total: $($Volumes.Count)" -Level SUCCESS

        Write-ProgressBar -Activity 'Disk Optimization' -PercentComplete 100 -Status 'Optimization completed'
        Write-Progress -Activity 'Disk Optimization' -Completed

        # Cache cleanup and final memory optimization
        Clear-DriveAnalysisCache
        Optimize-MemoryUsage

    } -TimeoutMinutes 45
}

<#
.SYNOPSIS
    Executes Windows Disk Cleanup utility with automated configuration.

.DESCRIPTION
    Configures and executes the Windows Disk Cleanup utility (cleanmgr.exe) using
    StateFlags registry settings to automate cleanup operations.

.PARAMETER StateFlag
    StateFlags number (0-9999) for cleanup configuration persistence

.PARAMETER IncludeRecycleBin
    Include Recycle Bin in cleanup operations (default: $false for safety)

.PARAMETER TimeoutMinutes
    Maximum time to allow for cleanup before timeout (default: 30 minutes)

.OUTPUTS
    [hashtable] Cleanup results with space freed and operation details

.EXAMPLE
    Invoke-WindowsDiskCleanup -IncludeRecycleBin:$false

.NOTES
    Security: Recycle Bin cleanup disabled by default to prevent accidental data loss
    Performance: Can take 10-30 minutes depending on system state
#>
function Invoke-WindowsDiskCleanup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateRange(1, 9999)]
        [int]$StateFlag = 1001,

        [Parameter(Mandatory=$false)]
        [bool]$IncludeRecycleBin = $false,

        [Parameter(Mandatory=$false)]
        [int]$TimeoutMinutes = 30
    )

    Write-MaintenanceLog -Message 'Starting Windows Disk Cleanup utility automation...' -Level PROGRESS
    Write-ProgressBar -Activity 'Disk Cleanup' -PercentComplete 65 -Status 'Configuring Windows Disk Cleanup...'

    $CleanupResult = @{
        Success = $false
        SpaceFreedMB = 0
        Duration = [TimeSpan]::Zero
        CategoriesCleaned = @()
        Errors = @()
    }

    try {
        # Get WhatIf from parent scope
        $WhatIfEnabled = if (Get-Variable -Name 'WhatIf' -Scope 1 -ErrorAction SilentlyContinue) {
            (Get-Variable -Name 'WhatIf' -Scope 1).Value
        } elseif (Get-Variable -Name 'WhatIf' -Scope Global -ErrorAction SilentlyContinue) {
            $Global:WhatIf
        } else { $false }

        if ($WhatIfEnabled) {
            Write-MaintenanceLog -Message "[WHATIF] Would execute Windows Disk Cleanup with automated configuration" -Level INFO
            $CleanupResult.Success = $true
            return $CleanupResult
        }

        # Measure disk space before cleanup
        $SystemDrive = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"
        $SpaceBeforeGB = [math]::Round($SystemDrive.FreeSpace / 1GB, 2)

        Write-MaintenanceLog -Message "Current free space on $($env:SystemDrive): ${SpaceBeforeGB}GB" -Level INFO
        Write-DetailedOperation -Operation 'Disk Cleanup Initialization' -Details "Pre-cleanup free space: ${SpaceBeforeGB}GB" -Result 'Measured'

        # Configure StateFlags registry for automated cleanup
        Write-MaintenanceLog -Message "Configuring Disk Cleanup StateFlags (StateFlags$StateFlag)..." -Level PROGRESS

        $StateRegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"

        # Define cleanup categories with their registry keys
        $CleanupCategories = @{
            # Safe cleanup categories (always enabled)
            "Downloaded Program Files" = "Downloaded Program Files"
            "Temporary Internet Files" = "Internet Cache Files"
            "Temporary Files" = "Temporary Files"
            "Thumbnails" = "Thumbnail Cache"
            "Windows Error Reporting" = "Windows Error Reporting Files"
            "Windows Defender" = "Windows Defender"
            "System Log Files" = "System Log Files"
            "DirectX Shader Cache" = "DirectX Shader Cache"
            "Delivery Optimization Files" = "Delivery Optimization Files"
            "Old Windows Installation" = "Previous Installations"
            "Windows Update Cleanup" = "Windows Update Cleanup"
            "Temporary Windows Files" = "Temporary Setup Files"
            "System Memory Dumps" = "System error memory dump files"
            "System Minidumps" = "System error minidump files"

            # Optional categories (user configurable)
            "Recycle Bin" = "Recycle Bin"
        }

        # Configure each cleanup category
        $ConfiguredCategories = 0
        foreach ($Category in $CleanupCategories.GetEnumerator()) {
            $CategoryPath = Join-Path $StateRegistryPath $Category.Value

            try {
                # Check if category registry key exists
                if (Test-Path $CategoryPath) {
                    # Decide whether to enable this category
                    $EnableCategory = $true

                    # Special handling for Recycle Bin (safety)
                    if ($Category.Key -eq "Recycle Bin" -and -not $IncludeRecycleBin) {
                        $EnableCategory = $false
                        Write-MaintenanceLog -Message "Skipping Recycle Bin cleanup for data safety" -Level INFO
                    }

                    if ($EnableCategory) {
                        # Set StateFlags value to enable this cleanup category
                        New-ItemProperty -Path $CategoryPath -Name "StateFlags$StateFlag" -PropertyType DWord -Value 2 -Force -ErrorAction SilentlyContinue | Out-Null
                        $ConfiguredCategories++
                        $CleanupResult.CategoriesCleaned += $Category.Key
                    }
                    else {
                        # Set to 0 to disable
                        New-ItemProperty -Path $CategoryPath -Name "StateFlags$StateFlag" -PropertyType DWord -Value 0 -Force -ErrorAction SilentlyContinue | Out-Null
                    }
                }
            }
            catch {
                Write-MaintenanceLog -Message "Failed to configure cleanup category '$($Category.Key)': $($_.Exception.Message)" -Level WARNING
                $CleanupResult.Errors += "Configuration: $($Category.Key)"
            }
        }

        Write-MaintenanceLog -Message "Configured $ConfiguredCategories cleanup categories" -Level SUCCESS
        Write-DetailedOperation -Operation 'Cleanup Configuration' -Details "$ConfiguredCategories categories enabled" -Result 'Configured'

        # Execute Windows Disk Cleanup with configured StateFlags
        Write-ProgressBar -Activity 'Disk Cleanup' -PercentComplete 70 -Status 'Executing Windows Disk Cleanup...'
        Write-MaintenanceLog -Message "Executing cleanmgr.exe with StateFlags$StateFlag..." -Level PROGRESS
        Write-MaintenanceLog -Message "This operation may take 10-30 minutes depending on system state..." -Level INFO

        $StartTime = Get-Date
        $TimeoutSeconds = $TimeoutMinutes * 60

        # Execute cleanmgr.exe with silent automation
        try {
            # Start cleanmgr process with StateFlags for automation
            $CleanmgrArgs = "/sagerun:$StateFlag"

            $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
            $ProcessInfo.FileName = "cleanmgr.exe"
            $ProcessInfo.Arguments = $CleanmgrArgs
            $ProcessInfo.UseShellExecute = $false
            $ProcessInfo.CreateNoWindow = $true
            $ProcessInfo.RedirectStandardOutput = $true
            $ProcessInfo.RedirectStandardError = $true

            $Process = New-Object System.Diagnostics.Process
            $Process.StartInfo = $ProcessInfo
            $Process.Start() | Out-Null

            Write-MaintenanceLog -Message "Disk Cleanup process started (PID: $($Process.Id))" -Level INFO
            Write-DetailedOperation -Operation 'Disk Cleanup Execution' -Details "Process started with PID: $($Process.Id)" -Result 'Running'

            # Wait for process completion with timeout
            $Completed = $Process.WaitForExit($TimeoutSeconds * 1000)

            if ($Completed) {
                $CleanupResult.Duration = (Get-Date) - $StartTime
                $ExitCode = $Process.ExitCode

                Write-MaintenanceLog -Message "Disk Cleanup completed with exit code: $ExitCode (Duration: $($CleanupResult.Duration.TotalMinutes.ToString('F2')) minutes)" -Level SUCCESS
                Write-DetailedOperation -Operation 'Disk Cleanup Completion' -Details "Exit code: $ExitCode | Duration: $($CleanupResult.Duration.TotalMinutes.ToString('F2')) min" -Result 'Completed'

                # Measure disk space after cleanup
                Start-Sleep -Seconds 2  # Allow file system to update
                $SystemDrive = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"
                $SpaceAfterGB = [math]::Round($SystemDrive.FreeSpace / 1GB, 2)
                $SpaceFreedGB = [math]::Round($SpaceAfterGB - $SpaceBeforeGB, 2)
                $SpaceFreedMB = [math]::Round($SpaceFreedGB * 1024, 2)

                $CleanupResult.SpaceFreedMB = $SpaceFreedMB
                $CleanupResult.Success = $true

                Write-MaintenanceLog -Message "Windows Disk Cleanup freed ${SpaceFreedGB}GB (${SpaceFreedMB}MB) of disk space" -Level SUCCESS
                Write-DetailedOperation -Operation 'Disk Cleanup Results' -Details "Freed: ${SpaceFreedGB}GB | Before: ${SpaceBeforeGB}GB | After: ${SpaceAfterGB}GB" -Result "Freed ${SpaceFreedGB}GB"
            }
            else {
                # Timeout occurred
                $CleanupResult.Duration = (Get-Date) - $StartTime
                $Process.Kill()

                Write-MaintenanceLog -Message "Disk Cleanup operation timed out after $TimeoutMinutes minutes" -Level ERROR
                $CleanupResult.Errors += "Operation timed out"

                # Attempt to measure partial cleanup
                $SystemDrive = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"
                $SpaceAfterGB = [math]::Round($SystemDrive.FreeSpace / 1GB, 2)
                $SpaceFreedGB = [math]::Round($SpaceAfterGB - $SpaceBeforeGB, 2)

                if ($SpaceFreedGB -gt 0) {
                    $CleanupResult.SpaceFreedMB = [math]::Round($SpaceFreedGB * 1024, 2)
                    Write-MaintenanceLog -Message "Partial cleanup completed before timeout - freed ${SpaceFreedGB}GB" -Level WARNING
                }
            }
        }
        catch {
            $CleanupResult.Duration = (Get-Date) - $StartTime
            Write-MaintenanceLog -Message "Disk Cleanup execution failed: $($_.Exception.Message)" -Level ERROR
            $CleanupResult.Errors += "Execution exception: $($_.Exception.Message)"
        }

        Write-ProgressBar -Activity 'Disk Cleanup' -PercentComplete 80 -Status 'Windows Disk Cleanup completed'

        return $CleanupResult
    }
    catch {
        Write-MaintenanceLog -Message "Windows Disk Cleanup automation failed: $($_.Exception.Message)" -Level ERROR
        $CleanupResult.Errors += "Fatal error: $($_.Exception.Message)"
        return $CleanupResult
    }
}

<#
.SYNOPSIS
    Clears Disk Cleanup StateFlags registry entries after execution.

.DESCRIPTION
    Removes StateFlags registry entries to clean up after Disk Cleanup execution.
    This is optional and only needed if you don't want to persist the configuration.

.PARAMETER StateFlag
    StateFlags number to clear from registry

.EXAMPLE
    Clear-DiskCleanupStateFlags -StateFlag 1001

.NOTES
    Optional: StateFlags can be left in place for consistent future executions
#>
function Clear-DiskCleanupStateFlags {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [int]$StateFlag
    )

    try {
        Write-MaintenanceLog -Message "Clearing Disk Cleanup StateFlags$StateFlag from registry..." -Level INFO

        $StateRegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
        $CategoriesPath = Get-ChildItem -Path $StateRegistryPath -ErrorAction SilentlyContinue

        $ClearedCount = 0
        foreach ($CategoryPath in $CategoriesPath) {
            try {
                $PropertyName = "StateFlags$StateFlag"
                if (Get-ItemProperty -Path $CategoryPath.PSPath -Name $PropertyName -ErrorAction SilentlyContinue) {
                    Remove-ItemProperty -Path $CategoryPath.PSPath -Name $PropertyName -Force -ErrorAction Stop
                    $ClearedCount++
                }
            }
            catch {
                # Silently continue if property doesn't exist or can't be removed
            }
        }

        Write-MaintenanceLog -Message "Cleared $ClearedCount StateFlags entries from registry" -Level SUCCESS
    }
    catch {
        Write-MaintenanceLog -Message "Failed to clear StateFlags: $($_.Exception.Message)" -Level WARNING
    }
}

<#
.SYNOPSIS
    Advanced Sage command execution for Disk Cleanup utility.

.DESCRIPTION
    Provides direct Sage command execution for advanced cleanup scenarios.

.PARAMETER SageCommand
    Sage command to execute (sageset, sagerun, tuneup, lowdisk, verylowdisk)

.PARAMETER StateFlag
    StateFlags number for sageset/sagerun operations

.PARAMETER Interactive
    Allow interactive GUI for sageset command

.OUTPUTS
    [hashtable] Command execution results

.EXAMPLE
    Invoke-DiskCleanupSageCommand -SageCommand "lowdisk"

.NOTES
    Security: Some Sage commands may show GUI - not suitable for silent automation
#>
function Invoke-DiskCleanupSageCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("sageset", "sagerun", "tuneup", "lowdisk", "verylowdisk")]
        [string]$SageCommand,

        [Parameter(Mandatory=$false)]
        [int]$StateFlag = 1001,

        [Parameter(Mandatory=$false)]
        [bool]$Interactive = $false
    )

    $Result = @{
        Success = $false
        Command = $SageCommand
        Output = ""
        Duration = [TimeSpan]::Zero
    }

    try {
        # Get WhatIf and SilentMode from parent scope
        $WhatIfEnabled = if (Get-Variable -Name 'WhatIf' -Scope 1 -ErrorAction SilentlyContinue) {
            (Get-Variable -Name 'WhatIf' -Scope 1).Value
        } elseif (Get-Variable -Name 'WhatIf' -Scope Global -ErrorAction SilentlyContinue) {
            $Global:WhatIf
        } else { $false }

        $SilentModeEnabled = if (Get-Variable -Name 'SilentMode' -Scope 1 -ErrorAction SilentlyContinue) {
            (Get-Variable -Name 'SilentMode' -Scope 1).Value
        } elseif (Get-Variable -Name 'SilentMode' -Scope Global -ErrorAction SilentlyContinue) {
            $Global:SilentMode
        } else { $false }

        if ($WhatIfEnabled) {
            Write-MaintenanceLog -Message "[WHATIF] Would execute: cleanmgr.exe /$SageCommand" -Level INFO
            $Result.Success = $true
            return $Result
        }

        # Construct command arguments
        $Arguments = switch ($SageCommand) {
            "sageset" {
                if (-not $Interactive -and $SilentModeEnabled) {
                    Write-MaintenanceLog -Message "Skipping sageset in silent mode (requires interaction)" -Level INFO
                    $Result.Output = "Skipped in silent mode"
                    return $Result
                }
                "/sageset:$StateFlag"
            }
            "sagerun" { "/sagerun:$StateFlag" }
            "tuneup" { "/tuneup:$StateFlag" }
            "lowdisk" { "/lowdisk" }
            "verylowdisk" { "/verylowdisk" }
        }

        Write-MaintenanceLog -Message "Executing Disk Cleanup Sage command: $Arguments" -Level INFO

        $StartTime = Get-Date

        # Execute command
        $Process = Start-Process -FilePath "cleanmgr.exe" -ArgumentList $Arguments -PassThru -Wait -NoNewWindow

        $Result.Duration = (Get-Date) - $StartTime
        $Result.Success = ($Process.ExitCode -eq 0)
        $Result.Output = "Exit code: $($Process.ExitCode)"

        Write-MaintenanceLog -Message "Sage command completed with exit code: $($Process.ExitCode) (Duration: $($Result.Duration.TotalMinutes.ToString('F2')) min)" -Level $(if ($Result.Success) { "SUCCESS" } else { "ERROR" })

        return $Result
    }
    catch {
        $Result.Output = "Exception: $($_.Exception.Message)"
        Write-MaintenanceLog -Message "Sage command failed: $($_.Exception.Message)" -Level ERROR
        return $Result
    }
}

<#
.SYNOPSIS
    Emergency low disk space cleanup handler.

.DESCRIPTION
    Executes aggressive cleanup operations when disk space is critically low.
    Combines manual cleanup with Windows Disk Cleanup emergency modes.

.PARAMETER ThresholdGB
    Disk space threshold to trigger emergency cleanup (default: 2GB)

.OUTPUTS
    [hashtable] Emergency cleanup results

.EXAMPLE
    Invoke-EmergencyDiskCleanup -ThresholdGB 2

.NOTES
    Safety: Includes Recycle Bin cleanup in emergency mode
    Performance: More aggressive than standard cleanup
#>
function Invoke-EmergencyDiskCleanup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [double]$ThresholdGB = 2.0
    )

    Write-MaintenanceLog -Message 'Checking if emergency disk cleanup is required...' -Level PROGRESS

    try {
        $SystemDrive = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"
        $FreeSpaceGB = [math]::Round($SystemDrive.FreeSpace / 1GB, 2)

        if ($FreeSpaceGB -le $ThresholdGB) {
            Write-MaintenanceLog -Message "CRITICAL: Low disk space detected (${FreeSpaceGB}GB) - initiating emergency cleanup" -Level ERROR
            Write-DetailedOperation -Operation 'Emergency Cleanup' -Details "Free space: ${FreeSpaceGB}GB (Threshold: ${ThresholdGB}GB)" -Result 'Triggered'

            # Execute emergency cleanup procedures
            $EmergencyResult = @{
                InitialFreeSpaceGB = $FreeSpaceGB
                FinalFreeSpaceGB = 0
                TotalFreedGB = 0
                Operations = @()
                Required = $true
            }

            # 1. Execute very low disk space Sage command
            Write-MaintenanceLog -Message "Executing emergency Disk Cleanup (verylowdisk mode)..." -Level PROGRESS
            $SageResult = Invoke-DiskCleanupSageCommand -SageCommand "verylowdisk"
            $EmergencyResult.Operations += @{ Operation = "VeryLowDisk Sage"; Success = $SageResult.Success }

            # 2. Execute standard cleanup with Recycle Bin included
            Write-MaintenanceLog -Message "Executing standard cleanup with Recycle Bin (emergency mode)..." -Level PROGRESS
            $StandardResult = Invoke-WindowsDiskCleanup -IncludeRecycleBin:$true -TimeoutMinutes 20
            $EmergencyResult.Operations += @{ Operation = "Full Cleanup"; Success = $StandardResult.Success; FreedMB = $StandardResult.SpaceFreedMB }

            # 3. Additional emergency cleanup - clear more temporary locations
            Write-MaintenanceLog -Message "Executing additional temporary file cleanup..." -Level PROGRESS
            $AdditionalPaths = @(
                "$env:LOCALAPPDATA\Temp\*",
                "$env:LOCALAPPDATA\Microsoft\Windows\WER\*",
                "$env:ProgramData\Microsoft\Windows\WER\*"
            )

            $AdditionalFreed = 0
            foreach ($Path in $AdditionalPaths) {
                try {
                    $Items = Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer }
                    $SizeBefore = ($Items | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum

                    Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue

                    $AdditionalFreed += if ($SizeBefore) { $SizeBefore } else { 0 }
                }
                catch {
                    # Continue on errors
                }
            }

            $AdditionalFreedMB = [math]::Round($AdditionalFreed / 1MB, 2)
            $EmergencyResult.Operations += @{ Operation = "Additional Temp Cleanup"; FreedMB = $AdditionalFreedMB }

            # Measure final disk space
            $SystemDrive = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"
            $EmergencyResult.FinalFreeSpaceGB = [math]::Round($SystemDrive.FreeSpace / 1GB, 2)
            $EmergencyResult.TotalFreedGB = [math]::Round($EmergencyResult.FinalFreeSpaceGB - $EmergencyResult.InitialFreeSpaceGB, 2)

            Write-MaintenanceLog -Message "Emergency cleanup completed - freed $($EmergencyResult.TotalFreedGB)GB ($($EmergencyResult.InitialFreeSpaceGB)GB -> $($EmergencyResult.FinalFreeSpaceGB)GB)" -Level SUCCESS
            Write-DetailedOperation -Operation 'Emergency Cleanup Results' -Details "Freed: $($EmergencyResult.TotalFreedGB)GB | Final: $($EmergencyResult.FinalFreeSpaceGB)GB" -Result 'Completed'

            # Critical warning if still low after emergency cleanup
            if ($EmergencyResult.FinalFreeSpaceGB -le $ThresholdGB) {
                Write-MaintenanceLog -Message "WARNING: Disk space still critically low after emergency cleanup ($($EmergencyResult.FinalFreeSpaceGB)GB)" -Level ERROR

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

                if ($ShowMessageBoxesEnabled -and -not $SilentModeEnabled) {
                    $CriticalMessage = @"
CRITICAL: Low Disk Space Warning

Emergency cleanup has been performed, but disk space remains critically low.

Current Free Space: $($EmergencyResult.FinalFreeSpaceGB)GB
Space Freed: $($EmergencyResult.TotalFreedGB)GB

URGENT ACTIONS REQUIRED:
• Delete large files or move them to external storage
• Uninstall unused programs
• Use Storage Sense to identify large files
• Consider upgrading to a larger drive

System stability may be affected if disk space is not increased.
"@
                    Show-MaintenanceMessageBox -Message $CriticalMessage -Title "Critical Low Disk Space" -Icon "Error" -ForceShow
                }
            }

            return $EmergencyResult
        }
        else {
            Write-MaintenanceLog -Message "Disk space is adequate (${FreeSpaceGB}GB) - emergency cleanup not required" -Level INFO
            return @{ Required = $false; FreeSpaceGB = $FreeSpaceGB }
        }
    }
    catch {
        Write-MaintenanceLog -Message "Emergency cleanup check failed: $($_.Exception.Message)" -Level ERROR
        return @{ Required = $false; Error = $_.Exception.Message }
    }
}

<#
.SYNOPSIS
    Intelligent drive optimization dispatcher with type-specific optimization strategies.

.DESCRIPTION
    Dispatches appropriate optimization strategy based on drive type and capabilities.

.PARAMETER DriveInfo
    Comprehensive drive analysis information from Get-DriveInfo

.OUTPUTS
    [hashtable] Optimization result with success status, duration, and details

.EXAMPLE
    $Result = Invoke-DriveOptimization -DriveInfo $DriveAnalysis

.NOTES
    Performance: Type-specific optimization ensures optimal performance for each drive type
#>
function Invoke-DriveOptimization {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, HelpMessage="Drive analysis information")]
        [hashtable]$DriveInfo
    )

    $Result = @{
        Drive = $DriveInfo.DriveLetter
        Action = "None"
        Duration = [TimeSpan]::Zero
        Success = $false
        Details = ""
        Reason = ""
    }

    try {
        # SSD optimization: TRIM operations with hardware validation
        if ($DriveInfo.MediaType -eq "SSD" -and $DriveInfo.SupportsTrim -and $DriveInfo.TrimCapabilityVerified) {
            $Result = Invoke-TrimOperation -DriveInfo $DriveInfo
        }
        # HDD optimization: Defragmentation with fragmentation analysis
        elseif ($DriveInfo.MediaType -eq "HDD" -and $DriveInfo.CanOptimize) {
            $Result = Invoke-DefragmentationOperation -DriveInfo $DriveInfo
        }
        else {
            # Graceful handling of unsupported or restricted drives
            $Result.Action = "Skipped"
            $Result.Reason = "Drive type not suitable for optimization or hardware limitations"
            $Result.Success = $true
        }

        return $Result
    }
    catch {
        $Result.Success = $false
        $Result.Reason = "Optimization failed: $($_.Exception.Message)"
        return $Result
    }
}

<#
.SYNOPSIS
    SSD TRIM operation with enterprise-grade safety and monitoring.

.DESCRIPTION
    Performs TRIM operations on SSD drives with comprehensive safety checks,
    user confirmation, hardware validation, and timeout protection.

.PARAMETER DriveInfo
    SSD drive information with TRIM capability validation

.OUTPUTS
    [hashtable] TRIM operation result with detailed metrics

.NOTES
    Security: User confirmation required for potentially disruptive operations
    Performance: Timeout protection prevents system hang scenarios
#>
function Invoke-TrimOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, HelpMessage="SSD drive information")]
        [hashtable]$DriveInfo
    )

    $Result = @{
        Drive = $DriveInfo.DriveLetter
        Action = "TRIM"
        Duration = [TimeSpan]::Zero
        Success = $false
        Details = ""
        Reason = ""
    }

    # Get ShowMessageBoxes, SilentMode, and WhatIf from parent scope
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

    $WhatIfEnabled = if (Get-Variable -Name 'WhatIf' -Scope 1 -ErrorAction SilentlyContinue) {
        (Get-Variable -Name 'WhatIf' -Scope 1).Value
    } elseif (Get-Variable -Name 'WhatIf' -Scope Global -ErrorAction SilentlyContinue) {
        $Global:WhatIf
    } else { $false }

    # Enterprise-grade user confirmation for TRIM operations
    $TrimConfirmation = $true
    if ($ShowMessageBoxesEnabled -and -not $SilentModeEnabled -and -not $WhatIfEnabled) {
        $TrimMessage = @"
TRIM Operation Confirmation

Drive: $($DriveInfo.DriveLetter)
Device Type: $($DriveInfo.DeviceType)
TRIM Support: Hardware verified

This operation will optimize SSD performance but may temporarily reduce drive availability.

Proceed with TRIM operation?
"@
        $TrimConfirmation = (Show-MaintenanceMessageBox -Message $TrimMessage -Title "TRIM Operation Confirmation" -Buttons "YesNo" -Icon "Question") -eq "Yes"
    }

    if (-not $TrimConfirmation) {
        $Result.Action = "Skipped"
        $Result.Reason = "User declined TRIM operation"
        $Result.Success = $true
        return $Result
    }

    try {
        Write-MaintenanceLog -Message "Executing TRIM operation on SSD drive $($DriveInfo.DriveLetter)" -Level PROGRESS

        if (!$WhatIfEnabled) {
            $TrimStartTime = Get-Date

            # Enterprise job management with timeout protection
            $TrimJob = Start-Job -ScriptBlock {
                param($DriveLetter)
                try {
                    Optimize-Volume -DriveLetter $DriveLetter -ReTrim -ErrorAction Stop
                    return @{ Success = $true; Error = $null }
                }
                catch {
                    return @{ Success = $false; Error = $_.Exception.Message }
                }
            } -ArgumentList $DriveInfo.DriveLetter.TrimEnd(':')

            # Get FastMode from parent scope
            $FastModeEnabled = if (Get-Variable -Name 'FastMode' -Scope 1 -ErrorAction SilentlyContinue) {
                (Get-Variable -Name 'FastMode' -Scope 1).Value
            } elseif (Get-Variable -Name 'FastMode' -Scope Global -ErrorAction SilentlyContinue) {
                $Global:FastMode
            } else { $false }

            # Adaptive timeout based on system performance mode
            $TimeoutSeconds = if ($FastModeEnabled) { 300 } else { 600 }  # 5 or 10 minutes
            $Completed = Wait-Job -Job $TrimJob -Timeout $TimeoutSeconds

            if ($Completed) {
                $JobResult = Receive-Job -Job $TrimJob
                $TrimDuration = (Get-Date) - $TrimStartTime

                if ($JobResult.Success) {
                    $Result.Duration = $TrimDuration
                    $Result.Success = $true
                    $Result.Details = "TRIM operation completed in $([math]::Round($TrimDuration.TotalSeconds, 1)) seconds"

                    Write-MaintenanceLog -Message $Result.Details -Level SUCCESS

                    # User notification for successful completion
                    if ($ShowMessageBoxesEnabled -and -not $SilentModeEnabled) {
                        Show-MaintenanceMessageBox -Message "TRIM operation completed successfully on drive $($DriveInfo.DriveLetter) in $([math]::Round($TrimDuration.TotalSeconds, 1)) seconds." -Title "TRIM Completed" -Icon "Information"
                    }
                }
                else {
                    $Result.Success = $false
                    $Result.Reason = "TRIM operation failed: $($JobResult.Error)"
                    $Result.Duration = $TrimDuration
                    Write-MaintenanceLog -Message $Result.Reason -Level ERROR
                }
            }
            else {
                # Timeout handling with graceful job termination
                try {
                    Stop-Job -Job $TrimJob -ErrorAction SilentlyContinue
                }
                catch {
                    Write-MaintenanceLog -Message "Warning: Could not stop TRIM job gracefully" -Level WARNING
                }

                $Result.Success = $false
                $Result.Reason = "TRIM operation timed out after $TimeoutSeconds seconds"
                $Result.Duration = (Get-Date) - $TrimStartTime
                Write-MaintenanceLog -Message $Result.Reason -Level WARNING
            }

            # Comprehensive job cleanup with error handling
            try {
                Remove-Job -Job $TrimJob -ErrorAction SilentlyContinue
            } catch {
                Write-MaintenanceLog -Message "Warning: Could not remove TRIM job" -Level WARNING
            }
        }
        else {
            $Result.Action = "TRIM (Simulated)"
            $Result.Success = $true
            $Result.Details = "WHATIF: Would perform TRIM operation"
        }

        return $Result
    }
    catch [System.Management.Automation.MethodInvocationException] {
        # Hardware compatibility error handling
        if ($_.Exception.InnerException.Message -match "not supported|cannot be optimized") {
            $Result.Success = $false
            $Result.Reason = "TRIM not supported by hardware (even though initially detected)"
            Write-MaintenanceLog -Message "TRIM operation failed: Hardware support verification failed for drive $($DriveInfo.DriveLetter)" -Level ERROR
        }
        else {
            $Result.Success = $false
            $Result.Reason = "TRIM operation failed: $($_.Exception.Message)"
            Write-MaintenanceLog -Message "TRIM operation error for drive $($DriveInfo.DriveLetter): $($_.Exception.Message)" -Level ERROR
        }
        return $Result
    }
    catch {
        $Result.Success = $false
        $Result.Reason = "TRIM operation failed: $($_.Exception.Message)"
        Write-MaintenanceLog -Message "TRIM operation critical error for drive $($DriveInfo.DriveLetter): $($_.Exception.Message)" -Level ERROR
        return $Result
    }
}

<#
.SYNOPSIS
    HDD defragmentation operation with fragmentation analysis and timeout protection.

.DESCRIPTION
    Performs intelligent defragmentation on HDD drives with fragmentation threshold
    analysis, timeout protection, and comprehensive progress monitoring.

.PARAMETER DriveInfo
    HDD drive information with fragmentation data

.OUTPUTS
    [hashtable] Defragmentation operation result with performance metrics

.NOTES
    Performance: Only defragments drives with >10% fragmentation
    Enterprise: Extended timeouts for large enterprise storage systems
#>
function Invoke-DefragmentationOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, HelpMessage="HDD drive information")]
        [hashtable]$DriveInfo
    )

    $Result = @{
        Drive = $DriveInfo.DriveLetter
        Action = "Defragmentation"
        Duration = [TimeSpan]::Zero
        Success = $false
        Details = ""
        Reason = ""
    }

    try {
        Write-MaintenanceLog -Message "Analyzing fragmentation on HDD drive $($DriveInfo.DriveLetter)" -Level PROGRESS

        # Get WhatIf and FastMode from parent scope
        $WhatIfEnabled = if (Get-Variable -Name 'WhatIf' -Scope 1 -ErrorAction SilentlyContinue) {
            (Get-Variable -Name 'WhatIf' -Scope 1).Value
        } elseif (Get-Variable -Name 'WhatIf' -Scope Global -ErrorAction SilentlyContinue) {
            $Global:WhatIf
        } else { $false }

        $FastModeEnabled = if (Get-Variable -Name 'FastMode' -Scope 1 -ErrorAction SilentlyContinue) {
            (Get-Variable -Name 'FastMode' -Scope 1).Value
        } elseif (Get-Variable -Name 'FastMode' -Scope Global -ErrorAction SilentlyContinue) {
            $Global:FastMode
        } else { $false }

        if (!$WhatIfEnabled) {
            # Comprehensive fragmentation analysis
            $FragAnalysis = Optimize-Volume -DriveLetter $DriveInfo.DriveLetter.TrimEnd(':') -Analyze -ErrorAction Stop

            if ($null -ne $FragAnalysis -and $FragAnalysis.PercentFragmented -gt 10) {
                Write-MaintenanceLog -Message "Drive $($DriveInfo.DriveLetter) is $($FragAnalysis.PercentFragmented)% fragmented - performing defragmentation" -Level INFO

                $DefragStartTime = Get-Date

                # Enterprise defragmentation with extended timeout support
                $DefragJob = Start-Job -ScriptBlock {
                    param($DriveLetter)
                    try {
                        Optimize-Volume -DriveLetter $DriveLetter -Defrag -ErrorAction Stop
                        return @{ Success = $true; Error = $null }
                    }
                    catch {
                        return @{ Success = $false; Error = $_.Exception.Message }
                    }
                } -ArgumentList $DriveInfo.DriveLetter.TrimEnd(':')

                # Extended timeout for defragmentation operations
                $TimeoutSeconds = if ($FastModeEnabled) { 1800 } else { 3600 }  # 30 or 60 minutes
                $Completed = Wait-Job -Job $DefragJob -Timeout $TimeoutSeconds

                if ($Completed) {
                    $JobResult = Receive-Job -Job $DefragJob
                    $DefragDuration = (Get-Date) - $DefragStartTime

                    if ($JobResult.Success) {
                        $Result.Duration = $DefragDuration
                        $Result.Success = $true
                        $Result.Details = "Defragmentation completed in $([math]::Round($DefragDuration.TotalMinutes, 1)) minutes (was $($FragAnalysis.PercentFragmented)% fragmented)"

                        Write-MaintenanceLog -Message $Result.Details -Level SUCCESS
                    }
                    else {
                        $Result.Success = $false
                        $Result.Reason = "Defragmentation failed: $($JobResult.Error)"
                        $Result.Duration = $DefragDuration
                        Write-MaintenanceLog -Message $Result.Reason -Level ERROR
                    }
                }
                else {
                    # Timeout handling with graceful termination
                    try {
                        Stop-Job -Job $DefragJob -ErrorAction SilentlyContinue
                    }
                    catch {
                        Write-MaintenanceLog -Message "Warning: Could not stop defrag job gracefully" -Level WARNING
                    }

                    $Result.Success = $false
                    $Result.Reason = "Defragmentation timed out after $([math]::Round($TimeoutSeconds/60, 1)) minutes"
                    $Result.Duration = (Get-Date) - $DefragStartTime
                    Write-MaintenanceLog -Message $Result.Reason -Level WARNING
                }

                # Job cleanup with error handling
                try {
                    Remove-Job -Job $DefragJob -ErrorAction SilentlyContinue
                }
                catch {
                    Write-MaintenanceLog -Message "Warning: Could not remove defrag job" -Level WARNING
                }
            }
            else {
                # Below threshold - no defragmentation needed
                $FragLevel = if ($null -ne $FragAnalysis) { "$($FragAnalysis.PercentFragmented)%" } else { "Unknown" }
                $Result.Action = "Analysis Only"
                $Result.Success = $true
                $Result.Details = "Drive fragmentation ($FragLevel) below threshold (10%) - defragmentation not needed"
                $Result.Reason = "Low fragmentation"

                Write-MaintenanceLog -Message $Result.Details -Level INFO
            }
        }
        else {
            $Result.Action = "Defragmentation (Simulated)"
            $Result.Success = $true
            $Result.Details = "WHATIF: Would analyze and potentially defragment drive"
        }

        return $Result
    }
    catch {
        $Result.Success = $false
        $Result.Reason = "Defragmentation failed: $($_.Exception.Message)"
        Write-MaintenanceLog -Message "Defragmentation error for drive $($DriveInfo.DriveLetter): $($_.Exception.Message)" -Level ERROR
        return $Result
    }
}

<#
.SYNOPSIS
    Generates comprehensive disk optimization report with enterprise-grade details.

.DESCRIPTION
    Creates detailed optimization reports including drive analysis results,
    optimization outcomes, performance metrics, and enterprise recommendations.

.PARAMETER DriveResults
    Array of drive optimization results

.PARAMETER OptimizedCount
    Number of successfully optimized drives

.PARAMETER SkippedCount
    Number of drives skipped during optimization

.OUTPUTS
    [string] Path to generated optimization report

.NOTES
    Enterprise: Comprehensive reporting for audit and compliance requirements
#>
function New-OptimizationReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [array]$DriveResults,

        [Parameter(Mandatory=$true)]
        [int]$OptimizedCount,

        [Parameter(Mandatory=$true)]
        [int]$SkippedCount
    )

    # Get Config, FastMode, and SkipExternalDrives from parent scope
    $Config = if (Get-Variable -Name 'Config' -Scope 1 -ErrorAction SilentlyContinue) {
        (Get-Variable -Name 'Config' -Scope 1).Value
    } elseif (Get-Variable -Name 'Config' -Scope Global -ErrorAction SilentlyContinue) {
        $Global:Config
    } else {
        @{ ReportsPath = "$env:TEMP\Reports" }
    }

    $FastModeEnabled = if (Get-Variable -Name 'FastMode' -Scope 1 -ErrorAction SilentlyContinue) {
        (Get-Variable -Name 'FastMode' -Scope 1).Value
    } elseif (Get-Variable -Name 'FastMode' -Scope Global -ErrorAction SilentlyContinue) {
        $Global:FastMode
    } else { $false }

    $SkipExternalDrivesEnabled = if (Get-Variable -Name 'SkipExternalDrives' -Scope 1 -ErrorAction SilentlyContinue) {
        (Get-Variable -Name 'SkipExternalDrives' -Scope 1).Value
    } elseif (Get-Variable -Name 'SkipExternalDrives' -Scope Global -ErrorAction SilentlyContinue) {
        $Global:SkipExternalDrives
    } else { $false }

    # Ensure reports directory exists
    if (-not (Test-Path $Config.ReportsPath)) {
        New-Item -Path $Config.ReportsPath -ItemType Directory -Force | Out-Null
    }

    $ReportFile = "$($Config.ReportsPath)\disk_optimization_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

    $ReportContent = @"
DISK OPTIMIZATION REPORT v4.0.0
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
===========================================

OPTIMIZATION SUMMARY:
Total Drives Processed: $($DriveResults.Count)
Successfully Optimized: $OptimizedCount
Skipped Drives: $SkippedCount
Fast Mode: $FastModeEnabled
Skip External Drives: $SkipExternalDrivesEnabled

DETAILED RESULTS:
$($DriveResults | ForEach-Object {
    if ($_.Success) {
        "$($_.Drive): $($_.Action) - $($_.Details) $(if ($_.Reason) { "($($_.Reason))" })"
    } else {
        "$($_.Drive): FAILED - $($_.Reason)"
    }
} | Out-String)

RECOMMENDATIONS:
$(if ($SkippedCount -gt 0) { "- $SkippedCount drives were skipped (Linux partitions, external drives, or hardware limitations)" })
$(if ($OptimizedCount -eq 0) { "- No drives required optimization at this time" })
- Regular disk optimization maintains system performance
- SSD TRIM operations should be performed monthly
- HDD defragmentation should be performed when fragmentation exceeds 10%
- Consider enabling Windows automatic maintenance for regular optimization

TROUBLESHOOTING:
- If TRIM operations fail, verify SSD firmware supports TRIM
- External drives may have limited optimization support
- Linux partitions are automatically skipped for safety
- Hardware limitations may prevent certain optimization operations

===========================================
"@

    $ReportContent | Out-File -FilePath $ReportFile

    Write-MaintenanceLog -Message "Optimization report saved: $ReportFile" -Level SUCCESS

    return $ReportFile
}

# Export public functions
Export-ModuleMember -Function @(
    'Invoke-DiskMaintenance',
    'Invoke-WindowsDiskCleanup',
    'Clear-DiskCleanupStateFlags',
    'Invoke-DiskCleanupSageCommand',
    'Invoke-EmergencyDiskCleanup',
    'Invoke-DriveOptimization',
    'Invoke-TrimOperation',
    'Invoke-DefragmentationOperation',
    'New-OptimizationReport'
)
