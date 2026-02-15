<#
.SYNOPSIS
    GPU maintenance and optimization module.

.DESCRIPTION
    Provides specialized maintenance for Graphics Processing Units (GPUs).
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator

# Import dependencies
Import-Module "$PSScriptRoot\Common\Logging.psm1" -Force
Import-Module "$PSScriptRoot\Common\SafeExecution.psm1" -Force
Import-Module "$PSScriptRoot\Common\UIHelpers.psm1" -Force

<#
.SYNOPSIS
    Main GPU maintenance orchestration function.
#>
function Invoke-GPUMaintenance {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Config
    )

    if ("GPUMaintenance" -notin $Config.EnabledModules) {
        Write-MaintenanceLog -Message 'GPU Maintenance module disabled' -Level INFO
        return
    }

    Write-MaintenanceLog -Message '======== GPU Maintenance Module ========' -Level INFO

    Invoke-SafeCommand -TaskName "GPU Hardware Detection" -Command {
        $GPUs = Get-CimInstance Win32_VideoController

        foreach ($GPU in $GPUs) {
            $GPUName = $GPU.Name
            Write-MaintenanceLog -Message "Detected GPU: $GPUName" -Level INFO

            if ($GPUName -like "*NVIDIA*" -and $Config.GPUMaintenance.EnableNVIDIACleanup) {
                Invoke-NVIDIAMaintenance -WhatIf:$PSCmdlet.MyInvocation.BoundParameters['WhatIf']
            }
            elseif (($GPUName -like "*AMD*" -or $GPUName -like "*Radeon*") -and $Config.GPUMaintenance.EnableAMDCleanup) {
                Invoke-AMDMaintenance -WhatIf:$PSCmdlet.MyInvocation.BoundParameters['WhatIf']
            }
            elseif ($GPUName -like "*Intel*" -and $Config.GPUMaintenance.EnableIntelCleanup) {
                Invoke-IntelMaintenance -WhatIf:$PSCmdlet.MyInvocation.BoundParameters['WhatIf']
            }
        }

        if ($Config.GPUMaintenance.EnableDirectXCleanup) {
            Invoke-DirectXMaintenance -WhatIf:$PSCmdlet.MyInvocation.BoundParameters['WhatIf']
        }
    }
}

function Invoke-NVIDIAMaintenance {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    $Paths = @( @{ Path = "$env:LOCALAPPDATA\NVIDIA\DXCache"; Name = "NVIDIA DirectX Cache" } )
    Clear-GPUCachePath -Paths $Paths
}

function Invoke-AMDMaintenance {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    $Paths = @( @{ Path = "$env:LOCALAPPDATA\AMD\DXCache"; Name = "AMD DirectX Cache" } )
    Clear-GPUCachePath -Paths $Paths
}

function Invoke-IntelMaintenance {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    $Paths = @( @{ Path = "$env:LOCALAPPDATA\Intel\ShaderCache"; Name = "Intel Shader Cache" } )
    Clear-GPUCachePath -Paths $Paths
}

function Invoke-DirectXMaintenance {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    $Paths = @( @{ Path = "$env:LOCALAPPDATA\Microsoft\DirectX Shader Cache"; Name = "Windows DirectX Cache" } )
    Clear-GPUCachePath -Paths $Paths
}

function Clear-GPUCachePath {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param([array]$Paths)

    foreach ($Entry in $Paths) {
        if (Test-Path $Entry.Path) {
            if ($PSCmdlet.ShouldProcess($Entry.Name, "Clear Cache Path")) {
                Remove-Item -Path "$($Entry.Path)\*" -Recurse -Force -ErrorAction SilentlyContinue
                Write-MaintenanceLog -Message "Cleaned: $($Entry.Name)" -Level SUCCESS
            }
        }
    }
}

# Export public functions
Export-ModuleMember -Function Invoke-GPUMaintenance
