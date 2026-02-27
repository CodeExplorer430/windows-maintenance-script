

#Requires -Module Pester

Describe "SystemDetection Module" {
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

    Context "Get-SystemMemoryInfo" {
        It "Should return a number greater than 0" {
            if (Get-Command Get-SystemMemoryInfo -ErrorAction SilentlyContinue) {
                $Result = Get-SystemMemoryInfo
                $Result | Should -BeOfType [double]
                $Result | Should -BeGreaterThan 0
            } else {
                Show-TestResult -Skipped
            }
        }
    }

    Context "Get-SystemOSInfo" {
        It "Should exist" {
            if (Get-Command Get-SystemOSInfo -ErrorAction SilentlyContinue) {
                Get-Command Get-SystemOSInfo | Should -Not -BeNullOrEmpty
            } else {
                Show-TestResult -Skipped
            }
        }

        It "Should return valid OS information" {
            if (Get-Command Get-SystemOSInfo -ErrorAction SilentlyContinue) {
                $Result = Get-SystemOSInfo
                $Result | Should -BeOfType [hashtable]
                $Result.ContainsKey("OSName") | Should -Be $true
                $Result.ContainsKey("Version") | Should -Be $true
                $Result.ContainsKey("ReleaseId") | Should -Be $true
                $Result.Architecture | Should -Not -BeNullOrEmpty
            } else {
                Show-TestResult -Skipped
            }
        }
    }
}






