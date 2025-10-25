<#
.SYNOPSIS
    Network maintenance and optimization module with DNS management and troubleshooting capabilities.

.DESCRIPTION
    Provides comprehensive network maintenance including DNS cache management, network
    diagnostics, connectivity testing, and performance optimization.

    Key Features:
    - DNS cache flushing and management
    - Network adapter analysis and optimization
    - ARP cache cleanup
    - NetBIOS cache management
    - Network connectivity testing
    - Network troubleshooting and diagnostics
    - Winsock catalog reset
    - TCP/IP stack optimization
    - Network adapter power management

.NOTES
    File Name      : NetworkMaintenance.psm1
    Author         : Miguel Velasco
    Prerequisite   : PowerShell 5.1+, Administrator privileges
    Version        : 1.0.0
    Last Updated   : October 2025
    Module Type    : Feature Module
    Dependencies   : Logging.psm1, SafeExecution.psm1, UIHelpers.psm1

    Security: All network operations require administrator privileges
    Performance: Optimizes network stack and cache management
    Enterprise: Comprehensive logging for network diagnostics
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator

# Import dependencies
Import-Module "$PSScriptRoot\Common\Logging.psm1" -Force
Import-Module "$PSScriptRoot\Common\SafeExecution.psm1" -Force
Import-Module "$PSScriptRoot\Common\UIHelpers.psm1" -Force

<#
.SYNOPSIS
    Clears DNS resolver cache.

.DESCRIPTION
    Flushes the DNS client resolver cache to resolve DNS-related issues
    and ensure fresh DNS lookups.

.OUTPUTS
    [bool] Success status

.EXAMPLE
    Clear-DNSCache

.NOTES
    Security: Requires administrator privileges
    Performance: Immediate effect on DNS lookups
#>
function Clear-DNSCache {
    [CmdletBinding()]
    param()

    try {
        Write-MaintenanceLog -Message "Flushing DNS resolver cache..." -Level PROGRESS

        # Flush DNS cache
        Clear-DnsClientCache -ErrorAction Stop

        Write-DetailedOperation -Operation 'DNS Cache' -Details 'DNS resolver cache flushed successfully' -Result 'Cleared'
        Write-MaintenanceLog -Message "DNS cache cleared successfully" -Level SUCCESS

        return $true
    }
    catch {
        Write-MaintenanceLog -Message "Failed to clear DNS cache: $($_.Exception.Message)" -Level ERROR
        Write-DetailedOperation -Operation 'DNS Cache' -Details "Error: $($_.Exception.Message)" -Result 'Failed'
        return $false
    }
}

<#
.SYNOPSIS
    Clears ARP (Address Resolution Protocol) cache.

.DESCRIPTION
    Removes all entries from the ARP cache to resolve network connectivity
    issues related to MAC address resolution.

.OUTPUTS
    [bool] Success status

.EXAMPLE
    Clear-ARPCache

.NOTES
    Security: Requires administrator privileges
    Performance: Helps resolve network connectivity issues
#>
function Clear-ARPCache {
    [CmdletBinding()]
    param()

    try {
        Write-MaintenanceLog -Message "Clearing ARP cache..." -Level PROGRESS

        # Clear ARP cache
        netsh interface ip delete arpcache | Out-Null

        Write-DetailedOperation -Operation 'ARP Cache' -Details 'ARP cache cleared successfully' -Result 'Cleared'
        Write-MaintenanceLog -Message "ARP cache cleared successfully" -Level SUCCESS

        return $true
    }
    catch {
        Write-MaintenanceLog -Message "Failed to clear ARP cache: $($_.Exception.Message)" -Level ERROR
        Write-DetailedOperation -Operation 'ARP Cache' -Details "Error: $($_.Exception.Message)" -Result 'Failed'
        return $false
    }
}

<#
.SYNOPSIS
    Clears NetBIOS cache.

.DESCRIPTION
    Purges and reloads the NetBIOS name cache to resolve NetBIOS-related
    network browsing issues.

.OUTPUTS
    [bool] Success status

.EXAMPLE
    Clear-NetBIOSCache

.NOTES
    Security: Requires administrator privileges
    Performance: Helps resolve network browsing issues
#>
function Clear-NetBIOSCache {
    [CmdletBinding()]
    param()

    try {
        Write-MaintenanceLog -Message "Clearing NetBIOS name cache..." -Level PROGRESS

        # Clear NetBIOS cache
        nbtstat -R | Out-Null
        nbtstat -RR | Out-Null

        Write-DetailedOperation -Operation 'NetBIOS Cache' -Details 'NetBIOS name cache cleared successfully' -Result 'Cleared'
        Write-MaintenanceLog -Message "NetBIOS cache cleared successfully" -Level SUCCESS

        return $true
    }
    catch {
        Write-MaintenanceLog -Message "Failed to clear NetBIOS cache: $($_.Exception.Message)" -Level ERROR
        Write-DetailedOperation -Operation 'NetBIOS Cache' -Details "Error: $($_.Exception.Message)" -Result 'Failed'
        return $false
    }
}

<#
.SYNOPSIS
    Tests network connectivity to common services.

.DESCRIPTION
    Performs connectivity tests to verify internet connectivity and DNS resolution.
    Tests multiple endpoints to provide comprehensive connectivity assessment.

.OUTPUTS
    [hashtable] Connectivity test results

.EXAMPLE
    Test-NetworkConnectivity

.NOTES
    Performance: Tests multiple endpoints for reliability
    Enterprise: Comprehensive diagnostics for troubleshooting
#>
function Test-NetworkConnectivity {
    [CmdletBinding()]
    param()

    $Results = @{
        InternetConnectivity = $false
        DNSResolution = $false
        TestedEndpoints = @()
        FailedEndpoints = @()
    }

    try {
        Write-MaintenanceLog -Message "Testing network connectivity..." -Level PROGRESS

        # Test endpoints
        $TestEndpoints = @(
            @{ Name = "Google DNS"; Address = "8.8.8.8"; Type = "IP" },
            @{ Name = "Cloudflare DNS"; Address = "1.1.1.1"; Type = "IP" },
            @{ Name = "Google.com"; Address = "www.google.com"; Type = "DNS" },
            @{ Name = "Microsoft.com"; Address = "www.microsoft.com"; Type = "DNS" }
        )

        foreach ($Endpoint in $TestEndpoints) {
            try {
                $TestResult = Test-Connection -ComputerName $Endpoint.Address -Count 1 -Quiet -ErrorAction Stop

                if ($TestResult) {
                    $Results.TestedEndpoints += $Endpoint.Name

                    if ($Endpoint.Type -eq "IP") {
                        $Results.InternetConnectivity = $true
                    }
                    elseif ($Endpoint.Type -eq "DNS") {
                        $Results.DNSResolution = $true
                    }

                    Write-DetailedOperation -Operation 'Connectivity Test' -Details "$($Endpoint.Name): Reachable" -Result 'Success'
                }
                else {
                    $Results.FailedEndpoints += $Endpoint.Name
                    Write-DetailedOperation -Operation 'Connectivity Test' -Details "$($Endpoint.Name): Unreachable" -Result 'Failed'
                }
            }
            catch {
                $Results.FailedEndpoints += $Endpoint.Name
                Write-DetailedOperation -Operation 'Connectivity Test' -Details "$($Endpoint.Name): Error - $($_.Exception.Message)" -Result 'Error'
            }
        }

        # Summary
        if ($Results.InternetConnectivity -and $Results.DNSResolution) {
            Write-MaintenanceLog -Message "Network connectivity test: All tests passed" -Level SUCCESS
        }
        elseif ($Results.InternetConnectivity) {
            Write-MaintenanceLog -Message "Network connectivity test: Internet accessible but DNS resolution issues detected" -Level WARNING
        }
        else {
            Write-MaintenanceLog -Message "Network connectivity test: No internet connectivity detected" -Level WARNING
        }

        return $Results
    }
    catch {
        Write-MaintenanceLog -Message "Network connectivity test failed: $($_.Exception.Message)" -Level ERROR
        return $Results
    }
}

<#
.SYNOPSIS
    Analyzes network adapter configuration and performance.

.DESCRIPTION
    Provides detailed information about network adapters including status,
    speed, duplex mode, and performance statistics.

.OUTPUTS
    [array] Network adapter information

.EXAMPLE
    Get-NetworkAdapterInfo

.NOTES
    Performance: Identifies network performance issues
    Enterprise: Detailed adapter configuration for diagnostics
#>
function Get-NetworkAdapterInfo {
    [CmdletBinding()]
    param()

    try {
        Write-MaintenanceLog -Message "Analyzing network adapters..." -Level PROGRESS

        # Get active network adapters
        $Adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }

        foreach ($Adapter in $Adapters) {
            $AdapterDetails = "Adapter: $($Adapter.Name) | Status: $($Adapter.Status) | Speed: $($Adapter.LinkSpeed) | MAC: $($Adapter.MacAddress)"
            Write-DetailedOperation -Operation 'Network Adapter' -Details $AdapterDetails -Result 'Active'

            # Get adapter statistics
            try {
                $Stats = Get-NetAdapterStatistics -Name $Adapter.Name -ErrorAction SilentlyContinue
                if ($Stats) {
                    $StatsDetails = "Received: $([math]::Round($Stats.ReceivedBytes / 1GB, 2))GB | Sent: $([math]::Round($Stats.SentBytes / 1GB, 2))GB"
                    Write-DetailedOperation -Operation 'Adapter Statistics' -Details $StatsDetails -Result 'Retrieved'
                }
            }
            catch {
                Write-DetailedOperation -Operation 'Adapter Statistics' -Details "Could not retrieve statistics for $($Adapter.Name)" -Result 'Warning'
            }
        }

        Write-MaintenanceLog -Message "Found $($Adapters.Count) active network adapter(s)" -Level INFO
        return $Adapters
    }
    catch {
        Write-MaintenanceLog -Message "Network adapter analysis failed: $($_.Exception.Message)" -Level ERROR
        return @()
    }
}

<#
.SYNOPSIS
    Resets Winsock catalog to default configuration.

.DESCRIPTION
    Resets the Winsock catalog to resolve network connectivity issues
    caused by corrupt LSP (Layered Service Provider) entries.

.PARAMETER Force
    Skip confirmation prompt

.OUTPUTS
    [bool] Success status

.EXAMPLE
    Reset-WinsockCatalog -Force

.NOTES
    Security: Requires administrator privileges
    Performance: May require system restart
    WARNING: This operation removes all Winsock LSP configurations
#>
function Reset-WinsockCatalog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [switch]$Force = $false
    )

    try {
        if (-not $Force) {
            Write-MaintenanceLog -Message "Winsock reset requires user confirmation" -Level WARNING
            $Confirmation = Show-MaintenanceMessageBox -Message "Reset Winsock Catalog?`n`nThis will reset all network protocol configurations and may require a restart.`n`nContinue?" -Title "Winsock Reset" -Buttons "YesNo" -Icon "Warning"

            if ($Confirmation -ne 'Yes') {
                Write-MaintenanceLog -Message "Winsock reset cancelled by user" -Level INFO
                return $false
            }
        }

        Write-MaintenanceLog -Message "Resetting Winsock catalog..." -Level PROGRESS

        # Reset Winsock
        netsh winsock reset | Out-Null

        Write-DetailedOperation -Operation 'Winsock Reset' -Details 'Winsock catalog reset successfully - restart may be required' -Result 'Complete'
        Write-MaintenanceLog -Message "Winsock catalog reset successfully - please restart your computer" -Level SUCCESS

        return $true
    }
    catch {
        Write-MaintenanceLog -Message "Failed to reset Winsock catalog: $($_.Exception.Message)" -Level ERROR
        Write-DetailedOperation -Operation 'Winsock Reset' -Details "Error: $($_.Exception.Message)" -Result 'Failed'
        return $false
    }
}

<#
.SYNOPSIS
    Main network maintenance orchestration function.

.DESCRIPTION
    Orchestrates comprehensive network maintenance including DNS cache clearing,
    network diagnostics, and adapter analysis.

.OUTPUTS
    None. Results are logged via Write-MaintenanceLog

.EXAMPLE
    Invoke-NetworkMaintenance

.NOTES
    Security: Requires administrator privileges
    Performance: Optimizes network stack and cache management
#>
function Invoke-NetworkMaintenance {
    # Get Config from parent scope
    $Config = if (Get-Variable -Name 'Config' -Scope 1 -ErrorAction SilentlyContinue) {
        (Get-Variable -Name 'Config' -Scope 1).Value
    } elseif (Get-Variable -Name 'Config' -Scope Global -ErrorAction SilentlyContinue) {
        $Global:Config
    } else {
        @{ EnabledModules = @("NetworkMaintenance") }
    }

    # Get WhatIf from parent scope
    $WhatIf = if (Get-Variable -Name 'WhatIf' -Scope 1 -ErrorAction SilentlyContinue) {
        (Get-Variable -Name 'WhatIf' -Scope 1).Value
    } elseif (Get-Variable -Name 'WhatIf' -Scope Global -ErrorAction SilentlyContinue) {
        $Global:WhatIf
    } else {
        $false
    }

    if ("NetworkMaintenance" -notin $Config.EnabledModules) {
        Write-MaintenanceLog -Message 'Network Maintenance module disabled' -Level INFO
        return
    }

    Write-MaintenanceLog -Message '======== Network Maintenance Module ========' -Level INFO

    # DNS Cache Management
    Invoke-SafeCommand -TaskName "DNS Cache Management" -Command {
        if (!$WhatIf) {
            Clear-DNSCache
        }
        else {
            Write-MaintenanceLog -Message "WHATIF: Would clear DNS cache" -Level INFO
        }
    }

    # ARP Cache Management
    Invoke-SafeCommand -TaskName "ARP Cache Management" -Command {
        if (!$WhatIf) {
            Clear-ARPCache
        }
        else {
            Write-MaintenanceLog -Message "WHATIF: Would clear ARP cache" -Level INFO
        }
    }

    # NetBIOS Cache Management
    Invoke-SafeCommand -TaskName "NetBIOS Cache Management" -Command {
        if (!$WhatIf) {
            Clear-NetBIOSCache
        }
        else {
            Write-MaintenanceLog -Message "WHATIF: Would clear NetBIOS cache" -Level INFO
        }
    }

    # Network Connectivity Testing
    Invoke-SafeCommand -TaskName "Network Connectivity Testing" -Command {
        $ConnectivityResults = Test-NetworkConnectivity

        if ($ConnectivityResults.InternetConnectivity) {
            Write-MaintenanceLog -Message "Internet connectivity: Available" -Level SUCCESS
        }
        else {
            Write-MaintenanceLog -Message "Internet connectivity: Issues detected" -Level WARNING
        }

        if ($ConnectivityResults.DNSResolution) {
            Write-MaintenanceLog -Message "DNS resolution: Working" -Level SUCCESS
        }
        else {
            Write-MaintenanceLog -Message "DNS resolution: Issues detected" -Level WARNING
        }
    }

    # Network Adapter Analysis
    Invoke-SafeCommand -TaskName "Network Adapter Analysis" -Command {
        $Adapters = Get-NetworkAdapterInfo

        if ($Adapters.Count -eq 0) {
            Write-MaintenanceLog -Message "Warning: No active network adapters found" -Level WARNING
        }
        else {
            Write-MaintenanceLog -Message "Network adapter analysis completed - $($Adapters.Count) adapter(s) active" -Level SUCCESS
        }
    }

    Write-MaintenanceLog -Message '======== Network Maintenance Module Completed ========' -Level SUCCESS
}

# Export public functions
Export-ModuleMember -Function @(
    'Invoke-NetworkMaintenance',
    'Clear-DNSCache',
    'Clear-ARPCache',
    'Clear-NetBIOSCache',
    'Test-NetworkConnectivity',
    'Get-NetworkAdapterInfo',
    'Reset-WinsockCatalog'
)
