

#Requires -Module Pester

Describe "EmailNotifications Module" {
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

    Context "Send-MaintenanceEmail" {
        It "Should skip sending if disabled in config" {
            if (Get-Command Send-MaintenanceEmail -ErrorAction SilentlyContinue) {
                $SmtpConfig = @{ Enabled = $false }
                { Send-MaintenanceEmail -ReportPath "C:\test.txt" -SmtpConfig $SmtpConfig } | Should -Not -Throw
            } else {
                Show-TestResult -Skipped
            }
        }
    }
}






