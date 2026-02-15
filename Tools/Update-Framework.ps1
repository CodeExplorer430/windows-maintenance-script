<#
.SYNOPSIS
    Self-update utility for Windows Maintenance Framework.
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$false)]
    [string]$Repo = "Miguel/windows-maintenance-script",

    [switch]$Force = $false
)

$InformationPreference = 'Continue'
$ModuleRoot = Split-Path -Parent $PSScriptRoot
$ManifestPath = Join-Path $ModuleRoot "WindowsMaintenance.psd1"
$CurrentVersion = (Import-PowerShellDataFile -Path $ManifestPath).ModuleVersion

Write-Information -MessageData "Checking for updates... (Current: $CurrentVersion)" -Tags "Color:Cyan"

try {
    # 1. Get latest release from GitHub API
    $Url = "https://api.github.com/repos/$Repo/releases/latest"
    $Release = Invoke-RestMethod -Uri $Url
    $LatestVersion = $Release.tag_name -replace '^v', ''

    if ([Version]$LatestVersion -gt [Version]$CurrentVersion -or $Force) {
        Write-Information -MessageData "New version found: $LatestVersion" -Tags "Color:Green"

        if ($PSCmdlet.ShouldProcess("Framework Update", "Upgrade from $CurrentVersion to $LatestVersion")) {
            $DownloadUrl = $Release.assets | Where-Object { $_.name -like "*.zip" } | Select-Object -ExpandProperty browser_download_url -First 1
            $TempZip = Join-Path $env:TEMP "maintenance_update.zip"

            Write-Information -MessageData "Downloading update..." -Tags "Color:PROGRESS"
            Invoke-WebRequest -Uri $DownloadUrl -OutFile $TempZip

            # Backup current version
            $BackupDir = "$ModuleRoot.bak"
            if (Test-Path $BackupDir) { Remove-Item $BackupDir -Recurse -Force }
            Move-Item -Path $ModuleRoot -Destination $BackupDir

            # Extract new version
            Expand-Archive -Path $TempZip -DestinationPath $ModuleRoot -Force
            Remove-Item $TempZip

            Write-Information -MessageData "Update successful! Please restart your session." -Tags "Color:SUCCESS"
        }
    } else {
        Write-Information -MessageData "Framework is up to date." -Tags "Color:Gray"
    }
}
catch {
    Write-Error "Update failed: $($_.Exception.Message)"
}
