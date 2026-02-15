<#
.SYNOPSIS
    Purges old maintenance logs and database entries.

.DESCRIPTION
    Scans the Logs directory and removes files older than the specified days.
    Also attempts to purge old history from the SQLite database.

.PARAMETER Days
    The age threshold in days for deletion. Defaults to 30.

.EXAMPLE
    .\Scripts\Cleanup-MaintenanceLogs.ps1 -Days 14
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [int]$Days = 30
)

# Load configuration
$ConfigPath = Join-Path (Split-Path $PSScriptRoot) "Config\maintenance-config.json"
if (-not (Test-Path $ConfigPath)) {
    Write-Error "Configuration file not found at $ConfigPath"
    return
}

$Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$LogsPath = $Config.LogsPath

if (-not (Test-Path $LogsPath)) {
    Write-Warning "Logs directory not found at $LogsPath"
    return
}

$CutoffDate = (Get-Date).AddDays(-$Days)

# 1. Cleanup Files
Write-Host "Cleaning up files in $LogsPath older than $Days days..." -ForegroundColor Cyan
$OldFiles = Get-ChildItem -Path $LogsPath -File -Recurse | Where-Object { $_.LastWriteTime -lt $CutoffDate }

foreach ($File in $OldFiles) {
    if ($PSCmdlet.ShouldProcess($File.FullName, "Delete old log file")) {
        Remove-Item $File.FullName -Force
        Write-Host "  Deleted: $($File.Name)" -ForegroundColor Gray
    }
}

# 2. Cleanup Database
$DbPath = Join-Path $LogsPath "maintenance_history.db"
if (Test-Path $DbPath) {
    Write-Host "`nCleaning up database entries..." -ForegroundColor Cyan
    try {
        $LibRoot = Join-Path (Split-Path (Split-Path $PSScriptRoot)) "Lib"
        $DllPath = Join-Path $LibRoot "System.Data.SQLite.dll"
        
        if (Test-Path $DllPath) {
            if (-not ([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.FullName -match "System.Data.SQLite" })) {
                Add-Type -Path $DllPath
            }

            $conn = New-Object System.Data.SQLite.SQLiteConnection("Data Source=$DbPath;Version=3;")
            $conn.Open()
            
            $Query = "DELETE FROM MaintenanceHistory WHERE Timestamp < datetime('now', '-$Days days')"
            if ($PSCmdlet.ShouldProcess("Database History", "Delete records older than $Days days")) {
                $cmd = $conn.CreateCommand()
                $cmd.CommandText = $Query
                $Count = $cmd.ExecuteNonQuery()
                Write-Host "  Purged $Count history records." -ForegroundColor Green
                
                # Vaccum to reclaim space
                $cmd.CommandText = "VACUUM"
                $cmd.ExecuteNonQuery() | Out-Null
            }
            $conn.Close()
        }
    }
    catch {
        Write-Warning "Could not purge database: $($_.Exception.Message)"
    }
}

Write-Host "`nCleanup complete." -ForegroundColor Green
