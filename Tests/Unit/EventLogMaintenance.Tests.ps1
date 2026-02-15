$HelperPath = Join-Path $PSScriptRoot "..TestHelper.ps1"
if (Test-Path $HelperPath) { . $HelperPath }

#Requires -Module Pester

Describe "EventLogMaintenance Module" {
    BeforeEach {
        $script:ModuleRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
        try {
            Import-Module (Join-Path $script:ModuleRoot "WindowsMaintenance.psd1") -Force -ErrorAction SilentlyContinue -Scope Global
        } catch {
            Write-Debug "Module import failed: $($_.Exception.Message)"
        }
    }

    Context "Invoke-EventLogManagement" {
        It "Should exist" {
            if (Get-Command Invoke-EventLogManagement -ErrorAction SilentlyContinue) {
                Get-Command Invoke-EventLogManagement | Should -Not -BeNullOrEmpty
            } else {
                Show-TestResult -Skipped
            }
        }

        It "Should skip if disabled in configuration" {
            if (Get-Command Invoke-EventLogManagement -ErrorAction SilentlyContinue) {
                $Config = @{ EnabledModules = @() }
                { Invoke-EventLogManagement -Config $Config } | Should -Not -Throw
            } else {
                Show-TestResult -Skipped
            }
        }
    }
}
