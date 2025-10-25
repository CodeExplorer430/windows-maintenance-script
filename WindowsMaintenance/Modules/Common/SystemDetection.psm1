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
    param()

    try {
        # Initialize detection state variables
        $MemoryDetected = $false
        $TotalMemoryGB = 0

        # Method 1: Win32_ComputerSystem (Primary detection method)
        try {
            $ComputerSystem = Get-WmiObject -Class Win32_ComputerSystem -ErrorAction Stop
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
                $PhysicalMemory = Get-WmiObject -Class Win32_PhysicalMemory -ErrorAction Stop
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

        # Method 3: CIM (Second fallback method)
        if (-not $MemoryDetected) {
            try {
                $CimMemory = Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction Stop
                if ($CimMemory) {
                    $TotalMemoryBytes = ($CimMemory | Measure-Object Capacity -Sum).Sum
                    if ($TotalMemoryBytes -gt 0) {
                        $TotalMemoryGB = [math]::Round($TotalMemoryBytes / 1GB, 2)
                        $MemoryDetected = $true
                        Write-DetailedOperation -Operation 'Memory Detection' -Details "Method: CIM | Total: ${TotalMemoryGB}GB" -Result 'Success'
                    }
                }
            }
            catch {
                Write-MaintenanceLog -Message "CIM memory detection failed: $($_.Exception.Message)" -Level WARNING
            }
        }

        # Method 4: SystemInfo command-line utility (Final fallback)
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

# Export public functions
Export-ModuleMember -Function @(
    'Get-SystemMemoryInfo'
)
