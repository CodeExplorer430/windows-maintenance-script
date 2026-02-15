<#
.SYNOPSIS
    Standalone launcher for the Windows Maintenance Framework.
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigPath,

    [switch]$WhatIf = $false,
    [switch]$SilentMode = $false
)

# Set InformationPreference to ensure visibility of modern output
$InformationPreference = 'Continue'

Write-Output "========================================"
Write-Output "  Windows Maintenance Framework v4.0.0"
Write-Output "  PowerShell: $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))"
Write-Output "========================================"

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

# Load Module
try {
    Import-Module $ModulePath -Force -ErrorAction Stop
    Write-Output "Module loaded successfully."
} catch {
    Write-Error "Failed to load WindowsMaintenance module: $($_.Exception.Message)"
    exit 1
}

# Execute
try {
    Invoke-WindowsMaintenance -ConfigPath $ConfigPath -SilentMode $SilentMode -WhatIf:$WhatIf
} catch {
    Write-Error "Maintenance failed: $($_.Exception.Message)"
    exit 1
}

Write-Output "========================================"
Write-Output "  Maintenance Complete!"
Write-Output "========================================"
