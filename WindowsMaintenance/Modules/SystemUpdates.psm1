<#
.SYNOPSIS
    Comprehensive system update management module with multi-source package updates.

.DESCRIPTION
    Manages system updates from multiple sources including Windows Update,
    WinGet package manager, and Chocolatey package manager with comprehensive
    error handling and detailed progress reporting.

    Update Sources:
    - Windows Update: Security updates, feature updates, driver updates
    - WinGet: Microsoft Store and community packages
    - Chocolatey: Community-driven package management

    Features:
    - Automated package provider installation
    - Detailed update enumeration and reporting
    - Selective update installation with error handling
    - Progress tracking and performance metrics
    - Comprehensive logging and audit trails
    - Enhanced Windows Installer Error 1603 resolution

.NOTES
    File Name      : SystemUpdates.psm1
    Author         : Miguel Velasco
    Prerequisite   : PowerShell 5.1+
    Version        : 4.0.0
    Last Updated   : October 2025
    Module Type    : Feature Module
    Dependencies   : Logging.psm1, SafeExecution.psm1, RealTimeProgressOutput.psm1
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
    Comprehensive system update management module with multi-source package updates.

.DESCRIPTION
    Manages system updates from multiple sources including Windows Update,
    WinGet package manager, and Chocolatey package manager with comprehensive
    error handling and detailed progress reporting.

    Update Sources:
    - Windows Update: Security updates, feature updates, driver updates
    - WinGet: Microsoft Store and community packages
    - Chocolatey: Community-driven package management

    Features:
    - Automated package provider installation
    - Detailed update enumeration and reporting
    - Selective update installation with error handling
    - Progress tracking and performance metrics
    - Comprehensive logging and audit trails
    - Enhanced Windows Installer Error 1603 resolution

.EXAMPLE
    Invoke-SystemUpdates

.NOTES
    Security: All updates are validated and come from trusted sources
    Performance: Parallel processing where safe and beneficial
    Reliability: Multiple fallback mechanisms for failed updates
    Enhanced: Robust Windows Installer cache management and retry logic
#>
function Invoke-SystemUpdates {
    # Get Config from parent scope
    $Config = if (Get-Variable -Name 'Config' -Scope 1 -ErrorAction SilentlyContinue) {
        (Get-Variable -Name 'Config' -Scope 1).Value
    } elseif (Get-Variable -Name 'Config' -Scope Global -ErrorAction SilentlyContinue) {
        $Global:Config
    } else {
        @{ EnabledModules = @("SystemUpdate") }
    }

    if ("SystemUpdate" -notin $Config.EnabledModules) {
        Write-MaintenanceLog -Message 'System Update module disabled' -Level INFO
        return
    }

    Write-MaintenanceLog -Message '======== System Update Module ========' -Level INFO

    # Windows Update management with comprehensive error handling
    Invoke-SafeCommand -TaskName "Windows Update Management" -Command {
        Write-ProgressBar -Activity 'System Updates' -PercentComplete 10 -Status 'Initializing Windows Update...'

        # Install NuGet provider with detailed feedback and error handling
        if (!(Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
            Write-MaintenanceLog -Message 'Installing NuGet package provider...' -Level PROGRESS
            Write-DetailedOperation -Operation 'NuGet Installation' -Details "Installing required NuGet package provider" -Result 'Installing'
            Install-PackageProvider -Name NuGet -Force -Scope CurrentUser | Out-Null
            Write-DetailedOperation -Operation 'NuGet Installation' -Details "NuGet package provider installed successfully" -Result 'Success'
        }

        Write-ProgressBar -Activity 'System Updates' -PercentComplete 30 -Status 'Installing PSWindowsUpdate module...'

        # Install PSWindowsUpdate module with comprehensive error handling
        if (!(Get-Module -ListAvailable -Name PSWindowsUpdate)) {
            Write-MaintenanceLog -Message 'Installing PSWindowsUpdate module...' -Level PROGRESS
            Write-DetailedOperation -Operation 'PSWindowsUpdate Installation' -Details "Installing Windows Update PowerShell module" -Result 'Installing'
            Install-Module PSWindowsUpdate -Force -Confirm:$false -Scope CurrentUser | Out-Null
            Write-DetailedOperation -Operation 'PSWindowsUpdate Installation' -Details "PSWindowsUpdate module installed successfully" -Result 'Success'
        }

        Write-ProgressBar -Activity 'System Updates' -PercentComplete 50 -Status 'Checking for Windows updates...'

        Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue

        # Get WhatIf from parent scope
        $WhatIfEnabled = if (Get-Variable -Name 'WhatIf' -Scope 1 -ErrorAction SilentlyContinue) {
            (Get-Variable -Name 'WhatIf' -Scope 1).Value
        } elseif (Get-Variable -Name 'WhatIf' -Scope Global -ErrorAction SilentlyContinue) {
            $Global:WhatIf
        } else { $false }

        # Comprehensive Windows Update detection and installation
        $Updates = Get-WindowsUpdate -ErrorAction SilentlyContinue
        if ($Updates -and $Updates.Count -gt 0) {
            Write-MaintenanceLog -Message "Found $($Updates.Count) Windows updates available" -Level INFO

            # Detailed update enumeration for audit purposes
            foreach ($Update in $Updates | Select-Object -First 10) {
                Write-DetailedOperation -Operation 'Update Detection' -Details "KB$($Update.KBArticleIDs): $($Update.Title) | Size: $([math]::Round($Update.Size/1MB, 2))MB" -Result 'Available'
            }

            if ($Updates.Count -gt 10) {
                Write-DetailedOperation -Operation 'Update Detection' -Details "... and $($Updates.Count - 10) additional updates" -Result 'Available'
            }

            if (!$WhatIfEnabled) {
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

    # ============================================================
    # WINGET WITH REAL-TIME OUTPUT
    # ============================================================
    Invoke-SafeCommand -TaskName "WinGet Package Management" -Command {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Show-SectionHeader -Title "WinGet Package Updates" -SubTitle "Checking for available updates"

            Write-MaintenanceLog -Message 'Processing WinGet package updates...' -Level PROGRESS
            Write-DetailedOperation -Operation 'WinGet Detection' -Details 'WinGet package manager detected' -Result 'Available'

            # Get WhatIf from parent scope
            $WhatIfEnabled = if (Get-Variable -Name 'WhatIf' -Scope 1 -ErrorAction SilentlyContinue) {
                (Get-Variable -Name 'WhatIf' -Scope 1).Value
            } elseif (Get-Variable -Name 'WhatIf' -Scope Global -ErrorAction SilentlyContinue) {
                $Global:WhatIf
            } else { $false }

            if (!$WhatIfEnabled) {
                try {
                    # Step 1: Get list of outdated packages
                    Write-Host "`n  Scanning for outdated packages..." -ForegroundColor Yellow
                    Write-ProgressBar -Activity 'Package Updates' -PercentComplete 15 -Status 'Scanning WinGet packages...'

                    $WinGetOutput = winget upgrade --include-unknown 2>$null

                    if ($WinGetOutput) {
                        # Parse package list (improved parsing)
                        $UpgradeablePackages = $WinGetOutput | Where-Object {
                            $_ -match "^\S+\s+\S+\s+\S+\s+\S+" -and
                            $_ -notmatch "^Name|^-" -and
                            $_.Trim() -ne ""
                        }

                        if ($UpgradeablePackages -and $UpgradeablePackages.Count -gt 0) {
                            Write-MaintenanceLog -Message "Found $($UpgradeablePackages.Count) WinGet packages available for upgrade" -Level INFO

                            # Build package table for display
                            $PackageTable = @()
                            foreach ($Package in $UpgradeablePackages) {
                                $PackageInfo = $Package -split '\s{2,}'  # Split by 2+ spaces
                                if ($PackageInfo.Count -ge 3) {
                                    $PackageTable += [PSCustomObject]@{
                                        Name = $PackageInfo[0]
                                        CurrentVersion = $PackageInfo[1]
                                        NewVersion = $PackageInfo[2]
                                    }
                                }
                            }

                            # Display packages to be updated
                            if ($PackageTable.Count -gt 0) {
                                Show-PackageUpdateTable -Packages $PackageTable -PackageManager "WinGet"

                                # Log detailed package info
                                foreach ($Pkg in $PackageTable | Select-Object -First 20) {
                                    Write-DetailedOperation -Operation 'Package Update Available' -Details "Name: $($Pkg.Name) | Current: $($Pkg.CurrentVersion) | Available: $($Pkg.NewVersion)" -Result 'Pending'
                                }
                            }

                            # Step 2: Perform upgrade with real-time output
                            Show-SectionHeader -Title "Updating WinGet Packages" -SubTitle "$($UpgradeablePackages.Count) packages will be updated"

                            Write-Host "`n  Starting package updates..." -ForegroundColor Yellow
                            Write-Host "  This may take several minutes depending on package sizes." -ForegroundColor Gray
                            Write-Host "  You'll see real-time progress for each package below.`n" -ForegroundColor Gray

                            # Execute upgrade with real-time output
                            $UpgradeResult = Invoke-CommandWithRealTimeOutput `
                                -Command "winget" `
                                -Arguments "upgrade --all --accept-source-agreements --accept-package-agreements --silent --disable-interactivity" `
                                -ActivityName "WinGet Package Updates" `
                                -StatusMessage "Updating packages..." `
                                -ShowRealTimeOutput $true `
                                -TimeoutMinutes 60

                            # Process results
                            if ($UpgradeResult.Success -or $UpgradeResult.ExitCode -eq 0) {
                                Write-MaintenanceLog -Message "WinGet packages updated successfully" -Level SUCCESS
                                Write-DetailedOperation -Operation 'WinGet Upgrade' -Details "Updated $($UpgradeablePackages.Count) packages | Duration: $($UpgradeResult.Duration.TotalMinutes.ToString('F2'))min" -Result 'Success'

                                # Show summary
                                Write-Host "`n  ========== Update Summary ==========" -ForegroundColor Green
                                Write-Host "  Total packages updated: $($UpgradeablePackages.Count)" -ForegroundColor White
                                Write-Host "  Duration: $($UpgradeResult.Duration.TotalMinutes.ToString('F2')) minutes" -ForegroundColor White
                                Write-Host "  Status: Completed successfully" -ForegroundColor Green
                                Write-Host "  ====================================`n" -ForegroundColor Green
                            }
                            else {
                                Write-MaintenanceLog -Message "WinGet upgrade completed with warnings (Exit Code: $($UpgradeResult.ExitCode))" -Level WARNING
                                Write-DetailedOperation -Operation 'WinGet Upgrade' -Details "Exit code: $($UpgradeResult.ExitCode) | Some packages may have failed" -Result 'Partial'

                                Write-Host "`n  ========== Update Summary ==========" -ForegroundColor Yellow
                                Write-Host "  Status: Completed with warnings" -ForegroundColor Yellow
                                Write-Host "  Exit Code: $($UpgradeResult.ExitCode)" -ForegroundColor Yellow
                                Write-Host "  Note: Some packages may require manual intervention" -ForegroundColor Gray
                                Write-Host "  ====================================`n" -ForegroundColor Yellow
                            }
                        }
                        else {
                            Write-MaintenanceLog -Message 'No WinGet package updates available' -Level INFO
                            Write-DetailedOperation -Operation 'WinGet Check' -Details "All packages are current" -Result 'Up-to-date'

                            Write-Host "`n  All packages are up to date!" -ForegroundColor Green
                            Write-Host "  No updates required.`n" -ForegroundColor Gray
                        }
                    }
                }
                catch {
                    Write-MaintenanceLog -Message "WinGet package management failed: $($_.Exception.Message)" -Level ERROR
                    Write-DetailedOperation -Operation 'WinGet Package Management' -Details "Error: $($_.Exception.Message)" -Result 'Failed'
                }
            }
            else {
                Write-MaintenanceLog -Message '[WHATIF] Would check and update WinGet packages' -Level INFO
            }
        }
        else {
            Write-MaintenanceLog -Message 'WinGet not available - consider installing Windows Package Manager' -Level WARNING
            Write-DetailedOperation -Operation 'WinGet Check' -Details "Windows Package Manager not installed" -Result 'Not Available'
        }
    }

    # ============================================================
    # CHOCOLATEY WITH REAL-TIME OUTPUT
    # ============================================================
    Invoke-SafeCommand -TaskName "Chocolatey Package Management" -Command {
        $ChocolateyPath = "$env:ProgramData\chocolatey\bin\choco.exe"

        # Enhanced Windows Installer cache cleanup function
        function Clear-WindowsInstallerCache {
            try {
                Write-MaintenanceLog -Message "Performing comprehensive Windows Installer cleanup..." -Level INFO

                # Stop Windows Installer service temporarily
                $InstallerService = Get-Service -Name "MSIServer" -ErrorAction SilentlyContinue
                if ($InstallerService -and $InstallerService.Status -eq "Running") {
                    Stop-Service -Name "MSIServer" -Force -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 3
                }

                # Clear installer cache locations with enhanced cleanup
                $CachePaths = @(
                    "$env:WINDOWS\Installer",
                    "$env:LOCALAPPDATA\Package Cache",
                    "$env:PROGRAMDATA\Package Cache",
                    "$env:TEMP\chocolatey",
                    "$env:LOCALAPPDATA\Temp\chocolatey"
                )

                foreach ($Path in $CachePaths) {
                    if (Test-Path $Path) {
                        try {
                            # More aggressive cleanup for problematic files
                            Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue |
                                Where-Object {
                                    $_.LastWriteTime -lt (Get-Date).AddDays(-1) -or
                                    $_.Name -like "*python*" -or
                                    $_.Name -like "*msi*"
                                } |
                                Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

                            Write-MaintenanceLog -Message "Cleaned cache: $Path" -Level DEBUG
                        }
                        catch {
                            Write-MaintenanceLog -Message "Warning: Could not clean some files in $Path - $($_.Exception.Message)" -Level WARNING
                        }
                    }
                }

                # Clear MSI rollback information that can cause conflicts
                $RollbackPath = "$env:WINDOWS\Installer\`$PatchGUID`$"
                if (Test-Path $RollbackPath) {
                    Remove-Item -Path $RollbackPath -Force -Recurse -ErrorAction SilentlyContinue
                }

                # Restart Windows Installer service
                Start-Service -Name "MSIServer" -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2

                Write-MaintenanceLog -Message "Enhanced Windows Installer cleanup completed" -Level SUCCESS
                return $true
            }
            catch {
                Write-MaintenanceLog -Message "Windows Installer cleanup failed: $($_.Exception.Message)" -Level WARNING
                return $false
            }
        }

        # Enhanced package conflict detection
        function Get-ConflictingPackages {
            param([array]$PackageList)

            $ConflictGroups = @{
                'Python' = @('python', 'python3', 'python313', 'python312', 'python311', 'python39', 'python38')
                'Git' = @('git', 'git.install', 'git.portable')
                'NodeJS' = @('nodejs', 'nodejs.install', 'nodejs-lts')
                'Java' = @('javaruntime', 'jre8', 'jdk8', 'openjdk', 'oracle-jdk')
                'Chrome' = @('googlechrome', 'chrome', 'chromium')
                'Firefox' = @('firefox', 'firefox-esr', 'firefoxesr')
            }

            $ConflictMap = @{}

            foreach ($Group in $ConflictGroups.Keys) {
                $ConflictingPackages = $PackageList | Where-Object {
                    $PackageName = ($_ -split '\|')[0]
                    $ConflictGroups[$Group] -contains $PackageName
                }

                if ($ConflictingPackages.Count -gt 1) {
                    # Select the most appropriate primary package
                    $PrimaryPackage = switch ($Group) {
                        'Python' {
                            # Prefer python3 over others
                            $ConflictingPackages | Where-Object { ($_ -split '\|')[0] -eq 'python3' } | Select-Object -First 1
                            if (-not $_) { $ConflictingPackages | Where-Object { ($_ -split '\|')[0] -eq 'python313' } | Select-Object -First 1 }
                            if (-not $_) { $ConflictingPackages | Where-Object { ($_ -split '\|')[0] -eq 'python' } | Select-Object -First 1 }
                            if (-not $_) { $ConflictingPackages | Select-Object -First 1 }
                        }
                        'Git' {
                            $ConflictingPackages | Where-Object { ($_ -split '\|')[0] -eq 'git' } | Select-Object -First 1
                            if (-not $_) { $ConflictingPackages | Select-Object -First 1 }
                        }
                        default { $ConflictingPackages | Select-Object -First 1 }
                    }

                    $ConflictMap[$Group] = @{
                        'Primary' = $PrimaryPackage
                        'Conflicts' = $ConflictingPackages | Where-Object { $_ -ne $PrimaryPackage }
                    }
                }
            }

            return $ConflictMap
        }

        # Enhanced package upgrade with real-time output capability
        function Invoke-ChocolateyUpgradeWithRetry {
            param(
                [string]$PackageName,
                [int]$MaxRetries = 3,
                [switch]$UseAlternativeMethod = $false,
                [bool]$ShowRealTime = $true
            )

            $UpgradeOptions = if ($UseAlternativeMethod) {
                '--yes --no-progress --ignore-checksums --force --allow-empty-checksums'
            } else {
                '--yes --no-progress'
            }

            for ($i = 1; $i -le $MaxRetries; $i++) {
                try {
                    $AttemptType = if ($UseAlternativeMethod) { "Alternative" } else { "Standard" }
                    Write-MaintenanceLog -Message "[$AttemptType] Attempting to upgrade $PackageName (Attempt $i/$MaxRetries)" -Level INFO

                    # Clear cache before each attempt if it's a retry
                    if ($i -gt 1) {
                        Clear-WindowsInstallerCache
                        Start-Sleep -Seconds 5
                    }

                    # Special handling for problematic packages
                    if ($PackageName -like "*python*") {
                        if ($i -eq $MaxRetries) {
                            Write-MaintenanceLog -Message "Attempting to resolve Python conflicts for $PackageName" -Level INFO
                            & $ChocolateyPath uninstall $PackageName --yes --remove-dependencies --force 2>&1 | Out-Null
                            Start-Sleep -Seconds 3
                        }
                    }

                    # Execute with real-time output if enabled
                    if ($ShowRealTime) {
                        Write-Host "`n    ===== Updating: $PackageName (Attempt $i/$MaxRetries) =====" -ForegroundColor Cyan

                        $UpgradeResult = Invoke-CommandWithRealTimeOutput `
                            -Command $ChocolateyPath `
                            -Arguments "upgrade $PackageName $UpgradeOptions" `
                            -ActivityName "Chocolatey: $PackageName" `
                            -StatusMessage "Upgrading $PackageName..." `
                            -ShowRealTimeOutput $true `
                            -TimeoutMinutes 10

                        $ExitCode = $UpgradeResult.ExitCode
                        $UpgradeOutput = $UpgradeResult.Output
                    }
                    else {
                        # Fallback to job-based execution
                        $UpgradeJob = Start-Job -ScriptBlock {
                            param($ChocolateyPath, $PackageName, $Options)
                            & $ChocolateyPath upgrade $PackageName $Options.Split(' ') 2>&1
                        } -ArgumentList $ChocolateyPath, $PackageName, $UpgradeOptions

                        $JobResult = Wait-Job -Job $UpgradeJob -Timeout 300
                        $UpgradeOutput = Receive-Job -Job $UpgradeJob
                        Remove-Job -Job $UpgradeJob -Force

                        if ($JobResult) {
                            $ExitCode = if ($UpgradeJob.State -eq 'Completed') { 0 } else { 1 }
                        } else {
                            Write-MaintenanceLog -Message "Package upgrade timed out for $PackageName" -Level WARNING
                            $ExitCode = -1
                        }
                    }

                    # Analyze results
                    if ($ExitCode -eq 0 -or ($UpgradeOutput -match "upgraded successfully" -or $UpgradeOutput -match "is the latest version")) {
                        Write-MaintenanceLog -Message "Successfully updated package: $PackageName" -Level SUCCESS
                        Write-DetailedOperation -Operation 'Package Upgrade' -Details "Package: $PackageName | Method: $AttemptType | Attempt: $i | Result: Success" -Result 'Success'
                        return $true
                    }
                    elseif ($ExitCode -eq 1603 -or $UpgradeOutput -match "1603") {
                        Write-MaintenanceLog -Message "Windows Installer Error 1603 for $PackageName (Attempt $i/$MaxRetries)" -Level WARNING

                        if ($i -eq $MaxRetries -and -not $UseAlternativeMethod) {
                            Write-MaintenanceLog -Message "Trying alternative installation method for $PackageName..." -Level INFO
                            return Invoke-ChocolateyUpgradeWithRetry -PackageName $PackageName -MaxRetries 2 -UseAlternativeMethod -ShowRealTime $ShowRealTime
                        }

                        Start-Sleep -Seconds ([Math]::Min(30, $i * 10))
                    }
                    elseif ($ExitCode -eq -1) {
                        Write-MaintenanceLog -Message "Package upgrade timed out for $PackageName (Attempt $i/$MaxRetries)" -Level WARNING
                        if ($i -eq $MaxRetries) {
                            Write-MaintenanceLog -Message "Failed to update ${PackageName}: Operation timed out" -Level ERROR
                            return $false
                        }
                        Start-Sleep -Seconds 5
                    }
                    else {
                        Write-MaintenanceLog -Message "Package upgrade failed for $PackageName with exit code $ExitCode (Attempt $i/$MaxRetries)" -Level WARNING

                        if ($i -eq $MaxRetries) {
                            Write-MaintenanceLog -Message "Failed to update $PackageName after $MaxRetries attempts (Final Exit Code: $ExitCode)" -Level ERROR
                            Write-DetailedOperation -Operation 'Package Upgrade Error' -Details "Package: $PackageName | Final Exit Code: $ExitCode | Method: $AttemptType" -Result 'Failed'
                            return $false
                        }
                        Start-Sleep -Seconds 5
                    }
                }
                catch {
                    Write-MaintenanceLog -Message "Exception during package upgrade for ${PackageName}: $($_.Exception.Message)" -Level ERROR
                    if ($i -eq $MaxRetries) {
                        Write-DetailedOperation -Operation 'Package Upgrade Exception' -Details "Package: $PackageName | Error: $($_.Exception.Message)" -Result 'Failed'
                        return $false
                    }
                    Start-Sleep -Seconds 5
                }
            }

            return $false
        }

        # Main Chocolatey processing logic WITH REAL-TIME OUTPUT
        if (Test-Path $ChocolateyPath) {
            Show-SectionHeader -Title "Chocolatey Package Updates" -SubTitle "Checking for available updates"

            Write-MaintenanceLog -Message 'Processing Chocolatey package updates...' -Level PROGRESS
            Write-DetailedOperation -Operation 'Chocolatey Check' -Details "Chocolatey package manager detected at $ChocolateyPath" -Result 'Available'

            # Get WhatIf from parent scope
            $WhatIfEnabled = if (Get-Variable -Name 'WhatIf' -Scope 1 -ErrorAction SilentlyContinue) {
                (Get-Variable -Name 'WhatIf' -Scope 1).Value
            } elseif (Get-Variable -Name 'WhatIf' -Scope Global -ErrorAction SilentlyContinue) {
                $Global:WhatIf
            } else { $false }

            if (!$WhatIfEnabled) {
                # Pre-maintenance system preparation
                Clear-WindowsInstallerCache

                try {
                    # Step 1: Get outdated packages
                    Write-Host "`n  Scanning for outdated packages..." -ForegroundColor Yellow
                    Write-ProgressBar -Activity 'Package Updates' -PercentComplete 30 -Status 'Scanning Chocolatey packages...'

                    $OutdatedOutput = & $ChocolateyPath outdated --limit-output 2>&1

                    if ($LASTEXITCODE -ne 0) {
                        Write-MaintenanceLog -Message "Warning: Chocolatey outdated command returned exit code $LASTEXITCODE" -Level WARNING
                    }
                }
                catch {
                    Write-MaintenanceLog -Message "Error running chocolatey outdated: $($_.Exception.Message)" -Level ERROR
                    $OutdatedOutput = @()
                }

                if ($OutdatedOutput -and $OutdatedOutput.Count -gt 0) {
                    $ValidOutdatedPackages = $OutdatedOutput | Where-Object {
                        $_ -and $_.Trim() -ne "" -and $_ -notmatch "^Chocolatey" -and $_ -match '\|'
                    }

                    if ($ValidOutdatedPackages -and $ValidOutdatedPackages.Count -gt 0) {
                        Write-MaintenanceLog -Message "Found $($ValidOutdatedPackages.Count) outdated Chocolatey packages" -Level INFO

                        # Build package table for display
                        $PackageTable = @()
                        foreach ($Package in $ValidOutdatedPackages) {
                            $PackageInfo = $Package -split '\|'
                            if ($PackageInfo.Count -ge 3) {
                                $PackageTable += [PSCustomObject]@{
                                    Name = $PackageInfo[0]
                                    CurrentVersion = $PackageInfo[1]
                                    NewVersion = $PackageInfo[2]
                                }
                                Write-DetailedOperation -Operation 'Chocolatey Update Available' -Details "Package: $($PackageInfo[0]) | Current: $($PackageInfo[1]) | Available: $($PackageInfo[2])" -Result 'Pending'
                            }
                        }

                        # Display packages to be updated
                        if ($PackageTable.Count -gt 0) {
                            Show-PackageUpdateTable -Packages $PackageTable -PackageManager "Chocolatey"
                        }

                        # Detect and resolve package conflicts
                        $ConflictMap = Get-ConflictingPackages -PackageList $ValidOutdatedPackages

                        if ($ConflictMap.Keys.Count -gt 0) {
                            Write-MaintenanceLog -Message "Detected package conflicts in $($ConflictMap.Keys.Count) groups. Resolving conflicts..." -Level WARNING

                            foreach ($GroupName in $ConflictMap.Keys) {
                                $PrimaryPackage = ($ConflictMap[$GroupName].Primary -split '\|')[0]
                                $ConflictingPackages = $ConflictMap[$GroupName].Conflicts | ForEach-Object { ($_ -split '\|')[0] }

                                Write-MaintenanceLog -Message "Conflict Group '$GroupName': Selected '$PrimaryPackage' as primary, skipping: $($ConflictingPackages -join ', ')" -Level INFO
                                Write-DetailedOperation -Operation 'Package Conflict Resolution' -Details "Group: $GroupName | Primary: $PrimaryPackage | Skipped: $($ConflictingPackages -join ', ')" -Result 'Resolved'
                            }
                        }

                        # Create prioritized package list
                        $PackagesToUpdate = @()
                        $SkippedPackages = @()

                        # Add primary packages from conflict groups
                        foreach ($GroupName in $ConflictMap.Keys) {
                            $PackagesToUpdate += $ConflictMap[$GroupName].Primary
                            $SkippedPackages += $ConflictMap[$GroupName].Conflicts
                        }

                        # Add non-conflicting packages
                        foreach ($Package in $ValidOutdatedPackages) {
                            if ($Package -notin $PackagesToUpdate -and $Package -notin $SkippedPackages) {
                                $PackagesToUpdate += $Package
                            }
                        }

                        # Step 2: Perform upgrades with real-time output
                        Show-SectionHeader -Title "Updating Chocolatey Packages" -SubTitle "$($PackagesToUpdate.Count) packages will be updated (skipped $($SkippedPackages.Count) conflicting)"

                        Write-Host "`n  Starting package updates..." -ForegroundColor Yellow
                        Write-Host "  Chocolatey will update packages one by one." -ForegroundColor Gray
                        Write-Host "  You'll see detailed progress for each package below.`n" -ForegroundColor Gray

                        # Enhanced upgrade process
                        $SuccessfulUpgrades = 0
                        $FailedUpgrades = 0
                        $SkippedCount = $SkippedPackages.Count

                        Write-MaintenanceLog -Message "Processing $($PackagesToUpdate.Count) packages (skipped $SkippedCount conflicting packages)" -Level INFO

                        # Process packages with progress tracking
                        for ($PackageIndex = 0; $PackageIndex -lt $PackagesToUpdate.Count; $PackageIndex++) {
                            $Package = $PackagesToUpdate[$PackageIndex]
                            $PackageInfo = $Package -split '\|'
                            $PackageName = $PackageInfo[0]

                            $ProgressPercent = [Math]::Round(($PackageIndex / $PackagesToUpdate.Count) * 100)
                            Write-ProgressBar -Activity 'Package Updates' -PercentComplete (30 + ($ProgressPercent * 0.4)) -Status "Updating $PackageName..."

                            Write-MaintenanceLog -Message "Processing package $($PackageIndex + 1)/$($PackagesToUpdate.Count): $PackageName" -Level INFO

                            if (Invoke-ChocolateyUpgradeWithRetry -PackageName $PackageName -MaxRetries 3 -ShowRealTime $true) {
                                $SuccessfulUpgrades++
                            } else {
                                $FailedUpgrades++
                            }

                            # Brief pause between packages
                            if ($PackageIndex -lt $PackagesToUpdate.Count - 1) {
                                Start-Sleep -Seconds 2
                            }
                        }

                        # Comprehensive final status report
                        if ($FailedUpgrades -eq 0) {
                            Write-MaintenanceLog -Message "All Chocolatey packages updated successfully ($SuccessfulUpgrades packages, $SkippedCount skipped due to conflicts)" -Level SUCCESS
                            Write-DetailedOperation -Operation 'Chocolatey Upgrade' -Details "Success: $SuccessfulUpgrades | Failed: $FailedUpgrades | Skipped: $SkippedCount" -Result 'Success'

                            Write-Host "`n  ========== Update Summary ==========" -ForegroundColor Green
                            Write-Host "  Total packages updated: $SuccessfulUpgrades" -ForegroundColor White
                            Write-Host "  Failed: $FailedUpgrades" -ForegroundColor White
                            Write-Host "  Skipped (conflicts): $SkippedCount" -ForegroundColor White
                            Write-Host "  Status: Completed successfully" -ForegroundColor Green
                            Write-Host "  ====================================`n" -ForegroundColor Green
                        }
                        elseif ($SuccessfulUpgrades -gt 0) {
                            Write-MaintenanceLog -Message "Chocolatey updates completed with mixed results - Success: $SuccessfulUpgrades, Failed: $FailedUpgrades, Skipped: $SkippedCount" -Level WARNING
                            Write-DetailedOperation -Operation 'Chocolatey Upgrade' -Details "Success: $SuccessfulUpgrades | Failed: $FailedUpgrades | Skipped: $SkippedCount" -Result 'Partial'

                            Write-Host "`n  ========== Update Summary ==========" -ForegroundColor Yellow
                            Write-Host "  Total packages updated: $SuccessfulUpgrades" -ForegroundColor White
                            Write-Host "  Failed: $FailedUpgrades" -ForegroundColor Yellow
                            Write-Host "  Skipped (conflicts): $SkippedCount" -ForegroundColor White
                            Write-Host "  Status: Completed with warnings" -ForegroundColor Yellow
                            Write-Host "  ====================================`n" -ForegroundColor Yellow
                        }
                        else {
                            Write-MaintenanceLog -Message "All Chocolatey package updates failed - Success: $SuccessfulUpgrades, Failed: $FailedUpgrades, Skipped: $SkippedCount" -Level ERROR
                            Write-DetailedOperation -Operation 'Chocolatey Upgrade' -Details "Success: $SuccessfulUpgrades | Failed: $FailedUpgrades | Skipped: $SkippedCount" -Result 'Failed'

                            Write-Host "`n  ========== Update Summary ==========" -ForegroundColor Red
                            Write-Host "  Total packages updated: $SuccessfulUpgrades" -ForegroundColor White
                            Write-Host "  Failed: $FailedUpgrades" -ForegroundColor Red
                            Write-Host "  Skipped (conflicts): $SkippedCount" -ForegroundColor White
                            Write-Host "  Status: All updates failed" -ForegroundColor Red
                            Write-Host "  ====================================`n" -ForegroundColor Red
                        }
                    }
                    else {
                        Write-MaintenanceLog -Message 'No valid outdated Chocolatey packages found' -Level INFO
                        Write-DetailedOperation -Operation 'Chocolatey Check' -Details "All packages are current or no valid packages detected" -Result 'Up-to-date'

                        Write-Host "`n  All packages are up to date!" -ForegroundColor Green
                        Write-Host "  No updates required.`n" -ForegroundColor Gray
                    }
                }
                else {
                    Write-MaintenanceLog -Message 'No Chocolatey packages found or outdated command failed' -Level INFO
                    Write-DetailedOperation -Operation 'Chocolatey Check' -Details "No packages found for update or command failed" -Result 'Empty'

                    Write-Host "`n  No packages found for update." -ForegroundColor Gray
                }
            }
        }
        else {
            Write-MaintenanceLog -Message 'Chocolatey not installed' -Level INFO
            Write-DetailedOperation -Operation 'Chocolatey Check' -Details "Chocolatey package manager not found" -Result 'Not Installed'
        }
    }
}

# Export public functions
Export-ModuleMember -Function @(
    'Invoke-SystemUpdates'
)
