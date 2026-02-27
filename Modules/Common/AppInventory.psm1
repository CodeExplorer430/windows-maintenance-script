<#
.SYNOPSIS
    Application inventory and selection helpers.

.DESCRIPTION
    Collects installed apps from winget, registry, and Appx, merges with a local catalog,
    and applies selection-driven configuration overrides.
#>

#Requires -Version 5.1

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

function ConvertTo-AppId {
    param([string]$Value)
    if (-not $Value) { return $null }
    $Value.ToLowerInvariant() -replace '[^a-z0-9]+', '-'
}

function Read-JsonFile {
    param([string]$Path)

    if (-not (Test-Path $Path)) { return @{} }
    $Raw = Get-Content -Path $Path -Raw
    if (-not $Raw) { return @{} }
    $Obj = $Raw | ConvertFrom-Json
    ConvertTo-Hashtable $Obj
}

<#
.SYNOPSIS
    Returns installed applications from configured sources.
#>
function Get-InstalledApp {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [hashtable]$Sources = @{ Winget = $true; Registry = $true; Store = $true }
    )

    $Apps = New-Object System.Collections.Generic.List[object]

    if ($Sources.Winget -and (Get-Command winget -ErrorAction SilentlyContinue)) {
        try {
            $WingetJson = & winget list --source winget --accept-source-agreements --disable-interactivity --output json 2>$null
            if ($WingetJson -and $WingetJson.Trim().StartsWith('{')) {
                $Parsed = $WingetJson | ConvertFrom-Json -ErrorAction Stop
                foreach ($Item in $Parsed.Sources.Packages) {
                    $Apps.Add([pscustomobject]@{
                        Id = ConvertTo-AppId $Item.PackageIdentifier
                        DisplayName = $Item.PackageName
                        Version = $Item.Version
                        Publisher = $Item.Publisher
                        Source = "Winget"
                    })
                }
            }
        } catch {
            Write-Verbose "Winget output parsing failed: $($_.Exception.Message)"
        }
    }

    if ($Sources.Registry) {
        $UninstallPaths = @(
            "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
        )

        foreach ($Path in $UninstallPaths) {
            Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue | ForEach-Object {
                if ($_.DisplayName) {
                    $Apps.Add([pscustomobject]@{
                        Id = ConvertTo-AppId $_.DisplayName
                        DisplayName = $_.DisplayName
                        Version = $_.DisplayVersion
                        Publisher = $_.Publisher
                        Source = "Registry"
                    })
                }
            }
        }
    }

    if ($Sources.Store) {
        try {
            Get-AppxPackage -ErrorAction SilentlyContinue | ForEach-Object {
                $Apps.Add([pscustomobject]@{
                    Id = ConvertTo-AppId $_.Name
                    DisplayName = $_.Name
                    Version = $_.Version.ToString()
                    Publisher = $_.Publisher
                    Source = "Store"
                })
            }
        } catch {
            Write-Verbose "Appx enumeration failed: $($_.Exception.Message)"
        }
    }

    return $Apps
}

<#
.SYNOPSIS
    Combines catalog entries with detected installed applications.
#>
function Merge-AppCatalog {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [array]$Catalog,
        [array]$InstalledApps
    )

    $CatalogById = @{}
    foreach ($Entry in $Catalog) {
        if (-not $Entry.Id) { continue }
        $CatalogById[(ConvertTo-AppId $Entry.Id)] = $Entry
    }

    $Merged = New-Object System.Collections.Generic.List[object]

    $InstalledById = @{}
    foreach ($App in $InstalledApps) {
        if (-not $App.Id) { continue }
        if (-not $InstalledById.ContainsKey($App.Id)) {
            $InstalledById[$App.Id] = @()
        }
        $InstalledById[$App.Id] += $App
    }

    foreach ($Key in $CatalogById.Keys) {
        $Entry = $CatalogById[$Key]
        $Detected = $InstalledById[$Key]
        $Sources = @()
        if ($Detected) { $Sources = $Detected | Select-Object -ExpandProperty Source -Unique }

        $Merged.Add([pscustomobject]@{
            Id = $Entry.Id
            DisplayName = $Entry.DisplayName
            Tags = $Entry.Tags
            ModuleMappings = $Entry.ModuleMappings
            DefaultEnabled = $Entry.DefaultEnabled
            SourceHints = $Entry.SourceHints
            IsInstalled = [bool]$Detected
            Sources = $Sources
            CatalogMatch = $true
        })
    }

    foreach ($App in $InstalledApps) {
        if ($CatalogById.ContainsKey($App.Id)) { continue }
        $Merged.Add([pscustomobject]@{
            Id = $App.Id
            DisplayName = $App.DisplayName
            Tags = @("Detected")
            ModuleMappings = @()
            DefaultEnabled = $false
            SourceHints = @()
            IsInstalled = $true
            Sources = @($App.Source)
            CatalogMatch = $false
        })
    }

    return $Merged
}

<#
.SYNOPSIS
    Builds a merged app selection model for UI or CLI usage.
#>
function Get-AppSelectionModel {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [hashtable]$Config,
        [string]$CatalogPath,
        [hashtable]$Sources = @{ Winget = $true; Registry = $true; Store = $true }
    )

    $Catalog = @()
    if ($CatalogPath -and (Test-Path $CatalogPath)) {
        $Catalog = Get-Content -Path $CatalogPath -Raw | ConvertFrom-Json
    }

    $Installed = Get-InstalledApp -Sources $Sources
    $Merged = Merge-AppCatalog -Catalog $Catalog -InstalledApps $Installed

    $Selections = ConvertTo-Hashtable $Config.AppSelections

    foreach ($Entry in $Merged) {
        $EntryId = ConvertTo-AppId $Entry.Id
        $Selected = $false

        foreach ($Map in ($Entry.ModuleMappings | ForEach-Object { $_ })) {
            $Module = $Map.Module
            if (-not $Module) { continue }
            $List = $Selections[$Module]
            if ($List -and ($EntryId -in ($List | ForEach-Object { ConvertTo-AppId $_ }))) {
                $Selected = $true
                break
            }
        }

        if (-not $Selections.Keys.Count) {
            $Selected = [bool]$Entry.DefaultEnabled
        }

        $Entry | Add-Member -NotePropertyName Selected -NotePropertyValue $Selected -Force
    }

    return $Merged
}

<#
.SYNOPSIS
    Applies app selections to module configuration toggles.
#>
<#
.SYNOPSIS
    Applies app selections to module configuration toggles.
#>
function Set-AppSelectionConfig {
    [CmdletBinding()]
    [OutputType([hashtable])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "", Justification = "Updates in-memory configuration only.")]
    param(
        [hashtable]$Config,
        [string]$CatalogPath
    )

    if (-not $Config.AppSelections) { return $Config }
    if (-not (Test-Path $CatalogPath)) { return $Config }

    $Catalog = Get-Content -Path $CatalogPath -Raw | ConvertFrom-Json
    $Selections = ConvertTo-Hashtable $Config.AppSelections

    foreach ($Entry in $Catalog) {
        foreach ($Map in ($Entry.ModuleMappings | ForEach-Object { $_ })) {
            $Module = $Map.Module
            $Key = $Map.ConfigKey
            if (-not $Module -or -not $Key) { continue }

            if (-not $Config.ContainsKey($Module)) { $Config[$Module] = @{} }
            if (-not ($Config[$Module] -is [hashtable])) {
                $Config[$Module] = ConvertTo-Hashtable $Config[$Module]
            }

            $SelectedList = $Selections[$Module]
            if ($SelectedList) {
                $Config[$Module][$Key] = (ConvertTo-AppId $Entry.Id) -in ($SelectedList | ForEach-Object { ConvertTo-AppId $_ })
            }
        }
    }

    return $Config
}

<#
.SYNOPSIS
    Writes the app selection override to a user config file.
#>
function Write-AppSelectionOverride {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        [Parameter(Mandatory=$true)]
        [hashtable]$Selections
    )

    $Payload = @{}
    if (Test-Path $Path) {
        try {
            $Existing = Get-Content -Path $Path -Raw | ConvertFrom-Json
            $Payload = ConvertTo-Hashtable $Existing
        } catch {
            $Payload = @{}
        }
    }

    $Payload.AppSelections = $Selections

    $Json = $Payload | ConvertTo-Json -Depth 6
    Set-Content -Path $Path -Value $Json -Encoding UTF8
}

Export-ModuleMember -Function @(
    'Get-InstalledApp',
    'Get-AppSelectionModel',
    'Set-AppSelectionConfig',
    'Write-AppSelectionOverride'
)
