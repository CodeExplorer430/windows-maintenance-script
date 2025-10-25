<#
.SYNOPSIS
    Test runner for Windows Maintenance Framework.

.DESCRIPTION
    Executes all Pester tests for the Windows Maintenance Framework and provides
    a comprehensive test report. Supports different output formats and test filtering.

.PARAMETER TestPath
    Path to specific test file or directory (default: all tests)

.PARAMETER OutputFormat
    Output format for test results (Normal, Detailed, Diagnostic)

.PARAMETER CodeCoverage
    Enable code coverage analysis

.PARAMETER CI
    Run in CI mode (returns non-zero exit code on failure)

.EXAMPLE
    .\Invoke-Tests.ps1

.EXAMPLE
    .\Invoke-Tests.ps1 -OutputFormat Detailed -CodeCoverage

.EXAMPLE
    .\Invoke-Tests.ps1 -TestPath "WindowsMaintenance.Tests.ps1" -CI

.NOTES
    File Name      : Invoke-Tests.ps1
    Author         : Miguel Velasco
    Prerequisite   : Pester 5.x, PowerShell 5.1+
    Version        : 1.0.0
    Last Updated   : October 2025
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$TestPath,

    [Parameter(Mandatory=$false)]
    [ValidateSet('Normal', 'Detailed', 'Diagnostic')]
    [string]$OutputFormat = 'Detailed',

    [Parameter(Mandatory=$false)]
    [switch]$CodeCoverage = $false,

    [Parameter(Mandatory=$false)]
    [switch]$CI = $false
)

# Ensure Pester is installed
if (-not (Get-Module -ListAvailable -Name Pester)) {
    Write-Host "ERROR: Pester module is not installed" -ForegroundColor Red
    Write-Host "Install Pester using: Install-Module -Name Pester -Force -SkipPublisherCheck" -ForegroundColor Yellow
    exit 1
}

# Import Pester
Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Windows Maintenance Framework Tests" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Determine test path
$ScriptRoot = $PSScriptRoot
if (-not $TestPath) {
    $TestPath = $ScriptRoot
}

if (-not (Test-Path $TestPath)) {
    Write-Host "ERROR: Test path not found: $TestPath" -ForegroundColor Red
    exit 1
}

Write-Host "Test Path:     $TestPath" -ForegroundColor Gray
Write-Host "Output Format: $OutputFormat" -ForegroundColor Gray
Write-Host "Code Coverage: $($CodeCoverage.ToString())" -ForegroundColor Gray
Write-Host "CI Mode:       $($CI.ToString())" -ForegroundColor Gray
Write-Host ""

# Configure Pester
$PesterConfiguration = New-PesterConfiguration

$PesterConfiguration.Run.Path = $TestPath
$PesterConfiguration.Run.PassThru = $true

# Set output verbosity
switch ($OutputFormat) {
    'Normal' {
        $PesterConfiguration.Output.Verbosity = 'Normal'
    }
    'Detailed' {
        $PesterConfiguration.Output.Verbosity = 'Detailed'
    }
    'Diagnostic' {
        $PesterConfiguration.Output.Verbosity = 'Diagnostic'
    }
}

# Configure code coverage if requested
if ($CodeCoverage) {
    $ModuleRoot = Split-Path -Parent $ScriptRoot
    $PesterConfiguration.CodeCoverage.Enabled = $true
    $PesterConfiguration.CodeCoverage.Path = @(
        "$ModuleRoot\WindowsMaintenance.psm1"
        "$ModuleRoot\Modules\*.psm1"
        "$ModuleRoot\Modules\Common\*.psm1"
    )
    $PesterConfiguration.CodeCoverage.OutputFormat = 'JaCoCo'
    $PesterConfiguration.CodeCoverage.OutputPath = "$ScriptRoot\CodeCoverage.xml"
}

# Run tests
Write-Host "Running tests..." -ForegroundColor Cyan
Write-Host ""

$StartTime = Get-Date
$Result = Invoke-Pester -Configuration $PesterConfiguration
$EndTime = Get-Date
$Duration = $EndTime - $StartTime

# Display results
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Test Results Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Total Tests:    $($Result.TotalCount)" -ForegroundColor Gray
Write-Host "Passed:         $($Result.PassedCount)" -ForegroundColor Green
Write-Host "Failed:         $($Result.FailedCount)" -ForegroundColor $(if ($Result.FailedCount -gt 0) { 'Red' } else { 'Gray' })
Write-Host "Skipped:        $($Result.SkippedCount)" -ForegroundColor Yellow
Write-Host "Duration:       $($Duration.ToString('mm\:ss\.fff'))" -ForegroundColor Gray
Write-Host ""

# Code coverage report
if ($CodeCoverage) {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Code Coverage" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    $CoveragePercent = [math]::Round(($Result.CodeCoverage.CommandsExecutedCount / $Result.CodeCoverage.CommandsAnalyzedCount) * 100, 2)

    Write-Host "Commands Analyzed:  $($Result.CodeCoverage.CommandsAnalyzedCount)" -ForegroundColor Gray
    Write-Host "Commands Executed:  $($Result.CodeCoverage.CommandsExecutedCount)" -ForegroundColor Gray
    Write-Host "Commands Missed:    $($Result.CodeCoverage.CommandsMissedCount)" -ForegroundColor Gray
    Write-Host "Coverage:           $CoveragePercent%" -ForegroundColor $(if ($CoveragePercent -ge 80) { 'Green' } elseif ($CoveragePercent -ge 60) { 'Yellow' } else { 'Red' })
    Write-Host ""
    Write-Host "Coverage report saved to: $($PesterConfiguration.CodeCoverage.OutputPath)" -ForegroundColor Gray
    Write-Host ""
}

# Display failed tests details
if ($Result.FailedCount -gt 0) {
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "  Failed Tests" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""

    foreach ($FailedTest in $Result.Failed) {
        Write-Host "  [FAILED] $($FailedTest.ExpandedName)" -ForegroundColor Red
        if ($FailedTest.ErrorRecord) {
            Write-Host "    Error: $($FailedTest.ErrorRecord.Exception.Message)" -ForegroundColor Red
        }
        Write-Host ""
    }
}

# Final status
Write-Host "========================================" -ForegroundColor Cyan
if ($Result.FailedCount -eq 0) {
    Write-Host "  All Tests Passed!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    exit 0
}
else {
    Write-Host "  Tests Failed" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    if ($CI) {
        Write-Host "CI Mode: Exiting with non-zero code due to test failures" -ForegroundColor Red
        exit 1
    }
    else {
        Write-Host "Some tests failed. Please review the failures above." -ForegroundColor Yellow
        exit 0
    }
}
