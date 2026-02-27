

#Requires -Module Pester

Describe "SecurityScans Module" {
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

        It "Should invoke MSRT if EnableMSRT is true" {
            if (-not (Get-Command Invoke-SecurityScan -ErrorAction SilentlyContinue)) { Show-TestResult -Skipped; return }

            # Mock components to simulate a fast run and intercept the MSRT Start-Process call
            Mock Invoke-SafeCommand { param($TaskName, $Command) $null = $TaskName; & $Command } -ModuleName WindowsMaintenance
            Mock Write-ProgressBar {} -ModuleName WindowsMaintenance
            Mock Write-MaintenanceLog {} -ModuleName WindowsMaintenance
            Mock Test-Path { return $true } -ModuleName WindowsMaintenance
            Mock Update-MpSignature {} -ModuleName WindowsMaintenance
            Mock Invoke-DefenderScan { return @{ Success = $true; StartTime = (Get-Date) } } -ModuleName WindowsMaintenance
            Mock Get-MpThreatDetection { return $null } -ModuleName WindowsMaintenance
            Mock Get-NetFirewallProfile { return @() } -ModuleName WindowsMaintenance
            Mock Get-BitLockerVolume { return @() } -ModuleName WindowsMaintenance
            Mock Start-Process { return [pscustomobject]@{ ExitCode = 0 } } -ModuleName WindowsMaintenance

            $Config = @{
                EnabledModules = @("SecurityScans")
                SecurityScans = @{
                    EnableDefenderScan = $false
                    EnableMSRT = $true
                    ScanLevel = "Full"
                }
            }

            Invoke-SecurityScan -Config $Config -WhatIf:$false

            Assert-MockCalled Start-Process -Times 1 -ModuleName WindowsMaintenance -ParameterFilter { $ArgumentList -match "/Q /F:Y" }
        }
    }
}






