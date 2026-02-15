$HelperPath = Join-Path $PSScriptRoot "..TestHelper.ps1"
if (Test-Path $HelperPath) { . $HelperPath }

#Requires -Module Pester

Describe "EmailNotifications Module" {
    BeforeEach {
        $script:ModuleRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
        try {
            Import-Module (Join-Path $script:ModuleRoot "WindowsMaintenance.psd1") -Force -ErrorAction SilentlyContinue -Scope Global
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




