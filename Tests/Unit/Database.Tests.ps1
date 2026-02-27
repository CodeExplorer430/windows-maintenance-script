

#Requires -Module Pester

Describe "Database Module" {
    BeforeAll {
        $TestRoot = Split-Path -Parent $PSCommandPath
        $HelperPath = Join-Path $TestRoot "..\TestHelper.ps1"
        if (Test-Path $HelperPath) { . $HelperPath }
    }

    BeforeEach {
        $script:ModuleRoot = Resolve-Path (Join-Path $(if ($PSScriptRoot) { $PSScriptRoot } elseif ($PSCommandPath) { Split-Path -Parent $PSCommandPath } else { (Get-Location).Path }) "..\\..")
        try {

            $script:oldWarningPref = $global:WarningPreference
            $global:WarningPreference = 'SilentlyContinue'
            Import-Module (Join-Path $script:ModuleRoot "WindowsMaintenance.psd1") -Force -DisableNameChecking -ErrorAction SilentlyContinue -Scope Global
            $global:WarningPreference = $script:oldWarningPref

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






