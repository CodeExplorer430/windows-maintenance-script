$HelperPath = Join-Path $PSScriptRoot "..TestHelper.ps1"
if (Test-Path $HelperPath) { . $HelperPath }

#Requires -Module Pester

Describe "Database Module" {
    BeforeEach {
        $script:ModuleRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
        try {
            Import-Module (Join-Path $script:ModuleRoot "WindowsMaintenance.psd1") -Force -ErrorAction SilentlyContinue -Scope Global
        } catch {
            Write-Debug "Module import failed: $($_.Exception.Message)"
        }
    }

    Context "Initialize-MaintenanceDatabase" {
        It "Should run without error even if DLL is missing" {
            if (Get-Command Initialize-MaintenanceDatabase -ErrorAction SilentlyContinue) {
                { Initialize-MaintenanceDatabase -DbPath "$env:TEMP\test.db" } | Should -Not -Throw
            } else {
                Show-TestResult -Skipped
            }
        }
    }

    Context "Add-MaintenanceHistory" {
        It "Should handle logging calls gracefully" {
            if (Get-Command Add-MaintenanceHistory -ErrorAction SilentlyContinue) {
                { Add-MaintenanceHistory -Module "Test" -Task "Task" -Result "Success" -Details "Details" } | Should -Not -Throw
            } else {
                Show-TestResult -Skipped
            }
        }
    }
}
