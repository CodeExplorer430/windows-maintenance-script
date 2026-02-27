<#
.SYNOPSIS
    Optional TUI launcher for the Windows Maintenance Framework.
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigPath
)

function Test-IsAdmin {
    $current = [Security.Principal.WindowsIdentity]::GetCurrent()
    $princ = New-Object Security.Principal.WindowsPrincipal($current)
    return $princ.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    Write-Error "This script requires Administrator privileges."
    exit 1
}

$ScriptRoot = Split-Path $PSScriptRoot
if (-not $ConfigPath) {
    $ConfigPath = Join-Path $ScriptRoot "Config\maintenance-config.json"
}

Import-Module (Join-Path $ScriptRoot "WindowsMaintenance.psm1") -Force
Import-Module (Join-Path $ScriptRoot "Modules\Common\AppInventory.psm1") -Force

function ConvertTo-Hashtable {
    param([object]$InputObject)

    if ($null -eq $InputObject) { return @{} }
    if ($InputObject -is [hashtable]) { return $InputObject }

    $Table = @{}
    $InputObject.PSObject.Properties | ForEach-Object {
        $Table[$_.Name] = $_.Value
    }
    return $Table
}

function Read-ConfigFile {
    param([string]$Path)

    if (-not (Test-Path $Path)) { return @{} }
    $Raw = Get-Content -Path $Path -Raw
    if (-not $Raw) { return @{} }
    $Obj = $Raw | ConvertFrom-Json
    ConvertTo-Hashtable $Obj
}

function Merge-Config {
    param(
        [hashtable]$Base,
        [hashtable]$Override
    )

    foreach ($Key in $Override.Keys) {
        $BaseValue = $Base[$Key]
        $OverrideValue = $Override[$Key]

        if ($BaseValue -is [hashtable] -and $OverrideValue -is [hashtable]) {
            $Base[$Key] = Merge-Config -Base $BaseValue -Override $OverrideValue
        } elseif ($BaseValue -is [pscustomobject] -and $OverrideValue -is [pscustomobject]) {
            $Base[$Key] = Merge-Config -Base (ConvertTo-Hashtable $BaseValue) -Override (ConvertTo-Hashtable $OverrideValue)
        } else {
            $Base[$Key] = $OverrideValue
        }
    }
    return $Base
}

function Get-TuiConfig {
    param([string]$ConfigPath)

    $Config = Read-ConfigFile -Path $ConfigPath
    $UserConfigPath = Join-Path (Split-Path $ConfigPath) "maintenance-config.user.json"
    if (Test-Path $UserConfigPath) {
        $UserConfig = Read-ConfigFile -Path $UserConfigPath
        $Config = Merge-Config -Base $Config -Override $UserConfig
    }

    if (-not $Config.AppCatalogPath) {
        $Config.AppCatalogPath = Join-Path $ScriptRoot "Config\app-catalog.json"
    } elseif (-not [System.IO.Path]::IsPathRooted($Config.AppCatalogPath)) {
        $Config.AppCatalogPath = Join-Path (Split-Path $ConfigPath) $Config.AppCatalogPath
    }

    return @{
        Config = $Config
        UserConfigPath = $UserConfigPath
    }
}

function Read-MultiSelection {
    param(
        [string]$Title,
        [string[]]$Choices,
        [string[]]$Default = @()
    )

    $Cmd = Get-Command -Name "Read-SpectreMultiSelection" -ErrorAction SilentlyContinue
    if ($Cmd) {
        return & $Cmd -Title $Title -Choices $Choices -Default $Default
    }

    $Cmd = Get-Command -Name "Get-SpectreMultiSelection" -ErrorAction SilentlyContinue
    if ($Cmd) {
        return & $Cmd -Title $Title -Choices $Choices -Default $Default
    }

    Write-Output $Title
    for ($i = 0; $i -lt $Choices.Count; $i++) {
        $Marker = if ($Choices[$i] -in $Default) { "*" } else { " " }
        Write-Output " [$Marker] $($i + 1). $($Choices[$i])"
    }
    $UserInput = Read-Host "Enter comma-separated numbers"
    if (-not $UserInput) { return $Default }
    $Indexes = $UserInput -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' }
    $Selected = @()
    foreach ($Idx in $Indexes) {
        $Pos = [int]$Idx - 1
        if ($Pos -ge 0 -and $Pos -lt $Choices.Count) {
            $Selected += $Choices[$Pos]
        }
    }
    return $Selected
}

function Read-YesNo {
    param([string]$Prompt, [bool]$Default = $false)

    $Suffix = if ($Default) { "Y/n" } else { "y/N" }
    $UserInput = Read-Host "$Prompt [$Suffix]"
    if (-not $UserInput) { return $Default }
    return $UserInput.ToLowerInvariant().StartsWith("y")
}

$SpectreModule = Get-Module -ListAvailable -Name "PwshSpectreConsole"
if ($PSVersionTable.PSVersion.Major -ge 7 -and $SpectreModule) {
    Import-Module PwshSpectreConsole -Force
}

$ConfigState = Get-TuiConfig -ConfigPath $ConfigPath
$Config = $ConfigState.Config
$UserConfigPath = $ConfigState.UserConfigPath

$ModuleChoices = $Config.EnabledModules
$SelectedModules = Read-MultiSelection -Title "Select maintenance modules" -Choices $ModuleChoices -Default $ModuleChoices

$WhatIf = Read-YesNo -Prompt "Enable WhatIf (simulation)?" -Default $true
$Silent = Read-YesNo -Prompt "Enable Silent mode?" -Default $false
$Detailed = Read-YesNo -Prompt "Enable Detailed output?" -Default $false

$Sources = if ($Config.AppSources) { ConvertTo-Hashtable $Config.AppSources } else { @{ Winget = $true; Registry = $true; Store = $true } }
$AppModel = Get-AppSelectionModel -Config $Config -CatalogPath $Config.AppCatalogPath -Sources $Sources
$AppChoices = $AppModel | ForEach-Object { $_.DisplayName }
$DefaultApps = $AppModel | Where-Object { $_.Selected } | ForEach-Object { $_.DisplayName }

$SelectedApps = Read-MultiSelection -Title "Select apps for maintenance toggles" -Choices $AppChoices -Default $DefaultApps

$Selections = @{}
foreach ($Entry in $AppModel) {
    if ($Entry.DisplayName -notin $SelectedApps) { continue }
    foreach ($Map in ($Entry.ModuleMappings | ForEach-Object { $_ })) {
        $Module = $Map.Module
        if (-not $Module) { continue }
        if (-not $Selections.ContainsKey($Module)) { $Selections[$Module] = @() }
        $Selections[$Module] += $Entry.Id
    }
}

Write-AppSelectionOverride -Path $UserConfigPath -Selections $Selections

Invoke-WindowsMaintenance -ConfigPath $ConfigPath -SilentMode:$Silent -DetailedOutput:$Detailed -WhatIf:$WhatIf -EnabledModulesOverride $SelectedModules
