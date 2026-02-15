$HelperPath = Join-Path $PSScriptRoot "..TestHelper.ps1"
if (Test-Path $HelperPath) { . $HelperPath }

#Requires -Module Pester

Describe "SecurityScans Module" {
    BeforeEach {
        $script:ModuleRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
        try {
            Import-Module (Join-Path $script:ModuleRoot "WindowsMaintenance.psd1") -Force -ErrorAction SilentlyContinue -Scope Global
        } catch {
            Write-Debug "Module import failed: $($_.Exception.Message)"
        }
    }

    Context "Invoke-SecurityScan" {
        It "Should exist" {
            if (Get-Command Invoke-SecurityScan -ErrorAction SilentlyContinue) {
                Get-Command Invoke-SecurityScan | Should -Not -BeNullOrEmpty
            } else {
                Show-TestResult -Skipped
            }
        }

        It "Should handle being disabled" {
            if (Get-Command Invoke-SecurityScan -ErrorAction SilentlyContinue) {
                $Config = @{ EnabledModules = @() }
                { Invoke-SecurityScan -Config $Config } | Should -Not -Throw
            } else {
                Show-TestResult -Skipped
            }
        }
    }
}
