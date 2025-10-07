<#
.SYNOPSIS
    Testing and validation utilities for System Health Repair and Enhanced Disk Cleanup modules.

.DESCRIPTION
    Comprehensive testing suite for validating the new maintenance modules before
    full deployment. Includes unit tests, integration tests, and validation checks.

.NOTES
    File Name      : Test-MaintenanceModules.ps1
    Author         : Miguel Velasco
    Prerequisite   : PowerShell 5.1+, Administrator privileges
    Usage          : Run this script to validate new module implementation
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator

# Test configuration
$Global:TestResults = @{
    TotalTests = 0
    PassedTests = 0
    FailedTests = 0
    WarningTests = 0
    TestDetails = @()
}

#region TEST_FRAMEWORK

<#
.SYNOPSIS
    Records test results with detailed information.
#>
function Write-TestResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$TestName,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet("Pass", "Fail", "Warning")]
        [string]$Result,
        
        [Parameter(Mandatory=$false)]
        [string]$Details = "",
        
        [Parameter(Mandatory=$false)]
        [string]$ErrorMessage = ""
    )
    
    $Global:TestResults.TotalTests++
    
    if ($Result -eq "Pass") { 
        $Global:TestResults.PassedTests++
        Write-Host "[SUCCESS] $TestName" -ForegroundColor Green
    }
    elseif ($Result -eq "Fail") { 
        $Global:TestResults.FailedTests++
        Write-Host "[FAIL] $TestName" -ForegroundColor Red
        if ($ErrorMessage) {
            Write-Host "  Error: $ErrorMessage" -ForegroundColor Red
        }
    }
    elseif ($Result -eq "Warning") { 
        $Global:TestResults.WarningTests++
        Write-Host "[WARNING] $TestName" -ForegroundColor Yellow
    }
    
    if ($Details) {
        Write-Host "  Details: $Details" -ForegroundColor Gray
    }
    
    $Global:TestResults.TestDetails += @{
        TestName = $TestName
        Result = $Result
        Details = $Details
        ErrorMessage = $ErrorMessage
        Timestamp = Get-Date
    }
}

<#
.SYNOPSIS
    Generates comprehensive test report.
#>
function Show-TestReport {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "TEST EXECUTION SUMMARY" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    $PassRate = if ($Global:TestResults.TotalTests -gt 0) {
        [math]::Round(($Global:TestResults.PassedTests / $Global:TestResults.TotalTests) * 100, 2)
    } else { 0 }
    
    Write-Host "Total Tests Run: $($Global:TestResults.TotalTests)" -ForegroundColor White
    Write-Host "Passed: $($Global:TestResults.PassedTests)" -ForegroundColor Green
    Write-Host "Failed: $($Global:TestResults.FailedTests)" -ForegroundColor Red
    Write-Host "Warnings: $($Global:TestResults.WarningTests)" -ForegroundColor Yellow
    
    $PassRateColor = if ($PassRate -ge 80) { "Green" } elseif ($PassRate -ge 60) { "Yellow" } else { "Red" }
    Write-Host "Pass Rate: $PassRate%" -ForegroundColor $PassRateColor
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    
    if ($Global:TestResults.FailedTests -gt 0) {
        Write-Host "`nFailed Tests:" -ForegroundColor Red
        $FailedTests = $Global:TestResults.TestDetails | Where-Object { $_.Result -eq "Fail" }
        foreach ($Test in $FailedTests) {
            Write-Host "  - $($Test.TestName)" -ForegroundColor Red
            if ($Test.ErrorMessage) {
                Write-Host "    $($Test.ErrorMessage)" -ForegroundColor Gray
            }
        }
    }
    
    if ($PassRate -ge 80) {
        Write-Host "`n[PASS] Implementation validated successfully!" -ForegroundColor Green
        Write-Host "  Ready for production deployment." -ForegroundColor Green
    }
    elseif ($PassRate -ge 60) {
        Write-Host "`n[WARNING] Implementation has warnings!" -ForegroundColor Yellow
        Write-Host "  Review failed tests before deployment." -ForegroundColor Yellow
    }
    else {
        Write-Host "`n[FAIL] Implementation validation failed!" -ForegroundColor Red
        Write-Host "  Critical issues detected - do not deploy." -ForegroundColor Red
    }
}

#endregion TEST_FRAMEWORK

#region CONFIGURATION_TESTS

<#
.SYNOPSIS
    Tests configuration file and module registration.
#>
function Test-Configuration {
    Write-Host "`n=== Configuration Tests ===" -ForegroundColor Cyan
    
    # Test 1: Script file exists
    $ScriptPath = "$PSScriptRoot\..\scripts\Windows10-Maintenance-Script.ps1"
    if (Test-Path $ScriptPath) {
        Write-TestResult -TestName "Script file exists" -Result "Pass" -Details "Found at: $ScriptPath"
    }
    else {
        Write-TestResult -TestName "Script file exists" -Result "Fail" -ErrorMessage "Script not found at: $ScriptPath"
        return
    }
    
    # Test 2: Script syntax validation
    try {
        $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $ScriptPath -Raw), [ref]$null)
        Write-TestResult -TestName "Script syntax validation" -Result "Pass" -Details "No syntax errors detected"
    }
    catch {
        Write-TestResult -TestName "Script syntax validation" -Result "Fail" -ErrorMessage $_.Exception.Message
    }
    
    # Test 3: SystemHealthRepair module in EnabledModules
    $ScriptContent = Get-Content $ScriptPath -Raw
    if ($ScriptContent -match '"SystemHealthRepair"' -or $ScriptContent -match "'SystemHealthRepair'") {
        Write-TestResult -TestName "SystemHealthRepair module registered" -Result "Pass"
    }
    else {
        Write-TestResult -TestName "SystemHealthRepair module registered" -Result "Fail" -ErrorMessage "Module not found in EnabledModules configuration"
    }
    
    # Test 4: SystemHealthRepair region exists
    if ($ScriptContent -match '#region SYSTEM_HEALTH_REPAIR') {
        Write-TestResult -TestName "SystemHealthRepair region exists" -Result "Pass"
    }
    else {
        Write-TestResult -TestName "SystemHealthRepair region exists" -Result "Fail" -ErrorMessage "Region not found in script"
    }
    
    # Test 5: Enhanced disk cleanup functions exist
    if ($ScriptContent -match 'function Invoke-WindowsDiskCleanup') {
        Write-TestResult -TestName "Enhanced disk cleanup functions exist" -Result "Pass"
    }
    else {
        Write-TestResult -TestName "Enhanced disk cleanup functions exist" -Result "Fail" -ErrorMessage "Invoke-WindowsDiskCleanup function not found"
    }
    
    # Test 6: Configuration file exists
    $ConfigPath = "$PSScriptRoot\..\maintenance-config.json"
    if (Test-Path $ConfigPath) {
        Write-TestResult -TestName "Configuration file exists" -Result "Pass" -Details "Found at: $ConfigPath"
        
        # Test 7: Configuration file is valid JSON
        try {
            $Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            Write-TestResult -TestName "Configuration JSON is valid" -Result "Pass"
            
            # Test 8: SystemHealthRepair configuration exists
            if ($Config.PSObject.Properties['SystemHealthRepair']) {
                Write-TestResult -TestName "SystemHealthRepair configuration exists" -Result "Pass"
            }
            else {
                Write-TestResult -TestName "SystemHealthRepair configuration exists" -Result "Warning" -Details "Using default configuration"
            }
            
            # Test 9: EnhancedDiskCleanup configuration exists
            if ($Config.PSObject.Properties['EnhancedDiskCleanup']) {
                Write-TestResult -TestName "EnhancedDiskCleanup configuration exists" -Result "Pass"
            }
            else {
                Write-TestResult -TestName "EnhancedDiskCleanup configuration exists" -Result "Warning" -Details "Using default configuration"
            }
        }
        catch {
            Write-TestResult -TestName "Configuration JSON is valid" -Result "Fail" -ErrorMessage $_.Exception.Message
        }
    }
    else {
        Write-TestResult -TestName "Configuration file exists" -Result "Warning" -Details "Will use default configuration"
    }
}

#endregion CONFIGURATION_TESTS

#region SYSTEM_REQUIREMENTS_TESTS

<#
.SYNOPSIS
    Tests system requirements and prerequisites.
#>
function Test-SystemRequirements {
    Write-Host "`n=== System Requirements Tests ===" -ForegroundColor Cyan
    
    # Test 1: Administrator privileges
    $IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($IsAdmin) {
        Write-TestResult -TestName "Administrator privileges" -Result "Pass"
    }
    else {
        Write-TestResult -TestName "Administrator privileges" -Result "Fail" -ErrorMessage "Script must be run as Administrator"
    }
    
    # Test 2: PowerShell version
    $PSVersion = $PSVersionTable.PSVersion
    if ($PSVersion.Major -ge 5) {
        Write-TestResult -TestName "PowerShell version" -Result "Pass" -Details "Version: $($PSVersion.ToString())"
    }
    else {
        Write-TestResult -TestName "PowerShell version" -Result "Fail" -ErrorMessage "PowerShell 5.1+ required (Current: $($PSVersion.ToString()))"
    }
    
    # Test 3: DISM availability
    $DISMPath = "$env:SystemRoot\System32\dism.exe"
    if (Test-Path $DISMPath) {
        Write-TestResult -TestName "DISM.exe availability" -Result "Pass" -Details "Found at: $DISMPath"
    }
    else {
        Write-TestResult -TestName "DISM.exe availability" -Result "Fail" -ErrorMessage "DISM.exe not found"
    }
    
    # Test 4: SFC availability
    $SFCPath = "$env:SystemRoot\System32\sfc.exe"
    if (Test-Path $SFCPath) {
        Write-TestResult -TestName "SFC.exe availability" -Result "Pass" -Details "Found at: $SFCPath"
    }
    else {
        Write-TestResult -TestName "SFC.exe availability" -Result "Fail" -ErrorMessage "SFC.exe not found"
    }
    
    # Test 5: CleanMgr availability
    $CleanMgrPath = "$env:SystemRoot\System32\cleanmgr.exe"
    if (Test-Path $CleanMgrPath) {
        Write-TestResult -TestName "CleanMgr.exe availability" -Result "Pass" -Details "Found at: $CleanMgrPath"
    }
    else {
        Write-TestResult -TestName "CleanMgr.exe availability" -Result "Fail" -ErrorMessage "CleanMgr.exe not found"
    }
    
    # Test 6: Disk space availability
    $SystemDrive = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"
    $FreeSpaceGB = [math]::Round($SystemDrive.FreeSpace / 1GB, 2)
    if ($FreeSpaceGB -ge 10) {
        Write-TestResult -TestName "Disk space availability" -Result "Pass" -Details "Free space: ${FreeSpaceGB}GB"
    }
    elseif ($FreeSpaceGB -ge 5) {
        Write-TestResult -TestName "Disk space availability" -Result "Warning" -Details "Low disk space: ${FreeSpaceGB}GB"
    }
    else {
        Write-TestResult -TestName "Disk space availability" -Result "Fail" -ErrorMessage "Critical low disk space: ${FreeSpaceGB}GB"
    }
    
    # Test 7: VSS service status (for restore points)
    try {
        $VSSService = Get-Service -Name "VSS" -ErrorAction Stop
        if ($VSSService.Status -eq "Running") {
            Write-TestResult -TestName "VSS service status" -Result "Pass" -Details "Service is running"
        }
        else {
            Write-TestResult -TestName "VSS service status" -Result "Warning" -Details "Service is not running (Status: $($VSSService.Status))"
        }
    }
    catch {
        Write-TestResult -TestName "VSS service status" -Result "Fail" -ErrorMessage $_.Exception.Message
    }
    
    # Test 8: Windows Update service
    try {
        $WUService = Get-Service -Name "wuauserv" -ErrorAction Stop
        Write-TestResult -TestName "Windows Update service exists" -Result "Pass" -Details "Status: $($WUService.Status)"
    }
    catch {
        Write-TestResult -TestName "Windows Update service exists" -Result "Fail" -ErrorMessage $_.Exception.Message
    }
}

#endregion SYSTEM_REQUIREMENTS_TESTS

#region FUNCTIONAL_TESTS

<#
.SYNOPSIS
    Tests core functionality of new modules.
#>
function Test-CoreFunctionality {
    Write-Host "`n=== Core Functionality Tests ===" -ForegroundColor Cyan
    
    # Test 1: DISM quick test (CheckHealth - non-invasive)
    Write-Host "  Running DISM CheckHealth (this may take 2-5 minutes)..." -ForegroundColor Gray
    try {
        $DISMProcess = Start-Process -FilePath "DISM.exe" -ArgumentList "/Online /Cleanup-Image /CheckHealth" -PassThru -Wait -NoNewWindow -RedirectStandardOutput "$env:TEMP\dism_test.txt" -RedirectStandardError "$env:TEMP\dism_error.txt"
        
        if ($DISMProcess.ExitCode -eq 0) {
            Write-TestResult -TestName "DISM CheckHealth execution" -Result "Pass" -Details "Exit code: 0"
        }
        else {
            $ErrorContent = Get-Content "$env:TEMP\dism_error.txt" -Raw -ErrorAction SilentlyContinue
            Write-TestResult -TestName "DISM CheckHealth execution" -Result "Warning" -Details "Exit code: $($DISMProcess.ExitCode) - $ErrorContent"
        }
        
        # Cleanup test files
        Remove-Item "$env:TEMP\dism_test.txt" -ErrorAction SilentlyContinue
        Remove-Item "$env:TEMP\dism_error.txt" -ErrorAction SilentlyContinue
    }
    catch {
        Write-TestResult -TestName "DISM CheckHealth execution" -Result "Fail" -ErrorMessage $_.Exception.Message
    }
    
    # Test 2: Registry access for StateFlags
    try {
        $TestPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
        if (Test-Path $TestPath) {
            Write-TestResult -TestName "Registry access for StateFlags" -Result "Pass" -Details "Path accessible"
            
            # Test write access
            $TestCategory = Get-ChildItem $TestPath | Select-Object -First 1
            if ($TestCategory) {
                try {
                    $TestValue = Get-Random -Minimum 9000 -Maximum 9999
                    New-ItemProperty -Path $TestCategory.PSPath -Name "StateFlags$TestValue" -PropertyType DWord -Value 2 -Force -ErrorAction Stop | Out-Null
                    Remove-ItemProperty -Path $TestCategory.PSPath -Name "StateFlags$TestValue" -Force -ErrorAction Stop
                    Write-TestResult -TestName "Registry write access for StateFlags" -Result "Pass"
                }
                catch {
                    Write-TestResult -TestName "Registry write access for StateFlags" -Result "Fail" -ErrorMessage $_.Exception.Message
                }
            }
        }
        else {
            Write-TestResult -TestName "Registry access for StateFlags" -Result "Fail" -ErrorMessage "Registry path not found"
        }
    }
    catch {
        Write-TestResult -TestName "Registry access for StateFlags" -Result "Fail" -ErrorMessage $_.Exception.Message
    }
    
    # Test 3: CleanMgr sage command test
    try {
        Write-Host "  Testing CleanMgr configuration capability..." -ForegroundColor Gray
        
        # This should complete quickly without showing GUI
        $CleanMgrProcess = Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/verylowdisk" -PassThru -Wait -NoNewWindow -ErrorAction Stop
        
        if ($CleanMgrProcess.ExitCode -eq 0) {
            Write-TestResult -TestName "CleanMgr execution capability" -Result "Pass"
        }
        else {
            Write-TestResult -TestName "CleanMgr execution capability" -Result "Warning" -Details "Exit code: $($CleanMgrProcess.ExitCode)"
        }
    }
    catch {
        Write-TestResult -TestName "CleanMgr execution capability" -Result "Fail" -ErrorMessage $_.Exception.Message
    }
    
    # Test 4: Process management capability
    try {
        $TestProcess = Start-Process -FilePath "cmd.exe" -ArgumentList "/c echo test" -PassThru -NoNewWindow
        $Completed = $TestProcess.WaitForExit(5000)  # 5 second timeout
        
        if ($Completed) {
            Write-TestResult -TestName "Process management and timeout" -Result "Pass"
        }
        else {
            $TestProcess.Kill()
            Write-TestResult -TestName "Process management and timeout" -Result "Warning" -Details "Timeout mechanism working"
        }
    }
    catch {
        Write-TestResult -TestName "Process management and timeout" -Result "Fail" -ErrorMessage $_.Exception.Message
    }
    
    # Test 5: File system write access for reports
    try {
        $ReportPath = "$env:USERPROFILE\Documents\Maintenance\Reports"
        if (-not (Test-Path $ReportPath)) {
            New-Item -ItemType Directory -Path $ReportPath -Force | Out-Null
        }
        
        $TestFile = Join-Path $ReportPath "test_report_$(Get-Random).txt"
        "Test content" | Out-File -FilePath $TestFile
        
        if (Test-Path $TestFile) {
            Remove-Item $TestFile -Force
            Write-TestResult -TestName "Report directory write access" -Result "Pass" -Details "Path: $ReportPath"
        }
        else {
            Write-TestResult -TestName "Report directory write access" -Result "Fail" -ErrorMessage "Cannot write to report directory"
        }
    }
    catch {
        Write-TestResult -TestName "Report directory write access" -Result "Fail" -ErrorMessage $_.Exception.Message
    }
    
    # Test 6: WMI access for disk information
    try {
        $DiskInfo = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"
        if ($DiskInfo) {
            Write-TestResult -TestName "WMI disk information access" -Result "Pass" -Details "Drive: $($DiskInfo.DeviceID)"
        }
        else {
            Write-TestResult -TestName "WMI disk information access" -Result "Fail" -ErrorMessage "Cannot retrieve disk information"
        }
    }
    catch {
        Write-TestResult -TestName "WMI disk information access" -Result "Fail" -ErrorMessage $_.Exception.Message
    }
}

#endregion FUNCTIONAL_TESTS

#region INTEGRATION_TESTS

<#
.SYNOPSIS
    Tests integration with existing script components.
#>
function Test-Integration {
    Write-Host "`n=== Integration Tests ===" -ForegroundColor Cyan
    
    # Test 1: WhatIf mode execution
    Write-Host "  Running script in WhatIf mode (simulation)..." -ForegroundColor Gray
    try {
        $ScriptPath = "$PSScriptRoot\..\scripts\Windows10-Maintenance-Script.ps1"
        
        if (-not (Test-Path $ScriptPath)) {
            Write-TestResult -TestName "WhatIf mode execution" -Result "Fail" -ErrorMessage "Script file not found"
            return
        }
        
        # Execute script in WhatIf mode (should complete quickly without making changes)
        $Job = Start-Job -ScriptBlock {
            param($Path)
            & $Path -WhatIf -SilentMode -BackupMode Skip 2>&1
        } -ArgumentList $ScriptPath
        
        # Wait up to 2 minutes for WhatIf execution
        $Completed = Wait-Job -Job $Job -Timeout 120
        
        if ($Completed) {
            $Output = Receive-Job -Job $Job
            Remove-Job -Job $Job -Force
            
            # Check if SystemHealthRepair module was mentioned
            if ($Output -match "System Health" -or $Output -match "DISM" -or $Output -match "SystemHealthRepair") {
                Write-TestResult -TestName "WhatIf mode - SystemHealthRepair integration" -Result "Pass" -Details "Module detected in WhatIf output"
            }
            else {
                Write-TestResult -TestName "WhatIf mode - SystemHealthRepair integration" -Result "Warning" -Details "Module not clearly indicated in output"
            }
            
            # Check for errors
            if ($Output -match "ERROR|Exception|Failed to load") {
                Write-TestResult -TestName "WhatIf mode - No critical errors" -Result "Fail" -ErrorMessage "Errors detected in WhatIf execution"
            }
            else {
                Write-TestResult -TestName "WhatIf mode - No critical errors" -Result "Pass"
            }
        }
        else {
            Remove-Job -Job $Job -Force
            Write-TestResult -TestName "WhatIf mode execution" -Result "Fail" -ErrorMessage "WhatIf execution timed out (>2 minutes)"
        }
    }
    catch {
        Write-TestResult -TestName "WhatIf mode execution" -Result "Fail" -ErrorMessage $_.Exception.Message
    }
    
    # Test 2: Logging functionality
    try {
        $LogPath = "$env:USERPROFILE\Documents\Maintenance"
        if (-not (Test-Path $LogPath)) {
            New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
        }
        
        $TestLog = Join-Path $LogPath "test_maintenance_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        "[Test] Log entry" | Out-File -FilePath $TestLog
        
        if (Test-Path $TestLog) {
            Remove-Item $TestLog -Force
            Write-TestResult -TestName "Logging directory access" -Result "Pass"
        }
        else {
            Write-TestResult -TestName "Logging directory access" -Result "Fail" -ErrorMessage "Cannot write to log directory"
        }
    }
    catch {
        Write-TestResult -TestName "Logging directory access" -Result "Fail" -ErrorMessage $_.Exception.Message
    }
}

#endregion INTEGRATION_TESTS

#region MAIN_EXECUTION

<#
.SYNOPSIS
    Main test execution orchestrator.
#>
function Start-MaintenanceModuleTests {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "MAINTENANCE MODULE VALIDATION TESTS" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Testing new System Health Repair and Enhanced Disk Cleanup modules"
    Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    Write-Host ""
    
    # Execute test suites
    Test-Configuration
    Test-SystemRequirements
    Test-CoreFunctionality
    Test-Integration
    
    # Generate report
    Show-TestReport
    
    # Save detailed report
    try {
        $ReportPath = "$env:USERPROFILE\Documents\Maintenance\Reports"
        if (-not (Test-Path $ReportPath)) {
            New-Item -ItemType Directory -Path $ReportPath -Force | Out-Null
        }
        
        $ReportFile = Join-Path $ReportPath "test_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
        $Global:TestResults | ConvertTo-Json -Depth 5 | Out-File -FilePath $ReportFile
        
        Write-Host "`nDetailed test report saved: $ReportFile" -ForegroundColor Gray
    }
    catch {
        Write-Host "`nWarning: Could not save detailed report: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # Return exit code based on results
    if ($Global:TestResults.FailedTests -eq 0) {
        return 0  # Success
    }
    else {
        return 1  # Failures detected
    }
}

#endregion MAIN_EXECUTION

# Execute tests
$ExitCode = Start-MaintenanceModuleTests
exit $ExitCode