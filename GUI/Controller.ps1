<#
.SYNOPSIS
    GUI Controller and Logic for the Windows Maintenance Framework (WPF Edition).
#>

Add-Type -AssemblyName PresentationFramework

$script:MaintenanceJob = $null
$script:AppSelectionModel = @()
$script:AppModelById = @{}
$script:AppItems = $null
$script:AppView = $null
$script:AppConfigPath = $null
$script:UserConfigPath = $null
$script:AppCatalogPath = $null

$ModuleRoot = Split-Path $PSScriptRoot
Import-Module "$ModuleRoot\Modules\Common\AppInventory.psm1" -Force

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
        [hashtable]$Theme,

        [Parameter(Mandatory=$false)]
        [string]$ConfigPath
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
    $Modules = [ordered]@{
        "SystemUpdates"           = "System Updates"
        "DiskMaintenance"         = "Disk Maintenance"
        "SystemHealthRepair"      = "System Health Repair"
        "SecurityScans"           = "Security Scans"
        "DeveloperMaintenance"    = "Developer Maintenance"
        "MultimediaMaintenance"   = "Multimedia Maintenance"
        "PerformanceOptimization" = "Performance Optimization"
        "NetworkMaintenance"      = "Network Maintenance"
        "GPUMaintenance"          = "GPU Maintenance"
        "EventLogManagement"      = "Event Log Management"
        "BackupOperations"        = "Backup Operations"
        "PrivacyMaintenance"      = "Privacy Maintenance"
        "BloatwareRemoval"        = "Bloatware Removal"
        "SystemReporting"         = "System Reporting"
    }

    foreach ($key in $Modules.Keys) {
        $Cb = New-Object System.Windows.Controls.CheckBox
        $Cb.Content = $Modules[$key]
        $Cb.Tag = $key
        $Cb.IsChecked = $true
        $Cb.Name = "Module_$key"
        $Controls.ModuleList.Children.Add($Cb) | Out-Null
    }

        # 3. Load Config and Initialize App Selection
        $Config = Get-GuiConfig -ConfigPath $ConfigPath
        Initialize-AppSelectionUI -Controls $Controls -Config $Config

        # 4. Wire Events
        $Controls.StartBtn.Add_Click({
            Invoke-StartMaintenanceUI -Controls $Controls
        })

        $Controls.StopBtn.Add_Click({
            Invoke-MaintenanceUIStop -Controls $Controls
        })
        $Controls.StopBtn.IsEnabled = $false

        $Controls.AppSearch.Add_TextChanged({ Update-AppView -Controls $Controls })
        $Controls.AppInstalledOnly.Add_Checked({ Update-AppView -Controls $Controls })
        $Controls.AppInstalledOnly.Add_Unchecked({ Update-AppView -Controls $Controls })
        $Controls.AppTagFilter.Add_SelectionChanged({ Update-AppView -Controls $Controls })
        $Controls.AppSelectAll.Add_Click({ Set-AppSelectionState -State $true })
        $Controls.AppSelectNone.Add_Click({ Set-AppSelectionState -State $false })
        $Controls.AppSave.Add_Click({ Save-AppSelectionSet -Controls $Controls })

        # 5. Initialize Timer
        $Timer = New-Object System.Windows.Threading.DispatcherTimer
        $Timer.Interval = [TimeSpan]::FromMilliseconds(500)
        $Timer.Add_Tick({
            Receive-MaintenanceTimerUIUpdate -Controls $Controls
        })
        $Timer.Start()

        return $Timer
    }

function ConvertTo-Hashtable {
    param([object]$InputObject)

    if ($null -eq $InputObject) { return @{} }
    if ($InputObject -is [hashtable]) { return $InputObject }

    $Table = @{}
    $InputObject.PSObject.Properties | ForEach-Object {
        $Table[$_.Name] = $_.Value
    }
    return $Table
}

function Read-ConfigFile {
    param([string]$Path)

    if (-not (Test-Path $Path)) { return @{} }
    $Raw = Get-Content -Path $Path -Raw
    if (-not $Raw) { return @{} }
    $Obj = $Raw | ConvertFrom-Json
    ConvertTo-Hashtable $Obj
}

function Merge-Config {
    param(
        [hashtable]$Base,
        [hashtable]$Override
    )

    foreach ($Key in $Override.Keys) {
        $BaseValue = $Base[$Key]
        $OverrideValue = $Override[$Key]

        if ($BaseValue -is [hashtable] -and $OverrideValue -is [hashtable]) {
            $Base[$Key] = Merge-Config -Base $BaseValue -Override $OverrideValue
        } elseif ($BaseValue -is [pscustomobject] -and $OverrideValue -is [pscustomobject]) {
            $Base[$Key] = Merge-Config -Base (ConvertTo-Hashtable $BaseValue) -Override (ConvertTo-Hashtable $OverrideValue)
        } else {
            $Base[$Key] = $OverrideValue
        }
    }
    return $Base
}

function Get-GuiConfig {
    param([string]$ConfigPath)

    if (-not $ConfigPath) {
        $ConfigPath = Join-Path $ModuleRoot "Config\maintenance-config.json"
    }

    $script:AppConfigPath = $ConfigPath
    $script:UserConfigPath = Join-Path (Split-Path $ConfigPath) "maintenance-config.user.json"

    $Config = Read-ConfigFile -Path $ConfigPath
    if (Test-Path $script:UserConfigPath) {
        $UserConfig = Read-ConfigFile -Path $script:UserConfigPath
        $Config = Merge-Config -Base $Config -Override $UserConfig
    }

    if (-not $Config.AppCatalogPath) {
        $Config.AppCatalogPath = Join-Path $ModuleRoot "Config\app-catalog.json"
    } elseif (-not [System.IO.Path]::IsPathRooted($Config.AppCatalogPath)) {
        $Config.AppCatalogPath = Join-Path (Split-Path $ConfigPath) $Config.AppCatalogPath
    }
    $script:AppCatalogPath = $Config.AppCatalogPath

    return $Config
}

function Initialize-AppSelectionUI {
    [CmdletBinding()]
    param(
        [hashtable]$Controls,
        [hashtable]$Config
    )

    $Sources = if ($Config.AppSources) { ConvertTo-Hashtable $Config.AppSources } else { @{ Winget = $true; Registry = $true; Store = $true } }
    $script:AppSelectionModel = Get-AppSelectionModel -Config $Config -CatalogPath $Config.AppCatalogPath -Sources $Sources
    $script:AppModelById = @{}
    foreach ($Entry in $script:AppSelectionModel) {
        $script:AppModelById[$Entry.Id] = $Entry
    }

    $script:AppItems = New-Object System.Collections.ObjectModel.ObservableCollection[object]
    $Tags = New-Object System.Collections.Generic.HashSet[string]

    foreach ($Entry in $script:AppSelectionModel) {
        $PrimaryTag = if ($Entry.Tags -and $Entry.Tags.Count -gt 0) { $Entry.Tags[0] } else { "Other" }
        [void]$Tags.Add($PrimaryTag)

        $script:AppItems.Add([pscustomobject]@{
            Id = $Entry.Id
            DisplayName = if ($Entry.IsInstalled) { "$($Entry.DisplayName) (Installed)" } else { $Entry.DisplayName }
            IsInstalled = [bool]$Entry.IsInstalled
            Selected = [bool]$Entry.Selected
            PrimaryTag = $PrimaryTag
            Tags = $Entry.Tags
            ModuleMappings = $Entry.ModuleMappings
        })
    }

    $Controls.AppList.ItemsSource = $script:AppItems
    $script:AppView = [System.Windows.Data.CollectionViewSource]::GetDefaultView($script:AppItems)
    $script:AppView.GroupDescriptions.Clear()
    $script:AppView.GroupDescriptions.Add((New-Object System.Windows.Data.PropertyGroupDescription "PrimaryTag"))

    $Controls.AppTagFilter.Items.Clear()
    [void]$Controls.AppTagFilter.Items.Add("All")
    foreach ($Tag in ($Tags | Sort-Object)) {
        [void]$Controls.AppTagFilter.Items.Add($Tag)
    }
    $Controls.AppTagFilter.SelectedIndex = 0

    Update-AppView -Controls $Controls
}

function Update-AppView {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "", Justification = "Updates in-memory UI state only.")]
    param([hashtable]$Controls)

    $Search = $Controls.AppSearch.Text
    $InstalledOnly = $Controls.AppInstalledOnly.IsChecked
    $SelectedTag = $Controls.AppTagFilter.SelectedItem

    if (-not $script:AppView) { return }

    $script:AppView.Filter = {
        param($Item)
        if ($InstalledOnly -and -not $Item.IsInstalled) { return $false }
        if ($SelectedTag -and $SelectedTag -ne "All" -and $Item.PrimaryTag -ne $SelectedTag) { return $false }
        if ($Search -and ($Item.DisplayName -notmatch [regex]::Escape($Search))) { return $false }
        return $true
    }
    $script:AppView.Refresh()
}

function Set-AppSelectionState {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "", Justification = "Updates in-memory UI state only.")]
    param(
        [bool]$State
    )

    if (-not $script:AppView) { return }
    foreach ($Entry in $script:AppView) {
        $Entry.Selected = $State
    }
    $script:AppView.Refresh()
}

function Save-AppSelectionSet {
    param([hashtable]$Controls)

    $Selections = @{}
    foreach ($Entry in $script:AppItems) {
        if (-not $Entry.Selected) { continue }
        foreach ($Map in ($Entry.ModuleMappings | ForEach-Object { $_ })) {
            $Module = $Map.Module
            if (-not $Module) { continue }
            if (-not $Selections.ContainsKey($Module)) { $Selections[$Module] = @() }
            $Selections[$Module] += $Entry.Id
        }
    }

    if ($script:UserConfigPath) {
        Write-AppSelectionOverride -Path $script:UserConfigPath -Selections $Selections
        Show-UIConsoleUpdate -ConsoleControl $Controls.Console -Text "App selections saved to: $script:UserConfigPath"
    }
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
                $EnabledModules += $Child.Tag
            }
        }

        if ($EnabledModules.Count -eq 0) {
            [System.Windows.MessageBox]::Show("Please select at least one module.")
            return
        }

        Save-AppSelectionSet -Controls $Controls

        Show-UIConsoleUpdate -ConsoleControl $Controls.Console -Text "Initializing maintenance for: $($EnabledModules -join ', ')"

        $Controls.StartBtn.IsEnabled = $false
        $Controls.StopBtn.IsEnabled = $true
        $Controls.Progress.IsIndeterminate = $true

        # Capture Options
        $WhatIf = $Controls.WhatIf.IsChecked
        $Silent = $Controls.Silent.IsChecked

        # Job ScriptBlock
        $JobScript = {
            param($ModulePath, $WhatIf, $Silent)
            $InformationPreference = 'Continue'

            # Enhance visibility for WhatIf mode
            if ($WhatIf) { $VerbosePreference = 'Continue' }

            Import-Module $ModulePath -Force

            $Params = @{}
            if ($Silent) { $Params['SilentMode'] = $true }
            if ($WhatIf) { $Params['WhatIf'] = $true }

            Invoke-WindowsMaintenance @Params *>&1
        }

        # Module root detection for job
        $ModuleRoot = Split-Path $PSScriptRoot
        $Manifest = Join-Path $ModuleRoot "WindowsMaintenance.psd1"

        $script:MaintenanceJob = Start-Job -ScriptBlock $JobScript -ArgumentList $Manifest, $WhatIf, $Silent
    }

<#
.SYNOPSIS
    Handles the Stop button click event.
#>
function Invoke-MaintenanceUIStop {
    [CmdletBinding()]
    param($Controls)

    if ($script:MaintenanceJob) {
        $Controls.StopBtn.IsEnabled = $false
        Show-UIConsoleUpdate -ConsoleControl $Controls.Console -Text "Stopping maintenance job..."

        # Stop asynchronously to prevent UI freeze
        [void][System.Threading.Tasks.Task]::Run([Action]{
            Stop-Job $script:MaintenanceJob -Force
        })
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
            $Controls.StopBtn.IsEnabled = $false
            Remove-Job -Job $script:MaintenanceJob
            $script:MaintenanceJob = $null
        }
    }
}
