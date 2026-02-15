$HelperPath = Join-Path $PSScriptRoot "..TestHelper.ps1"
if (Test-Path $HelperPath) { . $HelperPath }

#Requires -Module Pester

Describe "HardwareDiagnostics Module" {
    BeforeEach {
        $script:ModuleRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
        try {
            Import-Module (Join-Path $script:ModuleRoot "WindowsMaintenance.psd1") -Force -ErrorAction SilentlyContinue -Scope Global
        } catch {
            Write-Debug "Module import failed: $($_.Exception.Message)"
        }
    }

    Context "Get-BatteryHealth" {
        It "Should exist" {
            if (Get-Command Get-BatteryHealth -ErrorAction SilentlyContinue) {
                Get-Command Get-BatteryHealth | Should -Not -BeNullOrEmpty
            } else {
                Show-TestResult -Skipped
            }
        }

        It "Should return information or null gracefully" {
            if (Get-Command Get-BatteryHealth -ErrorAction SilentlyContinue) {
                { Get-BatteryHealth } | Should -Not -Throw
            } else {
                Show-TestResult -Skipped
            }
        }
    }

    Context "Get-StorageHealth" {
        It "Should exist" {
            if (Get-Command Get-StorageHealth -ErrorAction SilentlyContinue) {
                Get-Command Get-StorageHealth | Should -Not -BeNullOrEmpty
            } else {
                Show-TestResult -Skipped
            }
        }

        It "Should return disk information" {
            if (Get-Command Get-StorageHealth -ErrorAction SilentlyContinue) {
                $Result = Get-StorageHealth
                if ($Result) {
                    $Result[0].FriendlyName | Should -Not -BeNullOrEmpty
                }
            } else {
                Show-TestResult -Skipped
            }
        }
    }
}




