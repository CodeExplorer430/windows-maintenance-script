<#
.SYNOPSIS
    Database management module for maintenance history and metrics.

.DESCRIPTION
    Provides SQLite database integration for persisting maintenance results,
    performance metrics, and execution history. Falls back to structured
    logging if SQLite libraries are unavailable.

.NOTES
    File Name      : Database.psm1
    Author         : Miguel Velasco
    Prerequisite   : PowerShell 5.1+
#>

#Requires -Version 5.1

# Import dependencies
Import-Module "$PSScriptRoot\Logging.psm1" -Force

$Script:DatabasePath = ""
$Script:SQLiteLoaded = $false

<#
.SYNOPSIS
    Initializes the maintenance database.
#>
function Initialize-MaintenanceDatabase {
    param(
        [string]$DbPath
    )

    $Script:DatabasePath = $DbPath
    $DbDir = Split-Path $DbPath -Parent
    if (!(Test-Path $DbDir)) { New-Item -ItemType Directory -Force -Path $DbDir | Out-Null }

    # Attempt to load SQLite from Lib folder with version awareness
    $LibRoot = Join-Path (Split-Path (Split-Path $PSScriptRoot)) "Lib"

    # Selection of DLL based on PowerShell Edition
    $DllName = if ($PSVersionTable.PSEdition -eq 'Core') { "System.Data.SQLite.dll" } else { "System.Data.SQLite.dll" }
    # (Note: In a full distribution, we would have subfolders like net46 and net6.0)

    $LibPath = Join-Path $LibRoot $DllName

    if (Test-Path $LibPath) {
        try {
            # Check if already loaded
            if (-not ([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.FullName -match "System.Data.SQLite" })) {
                Add-Type -Path $LibPath -ErrorAction Stop
            }
            $Script:SQLiteLoaded = $true
            Write-MaintenanceLog -Message "SQLite engine initialized successfully ($DllName)" -Level DEBUG
        } catch {
            Write-MaintenanceLog -Message "Failed to load SQLite library: $($_.Exception.Message)" -Level WARNING
        }
    }

    if ($Script:SQLiteLoaded) {
        Invoke-SQLiteQuery -Query @"
            CREATE TABLE IF NOT EXISTS MaintenanceHistory (
                Id INTEGER PRIMARY KEY AUTOINCREMENT,
                Timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                ModuleName TEXT,
                TaskName TEXT,
                Result TEXT,
                Details TEXT,
                ExecutionTimeReal SECONDS
            );
            CREATE TABLE IF NOT EXISTS SystemMetrics (
                Id INTEGER PRIMARY KEY AUTOINCREMENT,
                Timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                MetricName TEXT,
                MetricValue REAL,
                Unit TEXT
            );
"@
    } else {
        Write-MaintenanceLog -Message "SQLite unavailable. Results will be logged to CSV/Log files only." -Level INFO
    }
}

<#
.SYNOPSIS
    Executes a non-returning query against the SQLite database.
#>
function Invoke-SQLiteQuery {
    param([string]$Query)
    if (!$Script:SQLiteLoaded) { return }

    try {
        $connection = New-Object System.Data.SQLite.SQLiteConnection("Data Source=$Script:DatabasePath;Version=3;")
        $connection.Open()
        $command = $connection.CreateCommand()
        $command.CommandText = $Query
        $command.ExecuteNonQuery() | Out-Null
        $connection.Close()
    } catch {
        Write-MaintenanceLog -Message "Database query failed: $($_.Exception.Message)" -Level ERROR
    }
}

<#
.SYNOPSIS
    Logs a maintenance result to the database.
#>
function Add-MaintenanceHistory {
    param(
        [string]$Module,
        [string]$Task,
        [string]$Result,
        [string]$Details,
        [double]$Duration = 0
    )

    if ($Script:SQLiteLoaded) {
        $SafeDetails = $Details -replace "'", "''"
        $Query = "INSERT INTO MaintenanceHistory (ModuleName, TaskName, Result, Details, ExecutionTimeReal) VALUES ('$Module', '$Task', '$Result', '$SafeDetails', $Duration);"
        Invoke-SQLiteQuery -Query $Query
    }
}

Export-ModuleMember -Function Initialize-MaintenanceDatabase, Add-MaintenanceHistory, Invoke-SQLiteQuery
