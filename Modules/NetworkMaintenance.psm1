<#
.SYNOPSIS
    Network maintenance and optimization module.

.DESCRIPTION
    Provides comprehensive network maintenance including DNS cache management.
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator

# Import dependencies
Import-Module "$PSScriptRoot\Common\Logging.psm1" -Force
Import-Module "$PSScriptRoot\Common\SafeExecution.psm1" -Force
Import-Module "$PSScriptRoot\Common\UIHelpers.psm1" -Force

<#
.SYNOPSIS
    Main network maintenance orchestration function.
#>
function Invoke-NetworkMaintenance {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Config
    )

    if ("NetworkMaintenance" -notin $Config.EnabledModules) {
        Write-MaintenanceLog -Message 'Network Maintenance module disabled' -Level INFO
        return
    }

    Write-MaintenanceLog -Message '======== Network Maintenance Module ========' -Level INFO

    # DNS
    Invoke-SafeCommand -TaskName "DNS Cache Management" -Command {
        if ($PSCmdlet.ShouldProcess("DNS Cache", "Flush resolver cache")) {
            Clear-DnsClientCache
            Write-MaintenanceLog -Message "DNS cache cleared" -Level SUCCESS
        }
    }

    # IP Refresh
    Invoke-SafeCommand -TaskName "IP Configuration Refresh" -Command {
        if ($PSCmdlet.ShouldProcess("Network Interface", "Release and Renew IP")) {
            & ipconfig /release 2>$null | Out-Null
            & ipconfig /renew 2>$null | Out-Null
            Write-MaintenanceLog -Message "IP configuration refreshed" -Level SUCCESS
        }
    }

    # Proxy
    Invoke-SafeCommand -TaskName "Network Proxy Reset" -Command {
        if ($PSCmdlet.ShouldProcess("WinHTTP Proxy", "Reset to direct")) {
            & netsh winhttp reset proxy | Out-Null
            Write-MaintenanceLog -Message "Network proxy reset" -Level SUCCESS
        }
    }

    # Connectivity
    Invoke-SafeCommand -TaskName "Network Connectivity Testing" -Command {
        $DNS_Target = "8.8.8.8"
        $Res = Test-Connection -ComputerName $DNS_Target -Count 1 -Quiet
        $Msg = if ($Res) { "Internet connectivity available" } else { "Internet connectivity issues detected" }
        Write-MaintenanceLog -Message $Msg -Level (if ($Res) { "SUCCESS" } else { "WARNING" })
    }
}

# Export public functions
Export-ModuleMember -Function @(
    'Invoke-NetworkMaintenance'
)
