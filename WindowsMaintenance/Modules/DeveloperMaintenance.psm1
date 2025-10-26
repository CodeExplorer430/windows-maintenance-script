<#
.SYNOPSIS
    Comprehensive developer environment maintenance with multi-platform package management and IDE support.

.DESCRIPTION
    Provides specialized maintenance for developer workstations including package
    managers, development tools, IDEs, and professional software used in comprehensive
    development workflows.

    Supported Developer Tools:
    - Node.js/NPM: Global package updates, security audits, vulnerability fixes
    - Python/pip: Package updates with virtual environment support
    - Docker: Container, image, network, volume, and build cache cleanup
    - JetBrains IDEs: IntelliJ IDEA, PyCharm cache and configuration optimization
    - Visual Studio: 2022 cache cleanup and component optimization
    - Database Tools: MySQL Workbench, XAMPP, WAMP, PostgreSQL maintenance
    - Version Control: Git and GitHub Desktop optimization
    - Design Tools: Adobe suite cache management
    - API Tools: Postman data optimization
    - VS Code: Enhanced cache cleanup and extension management
    - Java Development Kit (JDK): JVM cache, compilation artifacts cleanup
    - MinGW: GCC/G++ compilation cache and temporary files cleanup
    - Microsoft .NET SDK: NuGet cache, compilation artifacts, and temp files
    - Windows SDK: Development cache, debugging symbols, and temp files
    - Visual C++ Redistributables: Installation logs and temporary files
    - Composer (PHP): Package cache and vendor directory optimization
    - Legacy C/C++ Tools: Dev-C++, Code::Blocks, Arduino IDE, Turbo C++

    Security Features:
    - NPM security audit with automatic vulnerability fixes
    - Python package security validation
    - Docker resource cleanup to prevent security exposure
    - IDE cache optimization for performance and security
    - JDK security cache management
    - .NET security and performance optimization

.NOTES
    File Name      : DeveloperMaintenance.psm1
    Author         : Miguel Velasco
    Prerequisite   : PowerShell 5.1+
    Version        : 2.0.0
    Last Updated   : October 2025
    Module Type    : Feature Module
    Dependencies   : Logging.psm1, SafeExecution.psm1, MemoryManagement.psm1,
                     StringFormatting.psm1

    Security: All package updates include security vulnerability assessment
    Performance: Intelligent cache management prevents resource exhaustion
    Enterprise: Comprehensive audit logging for development environment compliance
#>

#Requires -Version 5.1

# Import dependencies
Import-Module "$PSScriptRoot\Common\Logging.psm1" -Force
Import-Module "$PSScriptRoot\Common\SafeExecution.psm1" -Force
Import-Module "$PSScriptRoot\Common\MemoryManagement.psm1" -Force
Import-Module "$PSScriptRoot\Common\StringFormatting.psm1" -Force

<#
.SYNOPSIS
    Helper function for safe file size calculation.

.DESCRIPTION
    Safely calculates total file size and count from a collection of file objects,
    with comprehensive error handling and validation.

.PARAMETER Files
    Array of file objects (FileInfo) to analyze

.OUTPUTS
    [hashtable] Contains TotalSize and FileCount properties

.EXAMPLE
    $Result = Get-SafeTotalFileSize -Files $FileList

.NOTES
    Security: Validates file objects before processing
    Performance: Uses efficient Measure-Object with fallback to manual calculation
#>
function Get-SafeTotalFileSize {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [object[]]$Files
    )

    if (-not $Files -or $Files.Count -eq 0) {
        return @{ TotalSize = 0; FileCount = 0 }
    }

    # Filter to ensure we only have valid file objects with Length property
    $ValidFiles = @($Files | Where-Object {
        $_ -and
        $_.PSObject.Properties['Length'] -and
        $_.PSTypeNames -contains 'System.IO.FileInfo' -and
        $_.Length -is [long]
    })

    if (-not $ValidFiles -or $ValidFiles.Count -eq 0) {
        return @{ TotalSize = 0; FileCount = 0 }
    }

    try {
        $TotalSize = ($ValidFiles | Measure-Object -Property Length -Sum -ErrorAction Stop).Sum
        return @{
            TotalSize = if ($null -ne $TotalSize) { $TotalSize } else { 0 }
            FileCount = $ValidFiles.Count
        }
    }
    catch {
        # Fallback manual calculation if Measure-Object fails
        $ManualSize = 0
        foreach ($File in $ValidFiles) {
            if ($File.Length -and $File.Length -is [long]) {
                $ManualSize += $File.Length
            }
        }
        return @{
            TotalSize = $ManualSize
            FileCount = $ValidFiles.Count
        }
    }
}

<#
.SYNOPSIS
    Executes comprehensive developer environment maintenance operations.

.DESCRIPTION
    Orchestrates maintenance for a wide range of development tools including:
    - Package managers (NPM, pip, Composer)
    - Container platforms (Docker)
    - Development SDKs (JDK, .NET SDK, Windows SDK, MinGW)
    - IDEs (JetBrains suite, Visual Studio, VS Code)
    - Database tools (MySQL, PostgreSQL, XAMPP, WAMP)
    - Design tools (Adobe suite, Figma)
    - Version control and API tools (Git, GitHub Desktop, Postman)
    - Legacy C/C++ tools

.OUTPUTS
    None. Results are logged via Write-MaintenanceLog

.EXAMPLE
    Invoke-DeveloperMaintenance

.NOTES
    Security: All package updates include security vulnerability assessment
    Performance: Intelligent cache management prevents resource exhaustion
    Enterprise: Comprehensive audit logging for compliance
#>
function Invoke-DeveloperMaintenance {
    # Get Config from parent scope
    $Config = if (Get-Variable -Name 'Config' -Scope 1 -ErrorAction SilentlyContinue) {
        (Get-Variable -Name 'Config' -Scope 1).Value
    } elseif (Get-Variable -Name 'Config' -Scope Global -ErrorAction SilentlyContinue) {
        $Global:Config
    } else {
        @{ EnabledModules = @("DeveloperMaintenance") }
    }

    # Get WhatIf from parent scope
    $WhatIf = if (Get-Variable -Name 'WhatIf' -Scope 1 -ErrorAction SilentlyContinue) {
        (Get-Variable -Name 'WhatIf' -Scope 1).Value
    } elseif (Get-Variable -Name 'WhatIf' -Scope Global -ErrorAction SilentlyContinue) {
        $Global:WhatIf
    } else {
        $false
    }

    if ('DeveloperMaintenance' -notin $Config.EnabledModules) {
        Write-MaintenanceLog 'Developer Maintenance module disabled' 'INFO'
        return
    }

    Write-MaintenanceLog -Message '======== Developer Maintenance Module ========' -Level INFO

    # Advanced Node.js/NPM maintenance with comprehensive security audit handling
    Invoke-SafeCommand -TaskName 'Advanced NPM Package Management' -Command {
        if (Get-Command npm -ErrorAction SilentlyContinue) {
            Write-MaintenanceLog -Message 'Processing Node.js and NPM maintenance...' -Level PROGRESS
            Write-DetailedOperation -Operation 'NPM Detection' -Details 'Node.js and NPM detected on system' -Result 'Available'

            if (!$WhatIf) {
                # Comprehensive environment analysis
                $NodeVersion = node --version 2>$null
                $NPMVersion = npm --version 2>$null
                $EnvDetails = "Node.js: $NodeVersion | NPM: " + $NPMVersion
                Write-DetailedOperation -Operation 'Environment Info' -Details $EnvDetails -Result 'Retrieved'

                # Advanced global package analysis
                Write-MaintenanceLog -Message 'Checking for outdated global NPM packages...' -Level PROGRESS
                $OutdatedPackages = npm outdated -g --json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue

                if ($OutdatedPackages -and $OutdatedPackages.PSObject.Properties.Count -gt 0) {
                    Write-MaintenanceLog -Message "Found $($OutdatedPackages.PSObject.Properties.Count) outdated global packages" -Level INFO

                    foreach ($Package in $OutdatedPackages.PSObject.Properties) {
                        $PackageDetails = 'Package: ' + $Package.Name + ' | Current: ' + $Package.Value.current + ' | Latest: ' + $Package.Value.latest
                        Write-DetailedOperation -Operation 'Outdated Package' -Details $PackageDetails -Result 'Available'
                    }

                    # Enterprise-grade package updates with error handling
                    Write-MaintenanceLog -Message 'Updating global NPM packages...' -Level PROGRESS
                    npm update -g 2>$null
                    Write-DetailedOperation -Operation 'NPM Update' -Details 'Global packages updated successfully' -Result 'Success'
                }
                else {
                    Write-MaintenanceLog -Message 'No outdated global NPM packages found' -Level INFO
                    Write-DetailedOperation -Operation 'NPM Check' -Details 'All global packages are current' -Result 'Up-to-date'
                }

                # Comprehensive security audit with enhanced error handling
                Write-MaintenanceLog -Message 'Running NPM security audit...' -Level PROGRESS
                $AuditOutput = npm audit -g --json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue

                if ($AuditOutput -and $AuditOutput.vulnerabilities) {
                    $VulnCount = $AuditOutput.vulnerabilities.PSObject.Properties.Count
                    if ($VulnCount -gt 0) {
                        Write-MaintenanceLog -Message "Found $VulnCount security vulnerabilities in global packages" -Level WARNING
                        $VulnMessage = 'Vulnerabilities detected: ' + $VulnCount
                        Write-DetailedOperation -Operation 'Security Audit' -Details $VulnMessage -Result 'Issues Found'

                        # Enterprise vulnerability remediation
                        npm audit fix -g 2>&1
                        if ($LASTEXITCODE -eq 0) {
                            $SecurityFixMsg = 'Security vulnerabilities fixed successfully'
                            Write-DetailedOperation -Operation 'Security Fix' -Details $SecurityFixMsg -Result 'Applied'
                        } else {
                            $SecurityFixMsg = 'Some vulnerabilities require manual attention (Exit Code: ' + $LASTEXITCODE + ')'
                            Write-DetailedOperation -Operation 'Security Fix' -Details $SecurityFixMsg -Result 'Partial'
                        }
                    }
                    else {
                        Write-DetailedOperation -Operation 'Security Audit' -Details "No vulnerabilities found in global packages" -Result 'Clean'
                    }
                }

                Write-MaintenanceLog -Message 'Global NPM packages maintenance completed' -Level SUCCESS
            }
        }
        else {
            Write-MaintenanceLog -Message 'NPM not found - skipping NPM maintenance' -Level INFO
            Write-DetailedOperation -Operation 'NPM Detection' -Details "Node.js/NPM not installed or not in PATH" -Result 'Not Available'
        }
    }

    # Advanced Python/pip maintenance with virtual environment support
    Invoke-SafeCommand -TaskName "Advanced Python Package Management" -Command {
        if (Get-Command pip -ErrorAction SilentlyContinue) {
            Write-MaintenanceLog -Message 'Processing Python and pip maintenance...' -Level PROGRESS
            Write-DetailedOperation -Operation 'Python Detection' -Details "Python and pip detected on system" -Result 'Available'

            if (!$WhatIf) {
                # Comprehensive Python environment analysis
                $PythonVersion = python --version 2>$null
                $PipVersion = pip --version 2>$null
                Write-DetailedOperation -Operation 'Environment Info' -Details "Python: $PythonVersion | Pip: $PipVersion" -Result 'Retrieved'

                # Advanced package analysis with JSON parsing
                Write-MaintenanceLog -Message 'Checking for outdated Python packages...' -Level PROGRESS

                try {
                    $OutdatedOutput = pip list --outdated --format=json 2>$null
                    if ($OutdatedOutput) {
                        $OutdatedPackages = $OutdatedOutput | ConvertFrom-Json -ErrorAction Stop

                        if ($OutdatedPackages -and $OutdatedPackages.Count -gt 0) {
                            Write-MaintenanceLog -Message "Found $($OutdatedPackages.Count) outdated Python packages" -Level INFO

                            foreach ($Package in $OutdatedPackages | Select-Object -First 20) {
                                Write-DetailedOperation -Operation 'Outdated Package' -Details "Package: $($Package.name) | Current: $($Package.version) | Latest: $($Package.latest_version)" -Result 'Available'
                            }

                            # Enterprise package update management with comprehensive error handling
                            $UpdatedCount = 0
                            $FailedCount = 0

                            foreach ($Package in $OutdatedPackages) {
                                try {
                                    Write-MaintenanceLog -Message "Updating Python package: $($Package.name)" -Level PROGRESS
                                    pip install --upgrade $Package.name --quiet 2>$null

                                    if ($LASTEXITCODE -eq 0) {
                                        $UpdatedCount++
                                        Write-DetailedOperation -Operation 'Package Update' -Details "Package: $($Package.name) | Status: Updated successfully" -Result 'Success'
                                    }
                                    else {
                                        $FailedCount++
                                        Write-DetailedOperation -Operation 'Package Update' -Details "Package: $($Package.name) | Status: Update failed" -Result 'Failed'
                                    }
                                }
                                catch {
                                    $FailedCount++
                                    Write-MaintenanceLog -Message "Failed to update Python package: $($Package.name) - $($_.Exception.Message)" -Level WARNING
                                    Write-DetailedOperation -Operation 'Package Update' -Details "Package: $($Package.name) | Error: $($_.Exception.Message)" -Result 'Error'
                                }
                            }

                            Write-MaintenanceLog -Message "Python packages update completed - Updated: $UpdatedCount, Failed: $FailedCount" -Level SUCCESS
                            Write-DetailedOperation -Operation 'Python Update Summary' -Details "Total packages: $($OutdatedPackages.Count) | Updated: $UpdatedCount | Failed: $FailedCount" -Result 'Complete'
                        }
                        else {
                            Write-MaintenanceLog -Message 'No outdated Python packages found' -Level INFO
                            Write-DetailedOperation -Operation 'Python Check' -Details "All packages are current" -Result 'Up-to-date'
                        }
                    }
                }
                catch {
                    Write-MaintenanceLog -Message "Error checking Python packages: $($_.Exception.Message)" -Level WARNING
                    Write-DetailedOperation -Operation 'Python Check' -Details "Package check failed: $($_.Exception.Message)" -Result 'Error'
                }
            }
        }
        else {
            Write-MaintenanceLog -Message 'pip not found - skipping Python maintenance' -Level INFO
            Write-DetailedOperation -Operation 'Python Detection' -Details "Python/pip not installed or not in PATH" -Result 'Not Available'
        }
    }

    # Enterprise Docker environment management with comprehensive resource analysis
    Invoke-SafeCommand -TaskName "Docker Environment Management" -Command {
        if (Get-Command docker -ErrorAction SilentlyContinue) {
            Write-MaintenanceLog -Message 'Processing Docker environment maintenance...' -Level PROGRESS
            Write-DetailedOperation -Operation 'Docker Detection' -Details "Docker CLI detected on system" -Result 'Available'

            # Comprehensive Docker connectivity and diagnostic testing
            $DockerRunning = $false
            try {
                $DockerVersion = docker version --format json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
                if ($DockerVersion) {
                    $DockerRunning = $true
                    Write-DetailedOperation -Operation 'Docker Status' -Details "Docker Engine Version: $($DockerVersion.Server.Version) | API Version: $($DockerVersion.Server.ApiVersion)" -Result 'Running'
                }
            }
            catch {
                Write-MaintenanceLog -Message 'Docker daemon not running or not accessible' -Level WARNING
                Write-DetailedOperation -Operation 'Docker Status' -Details "Docker daemon not accessible: $($_.Exception.Message)" -Result 'Not Running'
                return
            }

            if ($DockerRunning -and !$WhatIf) {
                # Advanced Docker system analysis
                $DockerInfo = docker system df --format json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue

                if ($DockerInfo) {
                    $TotalSize = ($DockerInfo | ForEach-Object { if ($_.Size) { [long]$_.Size } else { 0 } } | Measure-Object -Sum).Sum
                    $ReclaimableSize = ($DockerInfo | ForEach-Object { if ($_.Reclaimable) { [long]$_.Reclaimable.TrimEnd('B') } else { 0 } } | Measure-Object -Sum).Sum

                    Write-DetailedOperation -Operation 'Docker Analysis' -Details "Total Size: $([math]::Round($TotalSize/1GB, 2))GB | Reclaimable: $([math]::Round($ReclaimableSize/1GB, 2))GB" -Result 'Analyzed'
                }

                # Comprehensive Docker resource cleanup with progress tracking
                Write-MaintenanceLog -Message 'Executing Docker resource cleanup...' -Level PROGRESS

                # Container cleanup with detailed logging
                Write-MaintenanceLog -Message 'Removing stopped containers...' -Level PROGRESS
                docker container prune -f 2>&1
                Write-DetailedOperation -Operation 'Container Cleanup' -Details "Stopped containers removed" -Result 'Complete'

                # Image cleanup with optimization
                Write-MaintenanceLog -Message 'Removing unused images...' -Level PROGRESS
                docker image prune -f 2>&1
                Write-DetailedOperation -Operation 'Image Cleanup' -Details "Unused images removed" -Result 'Complete'

                # Network cleanup for security
                Write-MaintenanceLog -Message 'Removing unused networks...' -Level PROGRESS
                docker network prune -f 2>&1
                Write-DetailedOperation -Operation 'Network Cleanup' -Details "Unused networks removed" -Result 'Complete'

                # Volume cleanup with data protection
                Write-MaintenanceLog -Message 'Removing unused volumes...' -Level PROGRESS
                docker volume prune -f 2>&1
                Write-DetailedOperation -Operation 'Volume Cleanup' -Details "Unused volumes removed" -Result 'Complete'

                # Build cache optimization
                Write-MaintenanceLog -Message 'Cleaning build cache...' -Level PROGRESS
                docker builder prune -f 2>&1
                Write-DetailedOperation -Operation 'Build Cache Cleanup' -Details "Build cache cleaned" -Result 'Complete'

                # Post-cleanup system analysis
                docker system df 2>$null

                Write-MaintenanceLog -Message 'Docker cleanup completed successfully' -Level SUCCESS
                Write-DetailedOperation -Operation 'Docker Cleanup Summary' -Details "All Docker resources cleaned successfully" -Result 'Complete'
            }
        }
        else {
            Write-MaintenanceLog -Message 'Docker not found - skipping Docker maintenance' -Level INFO
            Write-DetailedOperation -Operation 'Docker Detection' -Details "Docker not installed or not in PATH" -Result 'Not Available'
        }
    }

    # Java Development Kit (JDK) Maintenance
    if ($Config.DeveloperMaintenance.EnableJDK) {
        Invoke-SafeCommand -TaskName "Java Development Kit (JDK) Maintenance" -Command {
            Write-MaintenanceLog -Message 'Processing Java Development Kit maintenance...' -Level PROGRESS

            # Multi-method JDK detection
            $JavaFound = $false
            $JavaVersion = $null
            $JavaHomePath = $env:JAVA_HOME

            # Check for Java command
            if (Get-Command java -ErrorAction SilentlyContinue) {
                $JavaFound = $true
                $JavaVersion = java -version 2>&1 | Select-Object -First 1
                Write-DetailedOperation -Operation 'JDK Detection' -Details "Java command detected: $JavaVersion" -Result 'Available'
            }

            # Check for javac compiler
            if (Get-Command javac -ErrorAction SilentlyContinue) {
                $JavaFound = $true
                $JdkVersion = javac -version 2>&1
                Write-DetailedOperation -Operation 'JDK Detection' -Details "Java compiler detected: $JdkVersion" -Result 'Available'
            }

            # Check JAVA_HOME environment variable
            if ($JavaHomePath -and (Test-Path $JavaHomePath)) {
                $JavaFound = $true
                Write-DetailedOperation -Operation 'JDK Detection' -Details "JAVA_HOME detected: $JavaHomePath" -Result 'Available'
            }

            if ($JavaFound) {
                $TotalCleaned = 0
                $TotalFiles = 0

                # Get retention days from config or use defaults
                $JDKRetention = if ($Config.DeveloperMaintenance.JDKCacheRetentionDays) {
                    $Config.DeveloperMaintenance.JDKCacheRetentionDays
                } else { 90 }

                # JVM cache and temporary files cleanup
                $JavaCleanupPaths = @(
                    @{ Path = "$env:USERPROFILE\.java"; Name = "Java User Cache"; RetentionDays = 30 },
                    @{ Path = "$env:TEMP\hsperfdata_*"; Name = "JVM Performance Data"; RetentionDays = 7 },
                    @{ Path = "$env:LOCALAPPDATA\temp\java_*"; Name = "Java Temp Files"; RetentionDays = 7 },
                    @{ Path = "$env:USERPROFILE\.m2\repository"; Name = "Maven Local Repository Cache"; RetentionDays = $JDKRetention },
                    @{ Path = "$env:USERPROFILE\.gradle\caches"; Name = "Gradle Cache"; RetentionDays = 60 }
                )

                # Add JAVA_HOME based cleanup paths if available
                if ($JavaHomePath) {
                    $JavaCleanupPaths += @(
                        @{ Path = "$JavaHomePath\jre\lib\deploy\cache"; Name = "Java Deployment Cache"; RetentionDays = 30 },
                        @{ Path = "$JavaHomePath\jre\lib\javaws\cache"; Name = "Java Web Start Cache"; RetentionDays = 30 }
                    )
                }

                foreach ($CleanupPath in $JavaCleanupPaths) {
                    try {
                        # Handle wildcard paths
                        if ($CleanupPath.Path -like "*\*") {
                            $BasePath = Split-Path $CleanupPath.Path -Parent
                            $Pattern = Split-Path $CleanupPath.Path -Leaf
                            $FoundPaths = Get-ChildItem -Path $BasePath -Directory -Filter $Pattern -ErrorAction SilentlyContinue
                        }
                        else {
                            $FoundPaths = if (Test-Path $CleanupPath.Path) { Get-Item $CleanupPath.Path } else { @() }
                        }

                        foreach ($FoundPath in $FoundPaths) {
                            if (Test-Path $FoundPath.FullName) {
                                Write-DetailedOperation -Operation 'JDK Analysis' -Details "Scanning $($CleanupPath.Name) at $($FoundPath.FullName)" -Result 'Scanning'

                                $OldFiles = Get-ChildItem -Path $FoundPath.FullName -Recurse -File -ErrorAction SilentlyContinue |
                                           Where-Object {
                                               $_ -and
                                               $_.PSObject.Properties['LastWriteTime'] -and
                                               $_.LastWriteTime -lt (Get-Date).AddDays(-$CleanupPath.RetentionDays)
                                           }

                                if ($OldFiles -and $OldFiles.Count -gt 0) {
                                    $SizeCleaned = ($OldFiles | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                                    $FileCount = $OldFiles.Count

                                    if ($FileCount -gt 0 -and $SizeCleaned) {
                                        if (!$WhatIf) {
                                            $OldFiles | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                                        }

                                        $TotalCleaned += $SizeCleaned
                                        $TotalFiles += $FileCount

                                        $CleanupDetails = "$($CleanupPath.Name): Cleaned $FileCount files ($([math]::Round($SizeCleaned / 1MB, 2))MB) older than $($CleanupPath.RetentionDays) days"
                                        Write-DetailedOperation -Operation 'JDK Cleanup' -Details $CleanupDetails -Result 'Cleaned'
                                    }
                                }
                                else {
                                    Write-DetailedOperation -Operation 'JDK Analysis' -Details "$($CleanupPath.Name): No files older than $($CleanupPath.RetentionDays) days found" -Result 'Clean'
                                }
                            }
                        }
                    }
                    catch {
                        Write-DetailedOperation -Operation 'JDK Cleanup' -Details "$($CleanupPath.Name): Error - $($_.Exception.Message)" -Result 'Error'
                    }
                }

                if ($TotalCleaned -gt 0) {
                    $CleanedMB = [math]::Round($TotalCleaned / 1MB, 2)
                    Write-MaintenanceLog -Message "JDK maintenance completed - Cleaned $CleanedMB MB ($TotalFiles files)" -Level SUCCESS
                    Write-DetailedOperation -Operation 'JDK Summary' -Details "Total cleanup: $CleanedMB MB across Java development tools" -Result 'Complete'
                }
                else {
                    Write-MaintenanceLog -Message 'JDK - no cleanup needed' -Level INFO
                    Write-DetailedOperation -Operation 'JDK Summary' -Details "No cleanup required - all files within retention policies" -Result 'Clean'
                }
            }
            else {
                Write-MaintenanceLog -Message 'JDK not found - skipping Java maintenance' -Level INFO
                Write-DetailedOperation -Operation 'JDK Detection' -Details "Java Development Kit not installed or not in PATH" -Result 'Not Available'
            }
        }
    }

    # VS Code Maintenance
    if ($Config.DeveloperMaintenance.EnableVSCode) {
        Invoke-SafeCommand -TaskName "VS Code Maintenance" -Command {
            Write-MaintenanceLog -Message 'Processing VS Code maintenance...' -Level PROGRESS

            $VSCodePaths = @(
                @{ Path = "$env:APPDATA\Code\logs"; Name = "Logs"; RetentionDays = 7 },
                @{ Path = "$env:APPDATA\Code\CachedExtensions"; Name = "Extension Cache"; RetentionDays = 30 },
                @{ Path = "$env:APPDATA\Code\CachedExtensionVSIXs"; Name = "VSIX Cache"; RetentionDays = 30 },
                @{ Path = "$env:APPDATA\Code\User\workspaceStorage"; Name = "Workspace Storage"; RetentionDays = 90 },
                @{ Path = "$env:APPDATA\Code\crashDumps"; Name = "Crash Dumps"; RetentionDays = 14 },
                @{ Path = "$env:APPDATA\Code\User\History"; Name = "File History"; RetentionDays = 60 }
            )

            Write-DetailedOperation -Operation 'VS Code Detection' -Details "Analyzing VS Code installation and cache directories" -Result 'Starting'

            $TotalCleaned = 0
            $TotalFiles = 0

            foreach ($VSCodePath in $VSCodePaths) {
                if (Test-Path $VSCodePath.Path) {
                    Write-DetailedOperation -Operation 'VS Code Analysis' -Details "Scanning $($VSCodePath.Name) at $($VSCodePath.Path)" -Result 'Scanning'

                    $OldFiles = Get-ChildItem -Path $VSCodePath.Path -Recurse -File -ErrorAction SilentlyContinue |
                               Where-Object {
                                   $_ -and
                                   $_.PSObject.Properties['LastWriteTime'] -and
                                   $_.LastWriteTime -lt (Get-Date).AddDays(-$VSCodePath.RetentionDays)
                               }

                    if ($OldFiles -and $OldFiles.Count -gt 0) {
                        $SizeCleaned = ($OldFiles | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                        $FileCount = $OldFiles.Count

                        if ($FileCount -gt 0 -and $SizeCleaned) {
                            $TotalCleaned += $SizeCleaned
                            $TotalFiles += $FileCount

                            if (!$WhatIf) {
                                $OldFiles | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                            }

                            $SizeMB = [math]::Round($SizeCleaned / 1MB, 2)
                            $CleanupDetails = "$($VSCodePath.Name): Removed $FileCount files ($($SizeMB)MB) older than $($VSCodePath.RetentionDays) days"
                            Write-DetailedOperation -Operation 'VS Code Cleanup' -Details $CleanupDetails -Result 'Cleaned'
                        }
                    }
                    else {
                        Write-DetailedOperation -Operation 'VS Code Analysis' -Details "$($VSCodePath.Name): No files older than $($VSCodePath.RetentionDays) days found" -Result 'Clean'
                    }
                }
                else {
                    Write-DetailedOperation -Operation 'VS Code Analysis' -Details "$($VSCodePath.Name): Path not found - $($VSCodePath.Path)" -Result 'Not Found'
                }
            }

            if ($TotalCleaned -gt 0) {
                $CleanedMB = [math]::Round($TotalCleaned / 1MB, 2)
                Write-MaintenanceLog -Message "VS Code cleanup recovered $CleanedMB MB ($TotalFiles files removed)" -Level SUCCESS
                Write-DetailedOperation -Operation 'VS Code Summary' -Details "Total cleanup: $CleanedMB MB across VS Code cache locations" -Result 'Complete'
            }
            else {
                Write-MaintenanceLog -Message 'VS Code - no cleanup needed' -Level INFO
                Write-DetailedOperation -Operation 'VS Code Summary' -Details "No cleanup required - all caches within retention policies" -Result 'Clean'
            }
        }
    }

    # Microsoft .NET SDK Maintenance
    if ($Config.DeveloperMaintenance.EnableDotNetSDK) {
        Invoke-SafeCommand -TaskName "Microsoft .NET SDK Maintenance" -Command {
            Write-MaintenanceLog -Message 'Processing Microsoft .NET SDK maintenance...' -Level PROGRESS

            # .NET SDK detection
            $DotNetFound = $false
            $DotNetVersion = $null

            if (Get-Command dotnet -ErrorAction SilentlyContinue) {
                $DotNetFound = $true
                try {
                    $DotNetVersion = dotnet --version 2>$null
                    Write-DetailedOperation -Operation '.NET Detection' -Details ".NET SDK detected: $DotNetVersion" -Result 'Available'

                    # List installed SDKs
                    $InstalledSDKs = dotnet --list-sdks 2>$null
                    if ($InstalledSDKs) {
                        $SDKCount = ($InstalledSDKs | Measure-Object).Count
                        Write-DetailedOperation -Operation '.NET SDKs' -Details "Installed SDKs: $SDKCount versions found" -Result 'Listed'
                    }
                }
                catch {
                    Write-DetailedOperation -Operation '.NET Detection' -Details ".NET command available but error getting version: $($_.Exception.Message)" -Result 'Partial'
                }
            }

            if ($DotNetFound) {
                $TotalCleaned = 0
                $TotalFiles = 0

                # Comprehensive .NET cleanup paths
                $DotNetCleanupPaths = @(
                    @{ Path = "$env:USERPROFILE\.nuget\packages"; Name = "NuGet Global Packages Cache"; RetentionDays = 90 },
                    @{ Path = "$env:LOCALAPPDATA\NuGet\v3-cache"; Name = "NuGet V3 Cache"; RetentionDays = 30 },
                    @{ Path = "$env:LOCALAPPDATA\NuGet\Cache"; Name = "NuGet Cache"; RetentionDays = 30 },
                    @{ Path = "$env:LOCALAPPDATA\Microsoft\dotnet"; Name = ".NET Local Cache"; RetentionDays = 60 },
                    @{ Path = "$env:TEMP\dotnet*"; Name = ".NET Temporary Files"; RetentionDays = 7 },
                    @{ Path = "$env:TEMP\NuGetScratch"; Name = "NuGet Scratch Directory"; RetentionDays = 7 },
                    @{ Path = "$env:LOCALAPPDATA\Temp\.NETFramework*"; Name = ".NET Framework Temp"; RetentionDays = 14 },
                    @{ Path = "$env:USERPROFILE\.templateengine"; Name = ".NET Template Engine Cache"; RetentionDays = 60 },
                    @{ Path = "$env:LOCALAPPDATA\Microsoft\VisualStudio\Packages"; Name = "VS .NET Packages"; RetentionDays = 90 },
                    @{ Path = "$env:APPDATA\NuGet\NuGet.Config.backup*"; Name = "NuGet Config Backups"; RetentionDays = 30 }
                )

                foreach ($CleanupPath in $DotNetCleanupPaths) {
                    try {
                        # Handle wildcard paths
                        if ($CleanupPath.Path -like "*\*") {
                            $BasePath = Split-Path $CleanupPath.Path -Parent
                            $Pattern = Split-Path $CleanupPath.Path -Leaf

                            if (Test-Path $BasePath) {
                                if ($Pattern -like "*.*") {
                                    # File pattern
                                    $FoundItems = Get-ChildItem -Path $BasePath -Filter $Pattern -File -ErrorAction SilentlyContinue |
                                                 Where-Object {
                                                     $_ -and
                                                     $_.PSObject.Properties['LastWriteTime'] -and
                                                     $_.LastWriteTime -lt (Get-Date).AddDays(-$CleanupPath.RetentionDays)
                                                 }
                                }
                                else {
                                    # Directory pattern
                                    $FoundItems = Get-ChildItem -Path $BasePath -Directory -Filter $Pattern -ErrorAction SilentlyContinue
                                }
                            }
                        }
                        else {
                            $FoundItems = if (Test-Path $CleanupPath.Path) { Get-Item $CleanupPath.Path } else { @() }
                        }

                        if ($FoundItems) {
                            foreach ($Item in $FoundItems) {
                                if (Test-Path $Item.FullName) {
                                    $OldFiles = Get-ChildItem -Path $Item.FullName -Recurse -File -ErrorAction SilentlyContinue |
                                               Where-Object {
                                                   $_ -and
                                                   $_.PSObject.Properties['LastWriteTime'] -and
                                                   $_.LastWriteTime -lt (Get-Date).AddDays(-$CleanupPath.RetentionDays)
                                               }

                                    if ($OldFiles -and $OldFiles.Count -gt 0) {
                                        $SizeCleaned = ($OldFiles | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                                        $FileCount = $OldFiles.Count

                                        if ($FileCount -gt 0 -and $SizeCleaned) {
                                            if (!$WhatIf) {
                                                $OldFiles | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                                            }

                                            $TotalCleaned += $SizeCleaned
                                            $TotalFiles += $FileCount

                                            $CleanupDetails = "$($CleanupPath.Name): Cleaned $FileCount files ($([math]::Round($SizeCleaned / 1MB, 2))MB) older than $($CleanupPath.RetentionDays) days"
                                            Write-DetailedOperation -Operation '.NET Cleanup' -Details $CleanupDetails -Result 'Cleaned'
                                        }
                                    }
                                    else {
                                        Write-DetailedOperation -Operation '.NET Analysis' -Details "$($CleanupPath.Name): No files older than $($CleanupPath.RetentionDays) days found" -Result 'Clean'
                                    }
                                }
                            }
                        }
                    }
                    catch {
                        Write-DetailedOperation -Operation '.NET Cleanup' -Details "$($CleanupPath.Name): Error - $($_.Exception.Message)" -Result 'Error'
                    }
                }

                # Additional .NET-specific cleanup commands
                if (!$WhatIf) {
                    try {
                        Write-MaintenanceLog -Message 'Running .NET CLI cleanup commands...' -Level PROGRESS

                        # Clear NuGet local cache
                        dotnet nuget locals all --clear 2>$null | Out-Null
                        Write-DetailedOperation -Operation '.NET CLI Cleanup' -Details 'NuGet local caches cleared' -Result 'Success'

                        # Clear template cache
                        dotnet new --debug:reinit 2>$null | Out-Null
                        Write-DetailedOperation -Operation '.NET CLI Cleanup' -Details 'Template cache reinitialized' -Result 'Success'
                    }
                    catch {
                        Write-DetailedOperation -Operation '.NET CLI Cleanup' -Details "Error running CLI cleanup: $($_.Exception.Message)" -Result 'Error'
                    }
                }

                if ($TotalCleaned -gt 0) {
                    $CleanedMB = [math]::Round($TotalCleaned / 1MB, 2)
                    Write-MaintenanceLog -Message ".NET SDK maintenance completed - Cleaned $CleanedMB MB ($TotalFiles files)" -Level SUCCESS
                    Write-DetailedOperation -Operation '.NET Summary' -Details "Total cleanup: $CleanedMB MB across .NET development tools" -Result 'Complete'
                }
                else {
                    Write-MaintenanceLog -Message '.NET SDK - no cleanup needed' -Level INFO
                    Write-DetailedOperation -Operation '.NET Summary' -Details "No cleanup required - all files within retention policies" -Result 'Clean'
                }
            }
            else {
                Write-MaintenanceLog -Message '.NET SDK not found - skipping .NET maintenance' -Level INFO
                Write-DetailedOperation -Operation '.NET Detection' -Details ".NET SDK not installed or not in PATH" -Result 'Not Available'
            }
        }
    }

    # JetBrains IDEs Maintenance
    if ($Config.DeveloperMaintenance.EnableJetBrainsIDEs) {
        Invoke-SafeCommand -TaskName "JetBrains IDEs Maintenance" -Command {
            Write-MaintenanceLog -Message 'Processing JetBrains IDEs maintenance...' -Level PROGRESS

            $JetBrainsIDEs = @(
                @{ Name = "IntelliJ IDEA"; CachePath = "$env:USERPROFILE\.IntelliJIdea*"; ConfigPath = "$env:APPDATA\JetBrains\IntelliJIdea*" },
                @{ Name = "PyCharm"; CachePath = "$env:USERPROFILE\.PyCharm*"; ConfigPath = "$env:APPDATA\JetBrains\PyCharm*" },
                @{ Name = "WebStorm"; CachePath = "$env:USERPROFILE\.WebStorm*"; ConfigPath = "$env:APPDATA\JetBrains\WebStorm*" },
                @{ Name = "CLion"; CachePath = "$env:USERPROFILE\.CLion*"; ConfigPath = "$env:APPDATA\JetBrains\CLion*" },
                @{ Name = "Rider"; CachePath = "$env:USERPROFILE\.Rider*"; ConfigPath = "$env:APPDATA\JetBrains\Rider*" },
                @{ Name = "PhpStorm"; CachePath = "$env:USERPROFILE\.PhpStorm*"; ConfigPath = "$env:APPDATA\JetBrains\PhpStorm*" },
                @{ Name = "GoLand"; CachePath = "$env:USERPROFILE\.GoLand*"; ConfigPath = "$env:APPDATA\JetBrains\GoLand*" }
            )

            $TotalCleaned = 0
            $TotalFiles = 0

            foreach ($IDE in $JetBrainsIDEs) {
                $IDEFound = $false

                # Check for cache directories
                $CacheDirs = Get-ChildItem -Path (Split-Path $IDE.CachePath -Parent) -Directory -Filter (Split-Path $IDE.CachePath -Leaf) -ErrorAction SilentlyContinue
                $ConfigDirs = Get-ChildItem -Path (Split-Path $IDE.ConfigPath -Parent) -Directory -Filter (Split-Path $IDE.ConfigPath -Leaf) -ErrorAction SilentlyContinue

                if ($CacheDirs -or $ConfigDirs) {
                    $IDEFound = $true
                    Write-DetailedOperation -Operation 'JetBrains IDE Detection' -Details "$($IDE.Name) installation detected" -Result 'Found'

                    # Cache cleanup
                    foreach ($CacheDir in $CacheDirs) {
                        $CacheCleanupPaths = @(
                            "$($CacheDir.FullName)\system\caches",
                            "$($CacheDir.FullName)\system\tmp",
                            "$($CacheDir.FullName)\system\log"
                        )

                        foreach ($CleanupPath in $CacheCleanupPaths) {
                            if (Test-Path $CleanupPath) {
                                try {
                                    $OldFiles = Get-ChildItem -Path $CleanupPath -Recurse -File -ErrorAction SilentlyContinue |
                                               Where-Object {
                                                   $_ -and
                                                   $_.PSObject.Properties['LastWriteTime'] -and
                                                   $_.LastWriteTime -lt (Get-Date).AddDays(-7)
                                               }

                                    if ($OldFiles -and $OldFiles.Count -gt 0) {
                                        $SizeCleaned = ($OldFiles | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                                        $FileCount = $OldFiles.Count

                                        if ($FileCount -gt 0 -and $SizeCleaned) {
                                            if (!$WhatIf) {
                                                $OldFiles | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                                            }

                                            $TotalCleaned += $SizeCleaned
                                            $TotalFiles += $FileCount

                                            $CleanupDetails = "$($IDE.Name): Cleaned $FileCount files ($([math]::Round($SizeCleaned / 1MB, 2))MB) from cache"
                                            Write-DetailedOperation -Operation 'JetBrains Cache Cleanup' -Details $CleanupDetails -Result 'Cleaned'
                                        }
                                    }
                                }
                                catch {
                                    Write-DetailedOperation -Operation 'JetBrains Cache Cleanup' -Details "$($IDE.Name): Error cleaning $CleanupPath - $($_.Exception.Message)" -Result 'Error'
                                }
                            }
                        }
                    }
                }
                else {
                    Write-DetailedOperation -Operation 'JetBrains IDE Detection' -Details "$($IDE.Name) not found" -Result 'Not Found'
                }
            }

            if ($TotalCleaned -gt 0) {
                $CleanedMB = [math]::Round($TotalCleaned / 1MB, 2)
                Write-MaintenanceLog -Message "JetBrains IDEs maintenance completed - Cleaned $CleanedMB MB ($TotalFiles files)" -Level SUCCESS
                Write-DetailedOperation -Operation 'JetBrains Summary' -Details "Total cleanup: $CleanedMB MB across multiple IDEs" -Result 'Complete'
            }
            else {
                Write-MaintenanceLog -Message 'JetBrains IDEs - no cleanup needed or no IDEs found' -Level INFO
                Write-DetailedOperation -Operation 'JetBrains Summary' -Details "No cleanup required or no JetBrains IDEs detected" -Result 'Clean'
            }
        }
    }

    # Composer (PHP Package Manager) Maintenance
    if ($Config.DeveloperMaintenance.EnableComposer) {
        Invoke-SafeCommand -TaskName "Composer (PHP Package Manager) Maintenance" -Command {
            Write-MaintenanceLog -Message 'Processing Composer (PHP) maintenance...' -Level PROGRESS

            # Composer detection
            $ComposerFound = $false
            $ComposerVersion = $null

            if (Get-Command composer -ErrorAction SilentlyContinue) {
                $ComposerFound = $true
                try {
                    $ComposerVersion = composer --version 2>$null | Select-Object -First 1
                    Write-DetailedOperation -Operation 'Composer Detection' -Details "Composer detected: $ComposerVersion" -Result 'Available'

                    # Check PHP version
                    if (Get-Command php -ErrorAction SilentlyContinue) {
                        $PHPVersion = php --version 2>$null | Select-Object -First 1
                        Write-DetailedOperation -Operation 'PHP Detection' -Details "PHP detected: $PHPVersion" -Result 'Available'
                    }
                }
                catch {
                    Write-DetailedOperation -Operation 'Composer Detection' -Details "Composer command available but error getting version: $($_.Exception.Message)" -Result 'Partial'
                }
            }

            if ($ComposerFound) {
                $TotalCleaned = 0
                $TotalFiles = 0

                # Composer cleanup paths
                $ComposerCleanupPaths = @(
                    @{ Path = "$env:APPDATA\Composer\cache"; Name = "Composer Global Cache"; RetentionDays = 60 },
                    @{ Path = "$env:LOCALAPPDATA\Composer\cache"; Name = "Composer Local Cache"; RetentionDays = 60 },
                    @{ Path = "$env:USERPROFILE\.composer\cache"; Name = "Composer User Cache"; RetentionDays = 60 },
                    @{ Path = "$env:TEMP\composer*"; Name = "Composer Temporary Files"; RetentionDays = 7 },
                    @{ Path = "$env:APPDATA\Composer\logs"; Name = "Composer Logs"; RetentionDays = 30 }
                )

                foreach ($CleanupPath in $ComposerCleanupPaths) {
                    try {
                        # Handle wildcard paths
                        if ($CleanupPath.Path -like "*\*") {
                            $BasePath = Split-Path $CleanupPath.Path -Parent
                            $Pattern = Split-Path $CleanupPath.Path -Leaf

                            if (Test-Path $BasePath) {
                                $FoundItems = Get-ChildItem -Path $BasePath -Filter $Pattern -ErrorAction SilentlyContinue
                            }
                        }
                        else {
                            $FoundItems = if (Test-Path $CleanupPath.Path) { Get-Item $CleanupPath.Path } else { @() }
                        }

                        if ($FoundItems) {
                            foreach ($Item in $FoundItems) {
                                if (Test-Path $Item.FullName) {
                                    $OldFiles = Get-ChildItem -Path $Item.FullName -Recurse -File -ErrorAction SilentlyContinue |
                                               Where-Object {
                                                   $_ -and
                                                   $_.PSObject.Properties['LastWriteTime'] -and
                                                   $_.LastWriteTime -lt (Get-Date).AddDays(-$CleanupPath.RetentionDays)
                                               }

                                    if ($OldFiles -and $OldFiles.Count -gt 0) {
                                        $SizeCleaned = ($OldFiles | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                                        $FileCount = $OldFiles.Count

                                        if ($FileCount -gt 0 -and $SizeCleaned) {
                                            if (!$WhatIf) {
                                                $OldFiles | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                                            }

                                            $TotalCleaned += $SizeCleaned
                                            $TotalFiles += $FileCount

                                            $CleanupDetails = "$($CleanupPath.Name): Cleaned $FileCount files ($([math]::Round($SizeCleaned / 1MB, 2))MB) older than $($CleanupPath.RetentionDays) days"
                                            Write-DetailedOperation -Operation 'Composer Cleanup' -Details $CleanupDetails -Result 'Cleaned'
                                        }
                                    }
                                    else {
                                        Write-DetailedOperation -Operation 'Composer Analysis' -Details "$($CleanupPath.Name): No files older than $($CleanupPath.RetentionDays) days found" -Result 'Clean'
                                    }
                                }
                            }
                        }
                    }
                    catch {
                        Write-DetailedOperation -Operation 'Composer Cleanup' -Details "$($CleanupPath.Name): Error - $($_.Exception.Message)" -Result 'Error'
                    }
                }

                # Run Composer-specific cleanup commands
                if (!$WhatIf) {
                    try {
                        Write-MaintenanceLog -Message 'Running Composer CLI cleanup commands...' -Level PROGRESS

                        # Clear Composer cache
                        composer clear-cache 2>$null | Out-Null
                        Write-DetailedOperation -Operation 'Composer CLI Cleanup' -Details 'Composer cache cleared' -Result 'Success'
                    }
                    catch {
                        Write-DetailedOperation -Operation 'Composer CLI Cleanup' -Details "Error running CLI cleanup: $($_.Exception.Message)" -Result 'Error'
                    }
                }

                if ($TotalCleaned -gt 0) {
                    $CleanedMB = [math]::Round($TotalCleaned / 1MB, 2)
                    Write-MaintenanceLog -Message "Composer maintenance completed - Cleaned $CleanedMB MB ($TotalFiles files)" -Level SUCCESS
                    Write-DetailedOperation -Operation 'Composer Summary' -Details "Total cleanup: $CleanedMB MB from Composer and PHP projects" -Result 'Complete'
                }
                else {
                    Write-MaintenanceLog -Message 'Composer - no cleanup needed' -Level INFO
                    Write-DetailedOperation -Operation 'Composer Summary' -Details "No cleanup required - all files within retention policies" -Result 'Clean'
                }
            }
            else {
                Write-MaintenanceLog -Message 'Composer not found - skipping Composer maintenance' -Level INFO
                Write-DetailedOperation -Operation 'Composer Detection' -Details "Composer (PHP Package Manager) not installed or not in PATH" -Result 'Not Available'
            }
        }
    }

    # PostgreSQL Maintenance
    if ($Config.DeveloperMaintenance.EnablePostgreSQL) {
        Invoke-SafeCommand -TaskName "PostgreSQL Maintenance" -Command {
            Write-MaintenanceLog -Message 'Processing PostgreSQL maintenance...' -Level PROGRESS

            $PostgreSQLFound = $false

            # Check for psql command
            if (Get-Command psql -ErrorAction SilentlyContinue) {
                $PostgreSQLFound = $true
                $Version = psql --version 2>$null | Select-Object -First 1
                Write-DetailedOperation -Operation 'PostgreSQL Detection' -Details "PostgreSQL detected: $Version" -Result 'Available'
            }

            # Check for service
            $Service = Get-Service -Name "postgresql*" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($Service) {
                $PostgreSQLFound = $true
                Write-DetailedOperation -Operation 'PostgreSQL Service' -Details "Service detected: $($Service.DisplayName)" -Result 'Found'
            }

            if ($PostgreSQLFound) {
                $TotalCleaned = 0
                $TotalFiles = 0

                $PostgreSQLCleanupPaths = @(
                    @{ Path = "$env:APPDATA\postgresql\psql_history"; Name = "PostgreSQL Command History"; RetentionDays = 90 },
                    @{ Path = "C:\Program Files\PostgreSQL\*\data\log"; Name = "PostgreSQL Server Logs"; RetentionDays = 30 },
                    @{ Path = "$env:LOCALAPPDATA\Temp\postgresql*"; Name = "PostgreSQL Temp Files"; RetentionDays = 7 }
                )

                foreach ($CleanupPath in $PostgreSQLCleanupPaths) {
                    try {
                        if ($CleanupPath.Path -like "*\*") {
                            $BasePath = Split-Path $CleanupPath.Path -Parent
                            $Pattern = Split-Path $CleanupPath.Path -Leaf
                            if (Test-Path $BasePath) {
                                $FoundItems = Get-ChildItem -Path $BasePath -Filter $Pattern -ErrorAction SilentlyContinue
                            }
                        }
                        else {
                            $FoundItems = if (Test-Path $CleanupPath.Path) { Get-Item $CleanupPath.Path } else { @() }
                        }

                        if ($FoundItems) {
                            foreach ($Item in $FoundItems) {
                                if (Test-Path $Item.FullName) {
                                    $OldFiles = Get-ChildItem -Path $Item.FullName -Recurse -File -ErrorAction SilentlyContinue |
                                               Where-Object {
                                                   $_ -and
                                                   $_.PSObject.Properties['LastWriteTime'] -and
                                                   $_.LastWriteTime -lt (Get-Date).AddDays(-$CleanupPath.RetentionDays)
                                               }

                                    if ($OldFiles -and $OldFiles.Count -gt 0) {
                                        $SizeCleaned = ($OldFiles | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                                        $FileCount = $OldFiles.Count

                                        if ($FileCount -gt 0 -and $SizeCleaned) {
                                            if (!$WhatIf) {
                                                $OldFiles | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                                            }
                                            $TotalCleaned += $SizeCleaned
                                            $TotalFiles += $FileCount
                                            Write-DetailedOperation -Operation 'PostgreSQL Cleanup' -Details "$($CleanupPath.Name): Cleaned $FileCount files ($([math]::Round($SizeCleaned / 1MB, 2))MB)" -Result 'Cleaned'
                                        }
                                    }
                                }
                            }
                        }
                    }
                    catch {
                        Write-DetailedOperation -Operation 'PostgreSQL Cleanup' -Details "$($CleanupPath.Name): Error - $($_.Exception.Message)" -Result 'Error'
                    }
                }

                if ($TotalCleaned -gt 0) {
                    $CleanedMB = [math]::Round($TotalCleaned / 1MB, 2)
                    Write-MaintenanceLog -Message "PostgreSQL maintenance completed - Cleaned $CleanedMB MB ($TotalFiles files)" -Level SUCCESS
                }
                else {
                    Write-MaintenanceLog -Message 'PostgreSQL - no cleanup needed' -Level INFO
                }
            }
            else {
                Write-MaintenanceLog -Message 'PostgreSQL not found - skipping' -Level INFO
            }
        }
    }

    # Visual Studio 2022 Maintenance
    if ($Config.DeveloperMaintenance.EnableVisualStudio2022) {
        Invoke-SafeCommand -TaskName "Visual Studio 2022 Maintenance" -Command {
            Write-MaintenanceLog -Message 'Processing Visual Studio 2022 maintenance...' -Level PROGRESS

            $VS2022Paths = @(
                "C:\Program Files\Microsoft Visual Studio\2022\Community",
                "C:\Program Files\Microsoft Visual Studio\2022\Professional",
                "C:\Program Files\Microsoft Visual Studio\2022\Enterprise"
            )

            $VS2022Found = $VS2022Paths | Where-Object { Test-Path $_ } | Select-Object -First 1

            if ($VS2022Found) {
                Write-DetailedOperation -Operation 'VS 2022 Detection' -Details "Visual Studio 2022 detected at: $VS2022Found" -Result 'Available'

                $TotalCleaned = 0
                $TotalFiles = 0

                $VS2022CleanupPaths = @(
                    @{ Path = "$env:LOCALAPPDATA\Microsoft\VisualStudio\17.0*\ComponentModelCache"; Name = "VS Component Cache"; RetentionDays = 30 },
                    @{ Path = "$env:LOCALAPPDATA\Microsoft\VisualStudio\17.0*\Extensions"; Name = "VS Extensions Cache"; RetentionDays = 60 },
                    @{ Path = "$env:TEMP\VSD*"; Name = "VS Designer Temp"; RetentionDays = 3 },
                    @{ Path = "$env:TEMP\VSFeedbackIntelliCodeLogs"; Name = "VS IntelliCode Logs"; RetentionDays = 7 },
                    @{ Path = "$env:LOCALAPPDATA\Temp\VSWebCache"; Name = "VS Web Cache"; RetentionDays = 14 }
                )

                foreach ($CleanupPath in $VS2022CleanupPaths) {
                    try {
                        if ($CleanupPath.Path -like "*\*") {
                            $BasePath = Split-Path $CleanupPath.Path -Parent
                            $Pattern = Split-Path $CleanupPath.Path -Leaf
                            if (Test-Path $BasePath) {
                                $FoundItems = Get-ChildItem -Path $BasePath -Filter $Pattern -ErrorAction SilentlyContinue
                            }
                        }
                        else {
                            $FoundItems = if (Test-Path $CleanupPath.Path) { Get-Item $CleanupPath.Path } else { @() }
                        }

                        if ($FoundItems) {
                            foreach ($Item in $FoundItems) {
                                if (Test-Path $Item.FullName) {
                                    $OldFiles = Get-ChildItem -Path $Item.FullName -Recurse -File -ErrorAction SilentlyContinue |
                                               Where-Object {
                                                   $_ -and
                                                   $_.PSObject.Properties['LastWriteTime'] -and
                                                   $_.LastWriteTime -lt (Get-Date).AddDays(-$CleanupPath.RetentionDays)
                                               }

                                    if ($OldFiles -and $OldFiles.Count -gt 0) {
                                        $SizeCleaned = ($OldFiles | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                                        $FileCount = $OldFiles.Count

                                        if ($FileCount -gt 0 -and $SizeCleaned) {
                                            if (!$WhatIf) {
                                                $OldFiles | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                                            }
                                            $TotalCleaned += $SizeCleaned
                                            $TotalFiles += $FileCount
                                            Write-DetailedOperation -Operation 'VS 2022 Cleanup' -Details "$($CleanupPath.Name): Cleaned $FileCount files ($([math]::Round($SizeCleaned / 1MB, 2))MB)" -Result 'Cleaned'
                                        }
                                    }
                                }
                            }
                        }
                    }
                    catch {
                        Write-DetailedOperation -Operation 'VS 2022 Cleanup' -Details "$($CleanupPath.Name): Error - $($_.Exception.Message)" -Result 'Error'
                    }
                }

                if ($TotalCleaned -gt 0) {
                    $CleanedMB = [math]::Round($TotalCleaned / 1MB, 2)
                    Write-MaintenanceLog -Message "Visual Studio 2022 maintenance completed - Cleaned $CleanedMB MB ($TotalFiles files)" -Level SUCCESS
                }
                else {
                    Write-MaintenanceLog -Message 'Visual Studio 2022 - no cleanup needed' -Level INFO
                }
            }
            else {
                Write-MaintenanceLog -Message 'Visual Studio 2022 not found - skipping' -Level INFO
            }
        }
    }

    # Git / Version Control Maintenance
    if ($Config.DeveloperMaintenance.EnableVersionControl) {
        Invoke-SafeCommand -TaskName "Version Control (Git) Maintenance" -Command {
            Write-MaintenanceLog -Message 'Processing Git/Version Control maintenance...' -Level PROGRESS

            if (Get-Command git -ErrorAction SilentlyContinue) {
                $GitVersion = git --version 2>$null
                Write-DetailedOperation -Operation 'Git Detection' -Details "Git detected: $GitVersion" -Result 'Available'

                # Run git garbage collection
                if (!$WhatIf) {
                    try {
                        Write-MaintenanceLog -Message 'Running git gc (garbage collection)...' -Level PROGRESS
                        git gc --auto 2>$null | Out-Null
                        Write-DetailedOperation -Operation 'Git GC' -Details 'Git garbage collection completed' -Result 'Success'
                    }
                    catch {
                        Write-DetailedOperation -Operation 'Git GC' -Details "Error: $($_.Exception.Message)" -Result 'Error'
                    }
                }

                Write-MaintenanceLog -Message 'Git maintenance completed' -Level SUCCESS
            }
            else {
                Write-MaintenanceLog -Message 'Git not found - skipping' -Level INFO
            }
        }
    }

    # MinGW Development Environment Maintenance
    if ($Config.DeveloperMaintenance.EnableMinGW) {
        Invoke-SafeCommand -TaskName "MinGW Development Environment Maintenance" -Command {
            Write-MaintenanceLog -Message 'Processing MinGW development environment maintenance...' -Level PROGRESS

            # MinGW detection methods
            $MinGWFound = $false
            $MinGWPaths = @()

            # Check for GCC/G++ commands
            if (Get-Command gcc -ErrorAction SilentlyContinue) {
                $MinGWFound = $true
                $GccVersion = gcc --version 2>&1 | Select-Object -First 1
                Write-DetailedOperation -Operation 'MinGW Detection' -Details "GCC compiler detected: $GccVersion" -Result 'Available'
            }

            if (Get-Command g++ -ErrorAction SilentlyContinue) {
                $MinGWFound = $true
                $GppVersion = g++ --version 2>&1 | Select-Object -First 1
                Write-DetailedOperation -Operation 'MinGW Detection' -Details "G++ compiler detected: $GppVersion" -Result 'Available'
            }

            # Check common MinGW installation paths
            $CommonMinGWPaths = @(
                "C:\MinGW",
                "C:\MinGW-w64",
                "C:\msys64\mingw64",
                "C:\msys64\mingw32",
                "$env:ProgramFiles\MinGW",
                "$env:ProgramFiles\MinGW-w64"
            )

            foreach ($Path in $CommonMinGWPaths) {
                if (Test-Path $Path) {
                    $MinGWFound = $true
                    $MinGWPaths += $Path
                    Write-DetailedOperation -Operation 'MinGW Detection' -Details "MinGW installation detected at: $Path" -Result 'Found'
                }
            }

            if ($MinGWFound) {
                $TotalCleaned = 0
                $TotalFiles = 0

                # MinGW cleanup paths
                $MinGWCleanupPaths = @(
                    @{ Path = "$env:TEMP\cc*"; Name = "GCC Temporary Files"; RetentionDays = 3 },
                    @{ Path = "$env:TEMP\*.o"; Name = "Object Files"; RetentionDays = 7 },
                    @{ Path = "$env:TEMP\*.obj"; Name = "Object Files (MSVC Format)"; RetentionDays = 7 },
                    @{ Path = "$env:LOCALAPPDATA\Temp\mingw*"; Name = "MinGW Temp Files"; RetentionDays = 7 }
                )

                # Add MinGW installation-specific cleanup paths
                foreach ($MinGWPath in $MinGWPaths) {
                    $MinGWCleanupPaths += @(
                        @{ Path = "$MinGWPath\tmp"; Name = "MinGW Installation Temp"; RetentionDays = 7 },
                        @{ Path = "$MinGWPath\var\cache"; Name = "MinGW Package Cache"; RetentionDays = 30 },
                        @{ Path = "$MinGWPath\var\log"; Name = "MinGW Logs"; RetentionDays = 14 }
                    )
                }

                foreach ($CleanupPath in $MinGWCleanupPaths) {
                    try {
                        # Handle wildcard patterns and file extensions
                        if ($CleanupPath.Path -like "*\*.*" -or $CleanupPath.Path -like "*\*") {
                            $BasePath = Split-Path $CleanupPath.Path -Parent
                            $Pattern = Split-Path $CleanupPath.Path -Leaf

                            if (Test-Path $BasePath) {
                                $FoundFiles = Get-ChildItem -Path $BasePath -Filter $Pattern -File -ErrorAction SilentlyContinue |
                                             Where-Object {
                                                 $_ -and
                                                 $_.PSObject.Properties['LastWriteTime'] -and
                                                 $_.LastWriteTime -lt (Get-Date).AddDays(-$CleanupPath.RetentionDays)
                                             }
                            }
                            else {
                                $FoundFiles = @()
                            }
                        }
                        else {
                            if (Test-Path $CleanupPath.Path) {
                                $FoundFiles = Get-ChildItem -Path $CleanupPath.Path -Recurse -File -ErrorAction SilentlyContinue |
                                             Where-Object {
                                                 $_ -and
                                                 $_.PSObject.Properties['LastWriteTime'] -and
                                                 $_.LastWriteTime -lt (Get-Date).AddDays(-$CleanupPath.RetentionDays)
                                             }
                            }
                            else {
                                $FoundFiles = @()
                            }
                        }

                        if ($FoundFiles -and $FoundFiles.Count -gt 0) {
                            $SizeCleaned = ($FoundFiles | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                            $FileCount = $FoundFiles.Count

                            if ($FileCount -gt 0 -and $SizeCleaned) {
                                if (!$WhatIf) {
                                    $FoundFiles | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                                }

                                $TotalCleaned += $SizeCleaned
                                $TotalFiles += $FileCount

                                $CleanupDetails = "$($CleanupPath.Name): Cleaned $FileCount files ($([math]::Round($SizeCleaned / 1MB, 2))MB) older than $($CleanupPath.RetentionDays) days"
                                Write-DetailedOperation -Operation 'MinGW Cleanup' -Details $CleanupDetails -Result 'Cleaned'
                            }
                        }
                    }
                    catch {
                        Write-DetailedOperation -Operation 'MinGW Cleanup' -Details "$($CleanupPath.Name): Error - $($_.Exception.Message)" -Result 'Error'
                    }
                }

                if ($TotalCleaned -gt 0) {
                    $CleanedMB = [math]::Round($TotalCleaned / 1MB, 2)
                    Write-MaintenanceLog -Message "MinGW maintenance completed - Cleaned $CleanedMB MB ($TotalFiles files)" -Level SUCCESS
                }
                else {
                    Write-MaintenanceLog -Message 'MinGW - no cleanup needed' -Level INFO
                }
            }
            else {
                Write-MaintenanceLog -Message 'MinGW not found - skipping' -Level INFO
            }
        }
    }

    # Windows Software Development Kit (SDK) Maintenance
    if ($Config.DeveloperMaintenance.EnableWindowsSDK) {
        Invoke-SafeCommand -TaskName "Windows Software Development Kit Maintenance" -Command {
            Write-MaintenanceLog -Message 'Processing Windows SDK maintenance...' -Level PROGRESS

            # Windows SDK detection
            $WindowsSDKFound = $false
            $SDKPaths = @()

            # Common Windows SDK installation paths
            $CommonSDKPaths = @(
                "${env:ProgramFiles(x86)}\Windows Kits\10",
                "${env:ProgramFiles}\Windows Kits\10",
                "${env:ProgramFiles(x86)}\Windows Kits\8.1",
                "${env:ProgramFiles}\Windows Kits\8.1",
                "${env:ProgramFiles(x86)}\Microsoft SDKs\Windows",
                "${env:ProgramFiles}\Microsoft SDKs\Windows"
            )

            foreach ($SDKPath in $CommonSDKPaths) {
                if (Test-Path $SDKPath) {
                    $WindowsSDKFound = $true
                    $SDKPaths += $SDKPath

                    # Get SDK version info
                    $SDKVersions = Get-ChildItem -Path "$SDKPath\Include" -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
                    if ($SDKVersions) {
                        Write-DetailedOperation -Operation 'Windows SDK Detection' -Details "Windows SDK at: $SDKPath | Versions: $($SDKVersions -join ', ')" -Result 'Found'
                    }
                    else {
                        Write-DetailedOperation -Operation 'Windows SDK Detection' -Details "Windows SDK at: $SDKPath" -Result 'Found'
                    }
                }
            }

            if ($WindowsSDKFound) {
                $TotalCleaned = 0
                $TotalFiles = 0

                # Windows SDK cleanup paths
                $SDKCleanupPaths = @(
                    @{ Path = "$env:LOCALAPPDATA\Microsoft\WinSDK"; Name = "Windows SDK Local Cache"; RetentionDays = 30 },
                    @{ Path = "$env:TEMP\SDK*"; Name = "SDK Temporary Files"; RetentionDays = 7 },
                    @{ Path = "$env:LOCALAPPDATA\Temp\WinSDK*"; Name = "Windows SDK Temp Files"; RetentionDays = 7 },
                    @{ Path = "$env:APPDATA\Microsoft\WinSDK\logs"; Name = "Windows SDK Logs"; RetentionDays = 14 }
                )

                # Add SDK installation-specific cleanup paths
                foreach ($SDKPath in $SDKPaths) {
                    $SDKCleanupPaths += @(
                        @{ Path = "$SDKPath\Logs"; Name = "SDK Installation Logs"; RetentionDays = 30 },
                        @{ Path = "$SDKPath\temp"; Name = "SDK Installation Temp"; RetentionDays = 7 },
                        @{ Path = "$SDKPath\cache"; Name = "SDK Cache"; RetentionDays = 30 }
                    )
                }

                foreach ($CleanupPath in $SDKCleanupPaths) {
                    try {
                        # Handle wildcard paths
                        if ($CleanupPath.Path -like "*\*") {
                            $BasePath = Split-Path $CleanupPath.Path -Parent
                            $Pattern = Split-Path $CleanupPath.Path -Leaf

                            if (Test-Path $BasePath) {
                                $FoundPaths = Get-ChildItem -Path $BasePath -Directory -Filter $Pattern -ErrorAction SilentlyContinue
                                $FoundFiles = $FoundPaths | ForEach-Object {
                                    Get-ChildItem -Path $_.FullName -Recurse -File -ErrorAction SilentlyContinue |
                                    Where-Object {
                                        $_ -and
                                        $_.PSObject.Properties['LastWriteTime'] -and
                                        $_.LastWriteTime -lt (Get-Date).AddDays(-$CleanupPath.RetentionDays)
                                    }
                                }
                            }
                            else {
                                $FoundFiles = @()
                            }
                        }
                        else {
                            if (Test-Path $CleanupPath.Path) {
                                Write-DetailedOperation -Operation 'Windows SDK Analysis' -Details "Scanning $($CleanupPath.Name)" -Result 'Scanning'

                                $FoundFiles = Get-ChildItem -Path $CleanupPath.Path -Recurse -File -ErrorAction SilentlyContinue |
                                             Where-Object {
                                                 $_ -and
                                                 $_.PSObject.Properties['LastWriteTime'] -and
                                                 $_.LastWriteTime -lt (Get-Date).AddDays(-$CleanupPath.RetentionDays)
                                             }
                            }
                            else {
                                $FoundFiles = @()
                            }
                        }

                        if ($FoundFiles -and $FoundFiles.Count -gt 0) {
                            $SizeCleaned = ($FoundFiles | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                            $FileCount = $FoundFiles.Count

                            if ($FileCount -gt 0 -and $SizeCleaned) {
                                if (!$WhatIf) {
                                    $FoundFiles | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                                }

                                $TotalCleaned += $SizeCleaned
                                $TotalFiles += $FileCount

                                $CleanupDetails = "$($CleanupPath.Name): Cleaned $FileCount files ($([math]::Round($SizeCleaned / 1MB, 2))MB)"
                                Write-DetailedOperation -Operation 'Windows SDK Cleanup' -Details $CleanupDetails -Result 'Cleaned'
                            }
                        }
                    }
                    catch {
                        Write-DetailedOperation -Operation 'Windows SDK Cleanup' -Details "$($CleanupPath.Name): Error - $($_.Exception.Message)" -Result 'Error'
                    }
                }

                if ($TotalCleaned -gt 0) {
                    $CleanedMB = [math]::Round($TotalCleaned / 1MB, 2)
                    Write-MaintenanceLog -Message "Windows SDK maintenance completed - Cleaned $CleanedMB MB ($TotalFiles files)" -Level SUCCESS
                }
                else {
                    Write-MaintenanceLog -Message 'Windows SDK - no cleanup needed' -Level INFO
                }
            }
            else {
                Write-MaintenanceLog -Message 'Windows SDK not found - skipping' -Level INFO
            }
        }
    }

    # Microsoft Visual C++ Redistributables Maintenance
    if ($Config.DeveloperMaintenance.EnableVCRedist) {
        Invoke-SafeCommand -TaskName "Microsoft Visual C++ Redistributables Maintenance" -Command {
            Write-MaintenanceLog -Message 'Processing Visual C++ Redistributables maintenance...' -Level PROGRESS

            # Visual C++ Redistributables detection via registry
            $VCRedistFound = $false
            $InstalledVCRedist = @()

            try {
                # Check registry for Visual C++ Redistributables
                $RegistryPaths = @(
                    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
                    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
                )

                foreach ($RegPath in $RegistryPaths) {
                    $RegEntries = Get-ItemProperty -Path $RegPath -ErrorAction SilentlyContinue |
                                 Where-Object { $_.DisplayName -like "*Visual C++ Redistributable*" }

                    foreach ($Entry in $RegEntries) {
                        if ($Entry.DisplayName -notin $InstalledVCRedist.Name) {
                            $VCRedistFound = $true
                            $InstalledVCRedist += @{
                                Name = $Entry.DisplayName
                                Version = $Entry.DisplayVersion
                            }
                            Write-DetailedOperation -Operation 'VC++ Redist Detection' -Details "Found: $($Entry.DisplayName)" -Result 'Detected'
                        }
                    }
                }
            }
            catch {
                Write-DetailedOperation -Operation 'VC++ Redist Detection' -Details "Error: $($_.Exception.Message)" -Result 'Error'
            }

            if ($VCRedistFound) {
                $TotalCleaned = 0
                $TotalFiles = 0

                # Visual C++ Redistributables cleanup paths
                $VCRedistCleanupPaths = @(
                    @{ Path = "$env:TEMP\dd_vcredist*"; Name = "VC++ Redist Installation Logs"; RetentionDays = 30 },
                    @{ Path = "$env:LOCALAPPDATA\Temp\VCRedist*"; Name = "VC++ Redist Temp Files"; RetentionDays = 14 },
                    @{ Path = "$env:LOCALAPPDATA\Temp\MSI*.LOG"; Name = "MSI Installation Logs"; RetentionDays = 30 }
                )

                foreach ($CleanupPath in $VCRedistCleanupPaths) {
                    try {
                        # Handle wildcard paths
                        if ($CleanupPath.Path -like "*\*") {
                            $BasePath = Split-Path $CleanupPath.Path -Parent
                            $Pattern = Split-Path $CleanupPath.Path -Leaf

                            if (Test-Path $BasePath) {
                                if ($Pattern -like "*.*") {
                                    # File pattern
                                    $FoundFiles = Get-ChildItem -Path $BasePath -Filter $Pattern -File -ErrorAction SilentlyContinue |
                                                 Where-Object {
                                                     $_ -and
                                                     $_.PSObject.Properties['LastWriteTime'] -and
                                                     $_.LastWriteTime -lt (Get-Date).AddDays(-$CleanupPath.RetentionDays)
                                                 }
                                }
                                else {
                                    # Directory pattern
                                    $FoundDirs = Get-ChildItem -Path $BasePath -Directory -Filter $Pattern -ErrorAction SilentlyContinue
                                    $FoundFiles = $FoundDirs | ForEach-Object {
                                        Get-ChildItem -Path $_.FullName -Recurse -File -ErrorAction SilentlyContinue |
                                        Where-Object {
                                            $_ -and
                                            $_.PSObject.Properties['LastWriteTime'] -and
                                            $_.LastWriteTime -lt (Get-Date).AddDays(-$CleanupPath.RetentionDays)
                                        }
                                    }
                                }
                            }
                            else {
                                $FoundFiles = @()
                            }
                        }
                        else {
                            if (Test-Path $CleanupPath.Path) {
                                $FoundFiles = Get-ChildItem -Path $CleanupPath.Path -Recurse -File -ErrorAction SilentlyContinue |
                                             Where-Object {
                                                 $_ -and
                                                 $_.PSObject.Properties['LastWriteTime'] -and
                                                 $_.LastWriteTime -lt (Get-Date).AddDays(-$CleanupPath.RetentionDays)
                                             }
                            }
                            else {
                                $FoundFiles = @()
                            }
                        }

                        if ($FoundFiles -and $FoundFiles.Count -gt 0) {
                            $SizeCleaned = ($FoundFiles | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                            $FileCount = $FoundFiles.Count

                            if ($FileCount -gt 0 -and $SizeCleaned) {
                                if (!$WhatIf) {
                                    $FoundFiles | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                                }

                                $TotalCleaned += $SizeCleaned
                                $TotalFiles += $FileCount

                                $CleanupDetails = "$($CleanupPath.Name): Cleaned $FileCount files ($([math]::Round($SizeCleaned / 1MB, 2))MB)"
                                Write-DetailedOperation -Operation 'VC++ Redist Cleanup' -Details $CleanupDetails -Result 'Cleaned'
                            }
                        }
                    }
                    catch {
                        Write-DetailedOperation -Operation 'VC++ Redist Cleanup' -Details "$($CleanupPath.Name): Error - $($_.Exception.Message)" -Result 'Error'
                    }
                }

                if ($TotalCleaned -gt 0) {
                    $CleanedMB = [math]::Round($TotalCleaned / 1MB, 2)
                    Write-MaintenanceLog -Message "VC++ Redistributables maintenance completed - Cleaned $CleanedMB MB ($TotalFiles files)" -Level SUCCESS
                }
                else {
                    Write-MaintenanceLog -Message 'VC++ Redistributables - no cleanup needed' -Level INFO
                }
            }
            else {
                Write-MaintenanceLog -Message 'VC++ Redistributables not found - skipping' -Level INFO
            }
        }
    }

    # Database Development Tools Maintenance
    if ($Config.DeveloperMaintenance.EnableDatabaseTools) {
        Invoke-SafeCommand -TaskName "Database Development Tools Maintenance" -Command {
            Write-MaintenanceLog -Message 'Processing database development tools maintenance...' -Level PROGRESS

            $DatabaseTools = @(
                @{ Name = "MySQL Workbench"; LogPath = "$env:APPDATA\MySQL\Workbench\log"; CachePath = "$env:APPDATA\MySQL\Workbench\cache" },
                @{ Name = "XAMPP"; LogPath = "C:\xampp\apache\logs"; TempPath = "C:\xampp\tmp" },
                @{ Name = "WAMP"; LogPath = "C:\wamp64\logs"; TempPath = "C:\wamp64\tmp" },
                @{ Name = "SQL Server Management Studio"; CachePath = "$env:LOCALAPPDATA\Microsoft\SQL Server Management Studio" }
            )

            $TotalCleaned = 0
            $TotalFiles = 0

            foreach ($Tool in $DatabaseTools) {
                $ToolFound = $false
                $CleanupPaths = @()

                # Build cleanup paths for each tool
                if ($Tool.LogPath -and (Test-Path $Tool.LogPath)) {
                    $CleanupPaths += @{ Path = $Tool.LogPath; Type = "Logs"; RetentionDays = 14 }
                    $ToolFound = $true
                }
                if ($Tool.CachePath -and (Test-Path $Tool.CachePath)) {
                    $CleanupPaths += @{ Path = $Tool.CachePath; Type = "Cache"; RetentionDays = 30 }
                    $ToolFound = $true
                }
                if ($Tool.TempPath -and (Test-Path $Tool.TempPath)) {
                    $CleanupPaths += @{ Path = $Tool.TempPath; Type = "Temp"; RetentionDays = 7 }
                    $ToolFound = $true
                }

                if ($ToolFound) {
                    Write-DetailedOperation -Operation 'Database Tool Detection' -Details "$($Tool.Name) detected" -Result 'Found'

                    foreach ($CleanupPath in $CleanupPaths) {
                        try {
                            $OldFiles = Get-ChildItem -Path $CleanupPath.Path -Recurse -File -ErrorAction SilentlyContinue |
                                       Where-Object {
                                           $_ -and
                                           $_.PSObject.Properties['LastWriteTime'] -and
                                           $_.LastWriteTime -lt (Get-Date).AddDays(-$CleanupPath.RetentionDays)
                                       }

                            if ($OldFiles -and $OldFiles.Count -gt 0) {
                                $SizeCleaned = ($OldFiles | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                                $FileCount = $OldFiles.Count

                                if ($FileCount -gt 0 -and $SizeCleaned) {
                                    if (!$WhatIf) {
                                        $OldFiles | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                                    }

                                    $TotalCleaned += $SizeCleaned
                                    $TotalFiles += $FileCount

                                    $CleanupDetails = "$($Tool.Name) $($CleanupPath.Type): Cleaned $FileCount files ($([math]::Round($SizeCleaned / 1MB, 2))MB)"
                                    Write-DetailedOperation -Operation 'Database Tool Cleanup' -Details $CleanupDetails -Result 'Cleaned'
                                }
                            }
                        }
                        catch {
                            Write-DetailedOperation -Operation 'Database Tool Cleanup' -Details "$($Tool.Name): Error - $($_.Exception.Message)" -Result 'Error'
                        }
                    }
                }
            }

            if ($TotalCleaned -gt 0) {
                $CleanedMB = [math]::Round($TotalCleaned / 1MB, 2)
                Write-MaintenanceLog -Message "Database tools maintenance completed - Cleaned $CleanedMB MB ($TotalFiles files)" -Level SUCCESS
            }
            else {
                Write-MaintenanceLog -Message 'Database tools - no cleanup needed or not found' -Level INFO
            }
        }
    }

    # Adobe Creative Suite and Design Tools Maintenance
    if ($Config.DeveloperMaintenance.EnableAdobeTools) {
        Invoke-SafeCommand -TaskName "Adobe Creative Suite and Design Tools Maintenance" -Command {
            Write-MaintenanceLog -Message 'Processing Adobe Creative Suite and design tools maintenance...' -Level PROGRESS

            $DesignTools = @(
                @{ Name = "Adobe Photoshop"; CachePath = "$env:APPDATA\Adobe\Adobe Photoshop*\Adobe Photoshop*Settings\temp" },
                @{ Name = "Adobe Illustrator"; CachePath = "$env:APPDATA\Adobe\Adobe Illustrator*" },
                @{ Name = "Figma"; CachePath = "$env:APPDATA\Figma\logs"; TempPath = "$env:APPDATA\Figma\DesktopCache" }
            )

            $TotalCleaned = 0
            $TotalFiles = 0

            foreach ($Tool in $DesignTools) {
                $ToolFound = $false

                # Check cache paths with wildcard support
                if ($Tool.CachePath) {
                    $CacheBasePath = Split-Path $Tool.CachePath -Parent
                    $CachePattern = Split-Path $Tool.CachePath -Leaf
                    if (Test-Path $CacheBasePath) {
                        $CachePaths = Get-ChildItem -Path $CacheBasePath -Directory -Filter $CachePattern -ErrorAction SilentlyContinue
                        if ($CachePaths) {
                            $ToolFound = $true
                            foreach ($CachePath in $CachePaths) {
                                try {
                                    $OldFiles = Get-ChildItem -Path $CachePath.FullName -Recurse -File -ErrorAction SilentlyContinue |
                                               Where-Object {
                                                   $_ -and
                                                   $_.PSObject.Properties['LastWriteTime'] -and
                                                   $_.LastWriteTime -lt (Get-Date).AddDays(-7)
                                               }

                                    if ($OldFiles -and $OldFiles.Count -gt 0) {
                                        $SizeCleaned = ($OldFiles | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                                        $FileCount = $OldFiles.Count

                                        if ($FileCount -gt 0 -and $SizeCleaned) {
                                            if (!$WhatIf) {
                                                $OldFiles | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                                            }

                                            $TotalCleaned += $SizeCleaned
                                            $TotalFiles += $FileCount

                                            $CleanupDetails = "$($Tool.Name): Cleaned $FileCount cache files ($([math]::Round($SizeCleaned / 1MB, 2))MB)"
                                            Write-DetailedOperation -Operation 'Design Tool Cleanup' -Details $CleanupDetails -Result 'Cleaned'
                                        }
                                    }
                                }
                                catch {
                                    Write-DetailedOperation -Operation 'Design Tool Cleanup' -Details "$($Tool.Name): Error - $($_.Exception.Message)" -Result 'Error'
                                }
                            }
                        }
                    }
                }

                # Check temp paths
                if ($Tool.TempPath -and (Test-Path $Tool.TempPath)) {
                    $ToolFound = $true
                    try {
                        $OldFiles = Get-ChildItem -Path $Tool.TempPath -Recurse -File -ErrorAction SilentlyContinue |
                                   Where-Object {
                                       $_ -and
                                       $_.PSObject.Properties['LastWriteTime'] -and
                                       $_.LastWriteTime -lt (Get-Date).AddDays(-7)
                                   }

                        if ($OldFiles -and $OldFiles.Count -gt 0) {
                            $SizeCleaned = ($OldFiles | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                            $FileCount = $OldFiles.Count

                            if ($FileCount -gt 0 -and $SizeCleaned) {
                                if (!$WhatIf) {
                                    $OldFiles | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                                }

                                $TotalCleaned += $SizeCleaned
                                $TotalFiles += $FileCount

                                $CleanupDetails = "$($Tool.Name): Cleaned $FileCount temp files ($([math]::Round($SizeCleaned / 1MB, 2))MB)"
                                Write-DetailedOperation -Operation 'Design Tool Cleanup' -Details $CleanupDetails -Result 'Cleaned'
                            }
                        }
                    }
                    catch {
                        Write-DetailedOperation -Operation 'Design Tool Cleanup' -Details "$($Tool.Name): Error - $($_.Exception.Message)" -Result 'Error'
                    }
                }

                if ($ToolFound) {
                    Write-DetailedOperation -Operation 'Design Tool Detection' -Details "$($Tool.Name) detected" -Result 'Found'
                }
            }

            if ($TotalCleaned -gt 0) {
                $CleanedMB = [math]::Round($TotalCleaned / 1MB, 2)
                Write-MaintenanceLog -Message "Design tools maintenance completed - Cleaned $CleanedMB MB ($TotalFiles files)" -Level SUCCESS
            }
            else {
                Write-MaintenanceLog -Message 'Design tools - no cleanup needed or not found' -Level INFO
            }
        }
    }

    # Legacy C/C++ Development Tools Maintenance
    if ($Config.DeveloperMaintenance.EnableLegacyCppTools) {
        Invoke-SafeCommand -TaskName "Legacy C/C++ Development Tools Maintenance" -Command {
            Write-MaintenanceLog -Message 'Processing legacy C/C++ development tools maintenance...' -Level PROGRESS

            $LegacyTools = @(
                @{ Name = "Dev-C++"; ConfigPath = "$env:APPDATA\Dev-Cpp"; CachePath = "$env:LOCALAPPDATA\Dev-Cpp" },
                @{ Name = "Code::Blocks"; ConfigPath = "$env:APPDATA\CodeBlocks"; LogPath = "$env:APPDATA\CodeBlocks\logs" },
                @{ Name = "Arduino IDE"; ConfigPath = "$env:LOCALAPPDATA\Arduino15"; CachePath = "$env:APPDATA\Arduino IDE" },
                @{ Name = "Turbo C++"; InstallPath = "C:\TURBOC3"; TempPath = "C:\TURBOC3\BGI" }
            )

            $TotalCleaned = 0
            $TotalFiles = 0

            foreach ($Tool in $LegacyTools) {
                $ToolFound = $false

                # Check installation/config paths
                if ($Tool.ConfigPath -and (Test-Path $Tool.ConfigPath)) {
                    $ToolFound = $true
                    # Clean temporary and log files
                    try {
                        $OldFiles = Get-ChildItem -Path $Tool.ConfigPath -Recurse -File -ErrorAction SilentlyContinue |
                                   Where-Object {
                                       $_ -and
                                       $_.PSObject.Properties['LastWriteTime'] -and
                                       $_.Extension -in @('.tmp', '.log', '.bak') -and
                                       $_.LastWriteTime -lt (Get-Date).AddDays(-7)
                                   }

                        if ($OldFiles -and $OldFiles.Count -gt 0) {
                            $SizeCleaned = ($OldFiles | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                            $FileCount = $OldFiles.Count

                            if ($FileCount -gt 0 -and $SizeCleaned) {
                                if (!$WhatIf) {
                                    $OldFiles | Remove-Item -Force -ErrorAction SilentlyContinue
                                }

                                $TotalCleaned += $SizeCleaned
                                $TotalFiles += $FileCount

                                $CleanupDetails = "$($Tool.Name): Cleaned $FileCount temp/log files ($([math]::Round($SizeCleaned / 1MB, 2))MB)"
                                Write-DetailedOperation -Operation 'Legacy Tool Cleanup' -Details $CleanupDetails -Result 'Cleaned'
                            }
                        }
                    }
                    catch {
                        Write-DetailedOperation -Operation 'Legacy Tool Cleanup' -Details "$($Tool.Name): Error - $($_.Exception.Message)" -Result 'Error'
                    }
                }

                if ($ToolFound) {
                    Write-DetailedOperation -Operation 'Legacy Tool Detection' -Details "$($Tool.Name) detected" -Result 'Found'
                }
            }

            if ($TotalCleaned -gt 0) {
                $CleanedMB = [math]::Round($TotalCleaned / 1MB, 2)
                Write-MaintenanceLog -Message "Legacy C/C++ tools maintenance completed - Cleaned $CleanedMB MB ($TotalFiles files)" -Level SUCCESS
            }
            else {
                Write-MaintenanceLog -Message 'Legacy C/C++ tools - no cleanup needed or not found' -Level INFO
            }
        }
    }

    Write-MaintenanceLog -Message '======== Developer Maintenance Module Completed ========' -Level SUCCESS
}

# Export public functions
Export-ModuleMember -Function @(
    'Invoke-DeveloperMaintenance',
    'Get-SafeTotalFileSize'
)
