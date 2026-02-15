<#
.SYNOPSIS
    Multimedia software maintenance and optimization module.

.DESCRIPTION
    Provides specialized maintenance for multimedia editing and recording software
    including Adobe suite, DaVinci Resolve, CapCut, Audacity, and OBS Studio.
    Focuses on clearing media caches, temporary files, and log files.
#>

#Requires -Version 5.1

# Import dependencies
Import-Module "$PSScriptRoot\Common\Logging.psm1" -Force
Import-Module "$PSScriptRoot\Common\SafeExecution.psm1" -Force
Import-Module "$PSScriptRoot\Common\SystemDetection.psm1" -Force

<#
.SYNOPSIS
    Executes comprehensive multimedia software maintenance.
#>
function Invoke-MultimediaMaintenance {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Config
    )

    if ('MultimediaMaintenance' -notin $Config.EnabledModules) {
        Write-MaintenanceLog -Message 'Multimedia Maintenance module disabled' -Level INFO
        return
    }

    Write-MaintenanceLog -Message '======== Multimedia Maintenance Module ========' -Level INFO

    # Adobe Suite (Photoshop, Illustrator, Acrobat Pro)
    if ($Config.MultimediaMaintenance.EnableAdobeSuite) {
        $AdobePaths = @(
            "$env:LOCALAPPDATA\Adobe\Common\Media Cache Files",
            "$env:LOCALAPPDATA\Adobe\Common\Media Cache",
            "$env:LOCALAPPDATA\Adobe\Acrobat\DC\Cache",
            "$env:APPDATA\Adobe\Common\Media Cache Files"
        )

        foreach ($Path in $AdobePaths) {
            if (Test-Path $Path) {
                if ($PSCmdlet.ShouldProcess($Path, "Clear Adobe media cache")) {
                    Invoke-SafeCommand -TaskName "Adobe Cache Cleanup: $(Split-Path $Path -Leaf)" -Command {
                        Remove-Item -Path "$Path\*" -Recurse -Force -ErrorAction SilentlyContinue
                    }
                }
            }
        }
    }

    # DaVinci Resolve
    if ($Config.MultimediaMaintenance.EnableDaVinciResolve) {
        $ResolvePaths = @(
            "$env:APPDATA\Blackmagic Design\DaVinci Resolve\Support\logs",
            "$env:LOCALAPPDATA\Blackmagic Design\DaVinci Resolve\Cache"
        )

        foreach ($Path in $ResolvePaths) {
            if (Test-Path $Path) {
                if ($PSCmdlet.ShouldProcess($Path, "Clear DaVinci Resolve logs/cache")) {
                    Invoke-SafeCommand -TaskName "DaVinci Resolve Cleanup: $(Split-Path $Path -Leaf)" -Command {
                        Remove-Item -Path "$Path\*" -Recurse -Force -ErrorAction SilentlyContinue
                    }
                }
            }
        }
    }

    # CapCut Desktop
    if ($Config.MultimediaMaintenance.EnableCapCut) {
        $CapCutPath = "$env:LOCALAPPDATA\CapCut\User Data\Cache"
        if (Test-Path $CapCutPath) {
            if ($PSCmdlet.ShouldProcess($CapCutPath, "Clear CapCut cache")) {
                Invoke-SafeCommand -TaskName "CapCut Cache Cleanup" -Command {
                    Remove-Item -Path "$CapCutPath\*" -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }

    # Audacity
    if ($Config.MultimediaMaintenance.EnableAudacity) {
        $AudacityPath = "$env:LOCALAPPDATA\audacity\SessionData"
        if (Test-Path $AudacityPath) {
            if ($PSCmdlet.ShouldProcess($AudacityPath, "Clear Audacity temporary session data")) {
                Invoke-SafeCommand -TaskName "Audacity Temp Cleanup" -Command {
                    Remove-Item -Path "$AudacityPath\*" -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }

    # OBS Studio
    if ($Config.MultimediaMaintenance.EnableOBSStudio) {
        $OBSPath = "$env:APPDATA\obs-studio\logs"
        if (Test-Path $OBSPath) {
            if ($PSCmdlet.ShouldProcess($OBSPath, "Clear OBS Studio log files")) {
                Invoke-SafeCommand -TaskName "OBS Studio Log Cleanup" -Command {
                    $RetentionDays = if ($Config.MultimediaMaintenance.LogRetentionDays) { $Config.MultimediaMaintenance.LogRetentionDays } else { 7 }
                    # Keep logs from the last N days
                    $OldLogs = Get-ChildItem -Path $OBSPath -Filter "*.txt" | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$RetentionDays) }
                    foreach ($Log in $OldLogs) {
                        Remove-Item -Path $Log.FullName -Force -ErrorAction SilentlyContinue
                    }
                }
            }
        }
    }

    Write-MaintenanceLog -Message '======== Multimedia Maintenance Module Completed ========' -Level SUCCESS
}

# Export public functions
Export-ModuleMember -Function @(
    'Invoke-MultimediaMaintenance'
)
