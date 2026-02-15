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

# Load required .NET assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Determine component paths
$GuiDir = Join-Path (Split-Path $PSScriptRoot) "GUI"
$ThemePath = Join-Path $GuiDir "Theme.ps1"
$ViewPath = Join-Path $GuiDir "View.ps1"
$ControllerPath = Join-Path $GuiDir "Controller.ps1"

# Load Components
. $ThemePath      # Loads $script:UITheme and $script:UIFonts
. $ViewPath       # Loads Get-MaintenanceView
. $ControllerPath # Loads event handler functions

# Create UI
$Controls = Get-MaintenanceView -Theme $script:UITheme -Fonts $script:UIFonts

# Register Event Handlers
$Controls.StartBtn.Add_Click({ Invoke-StartMaintenanceUI -Controls $Controls })
$Controls.StopBtn.Add_Click({ Invoke-MaintenanceUIStop -Controls $Controls })

# Initialize Timer for UI Updates
$Timer = New-Object System.Windows.Forms.Timer
$Timer.Interval = 500
$Timer.Add_Tick({ Receive-MaintenanceTimerUIUpdate -Controls $Controls })
$Timer.Start()

# Show Initial Message
Show-UIConsoleUpdate -ConsoleControl $Controls.Console -Text "Modern GUI initialized successfully."

if ($ConfigPath) {
    Show-UIConsoleUpdate -ConsoleControl $Controls.Console -Text "Using custom configuration: $ConfigPath"
}

if ($PSVersionTable.PSVersion.Major -ge 7) {
    Show-UIConsoleUpdate -ConsoleControl $Controls.Console -Text "PowerShell $($PSVersionTable.PSVersion) (Core) environment detected."
} else {
    Show-UIConsoleUpdate -ConsoleControl $Controls.Console -Text "PowerShell 5.1 (Desktop) environment detected. Parallel features disabled."
}

# Run Form
$Controls.Form.ShowDialog() | Out-Null

# Cleanup
$Timer.Stop()
$Timer.Dispose()
