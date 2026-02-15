<#
.SYNOPSIS
    Exports maintenance history from the SQLite database to a CSV file.

.DESCRIPTION
    Queries the localized maintenance_history.db and exports all records
    to a timestamped CSV for external auditing or reporting.

.PARAMETER OutputPath
    The directory where the CSV should be saved. Defaults to current directory.

.EXAMPLE
    .\Scripts\Export-MaintenanceHistory.ps1 -OutputPath "C:\Reports"
#>

[CmdletBinding()]
param(
    [string]$OutputPath = $PSScriptRoot
)

# Load configuration to find database path
$ConfigPath = Join-Path (Split-Path $PSScriptRoot) "Config\maintenance-config.json"
if (-not (Test-Path $ConfigPath)) {
    Write-Error "Configuration file not found at $ConfigPath"
    return
}

$Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$DbPath = Join-Path $Config.LogsPath "maintenance_history.db"

if (-not (Test-Path $DbPath)) {
    Write-Warning "Database not found at $DbPath. No history to export."
    return
}

# Import Database module
$ModulePath = Join-Path (Split-Path $PSScriptRoot) "Modules\Common\Database.psm1"
Import-Module $ModulePath -Force

Write-Information -MessageData "Exporting history from $DbPath..." -Tags "Color:Cyan"

# Note: In a real environment, we'd use a SQL query helper that returns objects.
# For this script, we'll use a simple approach to get the data if the SQLite engine is loaded.
# Since we already have the modular Database.psm1, we leverage its connection logic.

try {
    $LibRoot = Join-Path (Split-Path (Split-Path $PSScriptRoot)) "Lib"
    $DllPath = Join-Path $LibRoot "System.Data.SQLite.dll"

    if (-not (Test-Path $DllPath)) {
        throw "SQLite library not found at $DllPath"
    }

    if (-not ([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.FullName -match "System.Data.SQLite" })) {
        Add-Type -Path $DllPath
    }

    $conn = New-Object System.Data.SQLite.SQLiteConnection("Data Source=$DbPath;Version=3;")
    $conn.Open()
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = "SELECT * FROM MaintenanceHistory ORDER BY Timestamp DESC"
    $adapter = New-Object System.Data.SQLite.SQLiteDataAdapter($cmd)
    $data = New-Object System.Data.DataTable
    $adapter.Fill($data) | Out-Null
    $conn.Close()

    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $File = Join-Path $OutputPath "MaintenanceHistory_$Timestamp.csv"

$InformationPreference = 'Continue'
    $data | Export-Csv -Path $File -NoTypeInformation -Encoding UTF8
    Write-Information -MessageData "History exported successfully to: $File" -Tags "Color:Green"
}
catch {
    Write-Error "Failed to export history: $($_.Exception.Message)"
}
