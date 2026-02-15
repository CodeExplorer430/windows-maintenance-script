<#
.SYNOPSIS
    Installs required PowerShell modules for the framework.

.DESCRIPTION
    Automates the installation of Pester, PSScriptAnalyzer, and other
    development dependencies.

.PARAMETER Force
    Force reinstallation of modules.

.EXAMPLE
    .\Scripts\Install-Dependencies.ps1
#>

[CmdletBinding()]
param(
    [switch]$Force = $false
)

$InformationPreference = 'Continue'

$Modules = @(
    @{ Name = "Pester"; Version = "5.7.1" }
    @{ Name = "PSScriptAnalyzer"; Version = "1.21.0" }
    @{ Name = "Invoke-Build"; Version = "5.8.8" }
    @{ Name = "platyPS"; Version = "0.14.2" }
)

Write-Information -MessageData "Checking for project dependencies..." -Tags "Color:Cyan"

foreach ($Module in $Modules) {
    $Installed = Get-Module -ListAvailable -Name $Module.Name | Sort-Object Version -Descending | Select-Object -First 1

    if ($Force -or -not $Installed -or $Installed.Version -lt $Module.Version) {
        Write-Information -MessageData "Installing $($Module.Name) (>= $($Module.Version))..." -Tags "Color:Yellow"
        try {
            Install-Module -Name $Module.Name -MinimumVersion $Module.Version -Force -Scope CurrentUser -SkipPublisherCheck
            Write-Information -MessageData "  Success." -Tags "Color:Green"
        }
        catch {
            Write-Error "Failed to install $($Module.Name): $($_.Exception.Message)"
        }
    }
    else {
        Write-Information -MessageData "  $($Module.Name) v$($Installed.Version) is already installed." -Tags "Color:Gray"
    }
}

Write-Information -MessageData "`nAll dependencies verified." -Tags "Color:Green"
