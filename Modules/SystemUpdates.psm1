<#
.SYNOPSIS
    Comprehensive system update management module with multi-source package updates.

.DESCRIPTION
    Manages system updates from multiple sources including Windows Update,
    WinGet package manager, and Chocolatey package manager.
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator

# Import dependencies
$CommonPath = Join-Path $PSScriptRoot "Common"
Import-Module "$CommonPath\Logging.psm1" -Force
Import-Module "$CommonPath\SafeExecution.psm1" -Force
Import-Module "$CommonPath\RealTimeProgressOutput.psm1" -Force

<#
.SYNOPSIS
    Comprehensive system update management module.
#>
function Invoke-SystemUpdate {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Config
    )

    if ("SystemUpdates" -notin $Config.EnabledModules) {
        Write-MaintenanceLog -Message 'System Update module disabled' -Level INFO
        return
    }

    Write-MaintenanceLog -Message '======== System Update Module ========' -Level INFO

    # Optional Windows Update Component Reset
    if ($Config.SystemUpdates.EnableWUReset) {
        Invoke-SafeCommand -TaskName "Windows Update Reset" -Command {
            Reset-WindowsUpdateComponent -WhatIf:$PSCmdlet.MyInvocation.BoundParameters['WhatIf']
        }
    }

    # Windows Update Management
    Invoke-SafeCommand -TaskName "Windows Update Management" -Command {
        Write-ProgressBar -Activity 'System Updates' -PercentComplete 10 -Status 'Initializing Windows Update...'

        # Install NuGet provider
        if (!(Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
            Write-MaintenanceLog -Message 'Installing NuGet package provider...' -Level PROGRESS
            Install-PackageProvider -Name NuGet -Force -Scope CurrentUser | Out-Null
        }

        Write-ProgressBar -Activity 'System Updates' -PercentComplete 30 -Status 'Installing PSWindowsUpdate module...'

        # Install PSWindowsUpdate module
        if (!(Get-Module -ListAvailable -Name PSWindowsUpdate)) {
            Write-MaintenanceLog -Message 'Installing PSWindowsUpdate module...' -Level PROGRESS
            Install-Module PSWindowsUpdate -Force -Confirm:$false -Scope CurrentUser | Out-Null
        }

        Write-ProgressBar -Activity 'System Updates' -PercentComplete 50 -Status 'Checking for Windows updates...'

        Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue

        # Detect and install updates
        $Updates = Get-WindowsUpdate -ErrorAction SilentlyContinue
        if ($Updates -and $Updates.Count -gt 0) {
            Write-MaintenanceLog -Message "Found $($Updates.Count) Windows updates available" -Level INFO

            if ($PSCmdlet.ShouldProcess("System", "Install $($Updates.Count) Windows Updates")) {
                Write-ProgressBar -Activity 'System Updates' -PercentComplete 70 -Status 'Installing Windows updates...'
                $UpdateResults = Get-WindowsUpdate -AcceptAll -Install -AutoReboot:$false -ErrorAction SilentlyContinue

                if ($UpdateResults) {
                    foreach ($Result in $UpdateResults) {
                        $Status = if ($Result.Result -eq "Installed") { "Success" } else { "Warning" }
                        Write-DetailedOperation -Operation 'Update Installation' -Details "KB$($Result.KBArticleIDs): $($Result.Title)" -Result $Status
                    }
                }
                Write-MaintenanceLog -Message 'Windows updates installation completed' -Level SUCCESS
            }
        }
        else {
            Write-MaintenanceLog -Message 'No Windows updates available' -Level INFO
            Write-DetailedOperation -Operation 'Update Check' -Details "System is up to date" -Result 'Current'
        }
    }

    # WinGet Package Management
    Invoke-SafeCommand -TaskName "WinGet Package Management" -Command {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-MaintenanceLog -Message 'Processing WinGet package updates...' -Level PROGRESS

            $WinGetOutput = winget upgrade --include-unknown 2>$null
            if ($WinGetOutput) {
                $UpgradeablePackages = $WinGetOutput | Where-Object {
                    $_ -match "^\S+\s+\S+\s+\S+\s+\S+" -and $_ -notmatch "^Name|^-" -and $_.Trim() -ne ""
                }

                if ($UpgradeablePackages -and $UpgradeablePackages.Count -gt 0) {
                    Write-MaintenanceLog -Message "Found $($UpgradeablePackages.Count) WinGet packages available for upgrade" -Level INFO

                    if ($PSCmdlet.ShouldProcess("Packages", "Upgrade $($UpgradeablePackages.Count) WinGet packages")) {
                        $UpgradeResult = Invoke-CommandWithRealTimeOutput `
                            -Command "winget" `
                            -Arguments "upgrade --all --accept-source-agreements --accept-package-agreements --silent --disable-interactivity" `
                            -ActivityName "WinGet Updates" `
                            -StatusMessage "Updating packages..." `
                            -ShowRealTimeOutput $true `
                            -TimeoutMinutes 60

                        if ($UpgradeResult.Success -or $UpgradeResult.ExitCode -eq 0) {
                            Write-MaintenanceLog -Message "WinGet packages updated successfully" -Level SUCCESS
                        }
                        else {
                            Write-MaintenanceLog -Message "WinGet upgrade completed with warnings (Exit Code: $($UpgradeResult.ExitCode))" -Level WARNING
                        }
                    }
                }
                else {
                    Write-MaintenanceLog -Message 'No WinGet package updates available' -Level INFO
                }
            }
        }
    }

    # Microsoft Store Updates (Explicit)
    if ($Config.SystemUpdates.EnableMicrosoftStore) {
        Invoke-SafeCommand -TaskName "Microsoft Store Updates" -Command {
            if (Get-Command winget -ErrorAction SilentlyContinue) {
                Write-MaintenanceLog -Message 'Checking for Microsoft Store updates...' -Level PROGRESS

                # We specifically target the msstore source to ensure Store apps are covered
                # This is redundant if 'upgrade --all' above caught them, but ensures intent is met
                # and captures any that might have been skipped or requires specific agreements.

                $StoreArgs = "upgrade --all --source msstore --accept-package-agreements --accept-source-agreements --include-unknown --silent --disable-interactivity"

                $StoreResult = Invoke-CommandWithRealTimeOutput `
                    -Command "winget" `
                    -Arguments $StoreArgs `
                    -ActivityName "Microsoft Store Updates" `
                    -StatusMessage "Updating Store apps..." `
                    -ShowRealTimeOutput $true `
                    -TimeoutMinutes 45

                if ($StoreResult.Success -or $StoreResult.ExitCode -eq 0) {
                    Write-MaintenanceLog -Message "Microsoft Store apps check/update completed" -Level SUCCESS
                } else {
                    Write-MaintenanceLog -Message "Microsoft Store update completed with potential warnings (Exit Code: $($StoreResult.ExitCode))" -Level WARNING
                }
            } else {
                 Write-MaintenanceLog -Message "WinGet not available - cannot perform Store updates via CLI" -Level WARNING
            }
        }
    }

    # Chocolatey Package Management
    Invoke-SafeCommand -TaskName "Chocolatey Package Management" -Command {
        $ChocolateyPath = "$env:ProgramData\chocolatey\bin\choco.exe"
        if (Test-Path $ChocolateyPath) {
            Write-MaintenanceLog -Message 'Processing Chocolatey package updates...' -Level PROGRESS

            # Installer cache cleanup helper
            $ClearCache = {
                try {
                    $InstallerService = Get-Service -Name "MSIServer" -ErrorAction SilentlyContinue
                    if ($InstallerService -and $InstallerService.Status -eq "Running") {
                        Stop-Service -Name "MSIServer" -Force -ErrorAction SilentlyContinue
                    }
                    $CachePaths = @("$env:TEMP\chocolatey", "$env:LOCALAPPDATA\Temp\chocolatey")
                    foreach ($P in $CachePaths) {
                        if (Test-Path $P) { Remove-Item -Path $P -Recurse -Force -ErrorAction SilentlyContinue }
                    }
                    Start-Service -Name "MSIServer" -ErrorAction SilentlyContinue
                } catch {
        Write-MaintenanceLog -Message "Update check error: $($_.Exception.Message)" -Level WARNING
    }
            }

            & $ClearCache

            $OutdatedOutput = & $ChocolateyPath outdated --limit-output 2>&1
            if ($OutdatedOutput -and $OutdatedOutput.Count -gt 0) {
                $ValidPackages = $OutdatedOutput | Where-Object { $_ -match '\|' }
                if ($ValidPackages) {
                    Write-MaintenanceLog -Message "Found $($ValidPackages.Count) outdated Chocolatey packages" -Level INFO

                    if ($PSCmdlet.ShouldProcess("Packages", "Upgrade $($ValidPackages.Count) Chocolatey packages")) {
                        foreach ($Pkg in $ValidPackages) {
                            $PkgName = ($Pkg -split '\|')[0]
                            Write-MaintenanceLog -Message "Updating $PkgName..." -Level PROGRESS

                            $Res = Invoke-CommandWithRealTimeOutput `
                                -Command $ChocolateyPath `
                                -Arguments "upgrade $PkgName --yes --no-progress" `
                                -ActivityName "Chocolatey: $PkgName" `
                                -StatusMessage "Upgrading..." `
                                -ShowRealTimeOutput $true `
                                -TimeoutMinutes 10

                            if ($Res.ExitCode -eq 0) {
                                Write-MaintenanceLog -Message "Successfully updated $PkgName" -Level SUCCESS
                            } else {
                                Write-MaintenanceLog -Message "Failed to update $PkgName (Exit Code: $($Res.ExitCode))" -Level WARNING
                            }
                        }
                    }
                }
            }
        }
    }
}

<#
.SYNOPSIS
    Resets Windows Update components.

.DESCRIPTION
    Stops update services, clears the SoftwareDistribution and catroot2 folders,
    and restarts the services.
#>
function Reset-WindowsUpdateComponent {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()

    if ($PSCmdlet.ShouldProcess("Windows Update Components", "Reset services and clear download cache")) {
        $Services = @("wuauserv", "cryptSvc", "bits", "msiserver")

        Write-MaintenanceLog -Message "Stopping update services..." -Level PROGRESS
        foreach ($Svc in $Services) {
            $ServiceObj = Get-Service $Svc -ErrorAction SilentlyContinue
            if ($ServiceObj -and $ServiceObj.Status -eq "Running") {
                Stop-Service $Svc -Force -ErrorAction SilentlyContinue
            }
        }

        # Rename/Clear folders
        $Paths = @(
            "$env:SystemRoot\SoftwareDistribution",
            "$env:SystemRoot\System32\catroot2"
        )

        foreach ($P in $Paths) {
            if (Test-Path $P) {
                Write-MaintenanceLog -Message "Clearing: $P" -Level DETAIL
                Remove-Item -Path $P -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        Write-MaintenanceLog -Message "Restarting update services..." -Level PROGRESS
        foreach ($Svc in $Services) {
            Start-Service $Svc -ErrorAction SilentlyContinue
        }

        Write-MaintenanceLog -Message "Windows Update components reset successfully" -Level SUCCESS
    }
}

# Export public functions
Export-ModuleMember -Function @(
    'Invoke-SystemUpdate',
    'Reset-WindowsUpdateComponent'
)

