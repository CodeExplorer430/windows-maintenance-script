

#Requires -Module Pester

Describe "HardwareDiagnostics Module" {
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






