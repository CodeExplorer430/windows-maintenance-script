<#
.SYNOPSIS
    Modularized .NET 8 GUI Launcher for the Windows Maintenance Framework.

.DESCRIPTION
    Integrates the modular View, Theme, and Controller components to provide
    a responsive, modern maintenance interface. Optimized for PowerShell 7.4.
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigPath
)

# Load required .NET assemblies (WPF)
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# Determine component paths
$GuiDir = Join-Path (Split-Path $PSScriptRoot) "GUI"
$ThemePath = Join-Path $GuiDir "Theme.ps1"
$ViewPath = Join-Path $GuiDir "View.ps1"
$ControllerPath = Join-Path $GuiDir "Controller.ps1"

# Load Components
. $ThemePath      # Loads $script:UITheme and $script:UIFonts
. $ViewPath       # Loads Get-MaintenanceView
. $ControllerPath # Loads Initialize-MaintenanceUI, etc.

# Create UI (WPF View - Dumb Construction)
$Controls = Get-MaintenanceView -Theme $script:UITheme -Fonts $script:UIFonts

# Initialize Controller (Logic, Events, State)
$Timer = Initialize-MaintenanceUI -Controls $Controls -Theme $script:UITheme

# Show Initial Message
Show-UIConsoleUpdate -ConsoleControl $Controls.Console -Text "Modern WPF GUI initialized successfully."

if ($ConfigPath) {
    Show-UIConsoleUpdate -ConsoleControl $Controls.Console -Text "Using custom configuration: $ConfigPath"
}

if ($PSVersionTable.PSVersion.Major -ge 7) {
    Show-UIConsoleUpdate -ConsoleControl $Controls.Console -Text "PowerShell $($PSVersionTable.PSVersion) (Core) environment detected."
} else {
    Show-UIConsoleUpdate -ConsoleControl $Controls.Console -Text "PowerShell 5.1 (Desktop) environment detected."
}

# Run Window
$Controls.Window.ShowDialog() | Out-Null

# Cleanup
$Timer.Stop()
