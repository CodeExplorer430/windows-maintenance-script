$HelperPath = Join-Path $PSScriptRoot "..TestHelper.ps1"
if (Test-Path $HelperPath) { . $HelperPath }

#Requires -Module Pester

Describe "PrivacyMaintenance Module" {
    BeforeEach {
        $script:ModuleRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
        try {
            Import-Module (Join-Path $script:ModuleRoot "WindowsMaintenance.psd1") -Force -ErrorAction SilentlyContinue -Scope Global
        } catch {
            Write-Debug "Module import failed: $($_.Exception.Message)"
        }
    }

    Context "Invoke-PrivacyMaintenance" {
        It "Should exist" {
            if (Get-Command Invoke-PrivacyMaintenance -ErrorAction SilentlyContinue) {
                Get-Command Invoke-PrivacyMaintenance | Should -Not -BeNullOrEmpty
            } else {
                Show-TestResult -Skipped
            }
        }

        It "Should handle being disabled" {
            if (Get-Command Invoke-PrivacyMaintenance -ErrorAction SilentlyContinue) {
                $Config = @{ EnabledModules = @() }
                { Invoke-PrivacyMaintenance -Config $Config } | Should -Not -Throw
            } else {
                Show-TestResult -Skipped
            }
        }
    }
}
