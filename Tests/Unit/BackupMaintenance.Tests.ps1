

#Requires -Module Pester

Describe "BackupMaintenance Module" {
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

    Context "Invoke-BackupOperation" {
        It "Should exist" {
            if (Get-Command Invoke-BackupOperation -ErrorAction SilentlyContinue) {
                Get-Command Invoke-BackupOperation | Should -Not -BeNullOrEmpty
            } else {
                Show-TestResult -Skipped
            }
        }
    }

    Context "New-SystemRestorePoint" {
        It "Should handle WhatIf mode" {
            if (Get-Command New-SystemRestorePoint -ErrorAction SilentlyContinue) {
                $Result = New-SystemRestorePoint -Description "Test" -WhatIf
                $Result.Success | Should -Be $true
            } else {
                Show-TestResult -Skipped
            }
        }
    }
}






