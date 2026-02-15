<#
.SYNOPSIS
    Hardware diagnostics and reporting module.

.DESCRIPTION
    Provides reporting on battery health (for laptops) and SSD wear levels (using S.M.A.R.T. data).
#>

#Requires -Version 5.1

# Import dependencies
Import-Module "$PSScriptRoot\Logging.psm1" -Force

<#
.SYNOPSIS
    Retrieves battery health information.
#>
function Get-BatteryHealth {
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param()

    try {
        $Batteries = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue
        if (-not $Batteries) {
            return $null
        }

        $Results = foreach ($B in $Batteries) {
            [PSCustomObject]@{
                DeviceID = $B.DeviceID
                Status = $B.Status
                EstimatedChargeRemaining = $B.EstimatedChargeRemaining
                EstimatedRunTime = $B.EstimatedRunTime
            }
        }
        return $Results
    }
    catch {
        Write-MaintenanceLog -Message "Error checking battery health: $($_.Exception.Message)" -Level WARNING
        return $null
    }
}

<#
.SYNOPSIS
    Retrieves SSD wear level and SMART health status.
#>
function Get-StorageHealth {
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param()

    try {
        $PhysicalDisks = Get-PhysicalDisk -ErrorAction SilentlyContinue
        if (-not $PhysicalDisks) { return @() }

        $Results = foreach ($Disk in $PhysicalDisks) {
            $Wear = "N/A"
            if ($Disk.MediaType -eq 'SSD') {
                $StorageReliability = Get-StorageReliabilityCounter -PhysicalDisk $Disk -ErrorAction SilentlyContinue
                if ($StorageReliability) {
                    $Wear = 100 - $StorageReliability.Wear
                }
            }

            [PSCustomObject]@{
                FriendlyName = $Disk.FriendlyName
                MediaType = $Disk.MediaType
                HealthStatus = $Disk.HealthStatus
                OperationalStatus = $Disk.OperationalStatus
                RemainingLifePercent = $Wear
            }
        }
        return $Results
    }
    catch {
        Write-MaintenanceLog -Message "Error checking storage health: $($_.Exception.Message)" -Level WARNING
        return @()
    }
}

# Export public functions
Export-ModuleMember -Function @(
    'Get-BatteryHealth',
    'Get-StorageHealth'
)
