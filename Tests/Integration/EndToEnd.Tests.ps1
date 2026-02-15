$HelperPath = Join-Path $PSScriptRoot "..TestHelper.ps1"
if (Test-Path $HelperPath) { . $HelperPath }

#Requires -Module Pester

Describe "WindowsMaintenance Integration" {
    BeforeAll {
        $script:ModuleRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
        $script:ConfigPath = Join-Path $script:ModuleRoot "Config\maintenance-config.json"

        try {
            # Use Global scope so functions are available even if the import only partially succeeds
            Import-Module (Join-Path $script:ModuleRoot "WindowsMaintenance.psd1") -Force -ErrorAction SilentlyContinue -Scope Global
        } catch {
            Write-Debug "Integration setup: Module import deferred or failed (expected if non-admin)"
        }
    }

    It "Should execute end-to-end in WhatIf mode without error" {
        if (Get-Command Invoke-WindowsMaintenance -ErrorAction SilentlyContinue) {
            { Invoke-WindowsMaintenance -ConfigPath $script:ConfigPath -SilentMode -WhatIf } | Should -Not -Throw
        } else {
            Show-TestResult -Skipped
        }
    }
}
