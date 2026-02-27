<#
.SYNOPSIS
    Privacy maintenance module for managing telemetry and privacy settings.

.DESCRIPTION
    Provides comprehensive privacy management including telemetry disabling.
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator

Import-Module "$PSScriptRoot\Common\Logging.psm1" -Force
Import-Module "$PSScriptRoot\Common\SafeExecution.psm1" -Force

<#
.SYNOPSIS
    Executes privacy maintenance.
#>
function Invoke-PrivacyMaintenance {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Config
    )

    if ("PrivacyMaintenance" -notin $Config.EnabledModules) { return }

    Write-MaintenanceLog -Message '======== Privacy Maintenance Module ========' -Level INFO

    Invoke-SafeCommand -TaskName "Telemetry and Privacy Optimization" -Command {
        # Telemetry Services
        if ($Config.PrivacyMaintenance.DisableTelemetryServices) {
            $Services = @("DiagTrack", "dmwappushservice")
            foreach ($Svc in $Services) {
                if (Get-Service -Name $Svc -ErrorAction SilentlyContinue) {
                    if ($PSCmdlet.ShouldProcess($Svc, "Disable Telemetry Service")) {
                        Stop-Service -Name $Svc -Force -ErrorAction SilentlyContinue
                        Set-Service -Name $Svc -StartupType Disabled -ErrorAction SilentlyContinue
                    }
                }
            }
        }

        # Privacy Registry
        if ($Config.PrivacyMaintenance.DisablePrivacyRegistryPolicies) {
            $Regs = @(
                @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"; Name = "PublishUserActivities"; Value = 0 }
            )
            foreach ($R in $Regs) {
                if ($PSCmdlet.ShouldProcess($R.Name, "Set Privacy Registry Policy")) {
                    if (!(Test-Path $R.Path)) { New-Item -Path $R.Path -Force | Out-Null }
                    Set-ItemProperty -Path $R.Path -Name $R.Name -Value $R.Value -Type DWord -Force
                }
            }
        }
    } | Out-Null
}

Export-ModuleMember -Function Invoke-PrivacyMaintenance
