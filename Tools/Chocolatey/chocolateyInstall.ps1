$ErrorActionPreference = 'Stop'

$PackageName = 'windows-maintenance-framework'
$InstallDir  = Join-Path $env:ProgramData $PackageName

# Unzip artifact
Get-ChocolateyUnzip -FileFullPath $fileLocation -Destination $InstallDir

# Create shim for CLI
$ShimPath = Join-Path $InstallDir "Run-Maintenance.ps1"
Install-BinFile -Name "maintain-windows" -Path $ShimPath

# Create shortcut for GUI
$GuiPath = Join-Path $InstallDir "Tools\Start-MaintenanceGUI.ps1"
Install-ChocolateyShortcut -ShortcutFilePath "$env:Public\Desktop\Windows Maintenance.lnk" -TargetPath "powershell.exe" -Arguments "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$GuiPath`"" -IconUrl "https://raw.githubusercontent.com/CodeExplorer430/windows-maintenance-script/main/media/icon.png" -RunAsAdmin

Write-Output "Windows Maintenance Framework installed to $InstallDir"
