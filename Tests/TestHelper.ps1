# Test Helpers for Windows Maintenance Framework
# Provides utility functions for tests.

# Helper for showing test status in the console
# Uses Show-TestResult to avoid state-changing verb warnings
function Show-TestResult {


    [CmdletBinding()]
    param(
        [switch]$Skipped,
        [switch]$Inconclusive
    )
    if ($Skipped) {
        Write-Host "  [SKIPPED]" -ForegroundColor Yellow
    }
    elseif ($Inconclusive) {
        Write-Host "  [INCONCLUSIVE]" -ForegroundColor Cyan
    }
}

function Get-TestRepoRoot {
    [CmdletBinding()]
    param()

    $scriptPath = if ($PSScriptRoot) {
        $PSScriptRoot
    } elseif ($PSCommandPath) {
        Split-Path -Parent $PSCommandPath
    } elseif ($MyInvocation.MyCommand.Path) {
        Split-Path -Parent $MyInvocation.MyCommand.Path
    } else {
        (Get-Location).Path
    }

    $candidate = Join-Path $scriptPath ".."
    $resolved = Resolve-Path $candidate -ErrorAction SilentlyContinue
    if ($resolved) {
        return $resolved.Path
    }

    if ($candidate) {
        return $candidate
    }

    return (Get-Location).Path
}
