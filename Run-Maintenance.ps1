<#
.SYNOPSIS
    Standalone launcher for the Windows Maintenance Framework.
#>

#Requires -Version 5.1

[CmdletBinding()]
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigPath,

    [switch]$Interactive = $false,
    [switch]$WhatIf = $false,
    [switch]$SilentMode = $false,
    [switch]$DetailedOutput = $false
)

# Set InformationPreference to ensure visibility of modern output
$InformationPreference = 'Continue'

$SpectreModule = Get-Module -ListAvailable -Name "PwshSpectreConsole"

if (-not $SpectreModule -and $PSVersionTable.PSVersion.Major -ge 7) {
    $installPrompt = Read-Host "PwshSpectreConsole is recommended for the CLI. Install it now? [Y/n]"
    if ([string]::IsNullOrWhiteSpace($installPrompt) -or $installPrompt.ToLower().StartsWith('y')) {
        Write-Host "Installing PwshSpectreConsole from PSGallery..." -ForegroundColor Cyan
        Install-Module -Name PwshSpectreConsole -Scope CurrentUser -Force -AllowClobber -ErrorAction SilentlyContinue
        $SpectreModule = Get-Module -ListAvailable -Name "PwshSpectreConsole"
    }
}

if ($PSVersionTable.PSVersion.Major -ge 7 -and $SpectreModule) {
    Import-Module PwshSpectreConsole -Force
    Clear-Host

    $ManifestPath = Join-Path $PSScriptRoot "WindowsMaintenance.psd1"
    if (Test-Path $ManifestPath) {
        $Manifest = Import-PowerShellDataFile -Path $ManifestPath
        $Version = $Manifest.ModuleVersion
        $Author = $Manifest.Author
        $Desc = $Manifest.Description
    } else {
        $Version = "Unknown"
        $Author = "Unknown"
        $Desc = "Windows Maintenance Framework"
    }

    Write-SpectreFiglet -Text "Win Maintenance" -Color Cyan
    $InfoText = "[grey]v$Version[/] | [grey]By $Author[/] | [grey]CLI Mode[/]"
    Write-SpectreRule -Title $InfoText -Color DarkGray
    Write-SpectreHost ""
    Write-SpectreHost "  [white]$Desc[/]"
    Write-SpectreHost ""
} else {
    Clear-Host
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Windows Maintenance Framework" -ForegroundColor Cyan
    Write-Host "  PowerShell: $($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor) ($($PSVersionTable.PSEdition))" -ForegroundColor DarkGray
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

# Performance Tip: Suggest PowerShell 7
if ($PSVersionTable.PSVersion.Major -lt 7 -and (Get-Command pwsh -ErrorAction SilentlyContinue)) {
    Write-Output "TIP: PowerShell 7+ detected on system. Run with 'pwsh' for parallel performance features."
}

# Helper: Test Admin
function Test-IsAdmin {
    $current = [Security.Principal.WindowsIdentity]::GetCurrent()
    $princ = New-Object Security.Principal.WindowsPrincipal($current)
    return $princ.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    Write-Error "This script requires Administrator privileges."
    exit 1
}

# Paths
$ScriptRoot = $PSScriptRoot
$ModulePath = Join-Path $ScriptRoot "WindowsMaintenance.psm1"
if (-not $ConfigPath) { $ConfigPath = Join-Path $ScriptRoot "Config\maintenance-config.json" }

# Interactive TUI launcher
if ($Interactive) {
    $TuiPath = Join-Path $ScriptRoot "Tools\Start-MaintenanceTUI.ps1"
    if (Test-Path $TuiPath) {
        & $TuiPath -ConfigPath $ConfigPath
        exit $LASTEXITCODE
    }
}

# Load Module
try {
    # Suppress verbose output for import to avoid "Removing imported function" noise
    $OldVerbose = $VerbosePreference
    if ($VerbosePreference -eq 'Continue') { $VerbosePreference = 'SilentlyContinue' }
    Import-Module $ModulePath -Force -ErrorAction Stop
    $VerbosePreference = $OldVerbose
    Write-Output "Module loaded successfully."
} catch {
    Write-Error "Failed to load WindowsMaintenance module: $($_.Exception.Message)"
    exit 1
}

# Execute
try {
    Invoke-WindowsMaintenance -ConfigPath $ConfigPath -SilentMode:$SilentMode -DetailedOutput:$DetailedOutput -WhatIf:$WhatIf
} catch {
    Write-Error "Maintenance failed: $($_.Exception.Message)"
    exit 1
}

Write-Output "========================================"
Write-Output "  Maintenance Complete!"
Write-Output "========================================"
