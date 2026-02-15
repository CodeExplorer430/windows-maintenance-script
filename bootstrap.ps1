<#
.SYNOPSIS
    One-line bootstrapper for Windows Maintenance Framework.
    Usage: iex (irm https://raw.githubusercontent.com/CodeExplorer430/windows-maintenance-script/main/Bootstrap.ps1)
#>

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'
$Repo = "CodeExplorer430/windows-maintenance-script"
$Version = "v4.2.0"
$Url = "https://github.com/$Repo/releases/download/$Version/WindowsMaintenance-$Version.zip"
$Dest = "$env:ProgramData\WindowsMaintenance"

Write-Information -MessageData "========================================" -Tags "Color:Cyan"
Write-Information -MessageData "  Windows Maintenance Framework Setup" -Tags "Color:Cyan"
Write-Information -MessageData "========================================`n" -Tags "Color:Cyan"

# 1. Check Elevation
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "CRITICAL: Administrator privileges are required. Please relaunch PowerShell as Administrator."
    exit 1
}

# 2. Download and Install
try {
    Write-Information -MessageData "-> Downloading Framework ($Version)..." -Tags "Color:Cyan"
    if (!(Test-Path $Dest)) { New-Item -ItemType Directory -Path $Dest -Force | Out-Null }

    $ZipPath = Join-Path $env:TEMP "wm_setup.zip"
    Invoke-WebRequest -Uri $Url -OutFile $ZipPath -UseBasicParsing

    Write-Information -MessageData "-> Extracting files to $Dest..." -Tags "Color:Cyan"
    Expand-Archive -Path $ZipPath -DestinationPath $Dest -Force
    Remove-Item $ZipPath -Force

    # 3. Register Module
    $ModulePath = Join-Path $Dest "WindowsMaintenance.psd1"
    if (Test-Path $ModulePath) {
        Write-Information -MessageData "-> Registering module..." -Tags "Color:Green"
        Import-Module $ModulePath -Force
    }

    # 4. Finalize
    Write-Information -MessageData "`nSUCCESS: Windows Maintenance Framework installed successfully!" -Tags "Color:Green"
    Write-Information -MessageData "Documentation: https://codeexplorer430.github.io/windows-maintenance-script/`n" -Tags "Color:Yellow"

    # Non-interactive check for scheduling
    if ($Host.Name -ne "ConsoleHost" -or $env:WM_QUIET -eq "true") {
        Write-Information -MessageData "Skipping interactive scheduling (non-interactive host detected)." -Tags "Color:Gray"
    } else {
        $Response = Read-Host "Would you like to schedule a weekly maintenance task now? (Y/N)"
        if ($Response -eq 'Y' -or $Response -eq 'y') {
            & "$Dest\Tools\Install-MaintenanceTask.ps1" -Schedule Weekly -Quiet
            Write-Information -MessageData "Weekly task scheduled." -Tags "Color:Green"
        }
    }

    Write-Information -MessageData "`nYou can now run 'Invoke-WindowsMaintenance' to start." -Tags "Color:Cyan"
}
catch {
    Write-Error "Installation failed: $($_.Exception.Message)"
    exit 1
}
