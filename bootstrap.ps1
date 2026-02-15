<#
.SYNOPSIS
    One-line bootstrapper for Windows Maintenance Framework.
    Usage: iex (irm https://raw.githubusercontent.com/Miguel/windows-maintenance-script/main/Bootstrap.ps1)
#>

$ErrorActionPreference = 'Stop'
$Repo = "Miguel/windows-maintenance-script"
$Version = "v4.2.0"
$Url = "https://github.com/$Repo/releases/download/$Version/WindowsMaintenance-$Version.zip"
$Dest = "$env:ProgramData\WindowsMaintenance"

Write-Output "========================================"
Write-Output "  Windows Maintenance Framework Setup"
Write-Output "========================================`n"

# 1. Check Elevation
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "CRITICAL: Administrator privileges are required. Please relaunch PowerShell as Administrator."
    exit 1
}

# 2. Download and Install
try {
    Write-Host "-> Downloading Framework ($Version)..." -ForegroundColor Cyan
    if (!(Test-Path $Dest)) { New-Item -ItemType Directory -Path $Dest -Force | Out-Null }

    $ZipPath = Join-Path $env:TEMP "wm_setup.zip"
    Invoke-WebRequest -Uri $Url -OutFile $ZipPath -UseBasicParsing

    Write-Host "-> Extracting files to $Dest..." -ForegroundColor Cyan
    Expand-Archive -Path $ZipPath -DestinationPath $Dest -Force
    Remove-Item $ZipPath -Force

    # 3. Register Module
    $ModulePath = Join-Path $Dest "WindowsMaintenance.psd1"
    if (Test-Path $ModulePath) {
        Write-Host "-> Registering module..." -ForegroundColor Green
        Import-Module $ModulePath -Force
    }

    # 4. Finalize
    Write-Host "`nSUCCESS: Windows Maintenance Framework installed successfully!" -ForegroundColor Green
    Write-Host "Documentation: https://miguel.github.io/windows-maintenance-script/`n" -ForegroundColor Yellow

    # Non-interactive check for scheduling
    if ($Host.Name -ne "ConsoleHost" -or $env:WM_QUIET -eq "true") {
        Write-Host "Skipping interactive scheduling (non-interactive host detected)."
    } else {
        $Response = Read-Host "Would you like to schedule a weekly maintenance task now? (Y/N)"
        if ($Response -eq 'Y' -or $Response -eq 'y') {
            & "$Dest\Tools\Install-MaintenanceTask.ps1" -Schedule Weekly -Quiet
            Write-Host "Weekly task scheduled." -ForegroundColor Green
        }
    }

    Write-Host "`nYou can now run 'Invoke-WindowsMaintenance' to start." -ForegroundColor Cyan
}
catch {
    Write-Error "Installation failed: $($_.Exception.Message)"
    exit 1
}
