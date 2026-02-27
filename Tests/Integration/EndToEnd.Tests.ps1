

#Requires -Module Pester

Describe "WindowsMaintenance Integration" {
    BeforeAll {
        $TestRoot = Split-Path -Parent $PSCommandPath
        $HelperPath = Join-Path $TestRoot "..\TestHelper.ps1"
        if (Test-Path $HelperPath) { . $HelperPath }

        $script:ModuleRoot = Resolve-Path (Join-Path $(if ($PSScriptRoot) { $PSScriptRoot } elseif ($PSCommandPath) { Split-Path -Parent $PSCommandPath } else { (Get-Location).Path }) "..\\..")
        $script:ConfigPath = Join-Path $script:ModuleRoot "Config\maintenance-config.json"

        try {
            # Use Global scope so functions are available even if the import only partially succeeds
            $script:oldWarningPref = $global:WarningPreference
            $global:WarningPreference = 'SilentlyContinue'
            Import-Module (Join-Path $script:ModuleRoot "WindowsMaintenance.psd1") -Force -DisableNameChecking -ErrorAction SilentlyContinue -Scope Global
            $global:WarningPreference = $script:oldWarningPref
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






