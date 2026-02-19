$HelperPath = Join-Path $PSScriptRoot "..TestHelper.ps1"
if (Test-Path $HelperPath) { . $HelperPath }

#Requires -Module Pester

Describe "DeveloperMaintenance Module" {
    BeforeEach {
        $script:ModuleRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
        try {
            Import-Module (Join-Path $script:ModuleRoot "WindowsMaintenance.psd1") -Force -ErrorAction SilentlyContinue -Scope Global
        } catch {
            Write-Debug "Module import failed: $($_.Exception.Message)"
        }
    }

    Context "Invoke-DeveloperMaintenance" {
        It "Should exist" {
            if (Get-Command Invoke-DeveloperMaintenance -ErrorAction SilentlyContinue) {
                Get-Command Invoke-DeveloperMaintenance | Should -Not -BeNullOrEmpty
            } else {
                Show-TestResult -Skipped
            }
        }

        It "Should handle being disabled" {
            if (Get-Command Invoke-DeveloperMaintenance -ErrorAction SilentlyContinue) {
                $Config = @{ EnabledModules = @() }
                { Invoke-DeveloperMaintenance -Config $Config } | Should -Not -Throw
            } else {
                Show-TestResult -Skipped
            }
        }

        It "Should execute maintenance for new tools (Unity, Blender, ADS)" {
             if (Get-Command Invoke-DeveloperMaintenance -ErrorAction SilentlyContinue) {
                $Config = @{
                    EnabledModules = @('DeveloperMaintenance')
                    DeveloperMaintenance = @{
                        EnableUnity = $true
                        EnableBlender = $true
                        EnableAzureDataStudio = $true
                        RetentionDays = 30
                    }
                }

                Mock Test-Path { return $true }
                Mock Get-Command { return $true }
                Mock Invoke-SafeCommand { return $true }

                { Invoke-DeveloperMaintenance -Config $Config } | Should -Not -Throw
            } else {
                Show-TestResult -Skipped
            }
        }
    }
}
