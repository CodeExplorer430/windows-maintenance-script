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
