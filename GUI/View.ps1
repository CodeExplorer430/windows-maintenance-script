<#
.SYNOPSIS
    GUI View Construction for the Windows Maintenance Framework.
#>

function New-MaintenanceView {
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Theme,

        [Parameter(Mandatory=$true)]
        [hashtable]$Fonts
    )

    # Initialize Form
    $Form = New-Object System.Windows.Forms.Form
    $Form.Text = "Windows Maintenance Framework v4.2.0"
    $Form.Size = "900, 800"
    $Form.StartPosition = "CenterScreen"
    $Form.BackColor = $Theme.Background
    $Form.Font = $Fonts.Standard

    # --- Header ---
    $Header = New-Object System.Windows.Forms.Label
    $Header.Text = "System Maintenance Dashboard"
    $Header.Font = $Fonts.Header
    $Header.Location = "20, 20"
    $Header.Size = "600, 40"
    $Form.Controls.Add($Header)

    # --- Privilege Status ---
    $StatusLabel = New-Object System.Windows.Forms.Label
    $IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $StatusLabel.Text = if ($IsAdmin) { "Elevated Session: ACTIVE" } else { "NON-ELEVATED SESSION: LIMITED" }
    $StatusLabel.ForeColor = if ($IsAdmin) { $Theme.Success } else { $Theme.Error }
    $StatusLabel.Location = "20, 65"
    $StatusLabel.Size = "400, 25"
    $Form.Controls.Add($StatusLabel)

    # --- Module List Group ---
    $GroupModules = New-Object System.Windows.Forms.GroupBox
    $GroupModules.Text = "Select Modules"
    $GroupModules.Location = "20, 100"
    $GroupModules.Size = "400, 300"
    $Form.Controls.Add($GroupModules)

    $ModuleList = New-Object System.Windows.Forms.CheckedListBox
    $ModuleList.Location = "10, 25"
    $ModuleList.Size = "380, 260"
    $ModuleList.BorderStyle = "None"
    $Modules = @(
        "SystemUpdates",
        "DiskMaintenance",
        "SystemHealthRepair",
        "SecurityScans",
        "DeveloperMaintenance",
        "MultimediaMaintenance",
        "PerformanceOptimization",
        "NetworkMaintenance",
        "GPUMaintenance",
        "EventLogManagement",
        "BackupOperations",
        "PrivacyMaintenance",
        "BloatwareRemoval",
        "SystemReporting"
    )
    foreach ($m in $Modules) { $ModuleList.Items.Add($m, $true) }
    $GroupModules.Controls.Add($ModuleList)

    # --- Options Group ---
    $GroupOptions = New-Object System.Windows.Forms.GroupBox
    $GroupOptions.Text = "Execution Options"
    $GroupOptions.Location = "440, 100"
    $GroupOptions.Size = "420, 300"
    $Form.Controls.Add($GroupOptions)

    $CbWhatIf = New-Object System.Windows.Forms.CheckBox
    $CbWhatIf.Text = "Simulation Mode (-WhatIf)"
    $CbWhatIf.Location = "20, 30"
    $CbWhatIf.Size = "300, 25"
    $GroupOptions.Controls.Add($CbWhatIf)

    $CbSilent = New-Object System.Windows.Forms.CheckBox
    $CbSilent.Text = "Silent Mode (No Popups)"
    $CbSilent.Location = "20, 60"
    $CbSilent.Size = "300, 25"
    $GroupOptions.Controls.Add($CbSilent)

    # --- Console Output ---
    $Console = New-Object System.Windows.Forms.TextBox
    $Console.Multiline = $true
    $Console.Location = "20, 420"
    $Console.Size = "840, 250"
    $Console.ReadOnly = $true
    $Console.ScrollBars = "Vertical"
    $Console.BackColor = $Theme.ConsoleBg
    $Console.ForeColor = $Theme.ConsoleFg
    $Console.Font = $Fonts.Console
    $Form.Controls.Add($Console)

    # --- Progress Bar ---
    $Progress = New-Object System.Windows.Forms.ProgressBar
    $Progress.Location = "20, 680"
    $Progress.Size = "840, 25"
    $Form.Controls.Add($Progress)

    # --- Buttons ---
    $BtnStart = New-Object System.Windows.Forms.Button
    $BtnStart.Text = "START MAINTENANCE"
    $BtnStart.Location = "20, 720"
    $BtnStart.Size = "200, 40"
    $BtnStart.FlatStyle = "Flat"
    $BtnStart.BackColor = [System.Drawing.Color]::LightGreen
    $Form.Controls.Add($BtnStart)

    $BtnStop = New-Object System.Windows.Forms.Button
    $BtnStop.Text = "STOP"
    $BtnStop.Location = "230, 720"
    $BtnStop.Size = "150, 40"
    $BtnStop.FlatStyle = "Flat"
    $BtnStop.BackColor = [System.Drawing.Color]::LightCoral
    $Form.Controls.Add($BtnStop)

    # --- Control Map ---
    $Controls = @{
        Form       = $Form
        ModuleList = $ModuleList
        Console    = $Console
        Progress   = $Progress
        StartBtn   = $BtnStart
        StopBtn    = $BtnStop
        WhatIf     = $CbWhatIf
        Silent     = $CbSilent
    }

    return $Controls
}
