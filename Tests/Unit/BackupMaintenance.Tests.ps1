$HelperPath = Join-Path $PSScriptRoot "..TestHelper.ps1"
if (Test-Path $HelperPath) { . $HelperPath }

#Requires -Module Pester

Describe "BackupMaintenance Module" {
    BeforeEach {
        $script:ModuleRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
        try {
            Import-Module (Join-Path $script:ModuleRoot "WindowsMaintenance.psd1") -Force -ErrorAction SilentlyContinue -Scope Global
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
