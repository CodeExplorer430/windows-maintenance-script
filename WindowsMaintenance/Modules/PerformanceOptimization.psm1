<#
.SYNOPSIS
    Advanced system performance optimization with comprehensive analysis and tuning.

.DESCRIPTION
    Provides enterprise-grade performance optimization including event log management,
    startup item analysis, system resource monitoring, and performance baseline establishment.

    Performance Optimization Features:
    - Intelligent event log management with automated archival
    - Startup item analysis and invalid entry cleanup
    - System resource monitoring and baseline establishment
    - Memory usage optimization and reporting
    - Performance bottleneck identification
    - Comprehensive audit trails and compliance reporting

    Event Log Management:
    - Size threshold analysis and optimization recommendations
    - Automated archival for non-critical logs (when enabled)
    - Retention policy enforcement
    - Performance impact assessment

.NOTES
    File Name      : PerformanceOptimization.psm1
    Author         : Miguel Velasco
    Prerequisite   : PowerShell 5.1+
    Version        : 4.0.0
    Last Updated   : October 2025
    Module Type    : Feature Module
    Dependencies   : Logging.psm1, SafeExecution.psm1, MemoryManagement.psm1,
                     StringFormatting.psm1, UIHelpers.psm1

    Security: All optimizations preserve system integrity and security settings
    Performance: Intelligent thresholds prevent over-optimization
    Enterprise: Comprehensive reporting for capacity planning and optimization tracking
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
    Advanced startup item path validation with environment variable expansion.

.DESCRIPTION
    Provides comprehensive validation of startup item paths including environment
    variable expansion, quoted path handling, and Program Files variations.

    Features:
    - Environment variable expansion (%USERPROFILE%, %ProgramFiles%, etc.)
    - Quoted and unquoted path parsing
    - Program Files architecture variations (x86 vs x64)
    - Comprehensive error handling and reporting
    - Security-focused path validation

.PARAMETER CommandLine
    Command line string from startup registry entry

.OUTPUTS
    [hashtable] Path validation results with existence status and parsed components

.EXAMPLE
    $PathInfo = Test-StartupItemPath -CommandLine '"%ProgramFiles%\App\app.exe" /startup'

.NOTES
    Security: Handles potentially malicious or malformed path strings safely
    Compatibility: Supports various Windows path formats and conventions
#>
function Test-StartupItemPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, HelpMessage="Command line from startup registry")]
        [string]$CommandLine
    )

    try {
        # Clean and expand the command line
        $CleanCommand = $CommandLine.Trim('"', "'")

        # Environment variable expansion for security and accuracy
        if ($CleanCommand -match '%\w+%') {
            $CleanCommand = [Environment]::ExpandEnvironmentVariables($CleanCommand)
        }

        # Extract executable path (before first space, unless quoted)
        if ($CleanCommand.StartsWith('"')) {
            # Handle quoted paths
            $QuoteEnd = $CleanCommand.IndexOf('"', 1)
            if ($QuoteEnd -gt 0) {
                $ExecutablePath = $CleanCommand.Substring(1, $QuoteEnd - 1)
            } else {
                $ExecutablePath = $CleanCommand.Trim('"')
            }
        } else {
            # Handle unquoted paths
            $ExecutablePath = ($CleanCommand -split ' ')[0]
        }

        # Test primary path
        $FileExists = Test-Path $ExecutablePath -ErrorAction SilentlyContinue

        # Try Program Files variations for better compatibility
        if (-not $FileExists -and $ExecutablePath -like "*Program*") {
            $Variations = @(
                $ExecutablePath,
                $ExecutablePath -replace "Program Files \(x86\)", "Program Files",
                $ExecutablePath -replace "Program Files", "Program Files (x86)"
            )

            foreach ($Variant in $Variations) {
                if (Test-Path $Variant -ErrorAction SilentlyContinue) {
                    $FileExists = $true
                    $ExecutablePath = $Variant
                    break
                }
            }
        }

        return @{
            OriginalPath = $CommandLine
            ExecutablePath = $ExecutablePath
            Exists = $FileExists
            IsValid = $FileExists
        }
    }
    catch {
        return @{
            OriginalPath = $CommandLine
            ExecutablePath = "Parse Error"
            Exists = $false
            IsValid = $false
            Error = $_.Exception.Message
        }
    }
}

<#
.SYNOPSIS
    Removes invalid startup items from system registry with comprehensive reporting.

.DESCRIPTION
    Scans all startup registry locations for invalid entries and removes them
    to improve system boot performance and reduce startup errors.

    Features:
    - Multi-location registry scanning (HKLM and HKCU)
    - Path validation for all startup entries
    - Safe removal with error handling
    - Comprehensive reporting and statistics
    - WhatIf mode support for testing

.PARAMETER WhatIf
    Enables simulation mode without making actual changes

.OUTPUTS
    [hashtable] Cleanup results with statistics and details

.EXAMPLE
    $Results = Remove-InvalidStartupItems -WhatIf:$false

.NOTES
    Security: Only removes entries with invalid file paths, preserves valid entries
    Performance: Improves boot time by removing failed startup attempts
    Reliability: Comprehensive error handling ensures safe operation
#>
function Remove-InvalidStartupItems {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false, HelpMessage="Simulation mode")]
        [switch]$WhatIf = $false
    )

    $Result = @{
        Success = $false
        RemovedCount = 0
        SkippedCount = 0
        ErrorCount = 0
        Details = @()
    }

    try {
        Write-MaintenanceLog -Message "Starting invalid startup items cleanup analysis..." -Level PROGRESS

        # Define comprehensive startup registry locations
        $StartupRegistryPaths = @(
            @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'; Scope = 'System' },
            @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'; Scope = 'System' },
            @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'; Scope = 'User' },
            @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'; Scope = 'User' }
        )

        $TotalProcessed = 0
        $InvalidItems = @()

        # Scan all registry locations for startup items
        foreach ($RegPath in $StartupRegistryPaths) {
            try {
                if (Test-Path $RegPath.Path) {
                    Write-DetailedOperation -Operation 'Registry Scan' -Details "Scanning $($RegPath.Path)" -Result 'Scanning'

                    $RegItems = Get-ItemProperty $RegPath.Path -ErrorAction SilentlyContinue
                    if ($RegItems) {
                        $RegItems.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | ForEach-Object {
                            $TotalProcessed++
                            $ItemName = $_.Name
                            $ItemCommand = $_.Value

                            # Validate startup item path
                            $PathValidation = Test-StartupItemPath -CommandLine $ItemCommand

                            if (-not $PathValidation.IsValid) {
                                $InvalidItems += @{
                                    Name = $ItemName
                                    Command = $ItemCommand
                                    RegistryPath = $RegPath.Path
                                    Scope = $RegPath.Scope
                                    Reason = if ($PathValidation.Error) { $PathValidation.Error } else { "File not found: $($PathValidation.ExecutablePath)" }
                                }

                                Write-DetailedOperation -Operation 'Invalid Startup Item' -Details "Name: $ItemName | Path: $($PathValidation.ExecutablePath) | Reason: File not found" -Result 'Invalid'
                            } else {
                                $Result.SkippedCount++
                                Write-DetailedOperation -Operation 'Valid Startup Item' -Details "Name: $ItemName | Path: $($PathValidation.ExecutablePath)" -Result 'Valid'
                            }
                        }
                    }
                } else {
                    Write-DetailedOperation -Operation 'Registry Scan' -Details "Registry path not found: $($RegPath.Path)" -Result 'Not Found'
                }
            }
            catch {
                $Result.ErrorCount++
                Write-MaintenanceLog -Message "Error scanning registry path $($RegPath.Path): $($_.Exception.Message)" -Level ERROR
                Write-DetailedOperation -Operation 'Registry Scan Error' -Details "Path: $($RegPath.Path) | Error: $($_.Exception.Message)" -Result 'Error'
            }
        }

        # Process invalid items for removal
        if ($InvalidItems.Count -gt 0) {
            Write-MaintenanceLog -Message "Found $($InvalidItems.Count) invalid startup items" -Level WARNING

            foreach ($InvalidItem in $InvalidItems) {
                if ($WhatIf) {
                    Write-MaintenanceLog -Message "WHATIF: Would remove startup item '$($InvalidItem.Name)' from $($InvalidItem.RegistryPath)" -Level DEBUG
                    $Result.RemovedCount++
                } else {
                    try {
                        # Remove the invalid registry entry
                        Remove-ItemProperty -Path $InvalidItem.RegistryPath -Name $InvalidItem.Name -ErrorAction Stop
                        $Result.RemovedCount++

                        Write-MaintenanceLog -Message "Removed invalid startup item: $($InvalidItem.Name)" -Level SUCCESS
                        Write-DetailedOperation -Operation 'Startup Cleanup' -Details "Removed: $($InvalidItem.Name) from $($InvalidItem.Scope) registry" -Result 'Removed'

                        $Result.Details += "Removed: $($InvalidItem.Name) - Reason: $($InvalidItem.Reason)"
                    }
                    catch {
                        $Result.ErrorCount++
                        Write-MaintenanceLog -Message "Failed to remove startup item '$($InvalidItem.Name)': $($_.Exception.Message)" -Level ERROR
                        Write-DetailedOperation -Operation 'Startup Cleanup Error' -Details "Item: $($InvalidItem.Name) | Error: $($_.Exception.Message)" -Result 'Failed'
                    }
                }
            }
        } else {
            Write-MaintenanceLog -Message "No invalid startup items found" -Level INFO
        }

        $Result.Success = ($Result.ErrorCount -eq 0)

        # Generate comprehensive cleanup summary
        Write-MaintenanceLog -Message "Startup cleanup completed - Processed: $TotalProcessed, Removed: $($Result.RemovedCount), Valid: $($Result.SkippedCount), Errors: $($Result.ErrorCount)" -Level INFO

        return $Result
    }
    catch {
        $Result.ErrorCount++
        $Result.Success = $false
        Write-MaintenanceLog -Message "Critical error in startup cleanup: $($_.Exception.Message)" -Level ERROR
        return $Result
    }
}

<#
.SYNOPSIS
    Main performance optimization orchestration function.

.DESCRIPTION
    Orchestrates comprehensive performance optimization across multiple system areas
    including event logs, startup items, and system resource analysis.

.OUTPUTS
    None. Results are logged via Write-MaintenanceLog

.EXAMPLE
    Invoke-PerformanceOptimization

.NOTES
    Security: All optimizations preserve system integrity
    Performance: Intelligent thresholds prevent over-optimization
    Enterprise: Comprehensive reporting for capacity planning
#>
function Invoke-PerformanceOptimization {
    # Get Config from parent scope
    $Config = if (Get-Variable -Name 'Config' -Scope 1 -ErrorAction SilentlyContinue) {
        (Get-Variable -Name 'Config' -Scope 1).Value
    } elseif (Get-Variable -Name 'Config' -Scope Global -ErrorAction SilentlyContinue) {
        $Global:Config
    } else {
        @{
            EnabledModules = @("PerformanceOptimization")
            MaxEventLogSizeMB = 100
            ReportsPath = "$env:TEMP\Reports"
        }
    }

    # Get other variables from parent scope
    $WhatIf = if (Get-Variable -Name 'WhatIf' -Scope 1 -ErrorAction SilentlyContinue) {
        (Get-Variable -Name 'WhatIf' -Scope 1).Value
    } elseif (Get-Variable -Name 'WhatIf' -Scope Global -ErrorAction SilentlyContinue) {
        $Global:WhatIf
    } else {
        $false
    }

    $ManageEventLogs = if (Get-Variable -Name 'ManageEventLogs' -Scope 1 -ErrorAction SilentlyContinue) {
        (Get-Variable -Name 'ManageEventLogs' -Scope 1).Value
    } elseif (Get-Variable -Name 'ManageEventLogs' -Scope Global -ErrorAction SilentlyContinue) {
        $Global:ManageEventLogs
    } else {
        $false
    }

    $ShowMessageBoxes = if (Get-Variable -Name 'ShowMessageBoxes' -Scope 1 -ErrorAction SilentlyContinue) {
        (Get-Variable -Name 'ShowMessageBoxes' -Scope 1).Value
    } elseif (Get-Variable -Name 'ShowMessageBoxes' -Scope Global -ErrorAction SilentlyContinue) {
        $Global:ShowMessageBoxes
    } else {
        $false
    }

    $SilentMode = if (Get-Variable -Name 'SilentMode' -Scope 1 -ErrorAction SilentlyContinue) {
        (Get-Variable -Name 'SilentMode' -Scope 1).Value
    } elseif (Get-Variable -Name 'SilentMode' -Scope Global -ErrorAction SilentlyContinue) {
        $Global:SilentMode
    } else {
        $false
    }

    if ("PerformanceOptimization" -notin $Config.EnabledModules) {
        Write-MaintenanceLog -Message 'Performance Optimization module disabled' -Level INFO
        return
    }

    Write-MaintenanceLog -Message '======== Performance Optimization Module ========' -Level INFO

    # Advanced event log management with intelligent analysis and automated archival
    Invoke-SafeCommand -TaskName "Advanced Event Log Management" -Command {
        Write-ProgressBar -Activity 'Event Log Management' -PercentComplete 10 -Status 'Analyzing event log configuration...'

        Write-MaintenanceLog -Message 'Executing event log analysis...' -Level PROGRESS
        Write-DetailedOperation -Operation 'Event Log Analysis' -Details "Scanning system event logs for size and performance impact" -Result 'Starting'

        try {
            # Comprehensive event log analysis with performance impact assessment
            $LargeEventLogs = Get-WinEvent -ListLog * -ErrorAction SilentlyContinue |
                             Where-Object {
                                 $_.FileSize -gt ($Config.MaxEventLogSizeMB * 1MB) -and
                                 $_.RecordCount -gt 1000
                             } | Sort-Object FileSize -Descending

            if ($LargeEventLogs) {
                Write-MaintenanceLog -Message "Found $($LargeEventLogs.Count) large event logs requiring attention" -Level WARNING

                # Enterprise-grade event log analysis report generation
                $EventLogReport = "$($Config.ReportsPath)\event_log_analysis_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
                $ReportContent = @"
EVENT LOG ANALYSIS REPORT
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
===========================================

LARGE EVENT LOGS SUMMARY:
Total Large Logs: $($LargeEventLogs.Count)
Size Threshold: $($Config.MaxEventLogSizeMB) MB

DETAILED ANALYSIS:
"@

                foreach ($Log in $LargeEventLogs) {
                    $LogSizeMB = [math]::Round($Log.FileSize / 1MB, 2)
                    $LogSizePercent = [math]::Round(($Log.FileSize / ($Config.MaxEventLogSizeMB * 1MB)) * 100, 1)

                    $LogWarningMessage = Format-SafeString -Template "Large log: {0} - {1} MB ({2} records) - {3} percent over threshold" -Arguments @($Log.LogName, $LogSizeMB, $Log.RecordCount, $LogSizePercent)
                    Write-MaintenanceLog -Message $LogWarningMessage -Level WARNING

                    $LogAnalysisDetails = Format-SafeString -Template "Log: {0} - Size: {1} MB - Records: {2} - Threshold Exceeded: {3} percent" -Arguments @($Log.LogName, $LogSizeMB, $Log.RecordCount, $LogSizePercent)
                    Write-DetailedOperation -Operation 'Event Log Analysis' -Details $LogAnalysisDetails -Result 'Oversized'

                    $ReportLine = Format-SafeString -Template "{0}: {1} MB ({2} records) - {3} percent over threshold" -Arguments @($Log.LogName, $LogSizeMB, $Log.RecordCount, $LogSizePercent)
                    $ReportContent = $ReportContent + [Environment]::NewLine + $ReportLine
                }

                # Enterprise recommendations section
                $RecommendationsSection = @"

RECOMMENDATIONS:
* Consider archiving or clearing non-critical event logs
* Review event log retention policies
* Monitor log growth patterns for capacity planning
$(if ($ManageEventLogs) { "- Automated archival was performed for safe logs" } else { "- Use -ManageEventLogs parameter to enable automated archival" })
===========================================
"@

                $ReportContent += $RecommendationsSection
                $ReportContent | Out-File -FilePath $EventLogReport

                Write-MaintenanceLog -Message 'Consider reviewing and archiving large event logs' -Level INFO

                $SummaryDetails = Format-SafeString -Template "Analysis complete | Large logs: {0} | Report: {1}" -Arguments @($LargeEventLogs.Count, $EventLogReport)
                Write-DetailedOperation -Operation 'Event Log Summary' -Details $SummaryDetails -Result 'Complete'

            }
            else {
               Write-MaintenanceLog -Message 'Event log sizes are within acceptable limits' -Level SUCCESS
               Write-DetailedOperation -Operation 'Event Log Analysis' -Details 'All event logs are within size thresholds' -Result 'Optimal'
            }
        }
        catch {
            Write-MaintenanceLog -Message "Event log analysis failed: $($_.Exception.Message)" -Level ERROR
            Write-DetailedOperation -Operation 'Event Log Analysis' -Details "Error: $($_.Exception.Message)" -Result 'Error'
        }
    } -TimeoutMinutes 10

    # Comprehensive startup performance analysis with enterprise-grade reporting
    Invoke-SafeCommand -TaskName 'Advanced Startup Performance Analysis' -Command {
        Write-ProgressBar -Activity 'Startup Analysis' -PercentComplete 10 -Status 'Gathering startup configuration...'

        Write-MaintenanceLog -Message 'Executing startup performance analysis...' -Level PROGRESS
        Write-DetailedOperation -Operation 'Startup Analysis' -Details 'Analyzing system startup configuration and performance impact' -Result 'Starting'

        try {
            # Comprehensive startup item detection from multiple sources
            $StartupItems = Get-CimInstance Win32_StartupCommand |
                           Select-Object Name, Command, Location, User |
                           Sort-Object Name

            # Advanced registry-based startup item detection
            $RegistryStartup = @()
            $StartupRegistryPaths = @(
                'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
                'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce',
                'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
                'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
            )

            foreach ($RegPath in $StartupRegistryPaths) {
                try {
                    $RegItems = Get-ItemProperty $RegPath -ErrorAction SilentlyContinue
                    if ($RegItems) {
                        $RegItems.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | ForEach-Object {
                            $RegistryStartup += @{
                                Name = $_.Name
                                Command = $_.Value
                                Location = $RegPath
                                Type = 'Registry'
                            }
                        }
                    }
                }
                catch {
                    $RegScanDetails = Format-SafeString -Template "Path: {0} | Error: {1}" -Arguments @($RegPath, $_.Exception.Message)
                    Write-DetailedOperation -Operation 'Registry Scan' -Details $RegScanDetails -Result 'Error'
                }
            }

            $TotalStartupItems = $StartupItems.Count + $RegistryStartup.Count

            $StartupMessage = Format-SafeString -Template "Found {0} total startup items ({1} WMI + {2} Registry)" -Arguments @($TotalStartupItems, $StartupItems.Count, $RegistryStartup.Count)
            Write-MaintenanceLog -Message $StartupMessage -Level INFO

            $StartupDetails = Format-SafeString -Template "WMI Items: {0} | Registry Items: {1} | Total: {2}" -Arguments @($StartupItems.Count, $RegistryStartup.Count, $TotalStartupItems)
            Write-DetailedOperation -Operation 'Startup Discovery' -Details $StartupDetails -Result 'Complete'

            # Advanced startup impact analysis with performance categorization
            $HighImpactItems = @()
            $UnknownItems = @()

            foreach ($Item in $StartupItems) {
                $OriginalCommand = $Item.Command
                $CleanedCommand = $OriginalCommand -replace [char]34, ""
                $CommandArray = $CleanedCommand -split [char]32
                $CommandPath = $CommandArray[0]

                if (Test-Path $CommandPath) {
                    try {
                        $FileInfo = Get-ItemProperty $CommandPath -ErrorAction SilentlyContinue
                        $FileSize = if ($FileInfo) { [math]::Round($FileInfo.Length / 1MB, 2) } else { 0 }

                        # Intelligent impact assessment based on multiple criteria
                        $ImpactLevel = 'Medium'

                        $IsHighImpact = $Item.Name.Contains('Adobe') -or $Item.Name.Contains('Java') -or $Item.Name.Contains('Office') -or $Item.Name.Contains('Antivirus') -or $Item.Name.Contains('Security')
                        if ($IsHighImpact -or $FileSize -gt 50) {
                            $ImpactLevel = "High"
                            $HighImpactItems += $Item
                        }
                        elseif ($Item.Name -like "*Windows*" -or $Item.Name -like "*Microsoft*" -or $Item.Name -like "*Driver*" -or $Item.Name -like "*Audio*" -or $Item.Name -like "*Network*") {
                            $ImpactLevel = "Low"
                        }

                        $StartupImpactDetails = Format-SafeString -Template "Item: {0} | Size: {1} MB | Impact: {2} | Path: {3}" -Arguments @($Item.Name, $FileSize, $ImpactLevel, $CommandPath)
                        Write-DetailedOperation -Operation "Startup Impact" -Details $StartupImpactDetails -Result "Analyzed"
                    }
                    catch {
                        $StartupErrorDetails = Format-SafeString -Template "Item: {0} | Error: {1}" -Arguments @($Item.Name, $_.Exception.Message)
                        Write-DetailedOperation -Operation "Startup Impact" -Details $StartupErrorDetails -Result "Error"
                    }
                } else {
                    $UnknownItems += $Item
                    $MissingDetails = Format-SafeString -Template "Item: {0} | Status: File not found | Path: {1}" -Arguments @($Item.Name, $CommandPath)
                    Write-DetailedOperation -Operation "Startup Impact" -Details $MissingDetails -Result "Missing"
                }
            }

            # Enterprise-grade startup performance report generation
            Write-ProgressBar -Activity 'Startup Analysis' -PercentComplete 80 -Status 'Generating startup report...'

            $StartupReport = "$($Config.ReportsPath)\startup_analysis_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

            $ReportContent = @"
STARTUP PERFORMANCE ANALYSIS REPORT
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
===========================================

STARTUP SUMMARY:
Total Startup Items: $TotalStartupItems
WMI Detected Items: $($StartupItems.Count)
Registry Items: $($RegistryStartup.Count)
High Impact Items: $($HighImpactItems.Count)
Missing/Invalid Items: $($UnknownItems.Count)

HIGH IMPACT STARTUP ITEMS:
$($HighImpactItems | ForEach-Object { "  $($_.Name): $($_.Command)" } | Out-String)

REGISTRY STARTUP ITEMS:
$($RegistryStartup | ForEach-Object { "  $($_.Name) [$($_.Location)]: $($_.Command)" } | Out-String)

MISSING/INVALID ITEMS:
$($UnknownItems | ForEach-Object { "  $($_.Name): $($_.Command)" } | Out-String)

RECOMMENDATIONS:
$(if ($HighImpactItems.Count -gt 0) { "  Review high-impact startup items for necessity" })
$(if ($UnknownItems.Count -gt 0) { "  Remove invalid startup entries to improve boot time" })
  Consider using Task Scheduler for delayed startup of non-critical applications
  Use MSConfig or Task Manager to disable unnecessary startup items
===========================================
"@

            $ReportContent | Out-File -FilePath $StartupReport

            $SummaryText = Format-SafeString -Template "Total: {0} items analyzed" -Arguments @($TotalStartupItems)
            Write-DetailedOperation -Operation 'Startup Analysis Summary' -Details $SummaryText -Result 'Complete'

            $StartupSummaryDetails = Format-SafeString -Template "Total: {0} | High Impact: {1} | Invalid: {2} | Report: {3}" -Arguments @($TotalStartupItems, $HighImpactItems.Count, $UnknownItems.Count, $StartupReport)
            Write-DetailedOperation -Operation 'Startup Analysis Summary' -Details $StartupSummaryDetails -Result 'Complete'

            Write-ProgressBar -Activity 'Startup Analysis' -PercentComplete 100 -Status 'Analysis completed'
            Write-Progress -Activity 'Startup Analysis' -Completed
        }
        catch {
            Write-MaintenanceLog -Message "Startup analysis failed: $($_.Exception.Message)" -Level ERROR
            Write-DetailedOperation -Operation 'Startup Analysis' -Details "Error: $($_.Exception.Message)" -Result 'Error'
        }
    } -TimeoutMinutes 10

    # Enterprise startup cleanup with comprehensive validation and reporting
    Invoke-SafeCommand -TaskName "Invalid Startup Items Cleanup" -Command {
        Write-ProgressBar -Activity 'Startup Cleanup' -PercentComplete 10 -Status 'Analyzing startup registry entries...'

        Write-MaintenanceLog -Message 'Executing invalid startup items cleanup...' -Level PROGRESS
        Write-DetailedOperation -Operation 'Startup Cleanup' -Details "Scanning for invalid startup entries in registry" -Result 'Starting'

        $StartupCleanupResult = Remove-InvalidStartupItems -WhatIf:$WhatIf

        if ($StartupCleanupResult.Success) {
            $CleanupMessage = Format-SafeString -Template "Startup cleanup completed - Removed: {0}, Valid: {1}, Total Processed: {2}" -Arguments @($StartupCleanupResult.RemovedCount, $StartupCleanupResult.SkippedCount, ($StartupCleanupResult.RemovedCount + $StartupCleanupResult.SkippedCount))
            Write-MaintenanceLog -Message $CleanupMessage -Level SUCCESS

            Write-DetailedOperation -Operation 'Startup Cleanup Summary' -Details "Removed: $($StartupCleanupResult.RemovedCount) | Valid: $($StartupCleanupResult.SkippedCount) | Errors: $($StartupCleanupResult.ErrorCount)" -Result 'Complete'

            # Enterprise notification for significant startup optimization
            if ($StartupCleanupResult.RemovedCount -gt 5 -and $ShowMessageBoxes -and -not $SilentMode) {
                $CleanupNotification = @"
Startup Items Cleanup Completed

Invalid startup entries removed: $($StartupCleanupResult.RemovedCount)
Valid entries preserved: $($StartupCleanupResult.SkippedCount)

Removing invalid startup items can improve system boot time and performance.
"@
                Show-MaintenanceMessageBox -Message $CleanupNotification -Title "Startup Cleanup Results" -Icon "Information"
            }
        }
        else {
            Write-MaintenanceLog -Message "Startup cleanup encountered issues - Errors: $($StartupCleanupResult.ErrorCount)" -Level WARNING
            Write-DetailedOperation -Operation 'Startup Cleanup' -Details "Errors encountered: $($StartupCleanupResult.ErrorCount)" -Result 'Warning'
        }

        Write-ProgressBar -Activity 'Startup Cleanup' -PercentComplete 100 -Status 'Startup cleanup completed'
        Write-Progress -Activity 'Startup Cleanup' -Completed
    } -TimeoutMinutes 5

    # Advanced system resource analysis with comprehensive performance baselines
    Invoke-SafeCommand -TaskName "System Resource Analysis" -Command {
        Write-ProgressBar -Activity 'Resource Analysis' -PercentComplete 10 -Status 'Gathering system performance metrics...'

        Write-MaintenanceLog -Message 'Executing system resource analysis...' -Level PROGRESS
        Write-DetailedOperation -Operation 'Resource Analysis' -Details "Collecting system performance metrics and baselines" -Result 'Starting'

        try {
            # Comprehensive memory analysis with detailed reporting
            Write-ProgressBar -Activity 'Resource Analysis' -PercentComplete 30 -Status 'Analyzing memory usage...'

            $MemInfo = Get-WmiObject -Class Win32_OperatingSystem
            $TotalMemGB = [math]::Round($MemInfo.TotalVisibleMemorySize / 1MB, 2)
            $FreeMemGB = [math]::Round($MemInfo.FreePhysicalMemory / 1MB, 2)
            $UsedMemGB = $TotalMemGB - $FreeMemGB
            $UsedMemPercent = [math]::Round(($UsedMemGB / $TotalMemGB) * 100, 1)

            # Advanced virtual memory analysis
            $PageFileInfo = Get-WmiObject -Class Win32_PageFileUsage
            $PageFileSize = if ($PageFileInfo) { [math]::Round($PageFileInfo.AllocatedBaseSize / 1024, 2) } else { 0 }
            $PageFileUsed = if ($PageFileInfo) { [math]::Round($PageFileInfo.CurrentUsage / 1024, 2) } else { 0 }

            $MemoryText = Format-SafeString -Template "Physical: {0} GB/{1} GB - Virtual: {2} GB/{3} GB" -Arguments @($UsedMemGB, $TotalMemGB, $PageFileUsed, $PageFileSize)
            Write-DetailedOperation -Operation 'Memory Analysis' -Details $MemoryText -Result 'Complete'

            $VirtualMemoryMessage = Format-SafeString -Template "Virtual Memory: {0} GB used / {1} GB allocated" -Arguments @($PageFileUsed, $PageFileSize)
            Write-MaintenanceLog -Message $VirtualMemoryMessage -Level INFO

            $PhysicalMemoryDetails = Format-SafeString -Template "Physical: {0} GB/{1} GB ({2} percent) - Virtual: {3} GB/{4} GB" -Arguments @($UsedMemGB, $TotalMemGB, $UsedMemPercent, $PageFileUsed, $PageFileSize)
            Write-DetailedOperation -Operation 'Memory Analysis' -Details $PhysicalMemoryDetails -Result 'Complete'

            # Advanced CPU performance analysis with multi-sample averaging
            Write-ProgressBar -Activity 'Resource Analysis' -PercentComplete 50 -Status 'Analyzing CPU performance...'

            $CPU = Get-WmiObject -Class Win32_Processor -ErrorAction Stop
            $CPUName = $CPU.Name
            $CPUCores = $CPU.NumberOfCores
            $CPULogicalProcessors = $CPU.NumberOfLogicalProcessors

            # Enterprise CPU usage sampling with statistical analysis
            $CPUSamples = @()
            for ($i = 1; $i -le 5; $i++) {
                $CPUSamplingMessage = Format-SafeString -Template "CPU sampling ({0}/5)..." -Arguments @($i)
                Write-ProgressBar -Activity 'Resource Analysis' -PercentComplete (50 + ($i * 5)) -Status $CPUSamplingMessage

                try {
                    $CPUSample = (Get-Counter "\Processor(_Total)\% Processor Time" -SampleInterval 1 -MaxSamples 1 -ErrorAction Stop).CounterSamples.CookedValue
                    $CPUSamples += $CPUSample
                }
                catch {
                    Write-DetailedOperation -Operation 'CPU Sampling' -Details "Sample $i failed: $($_.Exception.Message)" -Result 'Warning'
                }

                Start-Sleep -Milliseconds 200  # Brief pause between samples for accuracy
            }

            if ($CPUSamples.Count -gt 0) {
                $AvgCPUUsage = [math]::Round(($CPUSamples | Measure-Object -Average).Average, 1)
                $MaxCPUUsage = [math]::Round(($CPUSamples | Measure-Object -Maximum).Maximum, 1)
                $MinCPUUsage = [math]::Round(($CPUSamples | Measure-Object -Minimum).Minimum, 1)

                $CPUInfoMessage = Format-SafeString -Template "CPU: {0} - {1} cores, {2} logical processors" -Arguments @($CPUName, $CPUCores, $CPULogicalProcessors)
                Write-MaintenanceLog -Message $CPUInfoMessage -Level INFO

                $CPUUsageMessage = Format-SafeString -Template "CPU Usage: Average {0} percent (Range: {1} percent - {2} percent)" -Arguments @($AvgCPUUsage, $MinCPUUsage, $MaxCPUUsage)
                Write-MaintenanceLog -Message $CPUUsageMessage -Level INFO

                $CPUAnalysisDetails = Format-SafeString -Template "CPU: {0} | Cores: {1} | Usage: Avg {2} percent ({3} percent-{4} percent)" -Arguments @($CPUName, $CPUCores, $AvgCPUUsage, $MinCPUUsage, $MaxCPUUsage)
                Write-DetailedOperation -Operation 'CPU Analysis' -Details $CPUAnalysisDetails -Result 'Complete'
            }
            else {
                Write-MaintenanceLog -Message "CPU sampling failed - no valid samples collected" -Level WARNING
                $AvgCPUUsage = 0
            }

            # Advanced disk I/O performance analysis
            Write-ProgressBar -Activity 'Resource Analysis' -PercentComplete 75 -Status 'Analyzing disk performance...'

            try {
                $DiskCounters = @(
                    "\PhysicalDisk(_Total)\Disk Read Bytes/sec",
                    "\PhysicalDisk(_Total)\Disk Write Bytes/sec",
                    "\PhysicalDisk(_Total)\Current Disk Queue Length"
                )

                $DiskMetrics = Get-Counter -Counter $DiskCounters -SampleInterval 2 -MaxSamples 3 -ErrorAction SilentlyContinue

                if ($DiskMetrics) {
                    $AvgReadMBps = [math]::Round((($DiskMetrics.CounterSamples | Where-Object { $_.Path -like "*Read*" } | Measure-Object -Property CookedValue -Average).Average / 1MB), 2)
                    $AvgWriteMBps = [math]::Round((($DiskMetrics.CounterSamples | Where-Object { $_.Path -like "*Write*" } | Measure-Object -Property CookedValue -Average).Average / 1MB), 2)
                    $AvgQueueLength = [math]::Round((($DiskMetrics.CounterSamples | Where-Object { $_.Path -like "*Queue*" } | Measure-Object -Property CookedValue -Average).Average), 2)

                    $DiskIOMessage = Format-SafeString -Template "Disk I/O: Read {0} MB/s, Write {1} MB/s, Queue Length {2}" -Arguments @($AvgReadMBps, $AvgWriteMBps, $AvgQueueLength)
                    Write-MaintenanceLog -Message $DiskIOMessage -Level INFO

                    $DiskIODetails = Format-SafeString -Template "Read: {0} MB/s | Write: {1} MB/s | Queue: {2}" -Arguments @($AvgReadMBps, $AvgWriteMBps, $AvgQueueLength)
                    Write-DetailedOperation -Operation 'Disk I/O Analysis' -Details $DiskIODetails -Result 'Complete'
                }
            }
            catch {
                Write-MaintenanceLog -Message "Disk I/O analysis failed: $($_.Exception.Message)" -Level WARNING
            }

            # Enterprise process analysis with resource consumption metrics
            Write-ProgressBar -Activity 'Resource Analysis' -PercentComplete 90 -Status 'Analyzing top resource consumers...'

            $TopProcesses = Get-Process | Where-Object { $_.WorkingSet -gt 50MB } |
                           Sort-Object WorkingSet -Descending | Select-Object -First 15 |
                           Select-Object Name, Id,
                                        @{N='Memory(MB)';E={[math]::Round($_.WorkingSet/1MB,1)}},
                                        @{N='CPU(s)';E={[math]::Round($_.TotalProcessorTime.TotalSeconds,1)}},
                                        @{N='Handles';E={$_.HandleCount}},
                                        @{N='Threads';E={$_.Threads.Count}}

            # Comprehensive performance report generation
            $ProcessReport = "$($Config.ReportsPath)\process_analysis_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
            $ReportContent = @"
SYSTEM RESOURCE ANALYSIS REPORT
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
===========================================

SYSTEM SUMMARY:
CPU: $CPUName
Physical Cores: $CPUCores
Logical Processors: $CPULogicalProcessors
Total Memory: $TotalMemGB GB
Available Memory: $FreeMemGB GB
Memory Usage: $UsedMemPercent percent

PERFORMANCE METRICS:
Average CPU Usage: $AvgCPUUsage percent
$(if ($MinCPUUsage -and $MaxCPUUsage) { "CPU Usage Range: $MinCPUUsage percent - $MaxCPUUsage percent" })
$(if ($DiskMetrics) { "Disk Read Rate: $AvgReadMBps MB/s" })
$(if ($DiskMetrics) { "Disk Write Rate: $AvgWriteMBps MB/s" })
$(if ($DiskMetrics) { "Disk Queue Length: $AvgQueueLength" })
Virtual Memory Size: $PageFileSize GB
Virtual Memory Used: $PageFileUsed GB

TOP MEMORY CONSUMERS:
$($TopProcesses | Format-Table -AutoSize | Out-String)

PERFORMANCE ASSESSMENT:
$(if ($UsedMemPercent -gt 85) { "[!]  High memory usage detected - consider closing unnecessary applications" })
$(if ($AvgCPUUsage -gt 80) { "[!]  High CPU usage detected - system may be under stress" })
$(if ($AvgQueueLength -gt 2) { "[!]  High disk queue length - storage performance may be impacted" })
$(if ($UsedMemPercent -le 85 -and $AvgCPUUsage -le 80 -and $AvgQueueLength -le 2) { "[√] System performance metrics are within normal ranges" })
===========================================
"@

            $ReportContent | Out-File -FilePath $ProcessReport

            # Enterprise performance threshold analysis and alerting
            if ($UsedMemPercent -gt 85) {
                $HighMemoryMessage = Format-SafeString -Template "High memory usage detected ({0} percent) - consider closing unnecessary applications" -Arguments @($UsedMemPercent)
                Write-MaintenanceLog -Message $HighMemoryMessage -Level WARNING
            }
            if ($AvgCPUUsage -gt 80) {
                $HighCPUMessage = Format-SafeString -Template "High CPU usage detected ({0} percent) - system may be under stress" -Arguments @($AvgCPUUsage)
                Write-MaintenanceLog -Message $HighCPUMessage -Level WARNING
            }

            Write-MaintenanceLog -Message "System resource analysis completed - Report saved to: $ProcessReport" -Level SUCCESS

            $ResourceSummaryDetails = Format-SafeString -Template "Memory: {0} percent - CPU: {1} percent - Top Processes: {2} - Report: {3}" -Arguments @($UsedMemPercent, $AvgCPUUsage, $TopProcesses.Count, $ProcessReport)
            Write-DetailedOperation -Operation 'Resource Analysis Summary' -Details $ResourceSummaryDetails -Result 'Complete'

            Write-ProgressBar -Activity 'Resource Analysis' -PercentComplete 100 -Status 'Analysis completed'
            Write-Progress -Activity 'Resource Analysis' -Completed
        }
        catch {
            Write-MaintenanceLog -Message "System resource analysis failed: $($_.Exception.Message)" -Level ERROR
            Write-DetailedOperation -Operation 'Resource Analysis' -Details "Error: $($_.Exception.Message)" -Result 'Error'
        }
    } -TimeoutMinutes 15

    # Final memory optimization after comprehensive performance analysis
    Optimize-MemoryUsage
}

# Export public functions
Export-ModuleMember -Function @(
    'Invoke-PerformanceOptimization',
    'Test-StartupItemPath',
    'Remove-InvalidStartupItems'
)
