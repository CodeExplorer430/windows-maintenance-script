<#
.SYNOPSIS
    Performs a diagnostic check of the current environment.

.DESCRIPTION
    Verifies OS version, Administrator privileges, PowerShell edition,
    and required modules (Pester, PSScriptAnalyzer) to ensure the
    framework can run optimally.

.EXAMPLE
    .\Scripts\Invoke-EnvironmentCheck.ps1
#>

[CmdletBinding()]
param()

$InformationPreference = 'Continue'

Write-Information -MessageData "========================================" -Tags "Color:Cyan"
Write-Information -MessageData "  Windows Maintenance Diagnostic Check  " -Tags "Color:Cyan"
Write-Information -MessageData "========================================`n" -Tags "Color:Cyan"

$Results = @()

# 1. Check Elevation
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$Results += [PSCustomObject]@{
    Check    = "Administrator Privileges"
    Status   = if ($IsAdmin) { "PASS" } else { "WARNING" }
    Details  = if ($IsAdmin) { "Running as Admin" } else { "Some modules will be skipped" }
}

# 2. Check PowerShell Version
$Results += [PSCustomObject]@{
    Check    = "PowerShell Version"
    Status   = if ($PSVersionTable.PSVersion.Major -ge 5) { "PASS" } else { "FAIL" }
    Details  = "v$($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))"
}

# 3. Check OS
$OS = Get-CimInstance Win32_OperatingSystem
$Results += [PSCustomObject]@{
    Check    = "Operating System"
    Status   = if ($OS.Caption -match "Windows 10|Windows 11") { "PASS" } else { "WARNING" }
    Details  = $OS.Caption
}

# 4. Check Pester
$Pester = Get-Module -ListAvailable Pester | Sort-Object Version -Descending | Select-Object -First 1
$Results += [PSCustomObject]@{
    Check    = "Pester Module"
    Status   = if ($Pester -and $Pester.Version.Major -ge 5) { "PASS" } else { "WARNING" }
    Details  = if ($Pester) { "v$($Pester.Version)" } else { "Not installed" }
}

# 5. Check ScriptAnalyzer
$PSSA = Get-Module -ListAvailable PSScriptAnalyzer
$Results += [PSCustomObject]@{
    Check    = "PSScriptAnalyzer"
    Status   = if ($PSSA) { "PASS" } else { "INFO" }
    Details  = if ($PSSA) { "Installed" } else { "Optional for dev only" }
}

# 6. Check SQLite
$LibRoot = Join-Path (Split-Path $PSScriptRoot) "Lib"
$DllPath = Join-Path $LibRoot "System.Data.SQLite.dll"
$Results += [PSCustomObject]@{
    Check    = "SQLite Library"
    Status   = if (Test-Path $DllPath) { "PASS" } else { "INFO" }
    Details  = if (Test-Path $DllPath) { "Ready" } else { "Database logging disabled" }
}

# Display Results
$Results | ForEach-Object {
    $Color = switch ($_.Status) {
        "PASS"    { "Green" }
        "WARNING" { "Yellow" }
        "FAIL"    { "Red" }
        "INFO"    { "Gray" }
        Default   { "White" }
    }
    $Line = ("[{0,-7}] {1,-25} : {2}" -f $_.Status, $_.Check, $_.Details)
    Write-Information -MessageData $Line -Tags "Color:$Color"
}

Write-Information -MessageData "`nRecommendation:" -Tags "Color:Cyan"
if (-not $IsAdmin) {
    Write-Information -MessageData " - Relaunch as Administrator for full functionality." -Tags "Color:White"
}
if ($Pester -and $Pester.Version.Major -lt 5) {
    Write-Information -MessageData " - Upgrade Pester to 5.7.1+ for the modern test suite." -Tags "Color:White"
}
if (-not (Test-Path $DllPath)) {
    Write-Information -MessageData " - Place System.Data.SQLite.dll in the /Lib folder to enable history." -Tags "Color:White"
}
Write-Information -MessageData "========================================`n" -Tags "Color:Cyan"
