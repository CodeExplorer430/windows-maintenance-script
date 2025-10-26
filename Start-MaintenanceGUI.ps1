<#
.SYNOPSIS
    Windows Forms GUI for the Windows Maintenance Framework.

.DESCRIPTION
    Provides a user-friendly graphical interface for managing Windows maintenance tasks.
    Allows users to configure modules, monitor progress, and view logs without using
    the command line.

    Features:
    - Visual module selection and configuration
    - Real-time progress monitoring
    - Interactive log viewer with filtering
    - Configuration editor with validation
    - WhatIf mode simulation
    - Schedule task creation

.PARAMETER ConfigPath
    Path to configuration file. Defaults to the standard configuration location.

.EXAMPLE
    .\Start-MaintenanceGUI.ps1
    Launches the GUI with default configuration.

.EXAMPLE
    .\Start-MaintenanceGUI.ps1 -ConfigPath ".\examples\config-developer.json"
    Launches the GUI with a custom configuration.

.NOTES
    File Name      : Start-MaintenanceGUI.ps1
    Author         : Miguel Velasco
    Prerequisite   : PowerShell 5.1+, .NET Framework 4.5+
    Version        : 4.0.0
    Last Updated   : October 2025

    Requirements:
    - Windows 10/11
    - PowerShell 5.1 or later
    - .NET Framework 4.5 or later (built into Windows 10/11)
    - Administrator privileges for execution
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigPath
)

# Add required assemblies for Windows Forms
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Script root for file paths
$Script:ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$Script:ModulePath = Join-Path $Script:ScriptRoot "WindowsMaintenance\WindowsMaintenance.psd1"

# Default configuration path
if (-not $ConfigPath) {
    $Script:ConfigPath = Join-Path $Script:ScriptRoot "config\maintenance-config.json"
} else {
    $Script:ConfigPath = $ConfigPath
}

# Global variables for GUI state
$Script:IsRunning = $false
$Script:Config = $null
$Script:LogBuffer = New-Object System.Collections.ArrayList

#region Helper Functions

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Load-Configuration {
    param([string]$Path)

    try {
        if (Test-Path $Path) {
            $Script:Config = Get-Content $Path -Raw | ConvertFrom-Json
            return $true
        } else {
            [System.Windows.Forms.MessageBox]::Show(
                "Configuration file not found at: $Path",
                "Configuration Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
            return $false
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Failed to load configuration: $($_.Exception.Message)",
            "Configuration Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        return $false
    }
}

function Save-Configuration {
    param(
        [object]$ConfigObject,
        [string]$Path
    )

    try {
        $ConfigObject | ConvertTo-Json -Depth 10 | Set-Content $Path -Force
        return $true
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Failed to save configuration: $($_.Exception.Message)",
            "Save Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        return $false
    }
}

#endregion

#region Main Form

function Show-MainForm {
    # Create main form
    $mainForm = New-Object System.Windows.Forms.Form
    $mainForm.Text = "Windows Maintenance Framework v4.0.0"
    $mainForm.Size = New-Object System.Drawing.Size(900, 780)
    $mainForm.StartPosition = "CenterScreen"
    $mainForm.FormBorderStyle = "FixedDialog"
    $mainForm.MaximizeBox = $false
    $mainForm.Icon = [System.Drawing.SystemIcons]::Shield

    # Create menu bar
    $menuStrip = New-Object System.Windows.Forms.MenuStrip

    # File menu
    $fileMenu = New-Object System.Windows.Forms.ToolStripMenuItem
    $fileMenu.Text = "&File"

    $loadConfigItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $loadConfigItem.Text = "Load Configuration..."
    $loadConfigItem.Add_Click({
        $openDialog = New-Object System.Windows.Forms.OpenFileDialog
        $openDialog.Filter = "JSON Files (*.json)|*.json|All Files (*.*)|*.*"
        $openDialog.Title = "Load Configuration"
        $openDialog.InitialDirectory = Split-Path $Script:ConfigPath

        if ($openDialog.ShowDialog() -eq "OK") {
            if (Load-Configuration -Path $openDialog.FileName) {
                $Script:ConfigPath = $openDialog.FileName
                Update-ModuleList
                [System.Windows.Forms.MessageBox]::Show(
                    "Configuration loaded successfully.",
                    "Success",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                )
            }
        }
    })

    $saveConfigItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $saveConfigItem.Text = "Save Configuration"
    $saveConfigItem.Add_Click({
        if (Save-Configuration -ConfigObject $Script:Config -Path $Script:ConfigPath) {
            [System.Windows.Forms.MessageBox]::Show(
                "Configuration saved successfully.",
                "Success",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        }
    })

    $exitItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $exitItem.Text = "E&xit"
    $exitItem.Add_Click({ $mainForm.Close() })

    $fileMenu.DropDownItems.Add($loadConfigItem) | Out-Null
    $fileMenu.DropDownItems.Add($saveConfigItem) | Out-Null
    $fileMenu.DropDownItems.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null
    $fileMenu.DropDownItems.Add($exitItem) | Out-Null

    # Tools menu
    $toolsMenu = New-Object System.Windows.Forms.ToolStripMenuItem
    $toolsMenu.Text = "&Tools"

    $configEditorItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $configEditorItem.Text = "Configuration Editor..."
    $configEditorItem.Add_Click({ Show-ConfigurationEditor })

    $logViewerItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $logViewerItem.Text = "Log Viewer..."
    $logViewerItem.Add_Click({ Show-LogViewer })

    $scheduleTaskItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $scheduleTaskItem.Text = "Schedule Maintenance Task..."
    $scheduleTaskItem.Add_Click({ Show-ScheduleTaskDialog })

    $toolsMenu.DropDownItems.Add($configEditorItem) | Out-Null
    $toolsMenu.DropDownItems.Add($logViewerItem) | Out-Null
    $toolsMenu.DropDownItems.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null
    $toolsMenu.DropDownItems.Add($scheduleTaskItem) | Out-Null

    # Help menu
    $helpMenu = New-Object System.Windows.Forms.ToolStripMenuItem
    $helpMenu.Text = "&Help"

    $aboutItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $aboutItem.Text = "&About"
    $aboutItem.Add_Click({
        [System.Windows.Forms.MessageBox]::Show(
            "Windows Maintenance Framework v4.0.0`n`nEnterprise-grade system maintenance for Windows 10/11`n`nAuthor: Miguel Velasco`nOctober 2025",
            "About",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    })

    $helpMenu.DropDownItems.Add($aboutItem) | Out-Null

    $menuStrip.Items.Add($fileMenu) | Out-Null
    $menuStrip.Items.Add($toolsMenu) | Out-Null
    $menuStrip.Items.Add($helpMenu) | Out-Null

    $mainForm.Controls.Add($menuStrip)
    $mainForm.MainMenuStrip = $menuStrip

    # Status label (Administrator check)
    $yOffset = 30
    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Location = New-Object System.Drawing.Point(20, $yOffset)
    $statusLabel.Size = New-Object System.Drawing.Size(860, 25)
    $statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)

    if (Test-Administrator) {
        $statusLabel.Text = "[/] Running with Administrator privileges"
        $statusLabel.ForeColor = [System.Drawing.Color]::DarkGreen
    } else {
        $statusLabel.Text = "[!] WARNING: Not running as Administrator - maintenance will fail!"
        $statusLabel.ForeColor = [System.Drawing.Color]::Red
    }
    $mainForm.Controls.Add($statusLabel)

    # Configuration path label
    $yOffset += 30
    $configPathLabel = New-Object System.Windows.Forms.Label
    $configPathLabel.Location = New-Object System.Drawing.Point(20, $yOffset)
    $configPathLabel.Size = New-Object System.Drawing.Size(860, 20)
    $configPathLabel.Text = "Configuration: $Script:ConfigPath"
    $configPathLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $mainForm.Controls.Add($configPathLabel)

    # Module selection group box
    $yOffset += 30
    $moduleGroupBox = New-Object System.Windows.Forms.GroupBox
    $moduleGroupBox.Location = New-Object System.Drawing.Point(20, $yOffset)
    $moduleGroupBox.Size = New-Object System.Drawing.Size(420, 350)
    $moduleGroupBox.Text = "Maintenance Modules"
    $mainForm.Controls.Add($moduleGroupBox)

    # Module checklist
    $Script:ModuleChecklist = New-Object System.Windows.Forms.CheckedListBox
    $Script:ModuleChecklist.Location = New-Object System.Drawing.Point(10, 25)
    $Script:ModuleChecklist.Size = New-Object System.Drawing.Size(400, 310)
    $Script:ModuleChecklist.CheckOnClick = $true
    $moduleGroupBox.Controls.Add($Script:ModuleChecklist)

    # Options group box
    $optionsGroupBox = New-Object System.Windows.Forms.GroupBox
    $optionsGroupBox.Location = New-Object System.Drawing.Point(460, $yOffset)
    $optionsGroupBox.Size = New-Object System.Drawing.Size(420, 350)
    $optionsGroupBox.Text = "Execution Options"
    $mainForm.Controls.Add($optionsGroupBox)

    # WhatIf checkbox
    $whatIfCheckbox = New-Object System.Windows.Forms.CheckBox
    $whatIfCheckbox.Location = New-Object System.Drawing.Point(15, 30)
    $whatIfCheckbox.Size = New-Object System.Drawing.Size(390, 25)
    $whatIfCheckbox.Text = "Simulation Mode (WhatIf) - No changes will be made"
    $whatIfCheckbox.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $optionsGroupBox.Controls.Add($whatIfCheckbox)

    # Detailed output checkbox
    $detailedOutputCheckbox = New-Object System.Windows.Forms.CheckBox
    $detailedOutputCheckbox.Location = New-Object System.Drawing.Point(15, 65)
    $detailedOutputCheckbox.Size = New-Object System.Drawing.Size(390, 25)
    $detailedOutputCheckbox.Text = "Detailed Output - Enable comprehensive logging"
    $optionsGroupBox.Controls.Add($detailedOutputCheckbox)

    # Manage event logs checkbox
    $manageEventLogsCheckbox = New-Object System.Windows.Forms.CheckBox
    $manageEventLogsCheckbox.Location = New-Object System.Drawing.Point(15, 100)
    $manageEventLogsCheckbox.Size = New-Object System.Drawing.Size(390, 25)
    $manageEventLogsCheckbox.Text = "Manage Event Logs - Enable automatic optimization"
    $optionsGroupBox.Controls.Add($manageEventLogsCheckbox)

    # Silent mode checkbox
    $silentModeCheckbox = New-Object System.Windows.Forms.CheckBox
    $silentModeCheckbox.Location = New-Object System.Drawing.Point(15, 135)
    $silentModeCheckbox.Size = New-Object System.Drawing.Size(390, 25)
    $silentModeCheckbox.Text = "Silent Mode - No user interaction required"
    $optionsGroupBox.Controls.Add($silentModeCheckbox)

    # Fast mode checkbox
    $fastModeCheckbox = New-Object System.Windows.Forms.CheckBox
    $fastModeCheckbox.Location = New-Object System.Drawing.Point(15, 170)
    $fastModeCheckbox.Size = New-Object System.Drawing.Size(390, 25)
    $fastModeCheckbox.Text = "Fast Mode - Reduced timeouts for quicker execution"
    $optionsGroupBox.Controls.Add($fastModeCheckbox)

    # Scan level selection
    $scanLevelLabel = New-Object System.Windows.Forms.Label
    $scanLevelLabel.Location = New-Object System.Drawing.Point(15, 210)
    $scanLevelLabel.Size = New-Object System.Drawing.Size(150, 20)
    $scanLevelLabel.Text = "Security Scan Level:"
    $optionsGroupBox.Controls.Add($scanLevelLabel)

    $scanLevelCombo = New-Object System.Windows.Forms.ComboBox
    $scanLevelCombo.Location = New-Object System.Drawing.Point(170, 207)
    $scanLevelCombo.Size = New-Object System.Drawing.Size(230, 25)
    $scanLevelCombo.DropDownStyle = "DropDownList"
    $scanLevelCombo.Items.AddRange(@("Quick", "Full", "Custom"))
    $scanLevelCombo.SelectedIndex = 0
    $optionsGroupBox.Controls.Add($scanLevelCombo)

    # Estimated time label
    $estimatedTimeLabel = New-Object System.Windows.Forms.Label
    $estimatedTimeLabel.Location = New-Object System.Drawing.Point(15, 250)
    $estimatedTimeLabel.Size = New-Object System.Drawing.Size(390, 40)
    $estimatedTimeLabel.Text = "Estimated execution time: Calculating..."
    $estimatedTimeLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
    $estimatedTimeLabel.ForeColor = [System.Drawing.Color]::DarkBlue
    $optionsGroupBox.Controls.Add($estimatedTimeLabel)

    # Update estimated time when modules change
    $Script:ModuleChecklist.Add_ItemCheck({
        $checkedCount = 0
        for ($i = 0; $i -lt $Script:ModuleChecklist.Items.Count; $i++) {
            if ($Script:ModuleChecklist.GetItemChecked($i)) {
                $checkedCount++
            }
        }

        # Adjust for current item being checked/unchecked
        if ($_.NewValue -eq "Checked") { $checkedCount++ } else { $checkedCount-- }

        $baseTime = 5
        $timePerModule = 8
        $estimatedMinutes = $baseTime + ($checkedCount * $timePerModule)

        if ($fastModeCheckbox.Checked) {
            $estimatedMinutes = [math]::Round($estimatedMinutes * 0.7)
        }

        $estimatedTimeLabel.Text = "Estimated execution time: $estimatedMinutes-$($estimatedMinutes + 10) minutes for $checkedCount module(s)"
    })

    # Progress bar
    $yOffset += 360
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(20, $yOffset)
    $progressBar.Size = New-Object System.Drawing.Size(860, 25)
    $progressBar.Style = "Continuous"
    $mainForm.Controls.Add($progressBar)

    # Status text box (read-only, shows real-time status)
    $yOffset += 35
    $statusTextBox = New-Object System.Windows.Forms.TextBox
    $statusTextBox.Location = New-Object System.Drawing.Point(20, $yOffset)
    $statusTextBox.Size = New-Object System.Drawing.Size(860, 150)
    $statusTextBox.Multiline = $true
    $statusTextBox.ScrollBars = "Vertical"
    $statusTextBox.ReadOnly = $true
    $statusTextBox.BackColor = [System.Drawing.Color]::White
    $statusTextBox.Font = New-Object System.Drawing.Font("Consolas", 9)
    $mainForm.Controls.Add($statusTextBox)

    # Action buttons
    $yOffset += 160
    $runButton = New-Object System.Windows.Forms.Button
    $runButton.Location = New-Object System.Drawing.Point(20, $yOffset)
    $runButton.Size = New-Object System.Drawing.Size(200, 40)
    $runButton.Text = "▶ Start Maintenance"
    $runButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $runButton.BackColor = [System.Drawing.Color]::LightGreen
    $runButton.Add_Click({
        if (-not (Test-Administrator)) {
            [System.Windows.Forms.MessageBox]::Show(
                "Administrator privileges are required to run maintenance.`n`nPlease restart the GUI as Administrator.",
                "Administrator Required",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            return
        }

        Start-Maintenance -ProgressBar $progressBar -StatusTextBox $statusTextBox `
            -WhatIf $whatIfCheckbox.Checked -DetailedOutput $detailedOutputCheckbox.Checked `
            -ManageEventLogs $manageEventLogsCheckbox.Checked -SilentMode $silentModeCheckbox.Checked `
            -FastMode $fastModeCheckbox.Checked -ScanLevel $scanLevelCombo.SelectedItem `
            -RunButton $runButton -StopButton $stopButton
    })
    $mainForm.Controls.Add($runButton)

    $stopButton = New-Object System.Windows.Forms.Button
    $stopButton.Location = New-Object System.Drawing.Point(240, $yOffset)
    $stopButton.Size = New-Object System.Drawing.Size(200, 40)
    $stopButton.Text = "■ Stop"
    $stopButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $stopButton.BackColor = [System.Drawing.Color]::LightCoral
    $stopButton.Enabled = $false
    $mainForm.Controls.Add($stopButton)

    $viewLogsButton = New-Object System.Windows.Forms.Button
    $viewLogsButton.Location = New-Object System.Drawing.Point(460, $yOffset)
    $viewLogsButton.Size = New-Object System.Drawing.Size(200, 40)
    $viewLogsButton.Text = "📄 View Logs"
    $viewLogsButton.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $viewLogsButton.Add_Click({ Show-LogViewer })
    $mainForm.Controls.Add($viewLogsButton)

    $exitButton = New-Object System.Windows.Forms.Button
    $exitButton.Location = New-Object System.Drawing.Point(680, $yOffset)
    $exitButton.Size = New-Object System.Drawing.Size(200, 40)
    $exitButton.Text = "✖ Exit"
    $exitButton.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $exitButton.Add_Click({ $mainForm.Close() })
    $mainForm.Controls.Add($exitButton)

    # Load initial module list
    function Update-ModuleList {
        $Script:ModuleChecklist.Items.Clear()
        if ($Script:Config -and $Script:Config.EnabledModules) {
            $allModules = @(
                "SystemUpdates",
                "DiskMaintenance",
                "SystemHealthRepair",
                "SecurityScans",
                "DeveloperMaintenance",
                "PerformanceOptimization",
                "NetworkMaintenance"
            )

            foreach ($module in $allModules) {
                $index = $Script:ModuleChecklist.Items.Add($module)
                if ($module -in $Script:Config.EnabledModules) {
                    $Script:ModuleChecklist.SetItemChecked($index, $true)
                }
            }
        }
    }

    # Show the form
    Update-ModuleList
    $mainForm.Add_Shown({$mainForm.Activate()})
    [void]$mainForm.ShowDialog()
}

#endregion

#region Configuration Editor

function Show-ConfigurationEditor {
    $editorForm = New-Object System.Windows.Forms.Form
    $editorForm.Text = "Configuration Editor"
    $editorForm.Size = New-Object System.Drawing.Size(800, 600)
    $editorForm.StartPosition = "CenterScreen"
    $editorForm.FormBorderStyle = "Sizable"

    # Tab control for different configuration sections
    $tabControl = New-Object System.Windows.Forms.TabControl
    $tabControl.Location = New-Object System.Drawing.Point(10, 10)
    $tabControl.Size = New-Object System.Drawing.Size(770, 490)
    $editorForm.Controls.Add($tabControl)

    # General tab
    $generalTab = New-Object System.Windows.Forms.TabPage
    $generalTab.Text = "General"
    $tabControl.TabPages.Add($generalTab)

    $yPos = 20

    # Logs path
    $logsPathLabel = New-Object System.Windows.Forms.Label
    $logsPathLabel.Location = New-Object System.Drawing.Point(20, $yPos)
    $logsPathLabel.Size = New-Object System.Drawing.Size(150, 20)
    $logsPathLabel.Text = "Logs Path:"
    $generalTab.Controls.Add($logsPathLabel)

    $logsPathTextBox = New-Object System.Windows.Forms.TextBox
    $logsPathTextBox.Location = New-Object System.Drawing.Point(180, $yPos)
    $logsPathTextBox.Size = New-Object System.Drawing.Size(500, 25)
    $logsPathTextBox.Text = $Script:Config.LogsPath
    $generalTab.Controls.Add($logsPathTextBox)

    $yPos += 40

    # Reports path
    $reportsPathLabel = New-Object System.Windows.Forms.Label
    $reportsPathLabel.Location = New-Object System.Drawing.Point(20, $yPos)
    $reportsPathLabel.Size = New-Object System.Drawing.Size(150, 20)
    $reportsPathLabel.Text = "Reports Path:"
    $generalTab.Controls.Add($reportsPathLabel)

    $reportsPathTextBox = New-Object System.Windows.Forms.TextBox
    $reportsPathTextBox.Location = New-Object System.Drawing.Point(180, $yPos)
    $reportsPathTextBox.Size = New-Object System.Drawing.Size(500, 25)
    $reportsPathTextBox.Text = $Script:Config.ReportsPath
    $generalTab.Controls.Add($reportsPathTextBox)

    $yPos += 40

    # Max event log size
    $maxEventLogLabel = New-Object System.Windows.Forms.Label
    $maxEventLogLabel.Location = New-Object System.Drawing.Point(20, $yPos)
    $maxEventLogLabel.Size = New-Object System.Drawing.Size(150, 20)
    $maxEventLogLabel.Text = "Max Event Log Size (MB):"
    $generalTab.Controls.Add($maxEventLogLabel)

    $maxEventLogNumeric = New-Object System.Windows.Forms.NumericUpDown
    $maxEventLogNumeric.Location = New-Object System.Drawing.Point(180, $yPos)
    $maxEventLogNumeric.Size = New-Object System.Drawing.Size(150, 25)
    $maxEventLogNumeric.Minimum = 10
    $maxEventLogNumeric.Maximum = 1000
    # Use default value if property doesn't exist or is invalid
    $eventLogValue = if ($Script:Config.MaxEventLogSizeMB -and $Script:Config.MaxEventLogSizeMB -ge 10) {
        [Math]::Min($Script:Config.MaxEventLogSizeMB, 1000)
    } else {
        100
    }
    $maxEventLogNumeric.Value = $eventLogValue
    $generalTab.Controls.Add($maxEventLogNumeric)

    # Disk Maintenance tab
    $diskTab = New-Object System.Windows.Forms.TabPage
    $diskTab.Text = "Disk Maintenance"
    $tabControl.TabPages.Add($diskTab)

    $diskYPos = 20
    $diskOptions = @(
        @{Name="EnableRecycleBinCleanup"; Label="Enable Recycle Bin Cleanup"},
        @{Name="EnableTempFileCleanup"; Label="Enable Temp File Cleanup"},
        @{Name="EnableWindowsTempCleanup"; Label="Enable Windows Temp Cleanup"},
        @{Name="EnableBrowserCacheCleanup"; Label="Enable Browser Cache Cleanup"},
        @{Name="EnableWindowsUpdateCleanup"; Label="Enable Windows Update Cleanup"},
        @{Name="EnableThumbnailCacheCleanup"; Label="Enable Thumbnail Cache Cleanup"},
        @{Name="EnableErrorReportCleanup"; Label="Enable Error Report Cleanup"},
        @{Name="EnablePrefetchCleanup"; Label="Enable Prefetch Cleanup"},
        @{Name="EnableLogFileCleanup"; Label="Enable Log File Cleanup"},
        @{Name="EnableDeliveryOptimizationCleanup"; Label="Enable Delivery Optimization Cleanup"}
    )

    $diskCheckboxes = @{}
    foreach ($option in $diskOptions) {
        $checkbox = New-Object System.Windows.Forms.CheckBox
        $checkbox.Location = New-Object System.Drawing.Point(20, $diskYPos)
        $checkbox.Size = New-Object System.Drawing.Size(350, 25)
        $checkbox.Text = $option.Label
        # Safely handle missing properties - default to false
        $checkbox.Checked = if ($Script:Config.DiskMaintenance.PSObject.Properties.Name -contains $option.Name) {
            [bool]$Script:Config.DiskMaintenance.($option.Name)
        } else {
            $false
        }
        $diskCheckboxes[$option.Name] = $checkbox
        $diskTab.Controls.Add($checkbox)
        $diskYPos += 30
    }

    # Retention days
    $diskYPos += 20
    $tempRetentionLabel = New-Object System.Windows.Forms.Label
    $tempRetentionLabel.Location = New-Object System.Drawing.Point(20, $diskYPos)
    $tempRetentionLabel.Size = New-Object System.Drawing.Size(200, 20)
    $tempRetentionLabel.Text = "Temp File Retention Days:"
    $diskTab.Controls.Add($tempRetentionLabel)

    $tempRetentionNumeric = New-Object System.Windows.Forms.NumericUpDown
    $tempRetentionNumeric.Location = New-Object System.Drawing.Point(230, $diskYPos)
    $tempRetentionNumeric.Size = New-Object System.Drawing.Size(100, 25)
    $tempRetentionNumeric.Minimum = 1
    $tempRetentionNumeric.Maximum = 365
    # Use default value if property doesn't exist or is invalid
    $retentionValue = if ($Script:Config.DiskMaintenance.TempFileRetentionDays -and $Script:Config.DiskMaintenance.TempFileRetentionDays -ge 1) {
        $Script:Config.DiskMaintenance.TempFileRetentionDays
    } else {
        7
    }
    $tempRetentionNumeric.Value = $retentionValue
    $diskTab.Controls.Add($tempRetentionNumeric)

    # Developer Maintenance tab
    $devTab = New-Object System.Windows.Forms.TabPage
    $devTab.Text = "Developer Tools"
    $tabControl.TabPages.Add($devTab)

    $devYPos = 20
    $devTools = @(
        "EnableNPM", "EnablePython", "EnableDocker", "EnableJDK",
        "EnableMinGW", "EnableDotNetSDK", "EnableWindowsSDK", "EnableVCRedist",
        "EnableComposer", "EnablePostgreSQL", "EnableJetBrainsIDEs",
        "EnableVisualStudio2022", "EnableVSCode", "EnableDatabaseTools",
        "EnableAdobeTools", "EnableVersionControl", "EnableLegacyCppTools"
    )

    $devCheckboxes = @{}
    foreach ($tool in $devTools) {
        $checkbox = New-Object System.Windows.Forms.CheckBox
        $checkbox.Location = New-Object System.Drawing.Point(20, $devYPos)
        $checkbox.Size = New-Object System.Drawing.Size(300, 25)
        $checkbox.Text = $tool -replace "Enable", ""
        # Safely handle missing properties - default to false
        $checkbox.Checked = if ($Script:Config.DeveloperMaintenance.PSObject.Properties.Name -contains $tool) {
            [bool]$Script:Config.DeveloperMaintenance.$tool
        } else {
            $false
        }
        $devCheckboxes[$tool] = $checkbox
        $devTab.Controls.Add($checkbox)
        $devYPos += 30

        if ($devYPos -gt 400) {
            $devYPos = 20
        }
    }

    # Save and Cancel buttons
    $saveButton = New-Object System.Windows.Forms.Button
    $saveButton.Location = New-Object System.Drawing.Point(500, 520)
    $saveButton.Size = New-Object System.Drawing.Size(130, 35)
    $saveButton.Text = "Save"
    $saveButton.Add_Click({
        # Update configuration object
        $Script:Config.LogsPath = $logsPathTextBox.Text
        $Script:Config.ReportsPath = $reportsPathTextBox.Text
        $Script:Config.MaxEventLogSizeMB = $maxEventLogNumeric.Value

        foreach ($key in $diskCheckboxes.Keys) {
            $Script:Config.DiskMaintenance.$key = $diskCheckboxes[$key].Checked
        }
        $Script:Config.DiskMaintenance.TempFileRetentionDays = $tempRetentionNumeric.Value

        foreach ($key in $devCheckboxes.Keys) {
            $Script:Config.DeveloperMaintenance.$key = $devCheckboxes[$key].Checked
        }

        if (Save-Configuration -ConfigObject $Script:Config -Path $Script:ConfigPath) {
            [System.Windows.Forms.MessageBox]::Show(
                "Configuration saved successfully.",
                "Success",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
            $editorForm.Close()
        }
    })
    $editorForm.Controls.Add($saveButton)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(650, 520)
    $cancelButton.Size = New-Object System.Drawing.Size(130, 35)
    $cancelButton.Text = "Cancel"
    $cancelButton.Add_Click({ $editorForm.Close() })
    $editorForm.Controls.Add($cancelButton)

    [void]$editorForm.ShowDialog()
}

#endregion

#region Log Viewer

function Show-LogViewer {
    $logViewerForm = New-Object System.Windows.Forms.Form
    $logViewerForm.Text = "Log Viewer"
    $logViewerForm.Size = New-Object System.Drawing.Size(1000, 700)
    $logViewerForm.StartPosition = "CenterScreen"

    # Log file selector
    $logFileLabel = New-Object System.Windows.Forms.Label
    $logFileLabel.Location = New-Object System.Drawing.Point(20, 20)
    $logFileLabel.Size = New-Object System.Drawing.Size(100, 20)
    $logFileLabel.Text = "Log File:"
    $logViewerForm.Controls.Add($logFileLabel)

    $logFileCombo = New-Object System.Windows.Forms.ComboBox
    $logFileCombo.Location = New-Object System.Drawing.Point(130, 17)
    $logFileCombo.Size = New-Object System.Drawing.Size(600, 25)
    $logFileCombo.DropDownStyle = "DropDownList"
    $logViewerForm.Controls.Add($logFileCombo)

    # Populate log files
    try {
        # Expand environment variables in the path
        $logsPath = [System.Environment]::ExpandEnvironmentVariables($Script:Config.LogsPath)

        if (Test-Path $logsPath) {
            $logFiles = Get-ChildItem -Path $logsPath -Filter "*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
            foreach ($file in $logFiles) {
                $logFileCombo.Items.Add($file.FullName) | Out-Null
            }
            if ($logFileCombo.Items.Count -gt 0) {
                $logFileCombo.SelectedIndex = 0
            }
        } else {
            $logTextBox.Text = "Log directory not found: $logsPath`n`nLogs will be created here when maintenance runs."
        }
    }
    catch {
        $logTextBox.Text = "Error loading log files: $($_.Exception.Message)"
    }

    # Refresh button
    $refreshButton = New-Object System.Windows.Forms.Button
    $refreshButton.Location = New-Object System.Drawing.Point(750, 15)
    $refreshButton.Size = New-Object System.Drawing.Size(100, 30)
    $refreshButton.Text = "Refresh"
    $refreshButton.Add_Click({
        try {
            $logFileCombo.Items.Clear()
            $logTextBox.Clear()

            # Expand environment variables in the path
            $logsPath = [System.Environment]::ExpandEnvironmentVariables($Script:Config.LogsPath)

            if (Test-Path $logsPath) {
                $logFiles = Get-ChildItem -Path $logsPath -Filter "*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
                foreach ($file in $logFiles) {
                    $logFileCombo.Items.Add($file.FullName) | Out-Null
                }
                if ($logFileCombo.Items.Count -gt 0) {
                    $logFileCombo.SelectedIndex = 0
                } else {
                    $logTextBox.Text = "No log files found in: $logsPath"
                }
            } else {
                $logTextBox.Text = "Log directory not found: $logsPath`n`nLogs will be created here when maintenance runs."
            }
        }
        catch {
            $logTextBox.Text = "Error refreshing log files: $($_.Exception.Message)"
        }
    })
    $logViewerForm.Controls.Add($refreshButton)

    # Open folder button
    $openFolderButton = New-Object System.Windows.Forms.Button
    $openFolderButton.Location = New-Object System.Drawing.Point(865, 15)
    $openFolderButton.Size = New-Object System.Drawing.Size(110, 30)
    $openFolderButton.Text = "Open Folder"
    $openFolderButton.Add_Click({
        try {
            # Expand environment variables in the path
            $logsPath = [System.Environment]::ExpandEnvironmentVariables($Script:Config.LogsPath)

            if (Test-Path $logsPath) {
                Start-Process explorer.exe -ArgumentList $logsPath
            } else {
                # Create the directory if it doesn't exist
                New-Item -Path $logsPath -ItemType Directory -Force | Out-Null
                Start-Process explorer.exe -ArgumentList $logsPath
            }
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Error opening log folder: $($_.Exception.Message)",
                "Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    })
    $logViewerForm.Controls.Add($openFolderButton)

    # Filter text box
    $filterLabel = New-Object System.Windows.Forms.Label
    $filterLabel.Location = New-Object System.Drawing.Point(20, 60)
    $filterLabel.Size = New-Object System.Drawing.Size(100, 20)
    $filterLabel.Text = "Filter:"
    $logViewerForm.Controls.Add($filterLabel)

    $filterTextBox = New-Object System.Windows.Forms.TextBox
    $filterTextBox.Location = New-Object System.Drawing.Point(130, 57)
    $filterTextBox.Size = New-Object System.Drawing.Size(600, 25)
    $logViewerForm.Controls.Add($filterTextBox)

    # Apply filter button
    $filterButton = New-Object System.Windows.Forms.Button
    $filterButton.Location = New-Object System.Drawing.Point(750, 55)
    $filterButton.Size = New-Object System.Drawing.Size(100, 30)
    $filterButton.Text = "Filter"
    $logViewerForm.Controls.Add($filterButton)

    # Log content text box
    $logTextBox = New-Object System.Windows.Forms.TextBox
    $logTextBox.Location = New-Object System.Drawing.Point(20, 100)
    $logTextBox.Size = New-Object System.Drawing.Size(955, 530)
    $logTextBox.Multiline = $true
    $logTextBox.ScrollBars = "Both"
    $logTextBox.Font = New-Object System.Drawing.Font("Consolas", 9)
    $logTextBox.ReadOnly = $true
    $logTextBox.WordWrap = $false
    $logViewerForm.Controls.Add($logTextBox)

    # Load log file when selected
    $logFileCombo.Add_SelectedIndexChanged({
        if ($logFileCombo.SelectedItem) {
            try {
                $content = Get-Content -Path $logFileCombo.SelectedItem -Raw
                $logTextBox.Text = $content
            }
            catch {
                $logTextBox.Text = "Error loading log file: $($_.Exception.Message)"
            }
        }
    })

    # Filter functionality
    $filterButton.Add_Click({
        if ($logFileCombo.SelectedItem -and $filterTextBox.Text) {
            try {
                $content = Get-Content -Path $logFileCombo.SelectedItem -ErrorAction Stop | Where-Object { $_ -match $filterTextBox.Text }
                if ($content) {
                    $logTextBox.Text = $content -join "`r`n"
                } else {
                    $logTextBox.Text = "No matches found for filter: '$($filterTextBox.Text)'"
                }
            }
            catch {
                $logTextBox.Text = "Error filtering log file: $($_.Exception.Message)"
            }
        } elseif (-not $logFileCombo.SelectedItem) {
            [System.Windows.Forms.MessageBox]::Show(
                "Please select a log file first.",
                "No File Selected",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        } elseif (-not $filterTextBox.Text) {
            [System.Windows.Forms.MessageBox]::Show(
                "Please enter a filter text.",
                "No Filter Text",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        }
    })

    # Close button
    $closeButton = New-Object System.Windows.Forms.Button
    $closeButton.Location = New-Object System.Drawing.Point(875, 640)
    $closeButton.Size = New-Object System.Drawing.Size(100, 30)
    $closeButton.Text = "Close"
    $closeButton.Add_Click({ $logViewerForm.Close() })
    $logViewerForm.Controls.Add($closeButton)

    [void]$logViewerForm.ShowDialog()
}

#endregion

#region Schedule Task Dialog

function Show-ScheduleTaskDialog {
    $scheduleForm = New-Object System.Windows.Forms.Form
    $scheduleForm.Text = "Schedule Maintenance Task"
    $scheduleForm.Size = New-Object System.Drawing.Size(500, 400)
    $scheduleForm.StartPosition = "CenterScreen"
    $scheduleForm.FormBorderStyle = "FixedDialog"
    $scheduleForm.MaximizeBox = $false

    $yPos = 20

    # Task name
    $taskNameLabel = New-Object System.Windows.Forms.Label
    $taskNameLabel.Location = New-Object System.Drawing.Point(20, $yPos)
    $taskNameLabel.Size = New-Object System.Drawing.Size(150, 20)
    $taskNameLabel.Text = "Task Name:"
    $scheduleForm.Controls.Add($taskNameLabel)

    $taskNameTextBox = New-Object System.Windows.Forms.TextBox
    $taskNameTextBox.Location = New-Object System.Drawing.Point(180, $yPos)
    $taskNameTextBox.Size = New-Object System.Drawing.Size(280, 25)
    $taskNameTextBox.Text = "WindowsMaintenance"
    $scheduleForm.Controls.Add($taskNameTextBox)

    $yPos += 40

    # Frequency
    $frequencyLabel = New-Object System.Windows.Forms.Label
    $frequencyLabel.Location = New-Object System.Drawing.Point(20, $yPos)
    $frequencyLabel.Size = New-Object System.Drawing.Size(150, 20)
    $frequencyLabel.Text = "Frequency:"
    $scheduleForm.Controls.Add($frequencyLabel)

    $frequencyCombo = New-Object System.Windows.Forms.ComboBox
    $frequencyCombo.Location = New-Object System.Drawing.Point(180, $yPos)
    $frequencyCombo.Size = New-Object System.Drawing.Size(280, 25)
    $frequencyCombo.DropDownStyle = "DropDownList"
    $frequencyCombo.Items.AddRange(@("Daily", "Weekly", "Monthly"))
    $frequencyCombo.SelectedIndex = 1
    $scheduleForm.Controls.Add($frequencyCombo)

    $yPos += 40

    # Day of week (for weekly)
    $dayOfWeekLabel = New-Object System.Windows.Forms.Label
    $dayOfWeekLabel.Location = New-Object System.Drawing.Point(20, $yPos)
    $dayOfWeekLabel.Size = New-Object System.Drawing.Size(150, 20)
    $dayOfWeekLabel.Text = "Day of Week:"
    $scheduleForm.Controls.Add($dayOfWeekLabel)

    $dayOfWeekCombo = New-Object System.Windows.Forms.ComboBox
    $dayOfWeekCombo.Location = New-Object System.Drawing.Point(180, $yPos)
    $dayOfWeekCombo.Size = New-Object System.Drawing.Size(280, 25)
    $dayOfWeekCombo.DropDownStyle = "DropDownList"
    $dayOfWeekCombo.Items.AddRange(@("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"))
    $dayOfWeekCombo.SelectedIndex = 6  # Sunday
    $scheduleForm.Controls.Add($dayOfWeekCombo)

    $yPos += 40

    # Start time
    $startTimeLabel = New-Object System.Windows.Forms.Label
    $startTimeLabel.Location = New-Object System.Drawing.Point(20, $yPos)
    $startTimeLabel.Size = New-Object System.Drawing.Size(150, 20)
    $startTimeLabel.Text = "Start Time:"
    $scheduleForm.Controls.Add($startTimeLabel)

    $startTimeTextBox = New-Object System.Windows.Forms.TextBox
    $startTimeTextBox.Location = New-Object System.Drawing.Point(180, $yPos)
    $startTimeTextBox.Size = New-Object System.Drawing.Size(280, 25)
    $startTimeTextBox.Text = "02:00"
    $scheduleForm.Controls.Add($startTimeTextBox)

    $yPos += 50

    # Info label
    $infoLabel = New-Object System.Windows.Forms.Label
    $infoLabel.Location = New-Object System.Drawing.Point(20, $yPos)
    $infoLabel.Size = New-Object System.Drawing.Size(440, 60)
    $infoLabel.Text = "This will create a Windows Scheduled Task that runs the maintenance with the current configuration. The task will run with SYSTEM privileges."
    $infoLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Italic)
    $scheduleForm.Controls.Add($infoLabel)

    $yPos += 80

    # Create button
    $createButton = New-Object System.Windows.Forms.Button
    $createButton.Location = New-Object System.Drawing.Point(180, $yPos)
    $createButton.Size = New-Object System.Drawing.Size(130, 35)
    $createButton.Text = "Create Task"
    $createButton.Add_Click({
        $result = [System.Windows.Forms.MessageBox]::Show(
            "This will create a scheduled task. Administrative privileges may be required.`n`nContinue?",
            "Confirm",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )

        if ($result -eq "Yes") {
            try {
                $installScriptPath = Join-Path $Script:ScriptRoot "Scripts\Install-MaintenanceTask.ps1"
                if (Test-Path $installScriptPath) {
                    $params = @(
                        "-TaskName", $taskNameTextBox.Text,
                        "-StartTime", $startTimeTextBox.Text,
                        "-ConfigPath", $Script:ConfigPath
                    )

                    if ($frequencyCombo.SelectedItem -eq "Weekly") {
                        $params += "-DayOfWeek"
                        $params += $dayOfWeekCombo.SelectedItem
                    }
                    elseif ($frequencyCombo.SelectedItem -eq "Daily") {
                        $params += "-RunDaily"
                    }

                    Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$installScriptPath`" $($params -join ' ')" -Verb RunAs -Wait

                    [System.Windows.Forms.MessageBox]::Show(
                        "Scheduled task created successfully!",
                        "Success",
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Information
                    )
                    $scheduleForm.Close()
                }
                else {
                    [System.Windows.Forms.MessageBox]::Show(
                        "Install-MaintenanceTask.ps1 script not found at:`n$installScriptPath",
                        "Error",
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Error
                    )
                }
            }
            catch {
                [System.Windows.Forms.MessageBox]::Show(
                    "Failed to create scheduled task: $($_.Exception.Message)",
                    "Error",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                )
            }
        }
    })
    $scheduleForm.Controls.Add($createButton)

    # Cancel button
    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(330, $yPos)
    $cancelButton.Size = New-Object System.Drawing.Size(130, 35)
    $cancelButton.Text = "Cancel"
    $cancelButton.Add_Click({ $scheduleForm.Close() })
    $scheduleForm.Controls.Add($cancelButton)

    [void]$scheduleForm.ShowDialog()
}

#endregion

#region Start Maintenance Function

function Start-Maintenance {
    param(
        $ProgressBar,
        $StatusTextBox,
        [bool]$WhatIf,
        [bool]$DetailedOutput,
        [bool]$ManageEventLogs,
        [bool]$SilentMode,
        [bool]$FastMode,
        [string]$ScanLevel,
        $RunButton,
        $StopButton
    )

    if ($Script:IsRunning) {
        [System.Windows.Forms.MessageBox]::Show(
            "Maintenance is already running!",
            "Already Running",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        return
    }

    # Get selected modules
    $selectedModules = New-Object System.Collections.ArrayList
    for ($i = 0; $i -lt $Script:ModuleChecklist.Items.Count; $i++) {
        if ($Script:ModuleChecklist.GetItemChecked($i)) {
            [void]$selectedModules.Add($Script:ModuleChecklist.Items[$i])
        }
    }

    if ($selectedModules.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "Please select at least one module to run.",
            "No Modules Selected",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        return
    }

    # Update config with selected modules
    $Script:Config.EnabledModules = $selectedModules.ToArray()

    # Update UI state
    $Script:IsRunning = $true
    $RunButton.Enabled = $false
    $StopButton.Enabled = $true
    $ProgressBar.Value = 0
    $StatusTextBox.Clear()
    $StatusTextBox.AppendText("Starting maintenance...`r`n")

    # Import module
    try {
        Import-Module $Script:ModulePath -Force -ErrorAction Stop
        $StatusTextBox.AppendText("Module loaded successfully.`r`n")
    }
    catch {
        $StatusTextBox.AppendText("ERROR: Failed to load module: $($_.Exception.Message)`r`n")
        $Script:IsRunning = $false
        $RunButton.Enabled = $true
        $StopButton.Enabled = $false
        return
    }

    # Prepare parameters
    $maintenanceParams = @{
        ConfigPath = $Script:ConfigPath
        WhatIf = $WhatIf
        DetailedOutput = $DetailedOutput
        ManageEventLogs = $ManageEventLogs
        SilentMode = $SilentMode
        FastMode = $FastMode
        ScanLevel = $ScanLevel
        ShowMessageBoxes = $false  # Disable message boxes in GUI mode
    }

    # Create background job to run maintenance
    $StatusTextBox.AppendText("Executing maintenance (this may take several minutes)...`r`n`r`n")

    # Note: In a real implementation, you'd use a background runspace or job
    # For now, we'll run synchronously (GUI will freeze)
    try {
        Invoke-WindowsMaintenance @maintenanceParams
        $ProgressBar.Value = 100
        $StatusTextBox.AppendText("`r`n=================================`r`n")
        $StatusTextBox.AppendText("Maintenance completed successfully!`r`n")
        $StatusTextBox.AppendText("=================================`r`n")

        [System.Windows.Forms.MessageBox]::Show(
            "Maintenance completed successfully!`n`nCheck the log viewer for detailed results.",
            "Success",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    }
    catch {
        $StatusTextBox.AppendText("`r`nERROR: $($_.Exception.Message)`r`n")
        [System.Windows.Forms.MessageBox]::Show(
            "Maintenance failed: $($_.Exception.Message)",
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
    finally {
        $Script:IsRunning = $false
        $RunButton.Enabled = $true
        $StopButton.Enabled = $false
    }
}

#endregion

# Main execution
if (-not (Load-Configuration -Path $Script:ConfigPath)) {
    Write-Host "Failed to load configuration. Exiting." -ForegroundColor Red
    exit 1
}

Show-MainForm
