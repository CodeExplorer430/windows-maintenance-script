Describe "${PLASTER_PARAM_ModuleName} Module" {
    $ModuleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    Import-Module (Join-Path $ModuleRoot "WindowsMaintenance.psd1") -Force

    Context "Invoke-${PLASTER_PARAM_ModuleName}" {
        It "Should exist" {
            (Get-Command Invoke-${PLASTER_PARAM_ModuleName}) | Should Not BeNullOrEmpty
        }
    }
}
