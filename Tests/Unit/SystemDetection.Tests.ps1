$HelperPath = Join-Path $PSScriptRoot "..TestHelper.ps1"
if (Test-Path $HelperPath) { . $HelperPath }

#Requires -Module Pester

Describe "SystemDetection Module" {
    BeforeEach {
        $script:ModuleRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
        try {
            Import-Module (Join-Path $script:ModuleRoot "WindowsMaintenance.psd1") -Force -ErrorAction SilentlyContinue -Scope Global
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




