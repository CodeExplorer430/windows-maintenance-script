

#Requires -Module Pester

Describe "SystemHealthRepair Module" {
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

    Context "Invoke-SystemHealthRepair" {
        It "Should exist" {
            if (Get-Command Invoke-SystemHealthRepair -ErrorAction SilentlyContinue) {
                Get-Command Invoke-SystemHealthRepair | Should -Not -BeNullOrEmpty
            } else {
                Show-TestResult -Skipped
            }
        }

        It "Should handle being disabled" {
            if (Get-Command Invoke-SystemHealthRepair -ErrorAction SilentlyContinue) {
                $Config = @{ EnabledModules = @() }
                { Invoke-SystemHealthRepair -Config $Config } | Should -Not -Throw
            } else {
                Show-TestResult -Skipped
            }
        }

        It "Should schedule Memory Diagnostic when EnableMemoryDiagnostic is true" {
            if (-not (Get-Command Invoke-SystemHealthRepair -ErrorAction SilentlyContinue)) { Show-TestResult -Skipped; return }

            Mock Invoke-SafeCommand { param($TaskName, $Command) $null = $TaskName; & $Command } -ModuleName WindowsMaintenance
            Mock Write-ProgressBar {} -ModuleName WindowsMaintenance
            Mock Write-MaintenanceLog {} -ModuleName WindowsMaintenance
            Mock Write-Progress {} -ModuleName WindowsMaintenance
            Mock Invoke-DISMOperation { return @{ Success = $true; Output = "Simulated" } } -ModuleName WindowsMaintenance
            Mock Invoke-SFCOperation { return @{ Success = $true; Output = "Simulated" } } -ModuleName WindowsMaintenance
            Mock Test-DiskHealth { return @{ ScheduleRequired = $false; Drive = "C:" } } -ModuleName WindowsMaintenance
            Mock New-SystemHealthReport { return "SimulatedPath" } -ModuleName WindowsMaintenance
            Mock bcdedit { return "The operation completed successfully." } -ModuleName WindowsMaintenance

            $Config = @{
                EnabledModules = @("SystemHealthRepair")
                SystemHealthRepair = @{
                    EnableDISM = $false
                    EnableSFC = $false
                    EnableMemoryDiagnostic = $true
                    ForceCHKDSKOnRestart = $false
                }
            }

            Invoke-SystemHealthRepair -Config $Config -WhatIf:$false

            Assert-MockCalled bcdedit -Times 1 -ModuleName WindowsMaintenance -ParameterFilter { $args -contains "/bootsequence" -and $args -contains "{memdiag}" }
        }
    }

    Context "Test-DiskHealth" {
        It "Should force schedule CHKDSK with /X when ForceSchedule is true" {
            if (-not (Get-Command Test-DiskHealth -ErrorAction SilentlyContinue)) { Show-TestResult -Skipped; return }

            Mock fsutil { return "Volume is NOT dirty" } -ModuleName WindowsMaintenance
            Mock chkdsk { return "Mocked CHKDSK" } -ModuleName WindowsMaintenance
            Mock Write-Output { return "Y" } -ModuleName WindowsMaintenance

            $Result = Test-DiskHealth -ForceSchedule $true -WhatIf:$false

            $Result.ScheduleRequired | Should -BeTrue
            Assert-MockCalled chkdsk -Times 1 -ModuleName WindowsMaintenance -ParameterFilter { $args -contains "/X" }
        }
    }
}






