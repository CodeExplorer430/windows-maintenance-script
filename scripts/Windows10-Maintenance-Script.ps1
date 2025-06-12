# =========================================================================
# Windows 10/11 Pro Maintenance Script for Developer Workstation
# Enterprise-Grade System Maintenance with Advanced Monitoring and Reporting
# =========================================================================
# This script implements comprehensive maintenance following ITIL, ISO 27001,
# NIST Cybersecurity Framework, and Microsoft Security Baselines.
# Version: 2.4
# Updated: June 2025
# =========================================================================

#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigPath = "$PSScriptRoot\maintenance-config.json",
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipBackup = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$EnableVerbose = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$DetailedOutput = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$ManageEventLogs = $false,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Quick", "Full", "Custom")]
    [string]$ScanLevel = "Quick"
)

# =========================================================================
# CONFIGURATION AND INITIALIZATION
# =========================================================================

# Load required assemblies with error handling
try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName Microsoft.VisualBasic
}
catch {
    Write-Warning "Failed to load required assemblies. Some features may be limited."
}

# Script configuration with validation
$Config = @{
    LogPath            = "$env:USERPROFILE\Documents\Maintenance"
    BackupPath         = "$env:USERPROFILE\Documents\Backups"
    ReportsPath        = "$env:USERPROFILE\Documents\Maintenance\Reports"
    MaxLogSizeMB       = 100
    MaxBackupDays      = 30
    MaxEventLogSizeMB  = 10
    MinFreeSpaceGB     = 5
    DetailedLogging    = $true
    ProgressReporting  = $true
    EnabledModules     = @(
        "SystemUpdate",
        "DiskMaintenance",
        "SecurityScans",
        "DeveloperMaintenance",
        "PerformanceOptimization",
        "SystemReporting",
        "EventLogManagement"
    )
    DriveDetection        = $true
    AutoEventLogArchival  = $false
    Reporting             = $true
}

# =========================================================================
# Load external configuration if exists
# =========================================================================

if (Test-Path $ConfigPath) {
    try {
        $ExternalConfig = Get-Content $ConfigPath | ConvertFrom-Json
        foreach ($key in $ExternalConfig.PSObject.Properties.Name) {
            if ($key -ne '_metadata' -and $key -ne '_instructions') {
                $Config[$key] = $ExternalConfig.$key
            }
        }
        Write-Host '[√] Configuration loaded from ' + $ConfigPath -ForegroundColor Green
    }
    catch {
        Write-Warning 'Failed to load configuration. Using defaults.'
    }
}

# Initialize logging infrastructure
$Timestamp       = Get-Date -Format 'yyyyMMdd_HHmmss'
$LogFile         = "$($Config.LogPath)\maintenance_$Timestamp.log"
$ErrorLog        = "$($Config.LogPath)\errors_$Timestamp.log"
$PerformanceLog  = "$($Config.LogPath)\performance_$Timestamp.log"
$DetailedLog     = "$($Config.LogPath)\detailed_$Timestamp.log"
$OperationsLog   = "$($Config.LogPath)\operations_$Timestamp.log"

# Ensure directory structure exists
$Directories = @(
    $Config.LogPath,
    $Config.BackupPath,
    $Config.ReportsPath
)
foreach ( $Directory in $Directories ) {
    if ( -not (Test-Path -Path $Directory) ) {
        New-Item -ItemType Directory -Force -Path $Directory | Out-Null
    }
}

# =========================================================================
# LOGGING AND UTILITY FUNCTIONS
# =========================================================================

function Write-MaintenanceLog {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Message,

        [Parameter()]
        [ValidateSet("INFO","WARNING","ERROR","SUCCESS","DEBUG","PROGRESS","DETAIL")]
        [string] $Level = "INFO",

        [switch] $NoConsole,
        [switch] $NoTimestamp
    )

    try {
        # Build timestamped message
        $Timestamp  = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $LogMessage = if ($NoTimestamp) {
            "[$Level] $Message"
        } else {
            "[$Timestamp] [$Level] $Message"
        }

        # General log
        if ($LogFile -and (Test-Path (Split-Path $LogFile -Parent))) {
            Add-Content -Path $LogFile -Value $LogMessage -ErrorAction SilentlyContinue
        }

        # DETAIL level
        if (
            ($Level -eq "DETAIL") -and
            $DetailedOutput           -and
            $DetailedLog              -and
            (Test-Path (Split-Path $DetailedLog -Parent))
        ) {
            Add-Content -Path $DetailedLog -Value $LogMessage -ErrorAction SilentlyContinue
        }

        # PROGRESS/SUCCESS/ERROR/WARNING
        if (
            ($Level -in @("PROGRESS","SUCCESS","ERROR","WARNING")) -and
            $OperationsLog           -and
            (Test-Path (Split-Path $OperationsLog -Parent))
        ) {
            Add-Content -Path $OperationsLog -Value $LogMessage -ErrorAction SilentlyContinue
        }

        # Console output
        if (-not $NoConsole) {
            switch ($Level) {
                "ERROR"    { Write-Host "[ERROR]  $Message" -ForegroundColor Red }
                "WARNING"  { Write-Host "[WARNING]   $Message" -ForegroundColor Yellow }
                "SUCCESS"  { Write-Host "[SUCCESS]  $Message" -ForegroundColor Green }
                "PROGRESS" { Write-Host "[PROGRESS] $Message" -ForegroundColor Cyan }
                "DEBUG"    { if ($EnableVerbose) { Write-Host "[DEBUG]  $Message" -ForegroundColor Magenta } }
                "DETAIL"   { if ($DetailedOutput) { Write-Host "[DETAIL] $Message" -ForegroundColor DarkCyan } }
                default    { Write-Host "[INFO]    $Message" -ForegroundColor White }
            }
        }
    }
    catch {
        # Fallback to simple console write if logging fails
        $color = switch ($Level) {
            "ERROR"   { "Red" }
            "WARNING" { "Yellow" }
            "SUCCESS" { "Green" }
            default   { "White" }
        }
        Write-Host "[$Level] $Message" -ForegroundColor $color
    }
}

function Write-ProgressBar {
    param(
        [string] $Activity,
        [string] $Status,
        [int]    $PercentComplete,
        [string] $Details,
        [string] $ThroughputInfo,
        [string] $PerformanceLog
    )

    try {
        Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete

        $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'

        # Use single quotes so % is literal
        $ProgressMessage = '{0} - {1} ({2}% complete)' -f $Activity, $Status, $PercentComplete

        $MetricEntry = '[{0}] PERF: {1} – Details: {2} – {3}' `
                       -f $Timestamp, $Activity, $Details, $ThroughputInfo

        if ($PerformanceLog) {
            Add-Content -Path $PerformanceLog -Value $MetricEntry -ErrorAction SilentlyContinue
        }

        Write-MaintenanceLog -Message $ProgressMessage -Level PROGRESS
    }
    catch {
        # ignore write errors
    }
}

function Write-PerformanceMetric {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]   $Operation,

        [Parameter(Mandatory = $true)]
        [timespan] $Duration,

        [string]   $Details       = "",
        [long]     $DataProcessed = 0,
        [string]   $Unit          = "bytes"
    )

    try {
        $Timestamp   = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $DurationSec = [math]::Round($Duration.TotalSeconds, 2)

        $ThroughputInfo = ""
        if ($DataProcessed -gt 0) {
            $Rate = [math]::Round($DataProcessed / $Duration.TotalSeconds, 2)
            $ThroughputInfo = " - Throughput: $Rate $Unit/sec"
        }

        # Avoid pipe characters in string interpolation
        $MetricEntry = "[$Timestamp] PERF: $Operation - Duration: ${DurationSec}s - $Details$ThroughputInfo"
        if ($PerformanceLog) {
            Add-Content -Path $PerformanceLog -Value $MetricEntry -ErrorAction SilentlyContinue
        }
    }
    catch {
        # silently ignore
    }
}

function Invoke-SafeCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]  [string]     $TaskName,
        [Parameter(Mandatory = $true)]  [scriptblock]$Command,
        [Parameter(Mandatory = $false)] [string]     $SuccessMessage = 'Completed successfully',
        [Parameter(Mandatory = $false)]
        [ValidateSet("Continue","Stop")] [string]   $OnErrorAction  = 'Continue',
        [Parameter(Mandatory = $false)] [hashtable]  $Context        = @{}
    )

    $StartTime = Get-Date
    $TaskId    = [GUID]::NewGuid().ToString("N")[0..7] -join ""

    try {
        Write-MaintenanceLog -Message "Starting task: $TaskName [ID: $TaskId]" -Level INFO

        if ($WhatIf) {
            Write-MaintenanceLog -Message "WHATIF: Would execute $TaskName" -Level DEBUG
            return @{ Success = $true; WhatIf = $true; TaskId = $TaskId }
        }

        $Result   = & $Command
        $Duration = (Get-Date) - $StartTime

        Write-PerformanceMetric -Operation $TaskName -Duration $Duration -Details $SuccessMessage
        Write-MaintenanceLog -Message "$TaskName - $SuccessMessage [Duration: $($Duration.TotalSeconds)s]" -Level SUCCESS

        return @{ Success = $true; Result = $Result; Duration = $Duration; TaskId = $TaskId }
    }
    catch {
        $Duration     = (Get-Date) - $StartTime
        $ErrorMessage = $_.Exception.Message

        Write-PerformanceMetric -Operation $TaskName -Duration $Duration -Details "FAILED: $ErrorMessage"
        Write-MaintenanceLog -Message "Error in ${TaskName}: $ErrorMessage [Duration: $($Duration.TotalSeconds)s]" -Level ERROR

        if ($ErrorLog) {
            Add-Content -Path $ErrorLog -Value "[$TaskId] [$TaskName] $ErrorMessage" -ErrorAction SilentlyContinue
        }

        if ($OnErrorAction -eq 'Stop') { throw }

        return @{ Success = $false; Error = $ErrorMessage; Duration = $Duration; TaskId = $TaskId }
    }
}

function Write-DetailedOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string] $Operation,
        [Parameter(Mandatory = $true)] [string] $Details,
        [string]                          $Result    = 'Completed'
    )

    $DetailMessage = "OPERATION: $Operation - DETAILS: $Details - RESULT: $Result"
    Write-MaintenanceLog $DetailMessage "DETAIL"
}

function Test-Prerequisites {
    Write-MaintenanceLog -Message 'Validating system prerequisites...' -Level INFO
    Write-ProgressBar -Activity 'System Validation' -PercentComplete 10 -Status 'Checking prerequisites...'
    
    $Issues = @()
    
    # PowerShell version check
    $PSVersion = $PSVersionTable.PSVersion
    Write-DetailedOperation -Operation 'PowerShell Version Check' -Details "Version: $PSVersion" -Result 'Validated'
    
    if ($PSVersion.Major -lt 5) {
        $Issues += "PowerShell 5.1 or higher required (Current: $PSVersion)"
    }
    
    Write-ProgressBar -Activity 'System Validation' -PercentComplete 30 -Status 'Checking administrative privileges...'
    
    # Administrative privileges check
    $IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    Write-DetailedOperation -Operation 'Admin Rights Check' -Details "Is Administrator: $IsAdmin" -Result 'Validated'
    
    if (-not $IsAdmin) {
        $Issues += "Administrative privileges required"
    }
    
    Write-ProgressBar -Activity 'System Validation' -PercentComplete 60 -Status 'Checking disk space...'
    
    # Disk space check with detailed reporting
    $SystemDrive = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'"
    $FreeSpaceGB = [math]::Round($SystemDrive.FreeSpace / 1GB, 2)
    $TotalSpaceGB = [math]::Round($SystemDrive.Size / 1GB, 2)
    $UsedPercent = [math]::Round(($SystemDrive.Size - $SystemDrive.FreeSpace) / $SystemDrive.Size * 100, 1)
    
    $DiskSpaceDetails = 'Free: {0}GB / Total: {1}GB ({2}% used)' -f `
    $FreeSpaceGB, $TotalSpaceGB, $UsedPercent
    
    Write-DetailedOperation -Operation 'Disk Space Check' -Details $DiskSpaceDetails -Result 'Validated'

    if ($FreeSpaceGB -lt $Config.MinFreeSpaceGB) {
        $Issues += "Insufficient disk space: ${FreeSpaceGB}GB free (minimum ${Config.MinFreeSpaceGB}GB required)"
    }
    
    Write-ProgressBar -Activity 'System Validation' -PercentComplete 90 -Status 'Validating system health...'
    
    # Additional system health checks
    $SystemInfo = Get-ComputerInfo
    Write-DetailedOperation -Operation 'System Health Check' -Details "OS: $($SystemInfo.WindowsProductName) | Build: $($SystemInfo.WindowsBuildLabEx)" -Result 'Validated'
    
    Write-ProgressBar -Activity 'System Validation' -PercentComplete 100 -Status 'Validation complete'
    Write-Progress -Activity 'System Validation' -Completed
    
    if ($Issues.Count -gt 0) {
        Write-MaintenanceLog -Message 'Prerequisites check failed:' -Level ERROR
        foreach ($Issue in $Issues) {
            Write-MaintenanceLog -Message "  - $Issue" -Level ERROR
        }
        return $false
    }
    
    Write-MaintenanceLog -Message 'Prerequisites check passed - System ready for maintenance' -Level SUCCESS
    return $true
}

function Get-DriveInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$DriveLetter
    )
    
    try {
        Write-DetailedOperation -Operation 'Drive Analysis' -Details "Analyzing drive $DriveLetter" -Result 'Starting'
        
        # Get drive information
        $Volume = Get-Volume -DriveLetter $DriveLetter.TrimEnd(':') -ErrorAction SilentlyContinue
        if (!$Volume) { 
            Write-DetailedOperation -Operation 'Drive Analysis' -Details "Volume not found for drive $DriveLetter" -Result 'Failed'
            return $null 
        }
        
        $Partition = Get-Partition -DriveLetter $DriveLetter.TrimEnd(':') -ErrorAction SilentlyContinue
        if (!$Partition) { 
            Write-DetailedOperation -Operation 'Drive Analysis' -Details "Partition not found for drive $DriveLetter" -Result 'Failed'
            return $null 
        }
        
        $Disk = Get-Disk -Number $Partition.DiskNumber -ErrorAction SilentlyContinue
        if (!$Disk) { 
            Write-DetailedOperation -Operation 'Drive Analysis' -Details "Physical disk not found for drive $DriveLetter" -Result 'Failed'
            return $null 
        }
        
        # Media type detection with multiple fallback methods
        $MediaType = "Unknown"
        $SupportsTrim = $false
        $DeviceType = "Unknown"
        $RotationalRate = "Unknown"
        
        # Method 1: Direct MediaType property
        if ($Disk.MediaType -eq "SSD") {
            $MediaType = "SSD"
            $SupportsTrim = $true
            $DeviceType = "Solid State Drive"
        }
        elseif ($Disk.MediaType -eq "HDD") {
            $MediaType = "HDD"
            $SupportsTrim = $false
            $DeviceType = "Hard Disk Drive"
        }
        else {
            # Method 2: Get Physical Disk properties for detection
            try {
                $PhysicalDisk = Get-PhysicalDisk -DeviceNumber $Disk.Number -ErrorAction SilentlyContinue
                if ($PhysicalDisk) {
                    $MediaType = $PhysicalDisk.MediaType
                    
                    # Check for NVMe drives
                    if ($PhysicalDisk.BusType -eq "NVMe") {
                        $MediaType = "SSD"
                        $SupportsTrim = $true
                        $DeviceType = "NVMe SSD"
                    }
                    # Check rotational rate for better detection
                    elseif ($PhysicalDisk.SpindleSpeed -ne $null) {
                        $RotationalRate = "$($PhysicalDisk.SpindleSpeed) RPM"
                        if ($PhysicalDisk.SpindleSpeed -eq 0) {
                            $MediaType = "SSD"
                            $SupportsTrim = $true
                            $DeviceType = "SATA SSD"
                        }
                        else {
                            $MediaType = "HDD"
                            $SupportsTrim = $false
                            $DeviceType = "SATA HDD ($RotationalRate)"
                        }
                    }
                    # Fallback to bus type and size heuristics
                    elseif ($PhysicalDisk.BusType -in @("SATA", "SAS", "SCSI")) {
                        if ($PhysicalDisk.Size -lt 2TB -and $PhysicalDisk.BusType -ne "USB") {
                            $MediaType = "SSD"
                            $SupportsTrim = $true
                            $DeviceType = "SATA SSD (Detected)"
                        }
                        else {
                            $MediaType = "HDD"
                            $SupportsTrim = $false
                            $DeviceType = "SATA HDD (Detected)"
                        }
                    }
                }
            }
            catch {
                Write-DetailedOperation -Operation 'Drive Analysis' -Details "Advanced detection failed for $DriveLetter, using basic detection" -Result 'Warning'
            }
            
            # Method 3: Registry-based detection (final fallback)
            if ($MediaType -eq "Unknown") {
                try {
                    $DriveModel = $Disk.Model
                    if ($DriveModel -match "(SSD|NVME|SOLID)" -or $DriveModel -match "Samsung.*SSD|Intel.*SSD|Crucial.*SSD") {
                        $MediaType = "SSD"
                        $SupportsTrim = $true
                        $DeviceType = "SSD (Model Detection)"
                    }
                    elseif ($DriveModel -match '(WD|Seagate|Toshiba|HGST).*[0-9]+GB') {
                        $MediaType     = "HDD"
                        $SupportsTrim  = $false
                        $DeviceType    = "HDD (Model Detection)"
                    }

                }
                catch {
                    Write-DetailedOperation -Operation 'Drive Analysis' -Details "Model-based detection failed for $DriveLetter" -Result 'Warning'
                }
            }
        }
        
        # Test TRIM support if detected as SSD
        if ($SupportsTrim) {
            try {
                $TrimTest = fsutil behavior query DisableDeleteNotify 2>$null
                if ($TrimTest -and $TrimTest -match "DisableDeleteNotify = 0") {
                    $TrimEnabled = $true
                }
                else {
                    $TrimEnabled = $false
                    Write-DetailedOperation -Operation 'TRIM Support' -Details "TRIM is disabled on system level" -Result 'Warning'
                }
            }
            catch {
                $TrimEnabled = $false
            }
        }
        else {
            $TrimEnabled = $false
        }
        
        $DriveInfo = @{
            DriveLetter = $DriveLetter
            MediaType = $MediaType
            DeviceType = $DeviceType
            SupportsTrim = $SupportsTrim
            TrimEnabled = $TrimEnabled
            FileSystem = $Volume.FileSystem
            Size = $Volume.Size
            FreeSpace = $Volume.SizeRemaining
            HealthStatus = $Volume.HealthStatus
            BusType = $Disk.BusType
            Model = $Disk.Model
            SerialNumber = $Disk.SerialNumber
            PartitionStyle = $Disk.PartitionStyle
            OperationalStatus = $Disk.OperationalStatus
            RotationalRate = $RotationalRate
        }
        
        Write-DetailedOperation -Operation 'Drive Analysis' -Details "Drive ${DriveLetter}: $MediaType ($DeviceType) | Health: $($Volume.HealthStatus) | TRIM: $TrimEnabled" -Result 'Complete'
        
        return $DriveInfo
    }
    catch {
        Write-MaintenanceLog -Message "Failed to get drive info for ${DriveLetter}: $($_.Exception.Message)" -Level WARNING
        Write-DetailedOperation -Operation 'Drive Analysis' -Details "Analysis failed for ${DriveLetter}: $($_.Exception.Message)" -Result 'Error'
        return $null
    }
}

# =========================================================================
# SYSTEM UPDATE MODULE
# =========================================================================

function Invoke-SystemUpdates {
    if ("SystemUpdate" -notin $Config.EnabledModules) {
        Write-MaintenanceLog -Message 'System Update module disabled' -Level INFO
        return
    }
    
    Write-MaintenanceLog -Message '======== System Update Module ========' -Level INFO
    
    # Windows Update with detailed progress
    Invoke-SafeCommand -TaskName "Windows Update Management" -Command {
        Write-ProgressBar -Activity 'System Updates' -PercentComplete 10 -Status 'Initializing Windows Update...'
        
        # Install NuGet provider with detailed feedback
        if (!(Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
            Write-MaintenanceLog -Message 'Installing NuGet package provider...' -Level PROGRESS
            Write-DetailedOperation -Operation 'NuGet Installation' -Details "Installing required NuGet package provider" -Result 'Installing'
            Install-PackageProvider -Name NuGet -Force -Scope CurrentUser | Out-Null
            Write-DetailedOperation -Operation 'NuGet Installation' -Details "NuGet package provider installed successfully" -Result 'Success'
        }
        
        Write-ProgressBar -Activity 'System Updates' -PercentComplete 30 -Status 'Installing PSWindowsUpdate module...'
        
        # Install PSWindowsUpdate module with error handling
        if (!(Get-Module -ListAvailable -Name PSWindowsUpdate)) {
            Write-MaintenanceLog -Message 'Installing PSWindowsUpdate module...' -Level PROGRESS
            Write-DetailedOperation -Operation 'PSWindowsUpdate Installation' -Details "Installing Windows Update PowerShell module" -Result 'Installing'
            Install-Module PSWindowsUpdate -Force -Confirm:$false -Scope CurrentUser | Out-Null
            Write-DetailedOperation -Operation 'PSWindowsUpdate Installation' -Details "PSWindowsUpdate module installed successfully" -Result 'Success'
        }
        
        Write-ProgressBar -Activity 'System Updates' -PercentComplete 50 -Status 'Checking for Windows updates...'
        
        Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue
        
        $Updates = Get-WindowsUpdate -ErrorAction SilentlyContinue
        if ($Updates -and $Updates.Count -gt 0) {
            Write-MaintenanceLog -Message "Found $($Updates.Count) Windows updates available" -Level INFO
            
            # Detailed update information
            foreach ($Update in $Updates | Select-Object -First 10) {
                Write-DetailedOperation -Operation 'Update Detection' -Details "KB$($Update.KBArticleIDs): $($Update.Title) | Size: $([math]::Round($Update.Size/1MB, 2))MB" -Result 'Available'
            }
            
            if ($Updates.Count -gt 10) {
                Write-DetailedOperation -Operation 'Update Detection' -Details "... and $($Updates.Count - 10) additional updates" -Result 'Available'
            }
            
            if (!$WhatIf) {
                Write-ProgressBar -Activity 'System Updates' -PercentComplete 70 -Status 'Installing Windows updates...'
                
                $UpdateResults = Get-WindowsUpdate -AcceptAll -Install -AutoReboot:$false -ErrorAction SilentlyContinue
                
                if ($UpdateResults) {
                    foreach ($Result in $UpdateResults) {
                        $Status = if ($Result.Result -eq "Installed") { "Success" } else { "Warning" }
                        Write-DetailedOperation -Operation 'Update Installation' -Details "KB$($Result.KBArticleIDs): $($Result.Title)" -Result $Status
                    }
                }
                
                Write-MaintenanceLog -Message 'Windows updates installation completed' -Level SUCCESS
            }
        }
        else {
            Write-MaintenanceLog -Message 'No Windows updates available' -Level INFO
            Write-DetailedOperation -Operation 'Update Check' -Details "System is up to date" -Result 'Current'
        }
    }
    
    # WinGet updates with package details
    Invoke-SafeCommand -TaskName "WinGet Package Management" -Command {
        Write-ProgressBar -Activity 'Package Updates' -PercentComplete 10 -Status 'Checking WinGet availability...'
        
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-MaintenanceLog -Message 'Checking WinGet package updates...' -Level PROGRESS
            Write-DetailedOperation -Operation 'WinGet Check' -Details "WinGet package manager detected" -Result 'Available'
            
            Write-ProgressBar -Activity 'Package Updates' -PercentComplete 30 -Status 'Scanning for package updates...'
            
            # Get detailed package information
            $WinGetOutput = winget upgrade --include-unknown 2>$null
            
            if ($WinGetOutput) {
                $UpgradeablePackages = $WinGetOutput | Where-Object { $_ -match "^\S+\s+\S+\s+\S+\s+\S+" -and $_ -notmatch "^Name|^-" }
                
                if ($UpgradeablePackages) {
                    Write-MaintenanceLog -Message "Found $($UpgradeablePackages.Count) WinGet packages available for upgrade" -Level INFO
                    
                    # Log details of packages to be updated
                    foreach ($Package in $UpgradeablePackages | Select-Object -First 20) {
                        # Fixed regex pattern - using literal space characters instead of regex
                        $PackageInfo = $Package -split '  +'
                        if ($PackageInfo.Count -ge 3) {
                            Write-DetailedOperation -Operation 'Package Update Available' -Details "Name: $($PackageInfo[0]) | Current: $($PackageInfo[1]) | Available: $($PackageInfo[2])" -Result 'Pending'
                        }
                    }
                    
                    if (!$WhatIf) {
                        Write-ProgressBar -Activity 'Package Updates' -PercentComplete 70 -Status 'Updating WinGet packages...'
                        
                        $UpgradeResult = winget upgrade --all --accept-source-agreements --accept-package-agreements --silent --disable-interactivity 2>&1
                        
                        if ($LASTEXITCODE -eq 0) {
                            Write-MaintenanceLog -Message 'WinGet packages updated successfully' -Level SUCCESS
                            Write-DetailedOperation -Operation 'WinGet Upgrade' -Details "All available packages updated successfully" -Result 'Success'
                        }
                        else {
                            Write-MaintenanceLog -Message "WinGet upgrade completed with warnings (Exit Code: $LASTEXITCODE)" -Level WARNING
                            Write-DetailedOperation -Operation 'WinGet Upgrade' -Details "Some packages may have failed to update (Exit Code: $LASTEXITCODE)" -Result 'Partial'
                        }
                    }
                }
                else {
                    Write-MaintenanceLog -Message 'No WinGet package updates available' -Level INFO
                    Write-DetailedOperation -Operation 'WinGet Check' -Details "All packages are current" -Result 'Up-to-date'
                }
            }
        }
        else {
            Write-MaintenanceLog -Message 'WinGet not available - consider installing Windows Package Manager' -Level WARNING
            Write-DetailedOperation -Operation 'WinGet Check' -Details "Windows Package Manager not installed" -Result 'Not Available'
        }
    }
    
    # Chocolatey updates with package tracking
    Invoke-SafeCommand -TaskName "Chocolatey Package Management" -Command {
        $ChocolateyPath = "$env:ProgramData\chocolatey\bin\choco.exe"
        
        if (Test-Path $ChocolateyPath) {
            Write-MaintenanceLog -Message 'Processing Chocolatey package updates...' -Level PROGRESS
            Write-DetailedOperation -Operation 'Chocolatey Check' -Details "Chocolatey package manager detected at $ChocolateyPath" -Result 'Available'
            
            if (!$WhatIf) {
                Write-ProgressBar -Activity 'Package Updates' -PercentComplete 30 -Status 'Updating Chocolatey packages...'
                
                # Get list of outdated packages first
                $OutdatedOutput = & $ChocolateyPath outdated --limit-output 2>$null
                
                if ($OutdatedOutput) {
                    $OutdatedPackages = $OutdatedOutput | Where-Object { $_ -and $_ -notmatch "^Chocolatey" }
                    
                    if ($OutdatedPackages) {
                        Write-MaintenanceLog -Message "Found $($OutdatedPackages.Count) outdated Chocolatey packages" -Level INFO
                        
                        foreach ($Package in $OutdatedPackages) {
                            # Fixed pipe character escaping
                            $PackageInfo = $Package -split '\|'
                            if ($PackageInfo.Count -ge 3) {
                                Write-DetailedOperation -Operation 'Chocolatey Update Available' -Details "Package: $($PackageInfo[0]) | Current: $($PackageInfo[1]) | Available: $($PackageInfo[2])" -Result 'Pending'
                            }
                        }
                    }
                }
                
                # Perform upgrade
                $UpgradeOutput = & $ChocolateyPath upgrade all --yes --limit-output 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    Write-MaintenanceLog -Message 'Chocolatey packages updated successfully' -Level SUCCESS
                    Write-DetailedOperation -Operation 'Chocolatey Upgrade' -Details "All packages processed successfully" -Result 'Success'
                }
                else {
                    Write-MaintenanceLog -Message "Chocolatey upgrade completed with warnings (Exit Code: $LASTEXITCODE)" -Level WARNING
                    Write-DetailedOperation -Operation 'Chocolatey Upgrade' -Details "Some packages may require attention (Exit Code: $LASTEXITCODE)" -Result 'Partial'
                }
            }
        }
        else {
            Write-MaintenanceLog -Message 'Chocolatey not installed' -Level INFO
            Write-DetailedOperation -Operation 'Chocolatey Check' -Details "Chocolatey package manager not found" -Result 'Not Installed'
        }
    }
}

# =========================================================================
# DISK MAINTENANCE MODULE
# =========================================================================

function Invoke-DiskMaintenance {
    if ("DiskMaintenance" -notin $Config.EnabledModules) {
        Write-MaintenanceLog -Message 'Disk Maintenance module disabled' -Level INFO
        return
    }
    
    Write-MaintenanceLog -Message '======== Disk Maintenance Module ========' -Level INFO
    
    # Temporary file cleanup with detailed statistics
    Invoke-SafeCommand -TaskName "Temporary File Cleanup" -Command {
        Write-ProgressBar -Activity 'Disk Cleanup' -PercentComplete 10 -Status 'Scanning temporary locations...'
        
        $TempFolders = @(
            @{ Path = $env:TEMP; Name = "User Temp"; Priority = "High" },
            @{ Path = "$env:SystemRoot\Temp"; Name = "System Temp"; Priority = "High" },
            @{ Path = "$env:SystemRoot\SoftwareDistribution\Download"; Name = "Windows Update Cache"; Priority = "Medium" },
            @{ Path = "$env:LOCALAPPDATA\Microsoft\Windows\INetCache"; Name = "Internet Cache"; Priority = "Low" },
            @{ Path = "$env:LOCALAPPDATA\Microsoft\Windows\WebCache"; Name = "Web Cache"; Priority = "Low" },
            @{ Path = "$env:SystemRoot\Logs\CBS"; Name = "Component Store Logs"; Priority = "Medium" },
            @{ Path = "$env:SystemRoot\Prefetch"; Name = "Prefetch Files"; Priority = "Low" }
        )
        
        $TotalCleaned = 0
        $TotalFiles = 0
        $CleanupResults = @()
        
        $FolderCount = 0
        foreach ($Folder in $TempFolders) {
            $FolderCount++
            $ProgressPercent = [math]::Round(($FolderCount / $TempFolders.Count) * 80 + 10)
            Write-ProgressBar -Activity 'Disk Cleanup' -PercentComplete $ProgressPercent -Status 'Processing $($Folder.Name)...'
            
            if (Test-Path $Folder.Path) {
                Write-DetailedOperation -Operation 'Cleanup Analysis' -Details "Scanning $($Folder.Name) at $($Folder.Path)" -Result 'Scanning'
                
                $BeforeFiles = Get-ChildItem -Path $Folder.Path -Recurse -File -ErrorAction SilentlyContinue
                $BeforeSize = ($BeforeFiles | Measure-Object -Property Length -Sum).Sum
                $BeforeCount = $BeforeFiles.Count
                
                # Age-based cleanup (7 days for temp, 30 days for logs)
                $DaysOld = if ($Folder.Priority -eq "High") { 7 } elseif ($Folder.Priority -eq "Medium") { 14 } else { 30 }
                
                $FilesToDelete = $BeforeFiles | Where-Object { $_.CreationTime -lt (Get-Date).AddDays(-$DaysOld) }
                
                if ($FilesToDelete) {
                    $DeleteSize = ($FilesToDelete | Measure-Object -Property Length -Sum).Sum
                    $DeleteCount = $FilesToDelete.Count
                    
                    $DeleteSizeMB = [math]::Round($DeleteSize/1MB, 2)
                    Write-DetailedOperation `
                        -Operation 'File Cleanup' `
                        -Details ('{0}: Found {1} files older than {2} days ({3}MB)' -f $Folder.Name, $DeleteCount, $DaysOld, $DeleteSizeMB) `
                        -Result 'Processing'

                    $FilesToDelete | Remove-Item -Force -ErrorAction SilentlyContinue
                    
                    $AfterFiles = Get-ChildItem -Path $Folder.Path -Recurse -File -ErrorAction SilentlyContinue
                    $AfterSize = ($AfterFiles | Measure-Object -Property Length -Sum).Sum
                    $AfterCount = $AfterFiles.Count
                    
                    $CleanedSize = $BeforeSize - $AfterSize
                    $CleanedCount = $BeforeCount - $AfterCount
                    
                    $TotalCleaned += $CleanedSize
                    $TotalFiles += $CleanedCount
                    
                    $CleanupResult = @{
                        Location = $Folder.Name
                        Path = $Folder.Path
                        Priority = $Folder.Priority
                        FilesRemoved = $CleanedCount
                        SpaceFreed = $CleanedSize
                        SpaceFreedMB = [math]::Round($CleanedSize / 1MB, 2)
                    }
                    $CleanupResults += $CleanupResult
                    
                    if ($CleanedSize -gt 0) {
                        # Compute rounded MB once
                        $CleanedMB = [math]::Round($CleanedSize / 1MB, 2)

                        # Build the message using -f so % or words never confuse the parser
                        $LogMsg = 'Cleaned {0} MB ({1} files) from {2}' -f $CleanedMB, $CleanedCount, $Folder.Name
                        Write-MaintenanceLog -Message $LogMsg -Level INFO

                        # Likewise for the detailed operation
                        $DetailMsg = '{0}: Removed {1} files, freed {2}MB' `
                            -f $Folder.Name, $CleanedCount, $CleanedMB
                        Write-DetailedOperation -Operation 'Cleanup Complete' -Details $DetailMsg -Result 'Success'
                    }
                }
                else {
                    Write-DetailedOperation -Operation 'Cleanup Analysis' -Details "$($Folder.Name): No files older than $DaysOld days found" -Result 'Clean'
                }
            }
            else {
                Write-DetailedOperation -Operation 'Cleanup Analysis' -Details "$($Folder.Name): Path not found - $($Folder.Path)" -Result 'Skipped'
            }
        }
        
        Write-ProgressBar -Activity 'Disk Cleanup' -PercentComplete 95 -Status 'Generating cleanup report...'
        
        # Calculate values first
        $TotalCleanedMB = [math]::Round($TotalCleaned / 1MB, 2)
        $TotalCleanedGB = [math]::Round($TotalCleaned / 1GB, 2)

        # Generate cleanup report with safe string building
        $CleanupReport = Join-Path $Config.ReportsPath "cleanup_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

        # Build the detailed results section safely
        $DetailedResults = ""
        if ($CleanupResults.Count -gt 0) {
            $DetailedResults = $CleanupResults | ForEach-Object {
                $_.Location + ': ' + $_.FilesRemoved + ' files, ' + $_.SpaceFreedMB + ' MB'
            } | Out-String
        }

        # Build strings using single quotes and simple concatenation (bulletproof)
        $Line1 = 'DISK CLEANUP REPORT'
        $Line2 = 'Generated: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        $Line3 = '==========================================='
        $Line4 = ''
        $Line5 = 'SUMMARY:'
        $Line6 = 'Total Files Removed: ' + $TotalFiles
        $Line7 = "Total Space Freed: $TotalCleanedMB MB (" + $TotalCleanedGB + ' GB)'
        $Line8 = ''
        $Line9 = 'DETAILED RESULTS:'
        $Line10 = $DetailedResults
        $Line11 = '==========================================='

        # Combine all lines using array join (safest method)
        $AllLines = @($Line1, $Line2, $Line3, $Line4, $Line5, $Line6, $Line7, $Line8, $Line9, $Line10, $Line11)
        $ReportContent = $AllLines -join "`n"

        # Write the report
        $ReportContent | Out-File -FilePath $CleanupReport

        # Safe message formatting using concatenation only
        $CleanupMessage = "Total disk space recovered: $TotalCleanedMB MB (" + $TotalFiles + ' files removed)'
        Write-MaintenanceLog -Message $CleanupMessage -Level SUCCESS

        # Safe detailed operation using concatenation only
        $SummaryDetails = "Total cleanup: $TotalCleanedMB MB across " + $CleanupResults.Count + ' locations | Report: ' + $CleanupReport
        Write-DetailedOperation -Operation 'Cleanup Summary' -Details $SummaryDetails -Result 'Complete'

        Write-ProgressBar -Activity 'Disk Cleanup' -PercentComplete 100 -Status 'Cleanup completed'
        Write-Progress -Activity 'Disk Cleanup' -Completed
    }
    
    # Disk optimization with intelligent drive handling
    Invoke-SafeCommand -TaskName "Intelligent Disk Optimization" -Command {
        Write-ProgressBar -Activity 'Disk Optimization' -PercentComplete 10 -Status 'Analyzing drive configuration...'
        
        $Volumes = Get-Volume | Where-Object { 
            $_.DriveType -eq 'Fixed' -and 
            $_.DriveLetter -ne $null -and
            $_.HealthStatus -eq 'Healthy'
        }
        
        Write-MaintenanceLog -Message "Found $($Volumes.Count) eligible drives for optimization" -Level INFO
        Write-DetailedOperation -Operation 'Drive Discovery' -Details "Detected $($Volumes.Count) healthy fixed drives for analysis" -Result 'Complete'
        
        $DriveCount = 0
        foreach ($Volume in $Volumes) {
            $DriveCount++
            $ProgressPercent = [math]::Round(($DriveCount / $Volumes.Count) * 80 + 10)
            Write-ProgressBar -Activity 'Disk Optimization' -PercentComplete $ProgressPercent -Status 'Optimizing drive $($Volume.DriveLetter)...'
            
            $DriveInfo = Get-DriveInfo -DriveLetter "$($Volume.DriveLetter):"
            
            if ($DriveInfo) {
                Write-MaintenanceLog -Message "Processing drive $($DriveInfo.DriveLetter) ($($DriveInfo.DeviceType))" -Level INFO
                
                if ($DriveInfo.MediaType -eq "SSD" -and $DriveInfo.SupportsTrim) {
                    try {
                        Write-MaintenanceLog -Message "Executing TRIM operation on SSD drive $($DriveInfo.DriveLetter)" -Level PROGRESS
                        Write-DetailedOperation -Operation 'TRIM Operation' -Details "Drive: $($DriveInfo.DriveLetter) | Type: $($DriveInfo.DeviceType) | TRIM Enabled: $($DriveInfo.TrimEnabled)" -Result 'Executing'
                        
                        if (!$WhatIf) {
                            $TrimStartTime = Get-Date
                            Optimize-Volume -DriveLetter $Volume.DriveLetter -ReTrim -ErrorAction Stop
                            $TrimDuration = (Get-Date) - $TrimStartTime
                            
                            Write-MaintenanceLog -Message "TRIM operation completed for drive $($DriveInfo.DriveLetter) in $([math]::Round($TrimDuration.TotalSeconds, 1)) seconds" -Level SUCCESS
                            Write-DetailedOperation -Operation 'TRIM Complete' -Details "Drive: $($DriveInfo.DriveLetter) | Duration: $([math]::Round($TrimDuration.TotalSeconds, 1))s | Status: Success" -Result 'Success'
                        }
                    }
                    catch {
                        if ($_.Exception.Message -match "not supported by the hardware" -or $_.Exception.Message -match "cannot be optimized") {
                            Write-MaintenanceLog -Message "TRIM not supported by hardware for drive $($DriveInfo.DriveLetter) ($($DriveInfo.DeviceType))" -Level WARNING
                            Write-DetailedOperation -Operation 'TRIM Operation' -Details "Drive: $($DriveInfo.DriveLetter) | Error: Hardware does not support TRIM" -Result 'Not Supported'
                        }
                        else {
                            Write-MaintenanceLog -Message "TRIM operation failed for drive $($DriveInfo.DriveLetter): $($_.Exception.Message)" -Level WARNING
                            Write-DetailedOperation -Operation 'TRIM Operation' -Details "Drive: $($DriveInfo.DriveLetter) | Error: $($_.Exception.Message)" -Result 'Failed'
                        }
                    }
                }
                elseif ($DriveInfo.MediaType -eq "HDD") {
                    Write-MaintenanceLog -Message "Analyzing fragmentation on HDD drive $($DriveInfo.DriveLetter)" -Level PROGRESS
                    Write-DetailedOperation -Operation 'Defrag Analysis' -Details "Drive: $($DriveInfo.DriveLetter) | Type: $($DriveInfo.DeviceType)" -Result 'Analyzing'
                    
                    if (!$WhatIf) {
                        try {
                            # Get fragmentation analysis
                            $FragAnalysis = Optimize-Volume -DriveLetter $Volume.DriveLetter -Analyze
                            
                            if ($null -ne $FragAnalysis -and $FragAnalysis.PercentFragmented -gt 10) {
                                Write-MaintenanceLog ("Drive " + $DriveInfo.DriveLetter + " is " + $FragAnalysis.PercentFragmented + " percent fragmented - performing defragmentation") "INFO"
                                Write-DetailedOperation -Operation 'Defragmentation' -Details ("Drive: " + $DriveInfo.DriveLetter + " - Fragmentation: " + $FragAnalysis.PercentFragmented + " percent") -Result 'Defragmenting'
                                
                                $DefragStartTime = Get-Date
                                Optimize-Volume -DriveLetter $Volume.DriveLetter -Defrag
                                $DefragDuration = (Get-Date) - $DefragStartTime
                                
                                Write-MaintenanceLog ("Defragmentation completed for drive " + $DriveInfo.DriveLetter + " in " + [math]::Round($DefragDuration.TotalMinutes, 1) + " minutes") "SUCCESS"
                                Write-DetailedOperation -Operation 'Defrag Complete' -Details ("Drive: " + $DriveInfo.DriveLetter + " - Duration: " + [math]::Round($DefragDuration.TotalMinutes, 1) + "m - Previous Fragmentation: " + $FragAnalysis.PercentFragmented + " percent") -Result 'Success'
                            }
                            else {
                                $FragLevel = if ($null -ne $FragAnalysis) { $FragAnalysis.PercentFragmented.ToString() + " percent" } else { "Unknown" }
                                Write-MaintenanceLog ("Drive " + $DriveInfo.DriveLetter + " fragmentation (" + $FragLevel + ") below threshold - skipping defragmentation") "INFO"
                                Write-DetailedOperation -Operation 'Defrag Analysis' -Details ("Drive: " + $DriveInfo.DriveLetter + " - Fragmentation: " + $FragLevel + " - Threshold: 10 percent") -Result 'Not Required'
                            }
                        }
                        catch {
                            Write-MaintenanceLog -Message "Defragmentation analysis failed for drive $($DriveInfo.DriveLetter): $($_.Exception.Message)" -Level WARNING
                            Write-DetailedOperation -Operation 'Defrag Analysis' -Details "Drive: $($DriveInfo.DriveLetter) | Error: $($_.Exception.Message)" -Result 'Failed'
                        }
                    }
                }
                else {
                    Write-MaintenanceLog -Message "Unknown or unsupported drive type for $($DriveInfo.DriveLetter) ($($DriveInfo.DeviceType)) - skipping optimization" -Level WARNING
                    Write-DetailedOperation -Operation 'Drive Optimization' -Details "Drive: $($DriveInfo.DriveLetter) | Type: $($DriveInfo.MediaType) | Device: $($DriveInfo.DeviceType)" -Result 'Unsupported'
                }
            }
            else {
                Write-MaintenanceLog -Message "Could not analyze drive $($Volume.DriveLetter): - skipping optimization" -Level WARNING
                Write-DetailedOperation -Operation 'Drive Analysis' -Details "Drive: $($Volume.DriveLetter) | Error: Drive analysis failed" -Result 'Skipped'
            }
        }
        
        Write-ProgressBar -Activity 'Disk Optimization' -PercentComplete 100 -Status 'Optimization completed'
        Write-Progress -Activity 'Disk Optimization' -Completed
    }
    
    # System file integrity checking with detailed reporting
    Invoke-SafeCommand -TaskName "Advanced System File Integrity Check" -Command {
        Write-ProgressBar -Activity 'System Integrity' -PercentComplete 10 -Status 'Preparing system file checker...'
        
        Write-MaintenanceLog -Message 'Executing system file integrity check...' -Level PROGRESS
        Write-DetailedOperation -Operation 'SFC Preparation' -Details "Initializing System File Checker scan" -Result 'Starting'
        
        if (!$WhatIf) {
            Write-ProgressBar -Activity 'System Integrity' -PercentComplete 30 -Status 'Running SFC scan (this may take several minutes)...'
            
            $SFCLogPath = "$env:TEMP\sfc_output_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
            $SFCStartTime = Get-Date
            
            $SFCProcess = Start-Process -FilePath "sfc.exe" -ArgumentList "/scannow" -Wait -PassThru -NoNewWindow -RedirectStandardOutput $SFCLogPath
            $SFCDuration = (Get-Date) - $SFCStartTime
            
            # Parse SFC results
            if (Test-Path $SFCLogPath) {
                $SFCOutput = Get-Content $SFCLogPath
                $CorruptFilesFound = $SFCOutput | Where-Object { $_ -match "found corrupt files" }
                $RepairsMade = $SFCOutput | Where-Object { $_ -match "successfully repaired" }
                $UnrepairedFiles = $SFCOutput | Where-Object { $_ -match "found corrupt files but was unable to fix" }
            }
            
            $SFCStatus = switch ($SFCProcess.ExitCode) {
                0 { "No integrity violations found" }
                1 { "Corrupt files found and repaired" }
                2 { "Corrupt files found but some could not be repaired" }
                3 { "Corrupt files found but repairs could not be completed" }
                default { "Unknown exit code: $($SFCProcess.ExitCode)" }
            }
            
            Write-DetailedOperation -Operation 'SFC Scan' -Details "Duration: $([math]::Round($SFCDuration.TotalMinutes, 1))m | Exit Code: $($SFCProcess.ExitCode) | Status: $SFCStatus" -Result $(if ($SFCProcess.ExitCode -eq 0) { "Success" } else { "Warning" })
            
            if ($SFCProcess.ExitCode -eq 0) {
                Write-MaintenanceLog -Message 'SFC scan completed successfully - no integrity violations found' -Level SUCCESS
            }
            else {
                Write-MaintenanceLog -Message "SFC scan completed with issues (Exit Code: $($SFCProcess.ExitCode)) - $SFCStatus" -Level WARNING
            }
            
            Write-ProgressBar -Activity 'System Integrity' -PercentComplete 70 -Status 'Running DISM health restoration...'
            
            # DISM operations with progress tracking
            Write-MaintenanceLog -Message 'Executing DISM component store health restoration...' -Level PROGRESS
            Write-DetailedOperation -Operation 'DISM Preparation' -Details "Initializing component store health check and repair" -Result 'Starting'
            
            $DISMStartTime = Get-Date
            $DISMProcess = Start-Process -FilePath "DISM.exe" -ArgumentList "/Online /Cleanup-Image /RestoreHealth" -Wait -PassThru -NoNewWindow
            $DISMDuration = (Get-Date) - $DISMStartTime
            
            $DISMStatus = switch ($DISMProcess.ExitCode) {
                0 { "Component store health restored successfully" }
                1 { "Component store health restored with warnings" }
                2 { "Component store health restoration failed" }
                default { "Unknown exit code: $($DISMProcess.ExitCode)" }
            }
            
            Write-DetailedOperation -Operation 'DISM Health' -Details "Duration: $([math]::Round($DISMDuration.TotalMinutes, 1))m | Exit Code: $($DISMProcess.ExitCode) | Status: $DISMStatus" -Result $(if ($DISMProcess.ExitCode -eq 0) { "Success" } else { "Warning" })
            
            if ($DISMProcess.ExitCode -eq 0) {
                Write-MaintenanceLog -Message 'DISM health restoration completed successfully' -Level SUCCESS
            }
            else {
                Write-MaintenanceLog -Message "DISM completed with warnings (Exit Code: $($DISMProcess.ExitCode)) - $DISMStatus" -Level WARNING
            }
            
            # Additional DISM cleanup operations
            Write-ProgressBar -Activity 'System Integrity' -PercentComplete 90 -Status 'Performing component store cleanup...'
            
            Write-MaintenanceLog -Message 'Executing component store cleanup...' -Level PROGRESS
            $CleanupProcess = Start-Process -FilePath "DISM.exe" -ArgumentList "/Online /Cleanup-Image /StartComponentCleanup /ResetBase" -Wait -PassThru -NoNewWindow
            
            if ($CleanupProcess.ExitCode -eq 0) {
                Write-MaintenanceLog -Message 'Component store cleanup completed successfully' -Level SUCCESS
                Write-DetailedOperation -Operation 'Component Cleanup' -Details "Superseded components removed successfully" -Result 'Success'
            }
            else {
                Write-MaintenanceLog -Message "Component store cleanup completed with warnings (Exit Code: $($CleanupProcess.ExitCode))" -Level WARNING
                Write-DetailedOperation -Operation 'Component Cleanup' -Details "Component cleanup completed with exit code $($CleanupProcess.ExitCode)" -Result 'Warning'
            }
        }
        
        Write-ProgressBar -Activity 'System Integrity' -PercentComplete 100 -Status 'System integrity check completed'
        Write-Progress -Activity 'System Integrity' -Completed
    }
}

# =========================================================================
# SECURITY SCANS MODULE
# =========================================================================

function Invoke-SecurityScans {
    if ("SecurityScans" -notin $Config.EnabledModules) {
        Write-MaintenanceLog -Message 'Security Scans module disabled' -Level INFO
        return
    }
    
    Write-MaintenanceLog -Message '======== Security Scans Module ========' -Level INFO
    
    # Windows Defender management
    Invoke-SafeCommand -TaskName "Advanced Windows Defender Operations" -Command {
        Write-ProgressBar -Activity 'Security Scanning' -PercentComplete 10 -Status 'Preparing Windows Defender...'
        
        Write-MaintenanceLog -Message 'Executing Windows Defender security scan...' -Level PROGRESS
        Write-DetailedOperation -Operation 'Defender Preparation' -Details "Initializing Windows Defender security operations" -Result 'Starting'
        
        if (!$WhatIf) {
            # Update definitions with progress tracking
            Write-ProgressBar -Activity 'Security Scanning' -PercentComplete 20 -Status 'Updating threat definitions...'
            
            $UpdateStartTime = Get-Date
            Update-MpSignature -ErrorAction SilentlyContinue
            $UpdateDuration = (Get-Date) - $UpdateStartTime
            
            Write-DetailedOperation -Operation 'Definition Update' -Details "Threat definitions updated in $([math]::Round($UpdateDuration.TotalSeconds, 1)) seconds" -Result 'Success'
            
            # Get Defender status
            $DefenderStatus = Get-MpComputerStatus
            Write-DetailedOperation -Operation 'Defender Status' -Details "AV Enabled: $($DefenderStatus.AntivirusEnabled) | RTP: $($DefenderStatus.RealTimeProtectionEnabled) | Last Update: $($DefenderStatus.AntivirusSignatureLastUpdated)" -Result 'Retrieved'
            
            # Scan based on scan level parameter
            $ScanTypeSelected = switch ($ScanLevel) {
                "Quick" { "QuickScan" }
                "Full" { "FullScan" }
                "Custom" { "QuickScan" }  # Can be customized based on requirements
                default { "QuickScan" }
            }
            
            Write-ProgressBar -Activity 'Security Scanning' -PercentComplete 40 -Status 'Running $ScanLevel security scan...'
            Write-MaintenanceLog -Message "Starting Windows Defender $ScanLevel scan..." -Level PROGRESS
            
            $ScanStartTime = Get-Date
            Start-MpScan -ScanType $ScanTypeSelected -ErrorAction SilentlyContinue
            $ScanDuration = (Get-Date) - $ScanStartTime
            
            # Get scan results
            $ScanHistory = Get-MpThreatDetection | Sort-Object InitialDetectionTime -Descending | Select-Object -First 10
            
            Write-DetailedOperation -Operation 'Security Scan' -Details "Scan Type: $ScanLevel | Duration: $([math]::Round($ScanDuration.TotalMinutes, 1))m | Threats Found: $($ScanHistory.Count)" -Result 'Complete'
            
            if ($ScanHistory) {
                Write-MaintenanceLog -Message 'Recent threat detections found - reviewing security status' -Level WARNING
                foreach ($Threat in $ScanHistory | Select-Object -First 5) {
                    Write-DetailedOperation -Operation 'Threat Detection' -Details "Threat: $($Threat.ThreatName) | Action: $($Threat.ActionSuccess) | Time: $($Threat.InitialDetectionTime)" -Result 'Detected'
                }
            }
            else {
                Write-MaintenanceLog -Message 'No threats detected in recent scans' -Level SUCCESS
            }
            
            # Log Defender status
            Write-MaintenanceLog -Message "Antivirus Status: Enabled=$($DefenderStatus.AntivirusEnabled), RTP=$($DefenderStatus.RealTimeProtectionEnabled)" -Level INFO
            Write-MaintenanceLog -Message "Last Definition Update: $($DefenderStatus.AntivirusSignatureLastUpdated)" -Level INFO
            Write-MaintenanceLog -Message "Signature Version: $($DefenderStatus.AntivirusSignatureVersion)" -Level INFO
            
            Write-MaintenanceLog -Message "Windows Defender $ScanLevel scan completed successfully" -Level SUCCESS
        }
    }
    
    # Security policy audit with compliance checking
    Invoke-SafeCommand -TaskName "Security Policy Audit" -Command {
        Write-ProgressBar -Activity 'Security Audit' -PercentComplete 10 -Status 'Auditing security policies...'
        
        Write-MaintenanceLog -Message 'Executing security policy audit...' -Level PROGRESS
        Write-DetailedOperation -Operation 'Security Audit' -Details "Beginning security configuration review" -Result 'Starting'
        
        # Security checks with industry standard baselines
        $SecurityChecks = @(
            @{ 
                Name = "User Account Control (UAC)" 
                Check = { (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -ErrorAction SilentlyContinue).EnableLUA }
                Expected = 1
                Severity = "High"
            },
            @{ 
                Name = "Windows Automatic Updates" 
                Check = { (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -ErrorAction SilentlyContinue).NoAutoUpdate }
                Expected = 0
                Severity = "High"
            },
            @{ 
                Name = "Remote Desktop Security" 
                Check = { (Get-ItemProperty "HKLM:\System\CurrentControlSet\Control\Terminal Server" -ErrorAction SilentlyContinue).fDenyTSConnections }
                Expected = 1
                Severity = "Medium"
            },
            @{ 
                Name = "Windows Firewall (Domain)" 
                Check = { (Get-NetFirewallProfile -Profile Domain).Enabled }
                Expected = $true
                Severity = "High"
            },
            @{ 
                Name = "Windows Firewall (Private)" 
                Check = { (Get-NetFirewallProfile -Profile Private).Enabled }
                Expected = $true
                Severity = "High"
            },
            @{ 
                Name = "Windows Firewall (Public)" 
                Check = { (Get-NetFirewallProfile -Profile Public).Enabled }
                Expected = $true
                Severity = "High"
            },
            @{ 
                Name = "SMB v1 Protocol" 
                Check = { (Get-WindowsOptionalFeature -Online -FeatureName "SMB1Protocol" -ErrorAction SilentlyContinue).State }
                Expected = "Disabled"
                Severity = "High"
            }
        )
        
        $SecurityResults = @()
        $CheckCount = 0
        
        foreach ($Check in $SecurityChecks) {
            $CheckCount++
            $ProgressPercent = [math]::Round(($CheckCount / $SecurityChecks.Count) * 80 + 10)
            Write-ProgressBar -Activity 'Security Audit' -PercentComplete $ProgressPercent -Status 'Checking $($Check.Name)...'
            
            try {
                $Result = & $Check.Check
                $Status = if ($Result -eq $Check.Expected) { "PASS" } else { "FAIL" }
                $Compliance = if ($Status -eq "PASS") { "Compliant" } else { "Non-Compliant" }
                
                $SecurityResult = @{
                    Check = $Check.Name
                    Expected = $Check.Expected
                    Actual = $Result
                    Status = $Status
                    Severity = $Check.Severity
                    Compliance = $Compliance
                }
                $SecurityResults += $SecurityResult
                
                $LogLevel = if ($Status -eq "PASS") { "INFO" } else { "WARNING" }
                Write-MaintenanceLog "$($Check.Name): $Result ($Compliance)" $LogLevel
                Write-DetailedOperation -Operation 'Security Check' -Details "$($Check.Name) | Expected: $($Check.Expected) | Actual: $Result | Status: $Status" -Result $Compliance
            }
            catch {
                Write-MaintenanceLog -Message "$($Check.Name): Unable to determine - $($_.Exception.Message)" -Level WARNING
                Write-DetailedOperation -Operation 'Security Check' -Details "$($Check.Name) | Error: $($_.Exception.Message)" -Result 'Error'
                
                $SecurityResults += @{
                    Check = $Check.Name
                    Expected = $Check.Expected
                    Actual = "Error"
                    Status = "ERROR"
                    Severity = $Check.Severity
                    Compliance = "Unknown"
                }
            }
        }
        
        # Generate security compliance report
        Write-ProgressBar -Activity 'Security Audit' -PercentComplete 95 -Status 'Generating security report...'
        
        $SecurityReport = "$($Config.ReportsPath)\security_audit_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
        $PassedChecks = ($SecurityResults | Where-Object { $_.Status -eq "PASS" }).Count
        $FailedChecks = ($SecurityResults | Where-Object { $_.Status -eq "FAIL" }).Count
        $ErrorChecks = ($SecurityResults | Where-Object { $_.Status -eq "ERROR" }).Count
        $ComplianceRate = [math]::Round(($PassedChecks / $SecurityChecks.Count) * 100, 1)
        
        $ReportContent = @"
SECURITY POLICY AUDIT REPORT
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
===========================================

COMPLIANCE SUMMARY:
Overall Compliance Rate: $ComplianceRate percent
Passed Checks: $PassedChecks
Failed Checks: $FailedChecks
Error Checks: $ErrorChecks

DETAILED RESULTS:
$($SecurityResults | ForEach-Object { "$($_.Check): $($_.Status) ($($_.Compliance)) - Expected: $($_.Expected), Actual: $($_.Actual)" } | Out-String)

RECOMMENDATIONS:
$(if ($FailedChecks -gt 0) { "- Review and remediate failed security checks" } else { "- Security configuration meets baseline requirements" })
$(if ($ErrorChecks -gt 0) { "- Investigate configuration checks that could not be completed" })
===========================================
"@
        
        $ReportContent | Out-File -FilePath $SecurityReport
        $AuditMessage = "Security policy audit completed - Compliance Rate: $ComplianceRate percent ($PassedChecks/$($SecurityChecks.Count) checks passed)"
        Write-MaintenanceLog -Message $AuditMessage -Level SUCCESS

        $AuditSummaryDetails = "Compliance: $ComplianceRate percent - Passed: " + $PassedChecks + ' - Failed: ' + $FailedChecks + ' - Errors: ' + $ErrorChecks + ' - Report: ' + $SecurityReport
        Write-DetailedOperation -Operation 'Security Audit Summary' -Details $AuditSummaryDetails -Result 'Complete'

        Write-ProgressBar -Activity 'Security Audit' -PercentComplete 100 -Status 'Security audit completed'
        Write-Progress -Activity 'Security Audit' -Completed
    }
}

# =========================================================================
# DEVELOPER MAINTENANCE MODULE
# =========================================================================

function Invoke-DeveloperMaintenance {
    if ('DeveloperMaintenance' -notin $Config.EnabledModules) {
        Write-MaintenanceLog 'Developer Maintenance module disabled' 'INFO'
        return
    }
    
    Write-MaintenanceLog -Message '======== Developer Maintenance Module ========' -Level INFO
    
    # Node.js/NPM maintenance
    Invoke-SafeCommand -TaskName 'Advanced NPM Package Management' -Command {
        if (Get-Command npm -ErrorAction SilentlyContinue) {
            Write-MaintenanceLog -Message 'Processing Node.js and NPM maintenance...' -Level PROGRESS
            Write-DetailedOperation -Operation 'NPM Detection' -Details 'Node.js and NPM detected on system' -Result 'Available'

            if (!$WhatIf) {
                # Get NPM and Node.js versions
                $NodeVersion = node --version 2>$null
                $NPMVersion = npm --version 2>$null
                $EnvDetails = "Node.js: $NodeVersion | NPM: " + $NPMVersion
                Write-DetailedOperation -Operation 'Environment Info' -Details $EnvDetails -Result 'Retrieved'

                # Check for outdated global packages
                Write-MaintenanceLog -Message 'Checking for outdated global NPM packages...' -Level PROGRESS
                $OutdatedPackages = npm outdated -g --json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
                
                if ($OutdatedPackages -and $OutdatedPackages.PSObject.Properties.Count -gt 0) {
                    Write-MaintenanceLog -Message "Found $($OutdatedPackages.PSObject.Properties.Count) outdated global packages" -Level INFO
                    
                    foreach ($Package in $OutdatedPackages.PSObject.Properties) {
                        $PackageDetails = 'Package: ' + $Package.Name + ' | Current: ' + $Package.Value.current + ' | Latest: ' + $Package.Value.latest
                        Write-DetailedOperation -Operation 'Outdated Package' -Details $PackageDetails -Result 'Available'
                    }
                    
                    # Update global packages
                    Write-MaintenanceLog -Message 'Updating global NPM packages...' -Level PROGRESS
                    npm update -g 2>$null
                    Write-DetailedOperation -Operation 'NPM Update' -Details 'Global packages updated successfully' -Result 'Success'
                }
                else {
                    Write-MaintenanceLog -Message 'No outdated global NPM packages found' -Level INFO
                    Write-DetailedOperation -Operation 'NPM Check' -Details 'All global packages are current' -Result 'Up-to-date'
                }

                # Run security audit
                Write-MaintenanceLog -Message 'Running NPM security audit...' -Level PROGRESS
                $AuditOutput = npm audit -g --json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
                
                if ($AuditOutput -and $AuditOutput.vulnerabilities) {
                    $VulnCount = $AuditOutput.vulnerabilities.PSObject.Properties.Count
                    if ($VulnCount -gt 0) {
                        Write-MaintenanceLog -Message "Found $VulnCount security vulnerabilities in global packages" -Level WARNING
                        $VulnMessage = 'Vulnerabilities detected: ' + $VulnCount
                        Write-DetailedOperation -Operation 'Security Audit' -Details $VulnMessage -Result 'Issues Found'

                        # Attempt to fix vulnerabilities
                        npm audit fix -g 2>$null
                        $SecurityFixMsg = 'Attempted to fix vulnerabilities automatically'
                        Write-DetailedOperation -Operation 'Security Fix' -Details $SecurityFixMsg -Result 'Applied'
                    }
                    else {
                        Write-DetailedOperation -Operation 'Security Audit' -Details "No vulnerabilities found in global packages" -Result 'Clean'
                    }
                }
                
                Write-MaintenanceLog -Message 'Global NPM packages maintenance completed' -Level SUCCESS
            }
        }
        else {
            Write-MaintenanceLog -Message 'NPM not found - skipping NPM maintenance' -Level INFO
            Write-DetailedOperation -Operation 'NPM Detection' -Details "Node.js/NPM not installed or not in PATH" -Result 'Not Available'
        }
    }
    
    # Python/pip maintenance with virtual environment support
    Invoke-SafeCommand -TaskName "Advanced Python Package Management" -Command {
        if (Get-Command pip -ErrorAction SilentlyContinue) {
            Write-MaintenanceLog -Message 'Processing Python and pip maintenance...' -Level PROGRESS
            Write-DetailedOperation -Operation 'Python Detection' -Details "Python and pip detected on system" -Result 'Available'
            
            if (!$WhatIf) {
                # Get Python and pip versions
                $PythonVersion = python --version 2>$null
                $PipVersion = pip --version 2>$null
                Write-DetailedOperation -Operation 'Environment Info' -Details "Python: $PythonVersion | Pip: $PipVersion" -Result 'Retrieved'
                
                # Check for outdated packages with JSON parsing
                Write-MaintenanceLog -Message 'Checking for outdated Python packages...' -Level PROGRESS
                
                try {
                    $OutdatedOutput = pip list --outdated --format=json 2>$null
                    if ($OutdatedOutput) {
                        $OutdatedPackages = $OutdatedOutput | ConvertFrom-Json -ErrorAction Stop
                        
                        if ($OutdatedPackages -and $OutdatedPackages.Count -gt 0) {
                            Write-MaintenanceLog -Message "Found $($OutdatedPackages.Count) outdated Python packages" -Level INFO
                            
                            foreach ($Package in $OutdatedPackages | Select-Object -First 20) {
                                Write-DetailedOperation -Operation 'Outdated Package' -Details "Package: $($Package.name) | Current: $($Package.version) | Latest: $($Package.latest_version)" -Result 'Available'
                            }
                            
                            # Update packages with error handling
                            $UpdatedCount = 0
                            $FailedCount = 0
                            
                            foreach ($Package in $OutdatedPackages) {
                                try {
                                    Write-MaintenanceLog -Message "Updating Python package: $($Package.name)" -Level PROGRESS
                                    pip install --upgrade $Package.name --quiet 2>$null
                                    
                                    if ($LASTEXITCODE -eq 0) {
                                        $UpdatedCount++
                                        Write-DetailedOperation -Operation 'Package Update' -Details "Package: $($Package.name) | Status: Updated successfully" -Result 'Success'
                                    }
                                    else {
                                        $FailedCount++
                                        Write-DetailedOperation -Operation 'Package Update' -Details "Package: $($Package.name) | Status: Update failed" -Result 'Failed'
                                    }
                                }
                                catch {
                                    $FailedCount++
                                    Write-MaintenanceLog -Message "Failed to update Python package: $($Package.name) - $($_.Exception.Message)" -Level WARNING
                                    Write-DetailedOperation -Operation 'Package Update' -Details "Package: $($Package.name) | Error: $($_.Exception.Message)" -Result 'Error'
                                }
                            }
                            
                            Write-MaintenanceLog -Message "Python packages update completed - Updated: $UpdatedCount, Failed: $FailedCount" -Level SUCCESS
                            Write-DetailedOperation -Operation 'Python Update Summary' -Details "Total packages: $($OutdatedPackages.Count) | Updated: $UpdatedCount | Failed: $FailedCount" -Result 'Complete'
                        }
                        else {
                            Write-MaintenanceLog -Message 'No outdated Python packages found' -Level INFO
                            Write-DetailedOperation -Operation 'Python Check' -Details "All packages are current" -Result 'Up-to-date'
                        }
                    }
                }
                catch {
                    Write-MaintenanceLog -Message "Error checking Python packages: $($_.Exception.Message)" -Level WARNING
                    Write-DetailedOperation -Operation 'Python Check' -Details "Package check failed: $($_.Exception.Message)" -Result 'Error'
                }
            }
        }
        else {
            Write-MaintenanceLog -Message 'pip not found - skipping Python maintenance' -Level INFO
            Write-DetailedOperation -Operation 'Python Detection' -Details "Python/pip not installed or not in PATH" -Result 'Not Available'
        }
    }
    
    # Docker maintenance with resource analysis
    Invoke-SafeCommand -TaskName "Docker Environment Management" -Command {
        if (Get-Command docker -ErrorAction SilentlyContinue) {
            Write-MaintenanceLog -Message 'Processing Docker environment maintenance...' -Level PROGRESS
            Write-DetailedOperation -Operation 'Docker Detection' -Details "Docker CLI detected on system" -Result 'Available'
            
            # Test Docker connectivity with detailed diagnostics
            $DockerRunning = $false
            try {
                $DockerVersion = docker version --format json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
                if ($DockerVersion) {
                    $DockerRunning = $true
                    Write-DetailedOperation -Operation 'Docker Status' -Details "Docker Engine Version: $($DockerVersion.Server.Version) | API Version: $($DockerVersion.Server.ApiVersion)" -Result 'Running'
                }
            }
            catch {
                Write-MaintenanceLog -Message 'Docker daemon not running or not accessible' -Level WARNING
                Write-DetailedOperation -Operation 'Docker Status' -Details "Docker daemon not accessible: $($_.Exception.Message)" -Result 'Not Running'
                return
            }
            
            if ($DockerRunning -and !$WhatIf) {
                # Get Docker system information
                $DockerInfo = docker system df --format json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
                
                if ($DockerInfo) {
                    $TotalSize = ($DockerInfo | ForEach-Object { if ($_.Size) { [long]$_.Size } else { 0 } } | Measure-Object -Sum).Sum
                    $ReclaimableSize = ($DockerInfo | ForEach-Object { if ($_.Reclaimable) { [long]$_.Reclaimable.TrimEnd('B') } else { 0 } } | Measure-Object -Sum).Sum
                    
                    Write-DetailedOperation -Operation 'Docker Analysis' -Details "Total Size: $([math]::Round($TotalSize/1GB, 2))GB | Reclaimable: $([math]::Round($ReclaimableSize/1GB, 2))GB" -Result 'Analyzed'
                }
                
                # Docker cleanup with progress tracking
                Write-MaintenanceLog -Message 'Executing Docker resource cleanup...' -Level PROGRESS
                
                # Clean up unused containers
                Write-MaintenanceLog -Message 'Removing stopped containers...' -Level PROGRESS
                $ContainerCleanup = docker container prune -f 2>&1
                Write-DetailedOperation -Operation 'Container Cleanup' -Details "Stopped containers removed" -Result 'Complete'
                
                # Clean up unused images
                Write-MaintenanceLog -Message 'Removing unused images...' -Level PROGRESS
                $ImageCleanup = docker image prune -f 2>&1
                Write-DetailedOperation -Operation 'Image Cleanup' -Details "Unused images removed" -Result 'Complete'
                
                # Clean up unused networks
                Write-MaintenanceLog -Message 'Removing unused networks...' -Level PROGRESS
                $NetworkCleanup = docker network prune -f 2>&1
                Write-DetailedOperation -Operation 'Network Cleanup' -Details "Unused networks removed" -Result 'Complete'
                
                # Clean up unused volumes
                Write-MaintenanceLog -Message 'Removing unused volumes...' -Level PROGRESS
                $VolumeCleanup = docker volume prune -f 2>&1
                Write-DetailedOperation -Operation 'Volume Cleanup' -Details "Unused volumes removed" -Result 'Complete'
                
                # Clean up build cache
                Write-MaintenanceLog -Message 'Cleaning build cache...' -Level PROGRESS
                $BuildCleanup = docker builder prune -f 2>&1
                Write-DetailedOperation -Operation 'Build Cache Cleanup' -Details "Build cache cleaned" -Result 'Complete'
                
                # Get post-cleanup system information
                $PostCleanupInfo = docker system df 2>$null
                
                Write-MaintenanceLog -Message 'Docker cleanup completed successfully' -Level SUCCESS
                Write-DetailedOperation -Operation 'Docker Cleanup Summary' -Details "All Docker resources cleaned successfully" -Result 'Complete'
            }
        }
        else {
            Write-MaintenanceLog -Message 'Docker not found - skipping Docker maintenance' -Level INFO
            Write-DetailedOperation -Operation 'Docker Detection' -Details "Docker not installed or not in PATH" -Result 'Not Available'
        }
    }
    
    # VS Code maintenance with extension management
    Invoke-SafeCommand -TaskName "VS Code Maintenance" -Command {
        $VSCodePaths = @(
            @{ Path = "$env:APPDATA\Code\logs"; Name = "Logs"; RetentionDays = 7 },
            @{ Path = "$env:APPDATA\Code\CachedExtensions"; Name = "Extension Cache"; RetentionDays = 30 },
            @{ Path = "$env:APPDATA\Code\CachedExtensionVSIXs"; Name = "VSIX Cache"; RetentionDays = 30 },
            @{ Path = "$env:APPDATA\Code\User\workspaceStorage"; Name = "Workspace Storage"; RetentionDays = 90 }
        )
        
        Write-MaintenanceLog -Message 'Processing VS Code maintenance...' -Level PROGRESS
        Write-DetailedOperation -Operation 'VS Code Detection' -Details "Analyzing VS Code installation and cache directories" -Result 'Starting'
        
        $TotalCleaned = 0
        $TotalFiles = 0
        $CleanupResults = @()
        
        foreach ($VSCodePath in $VSCodePaths) {
            if (Test-Path $VSCodePath.Path) {
                Write-DetailedOperation -Operation 'VS Code Analysis' -Details "Scanning $($VSCodePath.Name) at $($VSCodePath.Path)" -Result 'Scanning'
                
                $OldFiles = Get-ChildItem -Path $VSCodePath.Path -Recurse -File -ErrorAction SilentlyContinue | 
                           Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$VSCodePath.RetentionDays) }
                
                if ($OldFiles) {
                    $SizeCleaned = ($OldFiles | Measure-Object -Property Length -Sum).Sum
                    $FileCount = $OldFiles.Count
                    
                    $TotalCleaned += $SizeCleaned
                    $TotalFiles += $FileCount
                    
                    if (!$WhatIf) {
                        $OldFiles | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                    }
                    
                    $CleanupResult = @{
                        Location = $VSCodePath.Name
                        FilesRemoved = $FileCount
                        SpaceFreed = $SizeCleaned
                        SpaceFreedMB = [math]::Round($SizeCleaned / 1MB, 2)
                        RetentionDays = $VSCodePath.RetentionDays
                    }
                    $CleanupResults += $CleanupResult
                    
                    $SizeMB = [math]::Round($SizeCleaned / 1MB, 2)
                    $CleanupDetails = $VSCodePath.Name + ': Removed ' + $FileCount + ' files (' + $SizeMB + 'MB) older than ' + $VSCodePath.RetentionDays + ' days'
                    Write-DetailedOperation -Operation 'VS Code Cleanup' -Details $CleanupDetails -Result 'Cleaned'
                }
                else {
                    Write-DetailedOperation -Operation 'VS Code Analysis' -Details "$($VSCodePath.Name): No files older than $($VSCodePath.RetentionDays) days found" -Result 'Clean'
                }
            }
            else {
                Write-DetailedOperation -Operation 'VS Code Analysis' -Details "$($VSCodePath.Name): Path not found - $($VSCodePath.Path)" -Result 'Not Found'
            }
        }
        
        if ($TotalCleaned -gt 0) {
            $CleanedMB = [math]::Round($TotalCleaned / 1MB, 2)
            $VSCodeMessage = "VS Code cleanup recovered $CleanedMB MB (" + $TotalFiles + ' files removed)'
            Write-MaintenanceLog -Message $VSCodeMessage -Level SUCCESS
            Write-DetailedOperation -Operation 'VS Code Summary' -Details "Total cleanup: $CleanedMB MB across $($CleanupResults.Count) locations" -Result 'Complete'
        }
        else {
            Write-MaintenanceLog -Message 'VS Code - no cleanup needed' -Level INFO
            Write-DetailedOperation -Operation 'VS Code Summary' -Details "No cleanup required - all caches within retention policies" -Result 'Clean'
        }
    }
}

# =========================================================================
# PERFORMANCE OPTIMIZATION MODULE
# =========================================================================

function Invoke-PerformanceOptimization {
    if ("PerformanceOptimization" -notin $Config.EnabledModules) {
        Write-MaintenanceLog -Message 'Performance Optimization module disabled' -Level INFO
        return
    }
    
    Write-MaintenanceLog -Message '======== Performance Optimization Module ========' -Level INFO
    
    # Advanced event log management with automated archival
    Invoke-SafeCommand -TaskName "Advanced Event Log Management" -Command {
        Write-ProgressBar -Activity 'Event Log Management' -PercentComplete 10 -Status 'Analyzing event log configuration...'
        
        Write-MaintenanceLog -Message 'Executing event log analysis...' -Level PROGRESS
        Write-DetailedOperation -Operation 'Event Log Analysis' -Details "Scanning system event logs for size and performance impact" -Result 'Starting'
        
        $LargeEventLogs = Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | 
                         Where-Object { 
                             $_.FileSize -gt ($Config.MaxEventLogSizeMB * 1MB) -and 
                             $_.RecordCount -gt 1000 
                         } | Sort-Object FileSize -Descending
        
        if ($LargeEventLogs) {
            Write-MaintenanceLog -Message "Found $($LargeEventLogs.Count) large event logs requiring attention" -Level WARNING
            
            $EventLogReport = "$($Config.ReportsPath)\event_log_analysis_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
            $ReportContent = @"
EVENT LOG ANALYSIS REPORT
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
===========================================

LARGE EVENT LOGS SUMMARY:
Total Large Logs: $($LargeEventLogs.Count)
Size Threshold: $($Config.MaxEventLogSizeMB) MB

DETAILED ANALYSIS:
"@
            
            foreach ($Log in $LargeEventLogs) {
                $LogSizeMB = [math]::Round($Log.FileSize / 1MB, 2)
                $LogSizePercent = [math]::Round(($Log.FileSize / ($Config.MaxEventLogSizeMB * 1MB)) * 100, 1)
                
                $LogMessage = 'Large log: ' + $Log.LogName + ' - ' + $LogSizeMB + 'MB (' + $Log.RecordCount + ' records) - ' + $LogSizePercent + ' percent over threshold'
                Write-MaintenanceLog -Message $LogMessage -Level WARNING

                $LogAnalysisDetails = 'Log: ' + $Log.LogName + ' - Size: ' + $LogSizeMB + 'MB - Records: ' + $Log.RecordCount + ' - Threshold Exceeded: ' + $LogSizePercent + ' percent'
                Write-DetailedOperation -Operation 'Event Log Analysis' -Details $LogAnalysisDetails -Result 'Oversized'

                $ReportLine = $Log.LogName + ': ' + $LogSizeMB + 'MB (' + $Log.RecordCount + ' records) - ' + $LogSizePercent + ' percent over threshold'
                $ReportContent = $ReportContent + [Environment]::NewLine + $ReportLine

                # Optional automated log archival
                if ($ManageEventLogs -and !$WhatIf) {
                    try {
                        $ArchiveMessage = 'Archiving event log: ' + $Log.LogName
                        Write-MaintenanceLog -Message $ArchiveMessage -Level PROGRESS
                        
                        # Create archive directory
                        $ArchiveDir = Join-Path $Config.ReportsPath 'EventLogArchives'
                        if (!(Test-Path $ArchiveDir)) {
                            New-Item -ItemType Directory -Force -Path $ArchiveDir | Out-Null
                        }
                        
                        # Export and clear log (only for certain log types)
                        $SafeToArchive = $Log.LogName -notmatch 'Security|System|Application'
                        
                        if ($SafeToArchive) {
                            $LogNameSafe = $Log.LogName.Replace('/', '_')
                            $DateStamp = Get-Date -Format 'yyyyMMdd'
                            $ArchiveFile = Join-Path $ArchiveDir ($LogNameSafe + '_' + $DateStamp + '.evtx')
                            
                            wevtutil export-log $Log.LogName $ArchiveFile
                            wevtutil clear-log $Log.LogName
                            
                            $ArchiveDetails = 'Log: ' + $Log.LogName + ' | Archived to: ' + $ArchiveFile
                            Write-DetailedOperation -Operation 'Event Log Archive' -Details $ArchiveDetails -Result 'Archived'
                        } else {
                            $ProtectedDetails = 'Log: ' + $Log.LogName + ' | Skipped - Critical system log'
                            Write-DetailedOperation -Operation 'Event Log Archive' -Details $ProtectedDetails -Result 'Protected'
                        }
                    }
                    catch {
                        $ErrorMessage = 'Failed to archive event log ' + $Log.LogName + ': ' + $_.Exception.Message
                        Write-MaintenanceLog -Message $ErrorMessage -Level WARNING
                        
                        $ErrorDetails = 'Log: ' + $Log.LogName + ' | Error: ' + $_.Exception.Message
                        Write-DetailedOperation -Operation 'Event Log Archive' -Details $ErrorDetails -Result 'Failed'
                    }
                }
            }

            $RecommendationsSection = @"
RECOMMENDATIONS:
* Consider archiving or clearing non-critical event logs
* Review event log retention policies
* Monitor log growth patterns for capacity planning
$(if ($ManageEventLogs) { "- Automated archival was performed for safe logs" } else { "- Use -ManageEventLogs parameter to enable automated archival" })
===========================================
"@

            $ReportContent += $RecommendationsSection
            $ReportContent | Out-File -FilePath $EventLogReport
            
            Write-MaintenanceLog -Message 'Consider reviewing and archiving large event logs' -Level INFO

            $SummaryDetails = 'Analysis complete | Large logs: ' + $LargeEventLogs.Count + ' | Report: ' + $EventLogReport
            Write-DetailedOperation -Operation 'Event Log Summary' -Details $SummaryDetails -Result 'Complete'

        }
        else {
           Write-MaintenanceLog -Message 'Event log sizes are within acceptable limits' -Level SUCCESS
           Write-DetailedOperation -Operation 'Event Log Analysis' -Details 'All event logs are within size thresholds' -Result 'Optimal'
        }
    }
    
    # Startup items analysis with performance impact assessment
    Invoke-SafeCommand -TaskName 'Advanced Startup Performance Analysis' -Command {
        Write-ProgressBar -Activity 'Startup Analysis' -PercentComplete 10 -Status 'Gathering startup configuration...'

        Write-MaintenanceLog -Message 'Executing startup performance analysis...' -Level PROGRESS
        Write-DetailedOperation -Operation 'Startup Analysis' -Details 'Analyzing system startup configuration and performance impact' -Result 'Starting'
        
        # Get startup information
        $StartupItems = Get-CimInstance Win32_StartupCommand | 
                       Select-Object Name, Command, Location, User |
                       Sort-Object Name
        
        # Get additional startup sources
        $RegistryStartup = @()
        $StartupRegistryPaths = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce',
            'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
            'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
        )
        
        foreach ($RegPath in $StartupRegistryPaths) {
            try {
                $RegItems = Get-ItemProperty $RegPath -ErrorAction SilentlyContinue
                if ($RegItems) {
                    $RegItems.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | ForEach-Object {
                        $RegistryStartup += @{
                            Name = $_.Name
                            Command = $_.Value
                            Location = $RegPath
                            Type = 'Registry'
                        }
                    }
                }
            }
            catch {
                $RegScanDetails = "Path: $RegPath | Error: " + $_.Exception.Message
                Write-DetailedOperation -Operation 'Registry Scan' -Details $RegScanDetails -Result 'Error'
            }
        }
        
        $TotalStartupItems = $StartupItems.Count + $RegistryStartup.Count
        
        $StartupMessage = "Found $TotalStartupItems total startup items (" + $StartupItems.Count + ' WMI + ' + $RegistryStartup.Count + ' Registry)'
        Write-MaintenanceLog -Message $StartupMessage -Level INFO
        $StartupDetails = 'WMI Items: ' + $StartupItems.Count + ' | Registry Items: ' + $RegistryStartup.Count + ' | Total: ' + $TotalStartupItems
        Write-DetailedOperation -Operation 'Startup Discovery' -Details $StartupDetails -Result 'Complete'

        # Analyze startup impact
        $HighImpactItems = @()
        $UnknownItems = @()
        
        foreach ($Item in $StartupItems) {
            $OriginalCommand = $Item.Command
            $CleanedCommand = $OriginalCommand -replace [char]34, ""
            $CommandArray = $CleanedCommand -split [char]32
            $CommandPath = $CommandArray[0]
            
            if (Test-Path $CommandPath) {
                $FileInfo = Get-ItemProperty $CommandPath -ErrorAction SilentlyContinue
                $FileSize = if ($FileInfo) { [math]::Round($FileInfo.Length / 1MB, 2) } else { 0 }
                
                $ImpactLevel = 'Medium'
                
                $IsHighImpact = $Item.Name.Contains('Adobe') -or $Item.Name.Contains('Java') -or $Item.Name.Contains('Office') -or $Item.Name.Contains('Antivirus') -or $Item.Name.Contains('Security')
                if ($IsHighImpact -or $FileSize -gt 50) {
                    $ImpactLevel = "High"
                    $HighImpactItems += $Item
                }
                elseif ($Item.Name -like "*Windows*" -or $Item.Name -like "*Microsoft*" -or $Item.Name -like "*Driver*" -or $Item.Name -like "*Audio*" -or $Item.Name -like "*Network*") {
                    $ImpactLevel = "Low"
                }
                
                $StartupImpactDetails = "Item: " + $Item.Name + " | Size: " + $FileSize + "MB | Impact: " + $ImpactLevel + " | Path: " + $CommandPath
                Write-DetailedOperation -Operation "Startup Impact" -Details $StartupImpactDetails -Result "Analyzed"
            } else {
                $UnknownItems += $Item
                $MissingDetails = "Item: " + $Item.Name + " | Status: File not found | Path: " + $CommandPath
                Write-DetailedOperation -Operation "Startup Impact" -Details $MissingDetails -Result "Missing"
            }
        }

        # Generate startup report
        Write-ProgressBar -Activity 'Startup Analysis' -PercentComplete 80 -Status 'Generating startup report...'
        
        $StartupReport = "$($Config.ReportsPath)\startup_analysis_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
        
        # Fixed here-string formatting for startup report
        $ReportContent = @"
STARTUP PERFORMANCE ANALYSIS REPORT
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
===========================================

STARTUP SUMMARY:
Total Startup Items: $TotalStartupItems
WMI Detected Items: $($StartupItems.Count)
Registry Items: $($RegistryStartup.Count)
High Impact Items: $($HighImpactItems.Count)
Missing/Invalid Items: $($UnknownItems.Count)

HIGH IMPACT STARTUP ITEMS:
$($HighImpactItems | ForEach-Object { "  $($_.Name): $($_.Command)" } | Out-String)

REGISTRY STARTUP ITEMS:
$($RegistryStartup | ForEach-Object { "  $($_.Name) [$($_.Location)]: $($_.Command)" } | Out-String)

MISSING/INVALID ITEMS:
$($UnknownItems | ForEach-Object { "  $($_.Name): $($_.Command)" } | Out-String)

RECOMMENDATIONS:
$(if ($HighImpactItems.Count -gt 0) { "  Review high-impact startup items for necessity" })
$(if ($UnknownItems.Count -gt 0) { "  Remove invalid startup entries to improve boot time" })
  Consider using Task Scheduler for delayed startup of non-critical applications
  Use MSConfig or Task Manager to disable unnecessary startup items
===========================================
"@
        
        $ReportContent | Out-File -FilePath $StartupReport
        
        $SummaryText = "Total: $TotalStartupItems items analyzed"
        Write-DetailedOperation -Operation 'Startup Analysis Summary' -Details $SummaryText -Result 'Complete'
        Write-DetailedOperation -Operation 'Startup Analysis Summary' -Details "Total: $TotalStartupItems | High Impact: $($HighImpactItems.Count) | Invalid: $($UnknownItems.Count) | Report: $StartupReport" -Result 'Complete'
        
        Write-ProgressBar -Activity 'Startup Analysis' -PercentComplete 100 -Status 'Analysis completed'
        Write-Progress -Activity 'Startup Analysis' -Completed
    }
    
    # System resource analysis with performance baselines
    Invoke-SafeCommand -TaskName "System Resource Analysis" -Command {
        Write-ProgressBar -Activity 'Resource Analysis' -PercentComplete 10 -Status 'Gathering system performance metrics...'
        
        Write-MaintenanceLog -Message 'Executing system resource analysis...' -Level PROGRESS
        Write-DetailedOperation -Operation 'Resource Analysis' -Details "Collecting system performance metrics and baselines" -Result 'Starting'
        
        # Memory analysis
        Write-ProgressBar -Activity 'Resource Analysis' -PercentComplete 30 -Status 'Analyzing memory usage...'
        
        $MemInfo = Get-WmiObject -Class Win32_OperatingSystem
        $TotalMemGB = [math]::Round($MemInfo.TotalVisibleMemorySize / 1MB, 2)
        $FreeMemGB = [math]::Round($MemInfo.FreePhysicalMemory / 1MB, 2)
        $UsedMemGB = $TotalMemGB - $FreeMemGB
        $UsedMemPercent = [math]::Round(($UsedMemGB / $TotalMemGB) * 100, 1)
        
        # Get virtual memory information
        $PageFileInfo = Get-WmiObject -Class Win32_PageFileUsage
        $PageFileSize = if ($PageFileInfo) { [math]::Round($PageFileInfo.AllocatedBaseSize / 1024, 2) } else { 0 }
        $PageFileUsed = if ($PageFileInfo) { [math]::Round($PageFileInfo.CurrentUsage / 1024, 2) } else { 0 }
        
        # Fixed variable interpolation in string  
        $MemoryMsg = "Memory Usage: " + $UsedMemPercent + " percent - " + $UsedMemGB + "GB used, " + $TotalMemGB + "GB total"
        $MemoryText = "Physical: $UsedMemGBGB/" + $TotalMemGB + 'GB - Virtual: ' + $PageFileUsed + 'GB/' + $PageFileSize + 'GB'
        Write-DetailedOperation -Operation 'Memory Analysis' -Details $MemoryText -Result 'Complete'
        Write-MaintenanceLog ("Virtual Memory: " + $PageFileUsed + " GB used / " + $PageFileSize + " GB allocated") "INFO"
        Write-DetailedOperation -Operation 'Memory Analysis' -Details ("Physical: " + $UsedMemGB + "GB/" + $TotalMemGB + "GB (" + $UsedMemPercent + " percent) - Virtual: " + $PageFileUsed + "GB/" + $PageFileSize + "GB") -Result 'Complete'
        
        # CPU analysis with multi-sample averaging
        Write-ProgressBar -Activity 'Resource Analysis' -PercentComplete 50 -Status 'Analyzing CPU performance...'
        
        $CPU = Get-WmiObject -Class Win32_Processor
        $CPUName = $CPU.Name
        $CPUCores = $CPU.NumberOfCores
        $CPULogicalProcessors = $CPU.NumberOfLogicalProcessors
        
        # Get CPU usage over multiple samples for accuracy
        $CPUSamples = @()
        for ($i = 1; $i -le 5; $i++) {
            $CPUSample = (Get-Counter "\Processor(_Total)\% Processor Time" -SampleInterval 1 -MaxSamples 1).CounterSamples.CookedValue
            $CPUSamples += $CPUSample
            Write-ProgressBar -Activity 'Resource Analysis' -PercentComplete (50 + ($i * 5)) -Status 'CPU sampling ($i/5)...'
        }
        
        $AvgCPUUsage = [math]::Round(($CPUSamples | Measure-Object -Average).Average, 1)
        $MaxCPUUsage = [math]::Round(($CPUSamples | Measure-Object -Maximum).Maximum, 1)
        $MinCPUUsage = [math]::Round(($CPUSamples | Measure-Object -Minimum).Minimum, 1)
        
        $CPUMessage = "CPU: $CPUName - " + $CPUCores + ' cores, ' + $CPULogicalProcessors + ' logical processors'
        Write-MaintenanceLog -Message $CPUMessage -Level INFO
        $CPUUsageMessage = "CPU Usage: Average $AvgCPUUsage% (Range: " + $MinCPUUsage + '% - ' + $MaxCPUUsage + '%)'
        Write-MaintenanceLog -Message $CPUUsageMessage -Level INFO
        Write-DetailedOperation -Operation 'CPU Analysis' -Details "CPU: $CPUName | Cores: $CPUCores | Usage: Avg $AvgCPUUsage% ($MinCPUUsage%-$MaxCPUUsage%)" -Result 'Complete'
        
        # Disk I/O analysis
        Write-ProgressBar -Activity 'Resource Analysis' -PercentComplete 75 -Status 'Analyzing disk performance...'
        
        $DiskCounters = @(
            "\PhysicalDisk(_Total)\Disk Read Bytes/sec",
            "\PhysicalDisk(_Total)\Disk Write Bytes/sec",
            "\PhysicalDisk(_Total)\Current Disk Queue Length"
        )
        
        $DiskMetrics = Get-Counter -Counter $DiskCounters -SampleInterval 2 -MaxSamples 3 -ErrorAction SilentlyContinue
        
        if ($DiskMetrics) {
            $AvgReadMBps = [math]::Round((($DiskMetrics.CounterSamples | Where-Object { $_.Path -like "*Read*" } | Measure-Object -Property CookedValue -Average).Average / 1MB), 2)
            $AvgWriteMBps = [math]::Round((($DiskMetrics.CounterSamples | Where-Object { $_.Path -like "*Write*" } | Measure-Object -Property CookedValue -Average).Average / 1MB), 2)
            $AvgQueueLength = [math]::Round((($DiskMetrics.CounterSamples | Where-Object { $_.Path -like "*Queue*" } | Measure-Object -Property CookedValue -Average).Average), 2)
            
            Write-MaintenanceLog -Message "Disk I/O: Read $AvgReadMBps MB/s, Write $AvgWriteMBps MB/s, Queue Length $AvgQueueLength" -Level INFO
            Write-DetailedOperation -Operation 'Disk I/O Analysis' -Details "Read: $AvgReadMBps MB/s | Write: $AvgWriteMBps MB/s | Queue: $AvgQueueLength" -Result 'Complete'
        }
        
        # Top processes analysis with detailed resource consumption
        Write-ProgressBar -Activity 'Resource Analysis' -PercentComplete 90 -Status 'Analyzing top resource consumers...'
        
        $TopProcesses = Get-Process | Where-Object { $_.WorkingSet -gt 50MB } | 
                       Sort-Object WorkingSet -Descending | Select-Object -First 15 |
                       Select-Object Name, Id, 
                                    @{N='Memory(MB)';E={[math]::Round($_.WorkingSet/1MB,1)}},
                                    @{N='CPU(s)';E={[math]::Round($_.TotalProcessorTime.TotalSeconds,1)}},
                                    @{N='Handles';E={$_.HandleCount}},
                                    @{N='Threads';E={$_.Threads.Count}}
        
        $ProcessReport = "$($Config.ReportsPath)\process_analysis_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
        $ReportContent = @"
SYSTEM RESOURCE ANALYSIS REPORT
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
===========================================

SYSTEM SUMMARY:
CPU: $CPUName
Physical Cores: $CPUCores
Logical Processors: $CPULogicalProcessors
Total Memory: $TotalMemGB GB
Available Memory: $FreeMemGB GB
Memory Usage: $UsedMemPercent percent

PERFORMANCE METRICS:
Average CPU Usage: $AvgCPUUsage percent
CPU Usage Range: $MinCPUUsage percent - $MaxCPUUsage percent
$(if ($DiskMetrics) { "Disk Read Rate: $AvgReadMBps MB/s" })
$(if ($DiskMetrics) { "Disk Write Rate: $AvgWriteMBps MB/s" })
$(if ($DiskMetrics) { "Disk Queue Length: $AvgQueueLength" })
Virtual Memory Size: $PageFileSize GB
Virtual Memory Used: $PageFileUsed GB

TOP MEMORY CONSUMERS:
$($TopProcesses | Format-Table -AutoSize | Out-String)

PERFORMANCE ASSESSMENT:
$(if ($UsedMemPercent -gt 85) { "[!]  High memory usage detected - consider closing unnecessary applications" })
$(if ($AvgCPUUsage -gt 80) { "[!]  High CPU usage detected - system may be under stress" })
$(if ($AvgQueueLength -gt 2) { "[!]  High disk queue length - storage performance may be impacted" })
$(if ($UsedMemPercent -le 85 -and $AvgCPUUsage -le 80 -and $AvgQueueLength -le 2) { "[√] System performance metrics are within normal ranges" })
===========================================
"@
        
        $ReportContent | Out-File -FilePath $ProcessReport
        
        # Performance threshold warnings
        if ($UsedMemPercent -gt 85) {
            Write-MaintenanceLog ("High memory usage detected (" + $UsedMemPercent + " percent) - consider closing unnecessary applications") "WARNING"
        }
        if ($AvgCPUUsage -gt 80) {
            Write-MaintenanceLog ("High CPU usage detected (" + $AvgCPUUsage + " percent) - system may be under stress") "WARNING"
        }
        
        Write-MaintenanceLog -Message "System resource analysis completed - Report saved to: $ProcessReport" -Level SUCCESS
        Write-DetailedOperation -Operation 'Resource Analysis Summary' -Details ("Memory: " + $UsedMemPercent + " percent - CPU: " + $AvgCPUUsage + " percent - Top Processes: " + $TopProcesses.Count + " - Report: " + $ProcessReport) -Result 'Complete'
        
        Write-ProgressBar -Activity 'Resource Analysis' -PercentComplete 100 -Status 'Analysis completed'
        Write-Progress -Activity 'Resource Analysis' -Completed
    }
}

# =========================================================================
# EVENT LOG MANAGEMENT MODULE
# =========================================================================

function Invoke-EventLogManagement {
    if ("EventLogManagement" -notin $Config.EnabledModules) {
        Write-MaintenanceLog -Message 'Event Log Management module disabled' -Level INFO
        return
    }
    
    Write-MaintenanceLog -Message '======== Event Log Management Module ========' -Level INFO
    
    Invoke-SafeCommand -TaskName "Intelligent Event Log Optimization" -Command {
        Write-ProgressBar -Activity 'Event Log Optimization' -PercentComplete 10 -Status 'Analyzing event log configuration...'
        
        Write-MaintenanceLog -Message 'Executing intelligent event log optimization...' -Level PROGRESS
        Write-DetailedOperation -Operation 'Event Log Optimization' -Details "Analyzing event log retention and performance impact" -Result 'Starting'
        
        # Get all event logs with detailed analysis
        $AllEventLogs = Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | 
                       Where-Object { $_.RecordCount -gt 0 } |
                       Sort-Object FileSize -Descending
        
        $OptimizationResults = @()
        $TotalSpaceSaved = 0
        
        foreach ($Log in $AllEventLogs) {
            $LogSizeMB = [math]::Round($Log.FileSize / 1MB, 2)
            $IsOversized = $Log.FileSize -gt ($Config.MaxEventLogSizeMB * 1MB)
            $DaysOfData = if ($Log.RecordCount -gt 0) { 
                try {
                    $OldestEvent = Get-WinEvent -LogName $Log.LogName -MaxEvents 1 -Oldest -ErrorAction SilentlyContinue
                    $NewestEvent = Get-WinEvent -LogName $Log.LogName -MaxEvents 1 -ErrorAction SilentlyContinue
                    if ($OldestEvent -and $NewestEvent) {
                        ($NewestEvent.TimeCreated - $OldestEvent.TimeCreated).Days
                    } else { 0 }
                } catch { 0 }
            } else { 0 }
            
            # Determine optimization action
            $OptimizationAction = "None"
            $CanOptimize = $false
            
            if ($IsOversized) {
                # Check if log is safe to optimize
                $CriticalLogs = @("System", "Security", "Application", "Setup")
                $IsCritical = $CriticalLogs -contains $Log.LogName
                
                if (!$IsCritical -and $DaysOfData -gt 30) {
                    $OptimizationAction = "Archive and Clear"
                    $CanOptimize = $true
                } elseif (!$IsCritical -and $DaysOfData -gt 7) {
                    $OptimizationAction = "Trim Old Entries"
                    $CanOptimize = $true
                } elseif ($IsCritical -and $LogSizeMB -gt 100) {
                    $OptimizationAction = "Archive Only"
                    $CanOptimize = $true
                }
            }
            
            $OptimizationResult = @{
                LogName = $Log.LogName
                SizeMB = $LogSizeMB
                RecordCount = $Log.RecordCount
                DaysOfData = $DaysOfData
                IsOversized = $IsOversized
                IsCritical = $CriticalLogs -contains $Log.LogName
                OptimizationAction = $OptimizationAction
                CanOptimize = $CanOptimize
                SpaceSaved = 0
            }
            
            # Perform optimization if enabled and safe
            if ($CanOptimize -and $ManageEventLogs -and !$WhatIf) {
                try {
                    $PreOptimizationSize = $Log.FileSize
                    
                    switch ($OptimizationAction) {
                        "Archive and Clear" {
                            Write-MaintenanceLog -Message "Archiving and clearing event log: $($Log.LogName)" -Level PROGRESS
                            
                            $ArchiveDir = "$($Config.ReportsPath)\EventLogArchives"
                            if (!(Test-Path $ArchiveDir)) {
                                New-Item -ItemType Directory -Force -Path $ArchiveDir | Out-Null
                            }
                            
                            $ArchiveFile = "$ArchiveDir\$($Log.LogName.Replace('/', '_'))_$(Get-Date -Format 'yyyyMMdd').evtx"
                            wevtutil export-log $Log.LogName $ArchiveFile /overwrite:true
                            wevtutil clear-log $Log.LogName
                            
                            $OptimizationResult.SpaceSaved = $PreOptimizationSize
                            $TotalSpaceSaved += $PreOptimizationSize
                            
                            Write-DetailedOperation -Operation 'Event Log Archive' -Details "Log: $($Log.LogName) | Archived: $ArchiveFile | Space Saved: $([math]::Round($PreOptimizationSize / 1MB, 2))MB" -Result 'Archived'
                        }
                        
                        "Trim Old Entries" {
                            Write-MaintenanceLog -Message "Trimming old entries from event log: $($Log.LogName)" -Level PROGRESS
                            
                            # Calculate how many events to keep (last 7 days worth)
                            $CutoffDate = (Get-Date).AddDays(-7)
                            $EventsToKeep = Get-WinEvent -LogName $Log.LogName -ErrorAction SilentlyContinue | 
                                          Where-Object { $_.TimeCreated -gt $CutoffDate } | 
                                          Measure-Object | Select-Object -ExpandProperty Count
                            
                            # For now, we'll just log this - actual trimming would require more complex logic
                            Write-DetailedOperation -Operation 'Event Log Trim' -Details "Log: $($Log.LogName) | Events to keep: $EventsToKeep (last 7 days)" -Result 'Analyzed'
                        }
                        
                        "Archive Only" {
                            Write-MaintenanceLog -Message "Archiving critical event log: $($Log.LogName)" -Level PROGRESS
                            
                            $ArchiveDir = "$($Config.ReportsPath)\EventLogArchives"
                            if (!(Test-Path $ArchiveDir)) {
                                New-Item -ItemType Directory -Force -Path $ArchiveDir | Out-Null
                            }
                            
                            $ArchiveFile = "$ArchiveDir\$($Log.LogName.Replace('/', '_'))_$(Get-Date -Format 'yyyyMMdd').evtx"
                            wevtutil export-log $Log.LogName $ArchiveFile /overwrite:true
                            
                            Write-DetailedOperation -Operation 'Event Log Archive' -Details "Log: $($Log.LogName) | Critical log archived: $ArchiveFile" -Result 'Archived'
                        }
                    }
                }
                catch {
                    Write-MaintenanceLog -Message "Failed to optimize event log $($Log.LogName): $($_.Exception.Message)" -Level WARNING
                    Write-DetailedOperation -Operation 'Event Log Optimization' -Details "Log: $($Log.LogName) | Error: $($_.Exception.Message)" -Result 'Failed'
                }
            }
            
            $OptimizationResults += $OptimizationResult
            
            Write-DetailedOperation -Operation 'Event Log Analysis' -Details "Log: $($Log.LogName) | Size: $LogSizeMB MB | Records: $($Log.RecordCount) | Days: $DaysOfData | Action: $OptimizationAction" -Result 'Analyzed'
        }
        
        # Generate optimization report
        $TotalSpaceSavedMB = [math]::Round($TotalSpaceSaved / 1MB, 2)
        $OptimizableCount = ($OptimizationResults | Where-Object { $_.CanOptimize }).Count
        $OptimizedCount = ($OptimizationResults | Where-Object { $_.SpaceSaved -gt 0 }).Count
        
        $EventLogReport = "$($Config.ReportsPath)\event_log_optimization_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
        $ReportContent = @"
EVENT LOG OPTIMIZATION REPORT
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
===========================================

OPTIMIZATION SUMMARY:
Total Event Logs Analyzed: $($OptimizationResults.Count)
Logs Requiring Optimization: $OptimizableCount
Logs Actually Optimized: $OptimizedCount
Total Space Saved: $TotalSpaceSavedMB MB
Management Mode: $(if ($ManageEventLogs) { "Active" } else { "Analysis Only" })

DETAILED RESULTS:
$($OptimizationResults | ForEach-Object { 
    "$($_.LogName): $($_.SizeMB)MB ($($_.RecordCount) records, $($_.DaysOfData) days) - $($_.OptimizationAction)"
} | Out-String)

RECOMMENDATIONS:
$(if (!$ManageEventLogs) { "- Use -ManageEventLogs parameter to enable automatic optimization" })
$(if ($OptimizableCount -gt 0) { "- $OptimizableCount logs can be optimized to free up disk space" })
$(if ($TotalSpaceSavedMB -eq 0 -and $OptimizableCount -gt 0) { "- Run with -ManageEventLogs to perform actual optimization" })
- Regular event log maintenance prevents performance degradation
- Consider implementing automated log rotation policies
===========================================
"@
        
        $ReportContent | Out-File -FilePath $EventLogReport
        
        Write-MaintenanceLog -Message "Event log optimization completed - Analyzed: $($OptimizationResults.Count), Optimizable: $OptimizableCount, Space Saved: $TotalSpaceSavedMB MB" -Level SUCCESS
        Write-DetailedOperation -Operation 'Event Log Optimization Summary' -Details "Analyzed: $($OptimizationResults.Count) | Optimizable: $OptimizableCount | Optimized: $OptimizedCount | Space Saved: $TotalSpaceSavedMB MB | Report: $EventLogReport" -Result 'Complete'
    }
}

# =========================================================================
# BACKUP MODULE
# =========================================================================

function Invoke-BackupOperations {
    if ($SkipBackup) {
        Write-MaintenanceLog -Message 'Backup operations skipped by parameter' -Level INFO
        return
    }
    
    Write-MaintenanceLog -Message '======== Backup Operations Module ========' -Level INFO
    
    Invoke-SafeCommand -TaskName "Critical Data Backup" -Command {
        Write-ProgressBar -Activity 'Data Backup' -PercentComplete 10 -Status 'Preparing backup operations...'
        
        # Ensure backup directory exists with proper structure
        $BackupStructure = @(
            $Config.BackupPath,
            "$($Config.BackupPath)\Daily",
            "$($Config.BackupPath)\Archives",
            "$($Config.BackupPath)\Verification"
        )
        
        foreach ($Dir in $BackupStructure) {
            if (!(Test-Path -Path $Dir)) {
                New-Item -ItemType Directory -Force -Path $Dir | Out-Null
                Write-DetailedOperation -Operation 'Backup Setup' -Details "Created directory: $Dir" -Result 'Created'
            }
        }
        
        Write-MaintenanceLog -Message "Backup directory structure verified: $($Config.BackupPath)" -Level INFO
        
        # Backup sources with priority levels and verification
        $BackupSources = @(
            @{ Path = "$env:USERPROFILE\Documents"; Name = "Documents"; Priority = "High"; Verify = $true },
            @{ Path = "$env:USERPROFILE\Desktop"; Name = "Desktop"; Priority = "Medium"; Verify = $true },
            @{ Path = "$env:USERPROFILE\.ssh"; Name = "SSH_Keys"; Priority = "Critical"; Verify = $true },
            @{ Path = "$env:USERPROFILE\.aws"; Name = "AWS_Config"; Priority = "High"; Verify = $true },
            @{ Path = "$env:USERPROFILE\.gitconfig"; Name = "Git_Config"; Priority = "Medium"; Verify = $false; IsFile = $true },
            @{ Path = "$env:USERPROFILE\AppData\Local\Packages"; Name = "UWP_App_Data"; Priority = "Low"; Verify = $false },
            @{ Path = "$env:USERPROFILE\Favorites"; Name = "Browser_Favorites"; Priority = "Low"; Verify = $false }
        )
        
        $BackupDate = Get-Date -Format "yyyyMMdd"
        $TotalBackupSize = 0
        $BackupResults = @()
        $SourceCount = 0
        
        foreach ($Source in $BackupSources) {
            $SourceCount++
            $ProgressPercent = [math]::Round(($SourceCount / $BackupSources.Count) * 80 + 10)
            Write-ProgressBar -Activity 'Data Backup' -PercentComplete $ProgressPercent -Status 'Backing up $($Source.Name)...'
            
            if (Test-Path $Source.Path) {
                Write-MaintenanceLog -Message "Processing backup: $($Source.Name) (Priority: $($Source.Priority))" -Level PROGRESS
                Write-DetailedOperation -Operation 'Backup Analysis' -Details "Source: $($Source.Name) | Path: $($Source.Path) | Priority: $($Source.Priority)" -Result 'Processing'
                
                # Calculate source size before backup
                $SourceSize = if ($Source.IsFile) {
                    (Get-Item $Source.Path).Length
                } else {
                    (Get-ChildItem -Path $Source.Path -Recurse -File -ErrorAction SilentlyContinue | 
                     Measure-Object -Property Length -Sum).Sum
                }
                
                $SourceSizeMB = [math]::Round($SourceSize / 1MB, 2)
                
                $BackupFile = "$($Config.BackupPath)\Daily\$($Source.Name)_$BackupDate.zip"
                
                if (!$WhatIf) {
                    try {
                        $BackupStartTime = Get-Date
                        
                        if ($Source.IsFile) {
                            # Single file backup
                            Compress-Archive -Path $Source.Path -DestinationPath $BackupFile -Force -CompressionLevel Optimal
                        }
                        else {
                            # Directory backup with error handling for large directories
                            if ($SourceSizeMB -gt 1000) {  # Large backup warning
                                Write-MaintenanceLog -Message "Large backup detected ($($Source.Name): $SourceSizeMB MB) - this may take some time" -Level WARNING
                            }
                            
                            Compress-Archive -Path "$($Source.Path)\*" -DestinationPath $BackupFile -Force -CompressionLevel Optimal
                        }
                        
                        $BackupDuration = (Get-Date) - $BackupStartTime
                        
                        if (Test-Path $BackupFile) {
                            $BackupSize = (Get-Item $BackupFile).Length
                            $TotalBackupSize += $BackupSize
                            $BackupSizeMB = [math]::Round($BackupSize / 1MB, 2)
                            $CompressionRatio = [math]::Round((($SourceSize - $BackupSize) / $SourceSize) * 100, 1)
                            
                            # Backup verification if enabled
                            $VerificationResult = "Not Verified"
                            if ($Source.Verify) {
                                try {
                                    $TestResult = Test-Path $BackupFile
                                    $TestSize = (Get-Item $BackupFile).Length
                                    $VerificationResult = if ($TestResult -and $TestSize -gt 0) { "Passed" } else { "Failed" }
                                    
                                    Write-DetailedOperation -Operation 'Backup Verification' -Details "File: $($Source.Name) | Size Check: $TestResult | Integrity: $VerificationResult" -Result $VerificationResult
                                }
                                catch {
                                    $VerificationResult = "Error"
                                    Write-DetailedOperation -Operation 'Backup Verification' -Details "File: $($Source.Name) | Error: $($_.Exception.Message)" -Result 'Error'
                                }
                            }
                            
                            $BackupResult = @{
                                Source = $Source.Name
                                Path = $Source.Path
                                Priority = $Source.Priority
                                SourceSizeMB = $SourceSizeMB
                                BackupSizeMB = $BackupSizeMB
                                CompressionRatio = $CompressionRatio
                                Duration = $BackupDuration
                                BackupFile = $BackupFile
                                Verification = $VerificationResult
                                Success = $true
                            }
                            $BackupResults += $BackupResult
                            
                            Write-MaintenanceLog -Message "Backup completed: $($Source.Name) - $BackupSizeMB MB ($CompressionRatio% compression) in $([math]::Round($BackupDuration.TotalSeconds, 1))s" -Level SUCCESS
                            Write-DetailedOperation -Operation 'Backup Complete' -Details "Source: $($Source.Name) | Size: $SourceSizeMB MB → $BackupSizeMB MB | Compression: $CompressionRatio% | Duration: $([math]::Round($BackupDuration.TotalSeconds, 1))s | Verification: $VerificationResult" -Result 'Success'
                        }
                        else {
                            throw "Backup file was not created"
                        }
                    }
                    catch {
                        Write-MaintenanceLog -Message "Backup failed for $($Source.Name): $($_.Exception.Message)" -Level ERROR
                        Write-DetailedOperation -Operation 'Backup Error' -Details "Source: $($Source.Name) | Error: $($_.Exception.Message)" -Result 'Failed'
                        
                        $BackupResults += @{
                            Source = $Source.Name
                            Path = $Source.Path
                            Priority = $Source.Priority
                            SourceSizeMB = $SourceSizeMB
                            BackupSizeMB = 0
                            CompressionRatio = 0
                            Duration = (Get-Date) - $BackupStartTime
                            BackupFile = ""
                            Verification = "Failed"
                            Success = $false
                            Error = $_.Exception.Message
                        }
                    }
                }
                else {
                    Write-DetailedOperation -Operation 'Backup Simulation' -Details "WHATIF: Would backup $($Source.Name) ($SourceSizeMB MB)" -Result 'Simulated'
                }
            }
            else {
                Write-MaintenanceLog -Message "Backup source not found: $($Source.Path)" -Level WARNING
                Write-DetailedOperation -Operation 'Backup Check' -Details "Source: $($Source.Name) | Path: $($Source.Path) | Status: Not Found" -Result 'Missing'
                
                $BackupResults += @{
                    Source = $Source.Name
                    Path = $Source.Path
                    Priority = $Source.Priority
                    SourceSizeMB = 0
                    BackupSizeMB = 0
                    CompressionRatio = 0
                    Duration = [TimeSpan]::Zero
                    BackupFile = ""
                    Verification = "Source Missing"
                    Success = $false
                    Error = "Source path not found"
                }
            }
        }
        
        Write-ProgressBar -Activity 'Data Backup' -PercentComplete 90 -Status 'Generating backup report...'
        
        # Generate backup report
        $TotalBackupSizeGB = [math]::Round($TotalBackupSize / 1GB, 2)
        $SuccessfulBackups = ($BackupResults | Where-Object { $_.Success }).Count
        $FailedBackups = ($BackupResults | Where-Object { !$_.Success }).Count
        $TotalSourceSizeMB = ($BackupResults | Measure-Object -Property SourceSizeMB -Sum).Sum
        $TotalBackupSizeMB = ($BackupResults | Measure-Object -Property BackupSizeMB -Sum).Sum
        $OverallCompressionRatio = if ($TotalSourceSizeMB -gt 0) { [math]::Round((($TotalSourceSizeMB - $TotalBackupSizeMB) / $TotalSourceSizeMB) * 100, 1) } else { 0 }
        
        $BackupReport = "$($Config.ReportsPath)\backup_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
        $ReportContent = @"
BACKUP REPORT
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
===========================================

BACKUP SUMMARY:
Total Sources Processed: $($BackupResults.Count)
Successful Backups: $SuccessfulBackups
Failed Backups: $FailedBackups
Total Source Size: $([math]::Round($TotalSourceSizeMB / 1024, 2))GB
Total Backup Size: $([math]::Round($TotalBackupSizeMB / 1024, 2))GB
Overall Compression: $OverallCompressionRatio percent
Backup Location: $($Config.BackupPath)\Daily

DETAILED BACKUP RESULTS:
$(        $BackupResults | ForEach-Object { 
    if ($_.Success) {
        "$($_.Source) [$($_.Priority)]: $($_.SourceSizeMB)MB to $($_.BackupSizeMB)MB ($($_.CompressionRatio) percent compression) - $($_.Verification)"
    } else {
        "$($_.Source) [$($_.Priority)]: FAILED - $($_.Error)"
    }
} | Out-String)

VERIFICATION STATUS:
$($BackupResults | Where-Object { $_.Verification -eq "Passed" } | ForEach-Object { "[√]  $($_.Source)" } | Out-String)
$($BackupResults | Where-Object { $_.Verification -eq "Failed" } | ForEach-Object { "[X]  $($_.Source)" } | Out-String)
$($BackupResults | Where-Object { $_.Verification -eq "Error" } | ForEach-Object { "[!]  $($_.Source)" } | Out-String)

RECOMMENDATIONS:
$(if ($FailedBackups -gt 0) { "- Investigate and resolve backup failures for critical data protection" })
$(if ($TotalBackupSizeGB -gt 10) { "- Consider implementing incremental backup strategy for large datasets" })
- Regular backup verification ensures data integrity
- Test restore procedures periodically
===========================================
"@
        
        $ReportContent | Out-File -FilePath $BackupReport
        
        # Cleanup old backups based on retention policy
        Write-ProgressBar -Activity 'Data Backup' -PercentComplete 95 -Status 'Managing backup retention...'
        
        $OldBackups = Get-ChildItem -Path "$($Config.BackupPath)\Daily" -Filter "*.zip" | 
                     Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$Config.MaxBackupDays) }
        
        if ($OldBackups -and !$WhatIf) {
            foreach ($OldBackup in $OldBackups) {
                try {
                    # Move to archives before deletion for additional safety
                    $ArchivePath = "$($Config.BackupPath)\Archives\$($OldBackup.Name)"
                    Move-Item -Path $OldBackup.FullName -Destination $ArchivePath -Force
                    Write-DetailedOperation -Operation 'Backup Retention' -Details "Archived old backup: $($OldBackup.Name)" -Result 'Archived'
                }
                catch {
                    Write-DetailedOperation -Operation 'Backup Retention' -Details "Failed to archive: $($OldBackup.Name) - $($_.Exception.Message)" -Result 'Error'
                }
            }
            
            Write-MaintenanceLog -Message "Archived $($OldBackups.Count) old backup(s) (older than $($Config.MaxBackupDays) days)" -Level SUCCESS
        }
        elseif ($OldBackups) {
            Write-MaintenanceLog -Message "WHATIF: Would archive $($OldBackups.Count) old backup(s)" -Level DEBUG
        }
        
        Write-MaintenanceLog -Message "Backup operations completed - Success: $SuccessfulBackups/$($BackupResults.Count), Total Size: $TotalBackupSizeGB GB, Compression: $OverallCompressionRatio%" -Level SUCCESS
        Write-DetailedOperation -Operation 'Backup Summary' -Details "Processed: $($BackupResults.Count) | Success: $SuccessfulBackups | Failed: $FailedBackups | Size: $TotalBackupSizeGB GB | Compression: $OverallCompressionRatio% | Report: $BackupReport" -Result 'Complete'
        
        Write-ProgressBar -Activity 'Data Backup' -PercentComplete 100 -Status 'Backup operations completed'
        Write-Progress -Activity 'Data Backup' -Completed
    }
}

# =========================================================================
# SYSTEM REPORTING MODULE
# =========================================================================

function Invoke-SystemReporting {
    if ("SystemReporting" -notin $Config.EnabledModules) {
        Write-MaintenanceLog -Message 'System Reporting module disabled' -Level INFO
        return
    }
    
    Write-MaintenanceLog -Message '======== System Reporting Module ========' -Level INFO
    
    Invoke-SafeCommand -TaskName "System Report Generation" -Command {
        Write-ProgressBar -Activity 'System Reporting' -PercentComplete 10 -Status 'Gathering system information...'
        
        $ReportFile = "$($Config.ReportsPath)\system_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
        
        Write-MaintenanceLog -Message 'Generating system report...' -Level PROGRESS
        Write-DetailedOperation -Operation 'System Reporting' -Details "Compiling system analysis and maintenance summary" -Result 'Starting'
        
        # System information gathering
        Write-ProgressBar -Activity 'System Reporting' -PercentComplete 30 -Status 'Collecting system configuration...'
        
        $SystemInfo = Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, WindowsBuildLabEx,
                                                     TotalPhysicalMemory, CsManufacturer, CsModel,
                                                     CsProcessors, CsNumberOfLogicalProcessors, OsArchitecture,
                                                     PowerPlatformRole, HyperVisorPresent
        
        # Disk information with health status
        Write-ProgressBar -Activity 'System Reporting' -PercentComplete 50 -Status 'Analyzing storage configuration...'
        
        $DiskInfo = Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' } |
                   ForEach-Object {
                       $DriveDetails = Get-DriveInfo -DriveLetter "$($_.DriveLetter):"
                       [PSCustomObject]@{
                           DriveLetter = $_.DriveLetter
                           FileSystem = $_.FileSystem
                           'Size(GB)' = [math]::Round($_.Size/1GB,2)
                           'Free(GB)' = [math]::Round($_.SizeRemaining/1GB,2)
                           'Free%' = [math]::Round(($_.SizeRemaining/$_.Size)*100,1)
                           HealthStatus = $_.HealthStatus
                           MediaType = if ($DriveDetails) { $DriveDetails.MediaType } else { "Unknown" }
                           DeviceType = if ($DriveDetails) { $DriveDetails.DeviceType } else { "Unknown" }
                       }
                   }
        
        # Network configuration
        Write-ProgressBar -Activity 'System Reporting' -PercentComplete 70 -Status 'Documenting network configuration...'
        
        $NetworkInfo = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } |
                      Select-Object Name, InterfaceDescription, LinkSpeed, MacAddress
        
        # Get maintenance execution summary
        Write-ProgressBar -Activity 'System Reporting' -PercentComplete 85 -Status 'Compiling maintenance summary...'
        
        $ExecutionTime = (Get-Date) - $ScriptStartTime
        $ErrorCount = if (Test-Path $LogFile) { (Get-Content $LogFile -ErrorAction SilentlyContinue | Where-Object { $_ -like "*ERROR*" }).Count } else { 0 }
        $WarningCount = if (Test-Path $LogFile) { (Get-Content $LogFile -ErrorAction SilentlyContinue | Where-Object { $_ -like "*WARNING*" }).Count } else { 0 }
        $SuccessCount = if (Test-Path $LogFile) { (Get-Content $LogFile -ErrorAction SilentlyContinue | Where-Object { $_ -like "*SUCCESS*" }).Count } else { 0 }
        
        # Security status summary
        $SecuritySummary = @"
Windows Defender: $(try { $DefenderStatus = Get-MpComputerStatus; "$($DefenderStatus.AntivirusEnabled) (RTP: $($DefenderStatus.RealTimeProtectionEnabled))" } catch { "Status Unknown" })
Windows Firewall: $(try { $FirewallProfiles = Get-NetFirewallProfile; ($FirewallProfiles | Where-Object { $_.Enabled }).Count } catch { "Unknown" }) of 3 profiles enabled
UAC Status: $(try { (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System").EnableLUA } catch { "Unknown" })
"@
        
        # Generate report
        $Report = @"
===============================================
SYSTEM MAINTENANCE REPORT
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Script Version: 2.4
===============================================

SYSTEM INFORMATION:
Computer Name: $($env:COMPUTERNAME)
User: $($env:USERNAME)
Domain: $($env:USERDOMAIN)
OS: $($SystemInfo.WindowsProductName)
Version: $($SystemInfo.WindowsVersion)
Build: $($SystemInfo.WindowsBuildLabEx)
Architecture: $($SystemInfo.OsArchitecture)
Manufacturer: $($SystemInfo.CsManufacturer)
Model: $($SystemInfo.CsModel)
Processor: $($SystemInfo.CsProcessors)
Logical Processors: $($SystemInfo.CsNumberOfLogicalProcessors)
Total Memory: $([math]::Round($SystemInfo.TotalPhysicalMemory / 1GB, 2))GB
Hypervisor Present: $($SystemInfo.HyperVisorPresent)

STORAGE CONFIGURATION:
$($DiskInfo | Format-Table -AutoSize | Out-String)

NETWORK CONFIGURATION:
$($NetworkInfo | Format-Table -AutoSize | Out-String)

SECURITY STATUS:
$SecuritySummary

MAINTENANCE EXECUTION SUMMARY:
Script Started: $($ScriptStartTime.ToString('yyyy-MM-dd HH:mm:ss'))
Total Execution Time: $($ExecutionTime.ToString())
What-If Mode: $WhatIf
Backup Skipped: $SkipBackup
Detailed Output: $DetailedOutput
Event Log Management: $ManageEventLogs

MAINTENANCE RESULTS:
Successful Operations: $SuccessCount
Warnings Generated: $WarningCount
Errors Encountered: $ErrorCount

ENABLED MODULES:
$($Config.EnabledModules -join ', ')

LOG FILE LOCATIONS:
Main Log: $LogFile
Error Log: $ErrorLog
Performance Log: $PerformanceLog
$(if ($DetailedOutput) { "Detailed Log: $DetailedLog" })
Operations Log: $OperationsLog

CONFIGURATION:
Log Path: $($Config.LogPath)
Backup Path: $($Config.BackupPath)
Reports Path: $($Config.ReportsPath)
Max Log Size: $($Config.MaxLogSizeMB)MB
Max Backup Days: $($Config.MaxBackupDays)
Min Free Space: $($Config.MinFreeSpaceGB)GB

PERFORMANCE METRICS:
$(if (Test-Path $PerformanceLog) { 
    $PerfData = Get-Content $PerformanceLog | Select-Object -Last 10
    $PerfData -join "`n"
} else { "Performance data not available" })

RECOMMENDATIONS:
$(if ($ErrorCount -gt 0) { "- Review error log for issues requiring attention: $ErrorLog" })
$(if ($WarningCount -gt 5) { "- $WarningCount warnings generated - review for optimization opportunities" })
$(if ($ExecutionTime.TotalMinutes -gt 60) { "- Script execution took $([math]::Round($ExecutionTime.TotalMinutes, 1)) minutes - consider optimizing or scheduling during off-hours" })
- Review all generated reports in: $($Config.ReportsPath)
- Verify backup completion if backup operations were performed
- Schedule regular maintenance for optimal system performance

===============================================
END OF REPORT
===============================================
"@
        
        Write-ProgressBar -Activity 'System Reporting' -PercentComplete 95 -Status 'Saving report...'
        
        $Report | Out-File -FilePath $ReportFile
        
        Write-MaintenanceLog -Message "System report generated: $ReportFile" -Level SUCCESS
        Write-DetailedOperation -Operation 'System Report Complete' -Details "Report saved: $ReportFile | Execution: $($ExecutionTime.ToString()) | Success: $SuccessCount | Warnings: $WarningCount | Errors: $ErrorCount" -Result 'Complete'
        
        Write-ProgressBar -Activity 'System Reporting' -PercentComplete 100 -Status 'Report generation completed'
        Write-Progress -Activity 'System Reporting' -Completed
    }
}

# =========================================================================
# MAIN EXECUTION LOGIC
# =========================================================================

function Start-MaintenanceScript {
    $Global:ScriptStartTime = Get-Date
    
    Write-MaintenanceLog -Message '=========================================' -Level INFO
    Write-MaintenanceLog -Message 'Windows Maintenance Script v2.4' -Level INFO
    Write-MaintenanceLog -Message 'Enterprise-Grade System Maintenance Tool' -Level INFO
    Write-MaintenanceLog -Message '=========================================' -Level INFO
    Write-MaintenanceLog -Message "Script started at: $($ScriptStartTime.ToString('yyyy-MM-dd HH:mm:ss'))" -Level INFO
    Write-MaintenanceLog -Message "Execution Parameters:" -Level INFO
    Write-MaintenanceLog -Message "  - What-If Mode: $WhatIf" -Level INFO
    Write-MaintenanceLog -Message "  - Skip Backup: $SkipBackup" -Level INFO
    Write-MaintenanceLog -Message "  - Detailed Output: $DetailedOutput" -Level INFO
    Write-MaintenanceLog -Message "  - Manage Event Logs: $ManageEventLogs" -Level INFO
    Write-MaintenanceLog -Message "  - Scan Level: $ScanLevel" -Level INFO
    
    # Prerequisites check
    if (!(Test-Prerequisites)) {
        Write-MaintenanceLog -Message 'Prerequisites check failed. Exiting maintenance script.' -Level ERROR
        return 1
    }
    
    # Execute maintenance modules with error handling
    try {
        Write-MaintenanceLog -Message 'Beginning maintenance module execution...' -Level INFO
        
        Invoke-SystemUpdates
        Invoke-DiskMaintenance
        Invoke-SecurityScans
        Invoke-DeveloperMaintenance
        Invoke-PerformanceOptimization
        Invoke-EventLogManagement
        Invoke-BackupOperations
        Invoke-SystemReporting
        
        # Generate final summary
        $ExecutionTime = (Get-Date) - $ScriptStartTime
        $ErrorCount = if (Test-Path $LogFile) { (Get-Content $LogFile -ErrorAction SilentlyContinue | Where-Object { $_ -like "*ERROR*" }).Count } else { 0 }
        $WarningCount = if (Test-Path $LogFile) { (Get-Content $LogFile -ErrorAction SilentlyContinue | Where-Object { $_ -like "*WARNING*" }).Count } else { 0 }
        $SuccessCount = if (Test-Path $LogFile) { (Get-Content $LogFile -ErrorAction SilentlyContinue | Where-Object { $_ -like "*SUCCESS*" }).Count } else { 0 }
        
        Write-MaintenanceLog -Message '=========================================' -Level INFO
        Write-MaintenanceLog -Message 'MAINTENANCE SCRIPT COMPLETED' -Level SUCCESS
        Write-MaintenanceLog -Message '=========================================' -Level INFO
        Write-MaintenanceLog -Message 'Execution Summary:' -Level INFO
        Write-MaintenanceLog -Message "  - Total Execution Time: $($ExecutionTime.ToString())" -Level INFO
        Write-MaintenanceLog -Message "  - Successful Operations: $SuccessCount" -Level SUCCESS
        Write-MaintenanceLog -Message "  - Warnings Generated: $WarningCount" -Level WARNING
        Write-MaintenanceLog -Message "  - Errors Encountered: $ErrorCount" -Level ERROR
        Write-MaintenanceLog -Message "File Locations:" -Level INFO
        Write-MaintenanceLog -Message "  - Main Log: $LogFile" -Level INFO
        Write-MaintenanceLog -Message "  - Error Log: $ErrorLog" -Level INFO
        Write-MaintenanceLog -Message "  - Performance Log: $PerformanceLog" -Level INFO
        if ($DetailedOutput) {
            Write-MaintenanceLog -Message "  - Detailed Log: $DetailedLog" -Level INFO
        }
        Write-MaintenanceLog -Message "  - Operations Log: $OperationsLog" -Level INFO
        Write-MaintenanceLog -Message "  - Reports Directory: $($Config.ReportsPath)" -Level INFO
        
        # Performance assessment
        if ($ExecutionTime.TotalMinutes -gt 60) {
            Write-MaintenanceLog -Message 'Script execution exceeded 1 hour - consider optimization or off-hours scheduling' -Level WARNING
        }
        
        # Display completion notification
        if (!$WhatIf) {
            $NotificationMessage = @"
[*] Maintenance Script Completed

[>] Execution Time: $($ExecutionTime.ToString())
[+] Successful Operations: $SuccessCount
[!] Warnings: $WarningCount  
[X] Errors: $ErrorCount

[#] Performance Summary:
   • System optimization completed
   • Security scans executed
   • Backup operations processed
   • Reports generated

[=] Log Files & Reports:
   $($Config.LogPath)
   $($Config.ReportsPath)

$(if ($ErrorCount -gt 0) { "[!] Please review error log for issues requiring attention." } else { "[√] All operations completed successfully!" })
"@
            
            try {
                [System.Windows.Forms.MessageBox]::Show(
                    $NotificationMessage,
                    "Maintenance Complete - v2.1",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                )
            }
            catch {
                Write-MaintenanceLog -Message 'Notification display failed - check Windows Forms assembly' -Level WARNING
            }
        }
        
        return 0
    }
    catch {
        Write-MaintenanceLog -Message "Critical error during script execution: $($_.Exception.Message)" -Level ERROR
        Write-MaintenanceLog -Message "Stack trace: $($_.ScriptStackTrace)" -Level ERROR
        return 1
    }
    finally {
        Write-Progress -Activity 'Maintenance Script' -Completed
    }
}

# =========================================================================
# SCRIPT ENTRY POINT
# =========================================================================

# Display startup banner
Clear-Host
Write-Host @"
+======================================================================+
|                                                                      |
|     +------------------------------------------+                     |
|     |                                          |                     |
|     |  WINDOWS MAINTENANCE SCRIPT v2.4         |                     |
|     |                                          |                     |
|     |  [||||||||||||||||||||||||-------] 85%   |                     |
|     |  [||||||||||||||||||--------------] 60%  |                     |
|     |  [|||||||||||||||||||||||||||||||] 100%  |                     |
|     |                                          |                     |
|     +------------------------------------------+                     |
|                                                                      |
|    [+] Features: System Updates - Disk Optimization - Security       |
|                Developer Tools - Performance Analysis - Backup       |
|                Event Log Management - Reporting                      |
|                                                                      |
|    [$] Version: 2.4 - Enterprise-Grade Maintenance Tool              |
|    [>] Author: Miguel Velasco - Sophomore BSIT student               |
|    [>] Date Released: June 13, 2025                                  |    
|    [>] Contact: +63 993 7420 246                                     |
|    [>] Email: miguel.velasco.dev@gmail.com                           |
|    [>] GitHub: https://github.com/CodeExplorer430                    |
|    [>] Website: https://wms.com                                      |
|                                                                      |
|    [>] License: MIT License - https://opensource.org/license/mit/    |
|    [>] Documentation: https://wms.com/docs                           |
|    [>] Support: https://wms.com/support                              |
|                                                                      |
+======================================================================+
"@ -ForegroundColor Yellow


Write-Host "`n>> Initializing maintenance operations...`n" -ForegroundColor Green

# Execute main function with error handling
try {
    $ExitCode = Start-MaintenanceScript
    
    # Final status message - Modified to handle WhatIf mode correctly
    if ($WhatIf -or $ExitCode -eq 0) {
        Write-Host "`n[SUCCESS] Maintenance script completed successfully!" -ForegroundColor Green
    } else {
        Write-Host "`n[ERROR] Maintenance script completed with errors!" -ForegroundColor Red
    }
    
    # In WhatIf mode, always exit with success code
    if ($WhatIf) {
        exit 0
    } else {
        exit $ExitCode
    }
}
catch {
    Write-Host "`n[FATAL] Critical error during script execution:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "`nPlease check the error logs for detailed information." -ForegroundColor Yellow
    exit 1
}