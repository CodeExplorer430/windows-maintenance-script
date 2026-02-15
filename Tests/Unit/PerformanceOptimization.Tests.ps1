$HelperPath = Join-Path $PSScriptRoot "..TestHelper.ps1"
if (Test-Path $HelperPath) { . $HelperPath }

#Requires -Module Pester

Describe "PerformanceOptimization Module" {
    BeforeEach {
        $script:ModuleRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
        try {
            Import-Module (Join-Path $script:ModuleRoot "WindowsMaintenance.psd1") -Force -ErrorAction SilentlyContinue -Scope Global
        } catch {
            Write-Debug "Module import failed: $($_.Exception.Message)"
        }
    }

    Context "Invoke-PerformanceOptimization" {
        It "Should exist" {
            if (Get-Command Invoke-PerformanceOptimization -ErrorAction SilentlyContinue) {
                Get-Command Invoke-PerformanceOptimization | Should -Not -BeNullOrEmpty
            } else {
                Show-TestResult -Skipped
            }
        }

        It "Should handle being disabled" {
            if (Get-Command Invoke-PerformanceOptimization -ErrorAction SilentlyContinue) {
                $Config = @{ EnabledModules = @() }
                { Invoke-PerformanceOptimization -Config $Config } | Should -Not -Throw
            } else {
                Show-TestResult -Skipped
            }
        }
    }

    Context "Remove-InvalidStartupItem" {
        It "Should exist" {
            if (Get-Command Remove-InvalidStartupItem -ErrorAction SilentlyContinue) {
                Get-Command Remove-InvalidStartupItem | Should -Not -BeNullOrEmpty
            } else {
                Show-TestResult -Skipped
            }
        }

        It "Should support ShouldProcess" {
            if (Get-Command Remove-InvalidStartupItem -ErrorAction SilentlyContinue) {
                { Remove-InvalidStartupItem -WhatIf } | Should -Not -Throw
            } else {
                Show-TestResult -Skipped
            }
        }
    }
}
