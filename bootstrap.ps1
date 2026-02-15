<#
.SYNOPSIS
    One-line bootstrapper for Windows Maintenance Framework.
    Usage: iex (irm https://raw.githubusercontent.com/Miguel/windows-maintenance-script/main/bootstrap.ps1)
#>

$ErrorActionPreference = 'Stop'
$Repo = "Miguel/windows-maintenance-script"
$Version = "v4.2.0" # Should be dynamic in production
$Url = "https://github.com/$Repo/releases/download/$Version/WindowsMaintenance-$Version.zip"
$Dest = "$env:ProgramData\WindowsMaintenance"

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Please run this bootstrapper as Administrator."
    exit 1
}

Write-Output "Downloading Windows Maintenance Framework ($Version)..." -ForegroundColor Cyan
if (!(Test-Path $Dest)) { New-Item -ItemType Directory -Path $Dest | Out-Null }

$ZipPath = "$env:TEMP\wm.zip"
Invoke-WebRequest -Uri $Url -OutFile $ZipPath

Write-Output "Installing..." -ForegroundColor Cyan
Expand-Archive -Path $ZipPath -DestinationPath $Dest -Force
Remove-Item $ZipPath

# Register Module
$ModulePath = "$Dest\WindowsMaintenance.psd1"
if (Test-Path $ModulePath) {
    Write-Output "Registering module..." -ForegroundColor Green
    # In a real scenario, we might add to PSModulePath, but here we just verify it works
    Import-Module $ModulePath -Force
}

# Ask to schedule
$Response = Read-Host "Schedule weekly maintenance now? (Y/N)"
if ($Response -eq 'Y') {
    & "$Dest\Tools\Install-MaintenanceTask.ps1" -Schedule Weekly -Quiet
}

Write-Output "Done! Run 'Invoke-WindowsMaintenance' to start." -ForegroundColor Green
