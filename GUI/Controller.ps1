<#
.SYNOPSIS
    GUI Controller and Logic for the Windows Maintenance Framework (WPF Edition).
#>

Add-Type -AssemblyName PresentationFramework

$script:MaintenanceJob = $null

<#
.SYNOPSIS
    Displays text in the UI console with a timestamp.
#>
function Show-UIConsoleUpdate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        $ConsoleControl,
        [Parameter(Mandatory=$true)]
        [string]$Text
    )
    $Timestamp = Get-Date -Format "HH:mm:ss"

    # Check if we are on the UI thread
    if ($ConsoleControl.Dispatcher.CheckAccess()) {
        $ConsoleControl.AppendText("[$Timestamp] $Text`r`n")
        $ConsoleControl.ScrollToEnd()
    } else {
        $ConsoleControl.Dispatcher.Invoke([Action]{
            $ConsoleControl.AppendText("[$Timestamp] $Text`r`n")
            $ConsoleControl.ScrollToEnd()
        })
    }
}

<#
.SYNOPSIS
    Initializes the UI state, populates controls, and wires events.
#>
function Initialize-MaintenanceUI {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Controls,

        [Parameter(Mandatory=$true)]
        [hashtable]$Theme
    )

    # 1. Check Admin Privileges
    $IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($IsAdmin) {
        $Controls.StatusLabel.Content = "Elevated Session: ACTIVE"
        $Controls.StatusLabel.Foreground = $Theme["Brush_Success"]
    } else {
        $Controls.StatusLabel.Content = "NON-ELEVATED SESSION: LIMITED"
        $Controls.StatusLabel.Foreground = $Theme["Brush_Error"]
    }

    # 2. Populate Module List (Business Logic)
    $Modules = @(
        "SystemUpdates", "DiskMaintenance", "SystemHealthRepair", "SecurityScans",
        "DeveloperMaintenance", "MultimediaMaintenance", "PerformanceOptimization",
        "NetworkMaintenance", "GPUMaintenance", "EventLogManagement",
        "BackupOperations", "PrivacyMaintenance", "BloatwareRemoval", "SystemReporting"
    )

    foreach ($m in $Modules) {
        $Cb = New-Object System.Windows.Controls.CheckBox
        $Cb.Content = $m
        $Cb.IsChecked = $true
        $Cb.Name = "Module_$m"
        $Controls.ModuleList.Children.Add($Cb) | Out-Null
    }

    # 3. Wire Events
    $Controls.StartBtn.Add_Click({
        Invoke-StartMaintenanceUI -Controls $Controls
    })

    $Controls.StopBtn.Add_Click({
        Invoke-MaintenanceUIStop -Controls $Controls
    })

    # 4. Initialize Timer
    $Timer = New-Object System.Windows.Threading.DispatcherTimer
    $Timer.Interval = [TimeSpan]::FromMilliseconds(500)
    $Timer.Add_Tick({
        Receive-MaintenanceTimerUIUpdate -Controls $Controls
    })
    $Timer.Start()

    return $Timer
}

<#
.SYNOPSIS
    Handles the Start button click event.
#>
function Invoke-StartMaintenanceUI {
    [CmdletBinding()]
    param($Controls)

    if ($script:MaintenanceJob -and $script:MaintenanceJob.State -eq 'Running') {
        [System.Windows.MessageBox]::Show("A maintenance job is already in progress.")
        return
    }

    # Gather Enabled Modules (WPF CheckBoxes)
    $EnabledModules = @()
    foreach ($Child in $Controls.ModuleList.Children) {
        if ($Child.IsChecked) {
            $EnabledModules += $Child.Content
        }
    }

    if ($EnabledModules.Count -eq 0) {
        [System.Windows.MessageBox]::Show("Please select at least one module.")
        return
    }

    Show-UIConsoleUpdate -ConsoleControl $Controls.Console -Text "Initializing maintenance for: $($EnabledModules -join ', ')"

    $Controls.StartBtn.IsEnabled = $false
    $Controls.Progress.IsIndeterminate = $true

    # Job ScriptBlock
    $JobScript = {
        param($ModulePath)
        Import-Module $ModulePath -Force
        Invoke-WindowsMaintenance -SilentMode
    }

    # Module root detection for job
    $ModuleRoot = Split-Path $PSScriptRoot
    $Manifest = Join-Path $ModuleRoot "WindowsMaintenance.psd1"

    $script:MaintenanceJob = Start-Job -ScriptBlock $JobScript -ArgumentList $Manifest
}

<#
.SYNOPSIS
    Handles the Stop button click event.
#>
function Invoke-MaintenanceUIStop {
    [CmdletBinding()]
    param($Controls)

    if ($script:MaintenanceJob) {
        Stop-Job $script:MaintenanceJob
        Show-UIConsoleUpdate -ConsoleControl $Controls.Console -Text "Maintenance job stopped by user."
        $Controls.StartBtn.IsEnabled = $true
        $Controls.Progress.IsIndeterminate = $false
        $Controls.Progress.Value = 0
    }
}

<#
.SYNOPSIS
    Handles the timer tick event for UI updates.
#>
function Receive-MaintenanceTimerUIUpdate {
    [CmdletBinding()]
    param($Controls)

    if ($script:MaintenanceJob) {
        if ($script:MaintenanceJob.State -eq 'Running') {
            if ($script:MaintenanceJob.HasMoreData) {
                $Data = Receive-Job -Job $script:MaintenanceJob
                foreach ($line in $Data) {
                    if ($line) { Show-UIConsoleUpdate -ConsoleControl $Controls.Console -Text $line }
                }
            }
        } else {
            # Capture any remaining output
            $Data = Receive-Job -Job $script:MaintenanceJob
            foreach ($line in $Data) {
                if ($line) { Show-UIConsoleUpdate -ConsoleControl $Controls.Console -Text $line }
            }

            # Check for errors
            if ($script:MaintenanceJob.State -eq 'Failed' -or $script:MaintenanceJob.ChildJobs[0].Error) {
                foreach ($err in $script:MaintenanceJob.ChildJobs[0].Error) {
                    Show-UIConsoleUpdate -ConsoleControl $Controls.Console -Text "ERROR: $err"
                }
            }

            Show-UIConsoleUpdate -ConsoleControl $Controls.Console -Text "Maintenance completed with status: $($script:MaintenanceJob.State)"
            $Controls.Progress.IsIndeterminate = $false
            $Controls.Progress.Value = 100
            $Controls.StartBtn.IsEnabled = $true
            Remove-Job -Job $script:MaintenanceJob
            $script:MaintenanceJob = $null
        }
    }
}
