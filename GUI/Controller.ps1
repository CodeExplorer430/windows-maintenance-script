<#
.SYNOPSIS
    GUI Controller and Logic for the Windows Maintenance Framework.
#>

$script:MaintenanceJob = $null

<#
.SYNOPSIS
    Updates the UI console with timestamped text.
#>
function Update-UIConsole {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    param(
        [Parameter(Mandatory=$true)]
        $ConsoleControl,
        [Parameter(Mandatory=$true)]
        [string]$Text
    )
    $Timestamp = Get-Date -Format "HH:mm:ss"
    $ConsoleControl.AppendText("[$Timestamp] $Text`r`n")
}

<#
.SYNOPSIS
    Handles the Start button click event.
#>
function Invoke-StartMaintenanceUI {
    [CmdletBinding()]
    param($Controls)

    if ($script:MaintenanceJob -and $script:MaintenanceJob.State -eq 'Running') {
        [System.Windows.Forms.MessageBox]::Show("A maintenance job is already in progress.")
        return
    }

    $EnabledModules = $Controls.ModuleList.CheckedItems
    if ($EnabledModules.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select at least one module.")
        return
    }

    Update-UIConsole -ConsoleControl $Controls.Console -Text "Initializing maintenance for: $($EnabledModules -join ', ')"

    $Controls.StartBtn.Enabled = $false
    $Controls.Progress.Style = "Marquee"

    # Job ScriptBlock
    $JobScript = {
        param($ModulePath)
        Import-Module $ModulePath -Force
        Invoke-WindowsMaintenance -SilentMode
    }

    # Module root detection for job
    $ModuleRoot = Split-Path -Parent (Split-Path $PSScriptRoot)
    $Manifest = Join-Path $ModuleRoot "WindowsMaintenance.psd1"

    $script:MaintenanceJob = Start-Job -ScriptBlock $JobScript -ArgumentList $Manifest
}

<#
.SYNOPSIS
    Handles the Stop button click event.
#>
function Stop-MaintenanceUI {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    param($Controls)

    if ($script:MaintenanceJob) {
        Stop-Job $script:MaintenanceJob
        Update-UIConsole -ConsoleControl $Controls.Console -Text "Maintenance job stopped by user."
        $Controls.StartBtn.Enabled = $true
        $Controls.Progress.Style = "Continuous"
        $Controls.Progress.Value = 0
    }
}

<#
.SYNOPSIS
    Handles the timer tick event for UI updates.
#>
function Update-MaintenanceTimerUI {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    param($Controls)

    if ($script:MaintenanceJob) {
        if ($script:MaintenanceJob.State -eq 'Running') {
            if ($script:MaintenanceJob.HasMoreData) {
                $Data = Receive-Job -Job $script:MaintenanceJob
                foreach ($line in $Data) {
                    if ($line) { Update-UIConsole -ConsoleControl $Controls.Console -Text $line }
                }
            }
        } else {
            Update-UIConsole -ConsoleControl $Controls.Console -Text "Maintenance completed with status: $($script:MaintenanceJob.State)"
            $Controls.Progress.Style = "Continuous"
            $Controls.Progress.Value = 100
            $Controls.StartBtn.Enabled = $true
            Remove-Job -Job $script:MaintenanceJob
            $script:MaintenanceJob = $null
        }
    }
}
