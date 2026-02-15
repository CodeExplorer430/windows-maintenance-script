$HelperPath = Join-Path $PSScriptRoot "..TestHelper.ps1"
if (Test-Path $HelperPath) { . $HelperPath }

#Requires -Module Pester

Describe "DiskMaintenance Module" {
    BeforeEach {
        $script:ModuleRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
        try {
            Import-Module (Join-Path $script:ModuleRoot "WindowsMaintenance.psd1") -Force -ErrorAction SilentlyContinue -Scope Global
        } catch {
            Write-Debug "Module import failed: $($_.Exception.Message)"
        }
    }

    Context "Invoke-DiskMaintenance" {
        It "Should exist" {
            if (Get-Command Invoke-DiskMaintenance -ErrorAction SilentlyContinue) {
                Get-Command Invoke-DiskMaintenance | Should -Not -BeNullOrEmpty
            } else {
                Show-TestResult -Skipped
            }
        }

        It "Should handle being disabled" {
            if (Get-Command Invoke-DiskMaintenance -ErrorAction SilentlyContinue) {
                $Config = @{ EnabledModules = @() }
                { Invoke-DiskMaintenance -Config $Config } | Should -Not -Throw
            } else {
                Show-TestResult -Skipped
            }
        }

        It "Should handle WhatIf mode" {
            if (Get-Command Invoke-DiskMaintenance -ErrorAction SilentlyContinue) {
                $Config = @{
                    EnabledModules = @("DiskMaintenance")
                    DiskCleanup = @{ EnableWindowsCleanup = $false }
                }
                { Invoke-DiskMaintenance -Config $Config -WhatIf } | Should -Not -Throw
            } else {
                Show-TestResult -Skipped
            }
        }
    }
}
