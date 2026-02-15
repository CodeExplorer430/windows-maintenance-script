<#
.SYNOPSIS
    Test runner for Windows Maintenance Framework (Cross-Version Compatible).

.DESCRIPTION
    Executes all Pester tests for the Windows Maintenance Framework.
    Automatically detects PowerShell version and Pester version to use optimal execution strategy.

.PARAMETER TestPath
    Path to specific test file or directory (default: all tests)

.PARAMETER CodeCoverage
    Enable code coverage analysis

.PARAMETER CI
    Run in CI mode (returns non-zero exit code on failure)

.EXAMPLE
    .\Invoke-Tests.ps1

.NOTES
    File Name      : Invoke-Tests.ps1
    Author         : Miguel Velasco
    Prerequisite   : Pester 3.4.0+ or 5.x, PowerShell 5.1 or 7+
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$TestPath,

    [Parameter(Mandatory=$false)]
    [switch]$CodeCoverage = $false,

    [Parameter(Mandatory=$false)]
    [switch]$CI = $false
)

# Set information preference for UI output
$InformationPreference = 'Continue'

# Load helpers
$HelperPath = Join-Path $PSScriptRoot "TestHelper.ps1"
if (Test-Path $HelperPath) {
    . $HelperPath
}

# Detection logic
$PSVersion = $PSVersionTable.PSVersion.Major
$DetectedPSEdition = $PSVersionTable.PSEdition
$PesterModule = Get-Module -ListAvailable -Name Pester | Sort-Object Version -Descending | Select-Object -First 1

if (-not $PesterModule) {
    Write-Error "Pester module is not installed. Please install Pester to run tests."
    exit 1
}

$PesterVersion = $PesterModule.Version.Major

Write-Information -MessageData "========================================" -Tags "Color:Cyan"
Write-Information -MessageData "  Windows Maintenance Framework Tests" -Tags "Color:Cyan"
Write-Information -MessageData "  Environment: PS $PSVersion ($DetectedPSEdition) | Pester $PesterVersion" -Tags "Color:Cyan"
Write-Information -MessageData "========================================`n" -Tags "Color:Cyan"

# Determine test path
$ScriptRoot = $PSScriptRoot
if (-not $TestPath) {
    $TestPath = $ScriptRoot
}

if (-not (Test-Path $TestPath)) {
    Write-Error "Test path not found: $TestPath"
    exit 1
}

# Run Strategy
$Result = $null

if ($PesterVersion -ge 5) {
    Write-Information -MessageData "Using Pester 5.x execution engine..." -Tags "Color:Gray"
    Import-Module Pester -MinimumVersion 5.0 -Force

    $config = New-PesterConfiguration
    $config.Run.Path = $TestPath
    $config.Run.PassThru = $true
    $config.Output.Verbosity = 'Detailed'

    if ($CodeCoverage) {
        $ModuleRoot = Split-Path -Parent $ScriptRoot
        $config.CodeCoverage.Enabled = $true
        $config.CodeCoverage.Path = @(
            "$ModuleRoot\WindowsMaintenance.psm1"
            "$ModuleRoot\Modules\*.psm1"
            "$ModuleRoot\Modules\Common\*.psm1"
        )
    }

    $Result = Invoke-Pester -Configuration $config
}
else {
    Write-Information -MessageData "Using legacy Pester execution engine..." -Tags "Color:Gray"
    Import-Module Pester -Force

    $PesterParams = @{
        Script = $TestPath
        PassThru = $true
    }

    if ($CodeCoverage) {
        $ModuleRoot = Split-Path -Parent $ScriptRoot
        $PesterParams.CodeCoverage = @(
            "$ModuleRoot\WindowsMaintenance.psm1"
            "$ModuleRoot\Modules\*.psm1"
            "$ModuleRoot\Modules\Common\*.psm1"
        )
    }

    $Result = Invoke-Pester @PesterParams
}

# Display results
Write-Information -MessageData "`n========================================" -Tags "Color:Cyan"
Write-Information -MessageData "  Test Results Summary" -Tags "Color:Cyan"
Write-Information -MessageData "========================================`n" -Tags "Color:Cyan"

if ($Result) {
    Write-Information -MessageData "Passed:         $($Result.PassedCount)" -Tags "Color:Green"
    $FailedColor = if ($Result.FailedCount -gt 0) { 'Red' } else { 'Gray' }
    Write-Information -MessageData "Failed:         $($Result.FailedCount)" -Tags "Color:$FailedColor"

    if ($Result.SkippedCount) {
        Write-Information -MessageData "Skipped:        $($Result.SkippedCount)" -Tags "Color:Yellow"
    }
}

# Final status
Write-Information -MessageData "`n========================================" -Tags "Color:Cyan"
if ($Result.FailedCount -eq 0) {
    Write-Information -MessageData "  All Tests Passed!" -Tags "Color:Green"
    Write-Information -MessageData "========================================" -Tags "Color:Cyan"
    exit 0
}
else {
    Write-Information -MessageData "  Tests Failed" -Tags "Color:Red"
    Write-Information -MessageData "========================================" -Tags "Color:Cyan"

    if ($CI) {
        exit 1
    }
    else {
        exit 0
    }
}
