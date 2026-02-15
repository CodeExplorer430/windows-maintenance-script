<#
.SYNOPSIS
    Bloatware and junkware removal module.

.DESCRIPTION
    Provides automated removal of pre-installed UWP junkware.
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator

Import-Module "$PSScriptRoot\Common\Logging.psm1" -Force
Import-Module "$PSScriptRoot\Common\SafeExecution.psm1" -Force

<#
.SYNOPSIS
    Executes bloatware removal.
#>
function Invoke-BloatwareRemoval {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Config
    )

    if ("BloatwareRemoval" -notin $Config.EnabledModules) { return }

    Write-MaintenanceLog -Message '======== Bloatware Removal Module ========' -Level INFO

    Invoke-SafeCommand -TaskName "UWP Junkware Removal" -Command {
        if ($Config.BloatwareRemoval.EnableUWPRemoval) {
            $BloatwareList = @(
                "*Microsoft.SkypeApp*", "*Microsoft.Messaging*", "*Microsoft.OneConnect*",
                "*Microsoft.BingNews*", "*Microsoft.BingWeather*", "*Microsoft.GetHelp*",
                "*Microsoft.Getstarted*", "*Microsoft.MicrosoftOfficeHub*", "*Microsoft.Office.OneNote*",
                "*Microsoft.YourPhone*", "*Microsoft.People*", "*Microsoft.WindowsMaps*",
                "*Microsoft.WindowsFeedbackHub*", "*Disney*", "*Spotify*", "*CandyCrush*"
            )

            foreach ($Pattern in $BloatwareList) {
                $Apps = Get-AppxPackage -AllUsers -Name $Pattern -ErrorAction SilentlyContinue
                foreach ($App in $Apps) {
                    if ($PSCmdlet.ShouldProcess($App.Name, "Remove UWP Bloatware Package")) {
                        try {
                            Remove-AppxPackage -Package $App.PackageFullName -AllUsers -ErrorAction Stop
                            Write-MaintenanceLog -Message "Removed: $($App.Name)" -Level SUCCESS
                        } catch {
                            Write-MaintenanceLog -Message "Failed: $($App.Name)" -Level WARNING
                        }
                    }
                }
            }
        } else {
            Write-MaintenanceLog -Message "UWP removal skipped per configuration" -Level INFO
        }
    }
}

Export-ModuleMember -Function Invoke-BloatwareRemoval
