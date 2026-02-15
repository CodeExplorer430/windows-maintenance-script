<#
.SYNOPSIS
    System detection and hardware information utilities for Windows Maintenance module.

.DESCRIPTION
    Provides comprehensive system detection capabilities including memory detection
    using multiple fallback methods for maximum reliability across different Windows versions.

.NOTES
    File Name      : SystemDetection.psm1
    Author         : Miguel Velasco
    Prerequisite   : PowerShell 5.1+
    Version        : 4.0.0
    Last Updated   : October 2025
    Module Type    : Common Utility Module
    Dependencies   : Logging.psm1
#>

#Requires -Version 5.1

# Import dependencies
Import-Module "$PSScriptRoot\Logging.psm1" -Force

<#
.SYNOPSIS
    Detects total system memory using multiple detection methods with fallback.

.DESCRIPTION
    Implements comprehensive system memory detection with multiple fallback methods
    to ensure reliable detection across different Windows configurations and versions.

    Detection Methods (in order):
    1. Win32_ComputerSystem WMI class (primary)
    2. Win32_PhysicalMemory WMI class (first fallback)
    3. CIM instance queries (second fallback)
    4. SystemInfo command-line utility (final fallback)

.OUTPUTS
    [double] Total system memory in gigabytes

.EXAMPLE
    Get-SystemMemoryInfo
    Returns: 16.00 (for 16GB system)

.NOTES
    Performance: Uses fastest detection method first with progressive fallbacks
    Reliability: Returns reasonable default (16.0GB) if all methods fail
#>
function Get-SystemMemoryInfo {
    [CmdletBinding()]
    [OutputType([double])]
    param()

    try {
        # Initialize detection state variables
        $MemoryDetected = $false
        $TotalMemoryGB = 0

        # Method 1: Win32_ComputerSystem (Primary detection method)
        try {
            $ComputerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
            if ($ComputerSystem.TotalPhysicalMemory -and $ComputerSystem.TotalPhysicalMemory -gt 0) {
                $TotalMemoryGB = [math]::Round($ComputerSystem.TotalPhysicalMemory / 1GB, 2)
                $MemoryDetected = $true
                Write-DetailedOperation -Operation 'Memory Detection' -Details "Method: Win32_ComputerSystem | Total: ${TotalMemoryGB}GB" -Result 'Success'
            }
        }
        catch {
            Write-MaintenanceLog -Message "Win32_ComputerSystem memory detection failed: $($_.Exception.Message)" -Level WARNING
        }

        # Method 2: Win32_PhysicalMemory (First fallback method)
        if (-not $MemoryDetected) {
            try {
                $PhysicalMemory = Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction Stop
                if ($PhysicalMemory) {
                    $TotalMemoryBytes = ($PhysicalMemory | Measure-Object Capacity -Sum).Sum
                    if ($TotalMemoryBytes -gt 0) {
                        $TotalMemoryGB = [math]::Round($TotalMemoryBytes / 1GB, 2)
                        $MemoryDetected = $true
                        Write-DetailedOperation -Operation 'Memory Detection' -Details "Method: Win32_PhysicalMemory | Total: ${TotalMemoryGB}GB" -Result 'Success'
                    }
                }
            }
            catch {
                Write-MaintenanceLog -Message "Win32_PhysicalMemory detection failed: $($_.Exception.Message)" -Level WARNING
            }
        }

        # Method 3: SystemInfo command-line utility (Final fallback)
        if (-not $MemoryDetected) {
            try {
                $SystemInfo = systeminfo.exe 2>$null | Select-String "Total Physical Memory"
                if ($SystemInfo) {
                    $MemoryString = $SystemInfo.ToString()
                    if ($MemoryString -match '([\d,]+)\s*MB') {
                        $TotalMemoryMB = [int]($matches[1] -replace ',', '')
                        $TotalMemoryGB = [math]::Round($TotalMemoryMB / 1024, 2)
                        $MemoryDetected = $true
                        Write-DetailedOperation -Operation 'Memory Detection' -Details "Method: SystemInfo | Total: ${TotalMemoryGB}GB" -Result 'Success'
                    }
                }
            }
            catch {
                Write-MaintenanceLog -Message "SystemInfo memory detection failed: $($_.Exception.Message)" -Level WARNING
            }
        }

        # Return detected memory or reasonable default
        if ($MemoryDetected -and $TotalMemoryGB -gt 0) {
            return $TotalMemoryGB
        }
        else {
            Write-MaintenanceLog -Message "All memory detection methods failed - using default" -Level ERROR
            return 16.0  # Reasonable default for modern systems
        }
    }
    catch {
        Write-MaintenanceLog -Message "Critical memory detection error: $($_.Exception.Message)" -Level ERROR
        return 16.0  # Reasonable default on critical failure
    }
}

<#
.SYNOPSIS
    Retrieves detailed Operating System information.

.DESCRIPTION
    Detects OS Name, Version, Architecture, and specific Windows 10/11 Release IDs
    (e.g., 22H2, 25H2) using WMI/CIM and registry lookups.

.OUTPUTS
    [hashtable] Contains OSName, Version, Build, ReleaseId, Architecture

.EXAMPLE
    Get-SystemOSInfo

    Name                           Value
    ----                           -----
    OSName                         Microsoft Windows 11 Pro
    Version                        10.0.26100
    ReleaseId                      25H2
    Architecture                   64-bit

.NOTES
    Performance: Uses CIM/WMI with registry fallback for DisplayVersion
#>
function Get-SystemOSInfo {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    try {
        $OSInfo = @{
            OSName = "Unknown"
            Version = "Unknown"
            Build = "Unknown"
            ReleaseId = "Unknown"
            Architecture = "Unknown"
        }

        # Method 1: CIM
        try {
            $OS = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
            $OSInfo.OSName = $OS.Caption.Trim()
            $OSInfo.Version = $OS.Version
            $OSInfo.Build = $OS.BuildNumber
            $OSInfo.Architecture = $OS.OSArchitecture
        }
        catch {
            Write-MaintenanceLog -Message "CIM OS detection failed: $($_.Exception.Message)" -Level WARNING
        }

        # Method 2: Registry for ReleaseId (DisplayVersion) - Critical for Win 10/11 feature updates
        try {
            $RegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
            $DisplayVersion = (Get-ItemProperty -Path $RegPath -Name "DisplayVersion" -ErrorAction SilentlyContinue).DisplayVersion

            if ($DisplayVersion) {
                $OSInfo.ReleaseId = $DisplayVersion
            }
            else {
                # Fallback to ReleaseId (older Win10)
                $ReleaseId = (Get-ItemProperty -Path $RegPath -Name "ReleaseId" -ErrorAction SilentlyContinue).ReleaseId
                if ($ReleaseId) { $OSInfo.ReleaseId = $ReleaseId }
            }
        }
        catch {
            Write-MaintenanceLog -Message "Registry OS version detection failed: $($_.Exception.Message)" -Level WARNING
        }

        Write-DetailedOperation -Operation 'OS Detection' -Details "$($OSInfo.OSName) ($($OSInfo.ReleaseId))" -Result 'Success'
        return $OSInfo
    }
    catch {
        Write-MaintenanceLog -Message "Critical OS detection error: $($_.Exception.Message)" -Level ERROR
        return $OSInfo
    }
}

<#
.SYNOPSIS
    Searches for installed applications in the system registry.

.DESCRIPTION
    Scans HKLM (64-bit and 32-bit) and HKCU Uninstall registry keys for applications
    matching the provided name pattern.

.PARAMETER NamePattern
    Regex pattern to match against the DisplayName of installed applications.

.OUTPUTS
    [PSCustomObject[]] Array of objects with DisplayName, DisplayVersion, and UninstallString.

.EXAMPLE
    Get-InstalledApplication -NamePattern "Visual Studio"
#>
function Get-InstalledApplication {
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$NamePattern
    )

    $Keys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    try {
        $Apps = Get-ItemProperty $Keys -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -and ($_.DisplayName -match $NamePattern) } |
            ForEach-Object {
                [PSCustomObject]@{
                    DisplayName      = $_.DisplayName
                    DisplayVersion   = $_.DisplayVersion
                    UninstallString  = $_.UninstallString
                    InstallLocation  = $_.InstallLocation
                    RegistryPath     = $_.PSPath
                }
            }

        return $Apps
    }
    catch {
        Write-MaintenanceLog -Message "Error searching for applications: $($_.Exception.Message)" -Level WARNING
        return @()
    }
}

<#
.SYNOPSIS
    Checks for pending reboot flags in the system registry.

.DESCRIPTION
    Scans multiple registry locations used by Windows, component-based servicing,
    and various installers to identify if a system restart is required.

.OUTPUTS
    [hashtable] Contains IsRebootPending (bool) and Reasons (string array).
#>
function Test-PendingReboot {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $Results = @{
        IsRebootPending = $false
        Reasons = @()
    }

    $RegChecks = @(
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"; Name = "Windows Update" },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"; Name = "Component Based Servicing" },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\ServerManager\CurrentRebootAttempts"; Name = "Server Manager" }
    )

    foreach ($Check in $RegChecks) {
        if (Test-Path $Check.Path) {
            $Results.IsRebootPending = $true
            $Results.Reasons += $Check.Name
        }
    }

    # Check PendingFileRenameOperations
    $RenamePath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
    $RenameOp = (Get-ItemProperty -Path $RenamePath -Name "PendingFileRenameOperations" -ErrorAction SilentlyContinue).PendingFileRenameOperations
    if ($RenameOp) {
        $Results.IsRebootPending = $true
        $Results.Reasons += "Pending File Rename Operations"
    }

    if ($Results.IsRebootPending) {
        Write-MaintenanceLog -Message "Pending reboot detected: $($Results.Reasons -join ', ')" -Level WARNING
    }

    return $Results
}

<#
.SYNOPSIS
    Retrieves enterprise context (Domain and VPN status).
#>
function Get-EnterpriseContext {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $Results = @{
        DomainStatus = "Workgroup"
        VPNConnected = $false
    }

    try {
        # Domain status
        $Comp = Get-CimInstance Win32_ComputerSystem
        if ($Comp.PartOfDomain) {
            $Results.DomainStatus = "Domain ($($Comp.Domain))"
        }

        # VPN connectivity (simple check for common VPN adapters)
        $Adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
        foreach ($A in $Adapters) {
            if ($A.InterfaceDescription -match "VPN|TAP|Tunnel|Virtual Private") {
                $Results.VPNConnected = $true
                break
            }
        }
    } catch {
        Write-Debug "Error retrieving enterprise context: $($_.Exception.Message)"
    }

    return $Results
}

# Export public functions
Export-ModuleMember -Function @(
    'Get-SystemMemoryInfo',
    'Get-SystemOSInfo',
    'Get-InstalledApplication',
    'Test-PendingReboot',
    'Get-EnterpriseContext'
)
