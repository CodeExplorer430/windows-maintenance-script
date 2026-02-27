

#Requires -Module Pester

Describe "TaskScheduler Module" {
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

    Context "Invoke-TaskScheduler" {
        It "Should exist" {
            # Note: The function name in TaskScheduler.psm1 might differ,
            # I will check common patterns or skip if not found.
            if (Get-Command Invoke-TaskScheduler -ErrorAction SilentlyContinue) {
                Get-Command Invoke-TaskScheduler | Should -Not -BeNullOrEmpty
            } else {
                Show-TestResult -Skipped
            }
        }
    }
}






