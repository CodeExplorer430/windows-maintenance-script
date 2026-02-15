<#
.SYNOPSIS
    Comprehensive developer environment maintenance module.

.DESCRIPTION
    Provides specialized maintenance for developer workstations including package
    managers, development tools, IDEs, and professional software.
#>

#Requires -Version 5.1

# Import dependencies
Import-Module "$PSScriptRoot\Common\Logging.psm1" -Force
Import-Module "$PSScriptRoot\Common\SafeExecution.psm1" -Force
Import-Module "$PSScriptRoot\Common\MemoryManagement.psm1" -Force
Import-Module "$PSScriptRoot\Common\StringFormatting.psm1" -Force

<#
.SYNOPSIS
    Executes comprehensive developer environment maintenance operations.
#>
function Invoke-DeveloperMaintenance {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPositionalParameters", "npm")]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Config
    )

    if ('DeveloperMaintenance' -notin $Config.EnabledModules) {
        Write-MaintenanceLog -Message 'Developer Maintenance module disabled' -Level INFO
        return
    }

    Write-MaintenanceLog -Message '======== Developer Maintenance Module ========' -Level INFO

    # NPM Task
    if ($Config.DeveloperMaintenance.EnableNPM -ne $false -and (Get-Command npm -ErrorAction SilentlyContinue)) {
        if ($PSCmdlet.ShouldProcess("NPM", "Update global packages and clear cache")) {
            Invoke-SafeCommand -TaskName "NPM Cleanup" -Command {
                npm update -g 2>$null | Out-Null
                npm audit fix -g 2>&1 | Out-Null
                npm cache clean --force 2>$null | Out-Null
            }
        }
    }

    # Python Task
    if ($Config.DeveloperMaintenance.EnablePython -ne $false -and (Get-Command pip -ErrorAction SilentlyContinue)) {
        if ($PSCmdlet.ShouldProcess("Pip", "Update all outdated packages")) {
            Invoke-SafeCommand -TaskName "Pip Update" -Command {
                $Outdated = pip list --outdated --format=json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
                if ($Outdated) {
                    foreach ($Pkg in $Outdated) {
                        pip install --upgrade $Pkg.name --quiet 2>$null
                    }
                }
            }
        }
    }

    # Docker Task
    if ($Config.DeveloperMaintenance.EnableDocker -ne $false -and (Get-Command docker -ErrorAction SilentlyContinue)) {
        if ($PSCmdlet.ShouldProcess("Docker", "Prune system")) {
            Invoke-SafeCommand -TaskName "Docker Prune" -Command {
                docker system prune -af 2>&1 | Out-Null
            }
        }
    }

    # VS Code Task
    if ($Config.DeveloperMaintenance.EnableVSCode) {
        $Path = "$env:APPDATA\Code\CachedExtensions"
        if (Test-Path $Path) {
            if ($PSCmdlet.ShouldProcess($Path, "Clear extension cache")) {
                Invoke-SafeCommand -TaskName "VS Code Extension Cache Cleanup" -Command {
                    Remove-Item -Path "$Path\*" -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }

    # JDK Task
    if (Get-Command java -ErrorAction SilentlyContinue) {
        if ($PSCmdlet.ShouldProcess("JDK", "Clean Maven and Gradle caches")) {
            Invoke-SafeCommand -TaskName "JDK Cache Cleanup" -Command {
                # Maven local repository cleanup (older than 30 days)
                $M2Path = Join-Path $env:USERPROFILE ".m2\repository"
                if (Test-Path $M2Path) {
                    Get-ChildItem -Path $M2Path -Recurse -File | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | Remove-Item -Force -ErrorAction SilentlyContinue
                    Write-MaintenanceLog -Message "JDK: Maven repository cleaned (30d retention)" -Level SUCCESS
                }

                # Gradle cache cleanup
                $GradlePath = Join-Path $env:USERPROFILE ".gradle\caches"
                if (Test-Path $GradlePath) {
                    Get-ChildItem -Path $GradlePath -Recurse -File | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | Remove-Item -Force -ErrorAction SilentlyContinue
                    Write-MaintenanceLog -Message "JDK: Gradle cache cleaned (30d retention)" -Level SUCCESS
                }
            }
        }
    }

    # .NET SDK Task
    if (Get-Command dotnet -ErrorAction SilentlyContinue) {
        if ($PSCmdlet.ShouldProcess(".NET SDK", "Clear NuGet locals")) {
            Invoke-SafeCommand -TaskName ".NET SDK NuGet Cleanup" -Command {
                & dotnet nuget locals all --clear 2>$null | Out-Null
                Write-MaintenanceLog -Message ".NET SDK: NuGet locals cleared" -Level SUCCESS
            }
        }
    }

    # VC++ Redistributables
    if ($PSCmdlet.ShouldProcess("VC++ Redistributables", "Cleanup installation logs")) {
        Invoke-SafeCommand -TaskName "VC++ Redist Cleanup" -Command {
            $LogPaths = @("$env:TEMP\dd_vcredist*.log", "$env:WINDOWS\Temp\dd_vcredist*.log")
            foreach ($P in $LogPaths) {
                if (Test-Path $P) {
                    Remove-Item -Path $P -Force -ErrorAction SilentlyContinue
                }
            }
            Write-MaintenanceLog -Message "VC++ Redistributables: Installation logs cleaned" -Level SUCCESS
        }
    }

    # Composer (PHP)
    if (Get-Command composer -ErrorAction SilentlyContinue) {
        if ($PSCmdlet.ShouldProcess("Composer", "Clear cache")) {
            Invoke-SafeCommand -TaskName "Composer Cleanup" -Command {
                & composer clear-cache 2>$null | Out-Null
                Write-MaintenanceLog -Message "Composer cache cleared" -Level SUCCESS
            }
        }
    }

    # Visual Studio Maintenance (2022, 2026)
    $VSWherePath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $VSWherePath) {
        if ($PSCmdlet.ShouldProcess("Visual Studio", "Cleanup installation caches and temp files")) {
            Invoke-SafeCommand -TaskName "Visual Studio Cleanup" -Command {
                # Detect all VS installations including future 2026 (version 18.x)
                $Installations = & $VSWherePath -all -property installationPath 2>$null

                foreach ($Path in $Installations) {
                    Write-MaintenanceLog -Message "Visual Studio detected at: $Path" -Level DETAIL

                    # Cleanup specific to installation
                    $CachePath = Join-Path $Path "Common7\IDE\CommonExtensions\Microsoft\Editor\ServiceHub\Indexing\Index"
                    if (Test-Path $CachePath) {
                        Remove-Item -Path "$CachePath\*" -Recurse -Force -ErrorAction SilentlyContinue
                    }
                }

                # General VS Cache cleanup in AppData
                $VSAppDataPaths = @(
                    "$env:LOCALAPPDATA\Microsoft\VisualStudio\17.0*", # VS 2022
                    "$env:LOCALAPPDATA\Microsoft\VisualStudio\18.0*"  # VS 2026
                )
                foreach ($Path in $VSAppDataPaths) {
                    $Dirs = Get-ChildItem -Path (Split-Path $Path -Parent) -Directory -Filter (Split-Path $Path -Leaf) -ErrorAction SilentlyContinue
                    foreach ($Dir in $Dirs) {
                        $CompCache = Join-Path $Dir.FullName "ComponentModelCache"
                        if (Test-Path $CompCache) {
                            Remove-Item -Path "$CompCache\*" -Recurse -Force -ErrorAction SilentlyContinue
                        }
                    }
                }
                Write-MaintenanceLog -Message "Visual Studio caches cleaned" -Level SUCCESS
            }
        }
    }

    # Git
    if (Get-Command git -ErrorAction SilentlyContinue) {
        if ($PSCmdlet.ShouldProcess("Git", "Run garbage collection and clear credentials cache")) {
            Invoke-SafeCommand -TaskName "Git Optimization" -Command {
                & git gc --auto --quiet 2>$null
                & git credential-cache exit 2>$null
                Write-MaintenanceLog -Message "Git: Garbage collection performed" -Level SUCCESS
            }
        }
    }

    Write-MaintenanceLog -Message '======== Developer Maintenance Module Completed ========' -Level SUCCESS
}

# Export public functions
Export-ModuleMember -Function @(
    'Invoke-DeveloperMaintenance'
)
