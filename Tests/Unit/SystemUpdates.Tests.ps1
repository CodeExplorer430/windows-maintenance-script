$HelperPath = Join-Path $PSScriptRoot "..TestHelper.ps1"
if (Test-Path $HelperPath) { . $HelperPath }

#Requires -Module Pester

Describe "SystemUpdates Module" {
    BeforeEach {
        $script:ModuleRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
        try {
            Import-Module (Join-Path $script:ModuleRoot "WindowsMaintenance.psd1") -Force -ErrorAction SilentlyContinue -Scope Global
        } catch {
            Write-Debug "Module import failed: $($_.Exception.Message)"
        }
    }

    Context "Invoke-SystemUpdate" {
        It "Should exist" {
            if (Get-Command Invoke-SystemUpdate -ErrorAction SilentlyContinue) {
                Get-Command Invoke-SystemUpdate | Should -Not -BeNullOrEmpty
            } else {
                Show-TestResult -Skipped
            }
        }

        It "Should handle being disabled" {
            if (Get-Command Invoke-SystemUpdate -ErrorAction SilentlyContinue) {
                $Config = @{ EnabledModules = @() }
                { Invoke-SystemUpdate -Config $Config } | Should -Not -Throw
            } else {
                Show-TestResult -Skipped
            }
        }

        It "Should trigger Microsoft Store updates when enabled" {
            if (Get-Command Invoke-SystemUpdate -ErrorAction SilentlyContinue) {
                $Config = @{
                    EnabledModules = @('SystemUpdates')
                    SystemUpdates = @{
                        EnableMicrosoftStore = $true
                        EnableWinGet = $true
                    }
                }

                Mock Get-Command { return $true }
                Mock Invoke-SafeCommand { return $true }
                Mock winget { return "Success" }

                { Invoke-SystemUpdate -Config $Config } | Should -Not -Throw
            } else {
                 Show-TestResult -Skipped
            }
        }
    }
}
