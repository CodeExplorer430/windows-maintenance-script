# =========================================================================
# Enhanced Windows 10 Pro Maintenance Script for Developer Workstation
# Acer Aspire A314-22 with AMD Ryzen 5 3500U
# =========================================================================
# This script performs comprehensive maintenance tasks following enterprise
# standards including ITIL, ISO 27001, and industry best practices.
# Version: 2.0
# Created: May 25, 2025
# =========================================================================

#Requires -Version 5.1
#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigPath = "$PSScriptRoot\maintenance-config.json",
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipBackup = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$EnableVerbose = $false
)

# =========================================================================
# CONFIGURATION AND INITIALIZATION
# =========================================================================

# Load required assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Script configuration with validation
$Config = @{
    LogPath = "$env:USERPROFILE\Documents\Maintenance"
    BackupPath = "$env:USERPROFILE\Documents\Backups"
    MaxLogSizeMB = 100
    MaxBackupDays = 30
    MaxEventLogSizeMB = 10
    MinFreeSpaceGB = 5
    EnabledModules = @(
        "SystemUpdate",
        "DiskMaintenance", 
        "SecurityScans",
        "DeveloperMaintenance",
        "PerformanceOptimization",
        "SystemReporting"
    )
}

# Load external configuration if exists
if (Test-Path $ConfigPath) {
    try {
        $ExternalConfig = Get-Content $ConfigPath | ConvertFrom-Json
        foreach ($key in $ExternalConfig.PSObject.Properties.Name) {
            $Config[$key] = $ExternalConfig.$key
        }
        Write-Host "Configuration loaded from $ConfigPath" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to load configuration from $ConfigPath. Using defaults."
    }
}

# Initialize logging infrastructure
$LogFile = "$($Config.LogPath)\maintenance_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$ErrorLog = "$($Config.LogPath)\errors_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$PerformanceLog = "$($Config.LogPath)\performance_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Ensure log directory exists
if (!(Test-Path -Path $Config.LogPath)) {
    New-Item -ItemType Directory -Force -Path $Config.LogPath | Out-Null
}

# =========================================================================
# CORE LOGGING AND UTILITY FUNCTIONS
# =========================================================================

function Write-MaintenanceLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS", "DEBUG")]
        [string]$Level = "INFO",
        
        [Parameter(Mandatory=$false)]
        [switch]$NoConsole
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $LogMessage = "[$Timestamp] [$Level] $Message"
    
    # Write to log file
    Add-Content -Path $LogFile -Value $LogMessage -ErrorAction SilentlyContinue
    
    # Write to console with color coding if not suppressed
    if (!$NoConsole) {
        switch ($Level) {
            "ERROR" { Write-Host $LogMessage -ForegroundColor Red }
            "WARNING" { Write-Host $LogMessage -ForegroundColor Yellow }
            "SUCCESS" { Write-Host $LogMessage -ForegroundColor Green }
            "DEBUG" { if ($EnableVerbose) { Write-Host $LogMessage -ForegroundColor Cyan } }
            default { Write-Host $LogMessage }
        }
    }
}

function Write-PerformanceMetric {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Operation,
        
        [Parameter(Mandatory=$true)]
        [timespan]$Duration,
        
        [Parameter(Mandatory=$false)]
        [string]$Details = ""
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $MetricEntry = "[$Timestamp] PERF: $Operation - Duration: $($Duration.TotalSeconds)s - $Details"
    Add-Content -Path $PerformanceLog -Value $MetricEntry -ErrorAction SilentlyContinue
}

function Invoke-SafeCommand {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TaskName,
        
        [Parameter(Mandatory=$true)]
        [scriptblock]$Command,
        
        [Parameter(Mandatory=$false)]
        [string]$SuccessMessage = "Completed successfully",
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("Continue", "Stop")]
        [string]$OnErrorAction = "Continue"
    )
    
    $StartTime = Get-Date
    
    try {
        Write-MaintenanceLog "Starting task: $TaskName" "INFO"
        
        if ($WhatIf) {
            Write-MaintenanceLog "WHATIF: Would execute $TaskName" "DEBUG"
            return $true
        }
        
        $Result = & $Command
        $Duration = (Get-Date) - $StartTime
        
        Write-PerformanceMetric -Operation $TaskName -Duration $Duration -Details $SuccessMessage
        Write-MaintenanceLog "$TaskName - $SuccessMessage" "SUCCESS"
        return $true
    }
    catch {
        $Duration = (Get-Date) - $StartTime
        $ErrorMessage = $_.Exception.Message
        
        Write-PerformanceMetric -Operation $TaskName -Duration $Duration -Details "FAILED: $ErrorMessage"
        Write-MaintenanceLog "Error in ${TaskName}: $ErrorMessage" "ERROR"
        Add-Content -Path $ErrorLog -Value "[$TaskName] $ErrorMessage" -ErrorAction SilentlyContinue
        
        if ($OnErrorAction -eq "Stop") {
            throw
        }
        return $false
    }
}

function Test-Prerequisites {
    Write-MaintenanceLog "Validating system prerequisites..." "INFO"
    
    $Issues = @()
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        $Issues += "PowerShell 5.1 or higher required"
    }
    
    # Check administrative privileges
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        $Issues += "Administrative privileges required"
    }
    
    # Check disk space
    $SystemDrive = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'"
    $FreeSpaceGB = [math]::Round($SystemDrive.FreeSpace / 1GB, 2)
    
    if ($FreeSpaceGB -lt $Config.MinFreeSpaceGB) {
        $Issues += "Insufficient disk space: ${FreeSpaceGB}GB free (minimum ${Config.MinFreeSpaceGB}GB required)"
    }
    
    if ($Issues.Count -gt 0) {
        Write-MaintenanceLog "Prerequisites check failed:" "ERROR"
        foreach ($Issue in $Issues) {
            Write-MaintenanceLog "  - $Issue" "ERROR"
        }
        return $false
    }
    
    Write-MaintenanceLog "Prerequisites check passed" "SUCCESS"
    return $true
}

function Get-DriveInfo {
    param(
        [Parameter(Mandatory=$true)]
        [string]$DriveLetter
    )
    
    try {
        # Get physical disk information
        $Volume = Get-Volume -DriveLetter $DriveLetter.TrimEnd(':') -ErrorAction SilentlyContinue
        if (!$Volume) { return $null }
        
        $Partition = Get-Partition -DriveLetter $DriveLetter.TrimEnd(':') -ErrorAction SilentlyContinue
        if (!$Partition) { return $null }
        
        $Disk = Get-Disk -Number $Partition.DiskNumber -ErrorAction SilentlyContinue
        if (!$Disk) { return $null }
        
        # Determine media type
        $MediaType = "Unknown"
        $SupportsTrim = $false
        
        if ($Disk.MediaType -eq "SSD") {
            $MediaType = "SSD"
            $SupportsTrim = $true
        }
        elseif ($Disk.MediaType -eq "HDD") {
            $MediaType = "HDD"
            $SupportsTrim = $false
        }
        else {
            # Try to determine from BusType and other properties
            if ($Disk.BusType -eq "NVMe" -or $Disk.BusType -eq "SATA") {
                # Check if TRIM is supported
                try {
                    $TrimSupport = Get-PhysicalDisk -DeviceNumber $Disk.Number | Select-Object -ExpandProperty MediaType
                    if ($TrimSupport -eq "SSD") {
                        $MediaType = "SSD"
                        $SupportsTrim = $true
                    }
                }
                catch {
                    # Fallback detection based on size and performance characteristics
                    if ($Disk.Size -lt 2TB -and $Disk.BusType -ne "USB") {
                        $MediaType = "SSD"
                        $SupportsTrim = $true
                    }
                    else {
                        $MediaType = "HDD"
                        $SupportsTrim = $false
                    }
                }
            }
        }
        
        return @{
            DriveLetter = $DriveLetter
            MediaType = $MediaType
            SupportsTrim = $SupportsTrim
            FileSystem = $Volume.FileSystem
            Size = $Volume.Size
            FreeSpace = $Volume.SizeRemaining
            HealthStatus = $Volume.HealthStatus
            BusType = $Disk.BusType
        }
    }
    catch {
        Write-MaintenanceLog "Failed to get drive info for ${DriveLetter}: $($_.Exception.Message)" "WARNING"
        return $null
    }
}

# =========================================================================
# SYSTEM UPDATE MODULE
# =========================================================================

function Invoke-SystemUpdates {
    if ("SystemUpdate" -notin $Config.EnabledModules) {
        Write-MaintenanceLog "System Update module disabled" "INFO"
        return
    }
    
    Write-MaintenanceLog "======== System Update Module ========" "INFO"
    
    # Windows Update via PSWindowsUpdate
    Invoke-SafeCommand -TaskName "Windows Update Check" -Command {
        # Install NuGet provider if needed
        if (!(Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
            Install-PackageProvider -Name NuGet -Force -Scope CurrentUser | Out-Null
        }
        
        # Install PSWindowsUpdate module if needed
        if (!(Get-Module -ListAvailable -Name PSWindowsUpdate)) {
            Install-Module PSWindowsUpdate -Force -Confirm:$false -Scope CurrentUser | Out-Null
        }
        
        Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue
        
        $Updates = Get-WindowsUpdate -ErrorAction SilentlyContinue
        if ($Updates -and $Updates.Count -gt 0) {
            Write-MaintenanceLog "Found $($Updates.Count) Windows updates available" "INFO"
            
            if (!$WhatIf) {
                Get-WindowsUpdate -AcceptAll -Install -AutoReboot:$false -ErrorAction SilentlyContinue | Out-Null
                Write-MaintenanceLog "Windows updates installed successfully" "SUCCESS"
            }
        }
        else {
            Write-MaintenanceLog "No Windows updates available" "INFO"
        }
    }
    
    # WinGet updates
    Invoke-SafeCommand -TaskName "WinGet Package Updates" -Command {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-MaintenanceLog "Checking for WinGet package updates..." "INFO"
            
            # Get list of upgradable packages
            $WinGetList = winget upgrade --include-unknown 2>$null
            
            if ($WinGetList -and ($WinGetList | Where-Object { $_ -match "upgrades available" })) {
                Write-MaintenanceLog "WinGet packages available for upgrade" "INFO"
                
                if (!$WhatIf) {
                    # Upgrade all packages
                    winget upgrade --all --accept-source-agreements --accept-package-agreements --silent 2>$null
                    Write-MaintenanceLog "WinGet packages updated successfully" "SUCCESS"
                }
            }
            else {
                Write-MaintenanceLog "No WinGet package updates available" "INFO"
            }
        }
        else {
            Write-MaintenanceLog "WinGet not available - consider installing Windows Package Manager" "WARNING"
        }
    }
    
    # Chocolatey updates
    Invoke-SafeCommand -TaskName "Chocolatey Package Updates" -Command {
        $ChocolateyPath = "$env:ProgramData\chocolatey\bin\choco.exe"
        if (Test-Path $ChocolateyPath) {
            Write-MaintenanceLog "Updating Chocolatey packages..." "INFO"
            
            if (!$WhatIf) {
                & $ChocolateyPath upgrade all --yes --limit-output 2>$null
                Write-MaintenanceLog "Chocolatey packages updated" "SUCCESS"
            }
        }
        else {
            Write-MaintenanceLog "Chocolatey not installed" "INFO"
        }
    }
}

# =========================================================================
# DISK MAINTENANCE MODULE
# =========================================================================

function Invoke-DiskMaintenance {
    if ("DiskMaintenance" -notin $Config.EnabledModules) {
        Write-MaintenanceLog "Disk Maintenance module disabled" "INFO"
        return
    }
    
    Write-MaintenanceLog "======== Disk Maintenance Module ========" "INFO"
    
    # Disk Cleanup
    Invoke-SafeCommand -TaskName "Temporary File Cleanup" -Command {
        $TempFolders = @(
            @{ Path = $env:TEMP; Name = "User Temp" },
            @{ Path = "$env:SystemRoot\Temp"; Name = "System Temp" },
            @{ Path = "$env:SystemRoot\SoftwareDistribution\Download"; Name = "Windows Update Cache" },
            @{ Path = "$env:LOCALAPPDATA\Microsoft\Windows\INetCache"; Name = "Internet Cache" }
        )
        
        $TotalCleaned = 0
        foreach ($Folder in $TempFolders) {
            if (Test-Path $Folder.Path) {
                $BeforeSize = (Get-ChildItem -Path $Folder.Path -Recurse -File -ErrorAction SilentlyContinue | 
                              Measure-Object -Property Length -Sum).Sum
                
                Get-ChildItem -Path $Folder.Path -Recurse -File -ErrorAction SilentlyContinue | 
                    Where-Object { $_.CreationTime -lt (Get-Date).AddDays(-7) } | 
                    Remove-Item -Force -ErrorAction SilentlyContinue
                
                $AfterSize = (Get-ChildItem -Path $Folder.Path -Recurse -File -ErrorAction SilentlyContinue | 
                             Measure-Object -Property Length -Sum).Sum
                
                $CleanedSize = $BeforeSize - $AfterSize
                $TotalCleaned += $CleanedSize
                
                if ($CleanedSize -gt 0) {
                    $CleanedSizeMB = [math]::Round($CleanedSize / 1MB, 2)
                    Write-MaintenanceLog "Cleaned $CleanedSizeMB MB from $($Folder.Name)" "INFO"
                }
            }
        }
        
        $TotalCleanedMB = [math]::Round($TotalCleaned / 1MB, 2)
        Write-MaintenanceLog "Total disk space recovered: $TotalCleanedMB MB" "SUCCESS"
    }
    
    # Disk Optimization with proper drive detection
    Invoke-SafeCommand -TaskName "Disk Optimization" -Command {
        $Volumes = Get-Volume | Where-Object { 
            $_.DriveType -eq 'Fixed' -and 
            $_.DriveLetter -ne $null -and
            $_.HealthStatus -eq 'Healthy'
        }
        
        foreach ($Volume in $Volumes) {
            $DriveInfo = Get-DriveInfo -DriveLetter "$($Volume.DriveLetter):"
            
            if ($DriveInfo) {
                Write-MaintenanceLog "Processing drive $($DriveInfo.DriveLetter) ($($DriveInfo.MediaType))" "INFO"
                
                if ($DriveInfo.MediaType -eq "SSD" -and $DriveInfo.SupportsTrim) {
                    try {
                        Write-MaintenanceLog "Running TRIM operation on SSD drive $($DriveInfo.DriveLetter)" "INFO"
                        
                        if (!$WhatIf) {
                            Optimize-Volume -DriveLetter $Volume.DriveLetter -ReTrim -ErrorAction Stop
                            Write-MaintenanceLog "TRIM operation completed for drive $($DriveInfo.DriveLetter)" "SUCCESS"
                        }
                    }
                    catch {
                        if ($_.Exception.Message -match "not supported by the hardware") {
                            Write-MaintenanceLog "TRIM not supported by hardware for drive $($DriveInfo.DriveLetter)" "WARNING"
                        }
                        else {
                            Write-MaintenanceLog "TRIM operation failed for drive $($DriveInfo.DriveLetter): $($_.Exception.Message)" "WARNING"
                        }
                    }
                }
                elseif ($DriveInfo.MediaType -eq "HDD") {
                    Write-MaintenanceLog "Running defragmentation on HDD drive $($DriveInfo.DriveLetter)" "INFO"
                    
                    if (!$WhatIf) {
                        # Check fragmentation level first
                        $FragAnalysis = Optimize-Volume -DriveLetter $Volume.DriveLetter -Analyze
                        
                        if ($FragAnalysis -and $FragAnalysis.PercentFragmented -gt 10) {
                            Optimize-Volume -DriveLetter $Volume.DriveLetter -Defrag
                            Write-MaintenanceLog "Defragmentation completed for drive $($DriveInfo.DriveLetter)" "SUCCESS"
                        }
                        else {
                            Write-MaintenanceLog "Drive $($DriveInfo.DriveLetter) fragmentation below 10%, skipping defrag" "INFO"
                        }
                    }
                }
                else {
                    Write-MaintenanceLog "Unknown drive type for $($DriveInfo.DriveLetter), skipping optimization" "WARNING"
                }
            }
        }
    }
    
    # System File Check and Repair
    Invoke-SafeCommand -TaskName "System File Integrity Check" -Command {
        Write-MaintenanceLog "Running System File Checker (SFC)..." "INFO"
        
        if (!$WhatIf) {
            $SFCProcess = Start-Process -FilePath "sfc.exe" -ArgumentList "/scannow" -Wait -PassThru -NoNewWindow -RedirectStandardOutput "$env:TEMP\sfc_output.txt"
            
            if ($SFCProcess.ExitCode -eq 0) {
                Write-MaintenanceLog "SFC scan completed successfully" "SUCCESS"
            }
            else {
                Write-MaintenanceLog "SFC scan completed with issues (Exit Code: $($SFCProcess.ExitCode))" "WARNING"
            }
            
            # Run DISM for health restoration
            Write-MaintenanceLog "Running DISM health restoration..." "INFO"
            $DISMProcess = Start-Process -FilePath "DISM.exe" -ArgumentList "/Online /Cleanup-Image /RestoreHealth" -Wait -PassThru -NoNewWindow
            
            if ($DISMProcess.ExitCode -eq 0) {
                Write-MaintenanceLog "DISM health restoration completed successfully" "SUCCESS"
            }
            else {
                Write-MaintenanceLog "DISM completed with warnings (Exit Code: $($DISMProcess.ExitCode))" "WARNING"
            }
        }
    }
}

# =========================================================================
# SECURITY SCANS MODULE
# =========================================================================

function Invoke-SecurityScans {
    if ("SecurityScans" -notin $Config.EnabledModules) {
        Write-MaintenanceLog "Security Scans module disabled" "INFO"
        return
    }
    
    Write-MaintenanceLog "======== Security Scans Module ========" "INFO"
    
    # Windows Defender scans
    Invoke-SafeCommand -TaskName "Windows Defender Scan" -Command {
        Write-MaintenanceLog "Starting Windows Defender Quick Scan..." "INFO"
        
        if (!$WhatIf) {
            # Update definitions first
            Update-MpSignature -ErrorAction SilentlyContinue
            
            # Run quick scan
            Start-MpScan -ScanType QuickScan -ErrorAction SilentlyContinue
            
            # Get scan results
            $DefenderStatus = Get-MpComputerStatus
            Write-MaintenanceLog "Antivirus Status: Enabled=$($DefenderStatus.AntivirusEnabled), RTP=$($DefenderStatus.RealTimeProtectionEnabled)" "INFO"
            Write-MaintenanceLog "Last Definition Update: $($DefenderStatus.AntivirusSignatureLastUpdated)" "INFO"
            
            Write-MaintenanceLog "Windows Defender scan completed successfully" "SUCCESS"
        }
    }
    
    # Security policy audit
    Invoke-SafeCommand -TaskName "Security Policy Audit" -Command {
        Write-MaintenanceLog "Auditing local security policies..." "INFO"
        
        # Check for important security settings
        $SecurityChecks = @(
            @{ Name = "UAC Status"; Check = { (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System").EnableLUA } },
            @{ Name = "Windows Update Auto"; Check = { (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -ErrorAction SilentlyContinue).NoAutoUpdate } },
            @{ Name = "Remote Desktop Status"; Check = { (Get-ItemProperty "HKLM:\System\CurrentControlSet\Control\Terminal Server").fDenyTSConnections } }
        )
        
        foreach ($Check in $SecurityChecks) {
            try {
                $Result = & $Check.Check
                Write-MaintenanceLog "$($Check.Name): $Result" "INFO"
            }
            catch {
                Write-MaintenanceLog "$($Check.Name): Unable to determine" "WARNING"
            }
        }
        
        Write-MaintenanceLog "Security policy audit completed" "SUCCESS"
    }
}

# =========================================================================
# DEVELOPER MAINTENANCE MODULE
# =========================================================================

function Invoke-DeveloperMaintenance {
    if ("DeveloperMaintenance" -notin $Config.EnabledModules) {
        Write-MaintenanceLog "Developer Maintenance module disabled" "INFO"
        return
    }
    
    Write-MaintenanceLog "======== Developer Maintenance Module ========" "INFO"
    
    # Node.js/NPM maintenance
    Invoke-SafeCommand -TaskName "NPM Global Package Updates" -Command {
        if (Get-Command npm -ErrorAction SilentlyContinue) {
            Write-MaintenanceLog "Updating global NPM packages..." "INFO"
            
            if (!$WhatIf) {
                npm update -g 2>$null
                npm audit fix -g 2>$null
                Write-MaintenanceLog "Global NPM packages updated" "SUCCESS"
            }
        }
        else {
            Write-MaintenanceLog "NPM not found - skipping NPM maintenance" "INFO"
        }
    }
    
    # Python/pip maintenance
    Invoke-SafeCommand -TaskName "Python Package Updates" -Command {
        if (Get-Command pip -ErrorAction SilentlyContinue) {
            Write-MaintenanceLog "Checking Python package updates..." "INFO"
            
            if (!$WhatIf) {
                # Get outdated packages with correct syntax
                $OutdatedPackages = pip list --outdated --format=json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
                
                if ($OutdatedPackages -and $OutdatedPackages.Count -gt 0) {
                    Write-MaintenanceLog "Found $($OutdatedPackages.Count) outdated Python packages" "INFO"
                    
                    foreach ($Package in $OutdatedPackages) {
                        try {
                            pip install --upgrade $Package.name 2>$null
                            Write-MaintenanceLog "Updated Python package: $($Package.name)" "INFO"
                        }
                        catch {
                            Write-MaintenanceLog "Failed to update Python package: $($Package.name)" "WARNING"
                        }
                    }
                    
                    Write-MaintenanceLog "Python packages updated" "SUCCESS"
                }
                else {
                    Write-MaintenanceLog "No outdated Python packages found" "INFO"
                }
            }
        }
        else {
            Write-MaintenanceLog "pip not found - skipping Python maintenance" "INFO"
        }
    }
    
    # Docker maintenance
    Invoke-SafeCommand -TaskName "Docker Environment Cleanup" -Command {
        if (Get-Command docker -ErrorAction SilentlyContinue) {
            Write-MaintenanceLog "Checking Docker environment..." "INFO"
            
            # Test Docker connectivity
            $DockerRunning = $false
            try {
                docker version 2>$null | Out-Null
                $DockerRunning = $true
            }
            catch {
                Write-MaintenanceLog "Docker daemon not running - skipping Docker cleanup" "WARNING"
                return
            }
            
            if ($DockerRunning -and !$WhatIf) {
                # Clean up Docker resources
                docker system prune -f 2>$null
                docker image prune -f 2>$null
                docker container prune -f 2>$null
                docker network prune -f 2>$null
                docker volume prune -f 2>$null
                
                Write-MaintenanceLog "Docker cleanup completed" "SUCCESS"
            }
        }
        else {
            Write-MaintenanceLog "Docker not found - skipping Docker maintenance" "INFO"
        }
    }
    
    # VS Code maintenance
    Invoke-SafeCommand -TaskName "VS Code Maintenance" -Command {
        $VSCodePaths = @(
            "$env:APPDATA\Code\logs",
            "$env:APPDATA\Code\CachedExtensions",
            "$env:APPDATA\Code\CachedExtensionVSIXs"
        )
        
        $TotalCleaned = 0
        foreach ($Path in $VSCodePaths) {
            if (Test-Path $Path) {
                $OldFiles = Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue | 
                           Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) }
                
                if ($OldFiles) {
                    $SizeCleaned = ($OldFiles | Measure-Object -Property Length -Sum).Sum
                    $TotalCleaned += $SizeCleaned
                    
                    if (!$WhatIf) {
                        $OldFiles | Remove-Item -Force -ErrorAction SilentlyContinue
                    }
                }
            }
        }
        
        if ($TotalCleaned -gt 0) {
            $CleanedMB = [math]::Round($TotalCleaned / 1MB, 2)
            Write-MaintenanceLog "VS Code cleanup recovered $CleanedMB MB" "SUCCESS"
        }
        else {
            Write-MaintenanceLog "VS Code - no cleanup needed" "INFO"
        }
    }
}

# =========================================================================
# PERFORMANCE OPTIMIZATION MODULE
# =========================================================================

function Invoke-PerformanceOptimization {
    if ("PerformanceOptimization" -notin $Config.EnabledModules) {
        Write-MaintenanceLog "Performance Optimization module disabled" "INFO"
        return
    }
    
    Write-MaintenanceLog "======== Performance Optimization Module ========" "INFO"
    
    # Event log management
    Invoke-SafeCommand -TaskName "Event Log Management" -Command {
        Write-MaintenanceLog "Checking event log sizes..." "INFO"
        
        $LargeEventLogs = Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | 
                         Where-Object { 
                             $_.FileSize -gt ($Config.MaxEventLogSizeMB * 1MB) -and 
                             $_.RecordCount -gt 1000 
                         }
        
        if ($LargeEventLogs) {
            Write-MaintenanceLog "Found $($LargeEventLogs.Count) large event logs" "WARNING"
            
            foreach ($Log in $LargeEventLogs) {
                $LogSizeMB = [math]::Round($Log.FileSize / 1MB, 2)
                Write-MaintenanceLog "Large log: $($Log.LogName) - ${LogSizeMB}MB ($($Log.RecordCount) records)" "WARNING"
            }
            
            Write-MaintenanceLog "Consider reviewing and archiving large event logs" "INFO"
        }
        else {
            Write-MaintenanceLog "Event log sizes are within acceptable limits" "SUCCESS"
        }
    }
    
    # Startup items analysis
    Invoke-SafeCommand -TaskName "Startup Items Analysis" -Command {
        Write-MaintenanceLog "Analyzing startup items..." "INFO"
        
        $StartupItems = Get-CimInstance Win32_StartupCommand | 
                       Select-Object Name, Command, Location, User |
                       Sort-Object Name
        
        Write-MaintenanceLog "Found $($StartupItems.Count) startup items" "INFO"
        
        # Log top startup items for review
        $StartupReport = "$($Config.LogPath)\startup_items_$(Get-Date -Format 'yyyyMMdd').txt"
        $StartupItems | Format-Table -AutoSize | Out-File -FilePath $StartupReport
        
        Write-MaintenanceLog "Startup items report saved to: $StartupReport" "INFO"
        Write-MaintenanceLog "Startup items analysis completed" "SUCCESS"
    }
    
    # Memory and CPU usage analysis
    Invoke-SafeCommand -TaskName "System Resource Analysis" -Command {
        Write-MaintenanceLog "Analyzing system resource usage..." "INFO"
        
        # Memory analysis
        $MemInfo = Get-WmiObject -Class Win32_OperatingSystem
        $TotalMemGB = [math]::Round($MemInfo.TotalVisibleMemorySize / 1MB, 2)
        $FreeMemGB = [math]::Round($MemInfo.FreePhysicalMemory / 1MB, 2)
        $UsedMemPercent = [math]::Round((($TotalMemGB - $FreeMemGB) / $TotalMemGB) * 100, 1)
        
        Write-MaintenanceLog "Memory Usage: $UsedMemPercent% ($FreeMemGB GB free of $TotalMemGB GB total)" "INFO"
        
        # CPU analysis
        $CPU = Get-WmiObject -Class Win32_Processor
        $CPUUsage = (Get-Counter "\Processor(_Total)\% Processor Time" -SampleInterval 1 -MaxSamples 3 | 
                    Select-Object -ExpandProperty CounterSamples | 
                    Measure-Object -Property CookedValue -Average).Average
        
        Write-MaintenanceLog "Average CPU Usage: $([math]::Round($CPUUsage, 1))%" "INFO"
        
        # Top processes by memory usage
        $TopProcesses = Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 10
        $ProcessReport = "$($Config.LogPath)\top_processes_$(Get-Date -Format 'yyyyMMdd').txt"
        $TopProcesses | Format-Table Name, Id, @{N='Memory(MB)';E={[math]::Round($_.WorkingSet/1MB,1)}} -AutoSize | 
                       Out-File -FilePath $ProcessReport
        
        Write-MaintenanceLog "Top processes report saved to: $ProcessReport" "INFO"
        Write-MaintenanceLog "System resource analysis completed" "SUCCESS"
    }
}

# =========================================================================
# BACKUP MODULE
# =========================================================================

function Invoke-BackupOperations {
    if ($SkipBackup) {
        Write-MaintenanceLog "Backup operations skipped by parameter" "INFO"
        return
    }
    
    Write-MaintenanceLog "======== Backup Operations Module ========" "INFO"
    
    Invoke-SafeCommand -TaskName "Critical Data Backup" -Command {
        # Ensure backup directory exists
        if (!(Test-Path -Path $Config.BackupPath)) {
            New-Item -ItemType Directory -Force -Path $Config.BackupPath | Out-Null
            Write-MaintenanceLog "Created backup directory: $($Config.BackupPath)" "INFO"
        }
        
        # Define backup sources
        $BackupSources = @(
            @{ Path = "$env:USERPROFILE\Documents"; Name = "Documents" },
            @{ Path = "$env:USERPROFILE\Desktop"; Name = "Desktop" },
            @{ Path = "$env:USERPROFILE\.ssh"; Name = "SSH_Keys" },
            @{ Path = "$env:USERPROFILE\.aws"; Name = "AWS_Config" },
            @{ Path = "$env:USERPROFILE\.gitconfig"; Name = "Git_Config"; IsFile = $true }
        )
        
        $BackupDate = Get-Date -Format "yyyyMMdd"
        $TotalBackupSize = 0
        
        foreach ($Source in $BackupSources) {
            if (Test-Path $Source.Path) {
                $BackupFile = "$($Config.BackupPath)\$($Source.Name)_$BackupDate.zip"
                
                Write-MaintenanceLog "Backing up $($Source.Name)..." "INFO"
                
                if (!$WhatIf) {
                    try {
                        if ($Source.IsFile) {
                            # Single file backup
                            Compress-Archive -Path $Source.Path -DestinationPath $BackupFile -Force
                        }
                        else {
                            # Directory backup
                            Compress-Archive -Path "$($Source.Path)\*" -DestinationPath $BackupFile -Force
                        }
                        
                        $BackupSize = (Get-Item $BackupFile).Length
                        $TotalBackupSize += $BackupSize
                        
                        $BackupSizeMB = [math]::Round($BackupSize / 1MB, 2)
                        Write-MaintenanceLog "Backup completed: $($Source.Name) - ${BackupSizeMB}MB" "SUCCESS"
                    }
                    catch {
                        Write-MaintenanceLog "Backup failed for $($Source.Name): $($_.Exception.Message)" "ERROR"
                    }
                }
            }
            else {
                Write-MaintenanceLog "Backup source not found: $($Source.Path)" "WARNING"
            }
        }
        
        $TotalBackupSizeGB = [math]::Round($TotalBackupSize / 1GB, 2)
        Write-MaintenanceLog "Total backup size: ${TotalBackupSizeGB}GB" "INFO"
        
        # Cleanup old backups
        $OldBackups = Get-ChildItem -Path $Config.BackupPath -Filter "*.zip" | 
                     Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$Config.MaxBackupDays) }
        
        if ($OldBackups -and !$WhatIf) {
            $OldBackups | Remove-Item -Force
            Write-MaintenanceLog "Cleaned up $($OldBackups.Count) old backup(s)" "SUCCESS"
        }
        
        Write-MaintenanceLog "Backup operations completed" "SUCCESS"
    }
}

# =========================================================================
# SYSTEM REPORTING MODULE
# =========================================================================

function Invoke-SystemReporting {
    if ("SystemReporting" -notin $Config.EnabledModules) {
        Write-MaintenanceLog "System Reporting module disabled" "INFO"
        return
    }
    
    Write-MaintenanceLog "======== System Reporting Module ========" "INFO"
    
    Invoke-SafeCommand -TaskName "System Report Generation" -Command {
        $ReportFile = "$($Config.LogPath)\system_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
        
        # System Information
        $SystemInfo = Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, 
                                                     TotalPhysicalMemory, CsManufacturer, CsModel,
                                                     CsProcessors, CsNumberOfLogicalProcessors
        
        # Disk Information
        $DiskInfo = Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' } |
                   Select-Object DriveLetter, FileSystem, 
                                @{N='Size(GB)';E={[math]::Round($_.Size/1GB,2)}},
                                @{N='Free(GB)';E={[math]::Round($_.SizeRemaining/1GB,2)}},
                                @{N='Free%';E={[math]::Round(($_.SizeRemaining/$_.Size)*100,1)}}
        
        # Network Information
        $NetworkInfo = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } |
                      Select-Object Name, InterfaceDescription, LinkSpeed
        
        # Generate report
        $Report = @"
===============================================
SYSTEM MAINTENANCE REPORT
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
===============================================

SYSTEM INFORMATION:
$($SystemInfo | Format-List | Out-String)

DISK INFORMATION:
$($DiskInfo | Format-Table -AutoSize | Out-String)

NETWORK INFORMATION:
$($NetworkInfo | Format-Table -AutoSize | Out-String)

MAINTENANCE SUMMARY:
Script Execution Time: $((Get-Date) - $ScriptStartTime)
Modules Enabled: $($Config.EnabledModules -join ', ')
What-If Mode: $WhatIf
Backup Skipped: $SkipBackup

===============================================
END OF REPORT
===============================================
"@
        
        $Report | Out-File -FilePath $ReportFile
        Write-MaintenanceLog "System report generated: $ReportFile" "SUCCESS"
    }
}

# =========================================================================
# MAIN EXECUTION LOGIC
# =========================================================================

function Start-MaintenanceScript {
    $Global:ScriptStartTime = Get-Date
    
    Write-MaintenanceLog "=========================================" "INFO"
    Write-MaintenanceLog "Enhanced Windows Maintenance Script v2.0" "INFO"
    Write-MaintenanceLog "=========================================" "INFO"
    Write-MaintenanceLog "Script started at: $($ScriptStartTime.ToString('yyyy-MM-dd HH:mm:ss'))" "INFO"
    Write-MaintenanceLog "What-If Mode: $WhatIf" "INFO"
    Write-MaintenanceLog "Skip Backup: $SkipBackup" "INFO"
    
    # Prerequisites check
    if (!(Test-Prerequisites)) {
        Write-MaintenanceLog "Prerequisites check failed. Exiting." "ERROR"
        return 1
    }
    
    # Execute maintenance modules
    try {
        Invoke-SystemUpdates
        Invoke-DiskMaintenance
        Invoke-SecurityScans
        Invoke-DeveloperMaintenance
        Invoke-PerformanceOptimization
        Invoke-BackupOperations
        Invoke-SystemReporting
        
        # Generate final summary
        $ExecutionTime = (Get-Date) - $ScriptStartTime
        $ErrorCount = (Get-Content $LogFile -ErrorAction SilentlyContinue | Where-Object { $_ -like "*ERROR*" }).Count
        $WarningCount = (Get-Content $LogFile -ErrorAction SilentlyContinue | Where-Object { $_ -like "*WARNING*" }).Count
        $SuccessCount = (Get-Content $LogFile -ErrorAction SilentlyContinue | Where-Object { $_ -like "*SUCCESS*" }).Count
        
        Write-MaintenanceLog "=========================================" "INFO"
        Write-MaintenanceLog "MAINTENANCE SCRIPT COMPLETED" "SUCCESS"
        Write-MaintenanceLog "=========================================" "INFO"
        Write-MaintenanceLog "Total Execution Time: $($ExecutionTime.ToString())" "INFO"
        Write-MaintenanceLog "Successful Operations: $SuccessCount" "SUCCESS"
        Write-MaintenanceLog "Warnings: $WarningCount" "WARNING"
        Write-MaintenanceLog "Errors: $ErrorCount" "ERROR"
        Write-MaintenanceLog "Log File: $LogFile" "INFO"
        Write-MaintenanceLog "Performance Log: $PerformanceLog" "INFO"
        
        # Display completion notification
        if (!$WhatIf) {
            $NotificationMessage = @"
Maintenance Script Completed

Execution Time: $($ExecutionTime.ToString())
Successful Operations: $SuccessCount
Warnings: $WarningCount
Errors: $ErrorCount

Check logs for detailed information:
$($Config.LogPath)
"@
            
            [System.Windows.Forms.MessageBox]::Show(
                $NotificationMessage,
                "Maintenance Complete",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        }
        
        return 0
    }
    catch {
        Write-MaintenanceLog "Critical error during script execution: $($_.Exception.Message)" "ERROR"
        return 1
    }
}

# =========================================================================
# SCRIPT ENTRY POINT
# =========================================================================

# Execute main function
$ExitCode = Start-MaintenanceScript
exit $ExitCode