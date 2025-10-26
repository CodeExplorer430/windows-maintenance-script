# Windows Maintenance Framework - Implementation Guide

This guide tracks the refactoring progress from the monolithic script to the modular framework.

## Current Status

### ✅ Completed Modules

#### Core Framework (100%)
- [x] Modular architecture structure
- [x] WindowsMaintenance.psm1 (root orchestrator)
- [x] WindowsMaintenance.psd1 (manifest)
- [x] Configuration system with JSON schema
- [x] Validation script (Test-MaintenanceConfig.ps1)
- [x] Pester test structure
- [x] Comprehensive documentation (CONFIG.md, README for tests)

#### Common Modules (100% - 8/8 modules)
- [x] Logging.psm1
- [x] StringFormatting.psm1
- [x] SystemDetection.psm1
- [x] MemoryManagement.psm1
- [x] SafeExecution.psm1
- [x] UIHelpers.psm1
- [x] RealTimeProgressOutput.psm1
- [x] DriveAnalysis.psm1

#### Feature Modules (100% - 7/7 modules)
- [x] SystemUpdates.psm1
- [x] DiskMaintenance.psm1
- [x] SystemHealthRepair.psm1
- [x] SecurityScans.psm1
- [x] **DeveloperMaintenance.psm1** (25% - 4/14 tools) ⚠️
- [x] PerformanceOptimization.psm1 (60% - core done, 3 features missing) ⚠️
- [x] NetworkMaintenance.psm1 (NEW - 100%)

#### Utility Modules (100%)
- [x] TaskScheduler.psm1 (NEW)
- [x] Install-MaintenanceTask.ps1 (NEW)
- [x] Test-MaintenanceConfig.ps1 (NEW)

---

## 🔧 Remaining Implementation Tasks

### 1. DeveloperMaintenance Module (25% Complete)

**Implemented Tools (4/14)**:
- ✅ NPM (lines 6828-6946 in original)
- ✅ Python (lines 6948-7064 in original)
- ✅ Docker (lines 6753-6826 in original)
- ✅ JDK/Maven/Gradle (lines 7066-7181 in original)

**Remaining Tools (10/14)** - **Priority: HIGH**:

| Tool | Original Lines | Retention Days | Detection Method | Cache Locations |
|------|----------------|----------------|------------------|-----------------|
| **MinGW** | 7183-7316 | 3-30 days | gcc/g++ command, installation paths | GCC temp, object files, MinGW cache |
| **.NET SDK** | 7318-7510 | 30-90 days | dotnet command | NuGet cache, template engine, compilation artifacts |
| **Windows SDK** | 7511-7650 | 14-60 days | Registry check, installation paths | Dev cache, debug symbols, temp files |
| **VC++ Redistributables** | 7651-7750 | 14-30 days | Installation registry | Installation logs, temp files |
| **Composer (PHP)** | 7819-7991 | 7-60 days | composer command | Package cache, vendor dirs, project caches |
| **PostgreSQL** | 7993-8187 | 7-90 days | psql command, service check | Server logs, temp files, command history |
| **JetBrains IDEs** | 8189-8282 | 7 days | Installation paths | System caches, temp files, logs (IntelliJ, PyCharm, WebStorm, CLion, Rider) |
| **Visual Studio 2022** | 8284-8360 | 3-30 days | Installation path | Cache, temp files, NuGet, IntelliCode logs |
| **VS Code** | 8362-8437 | 7-90 days | Installation path | Logs, extension cache, VSIX, workspace storage, crash dumps |
| **Database Tools** | 8439-8530 | 7-30 days | Installation checks | SSMS logs, Azure Data Studio cache |
| **Adobe Tools** | 8532-8620 | 7-30 days | Installation paths | Cache, temp files (Creative Cloud) |
| **Version Control** | 8622-8705 | 30 days | git command | .git/objects optimization, gc |
| **Legacy C/C++ Tools** | 8707-8795 | 14-30 days | Installation checks | MSVC cache, Build logs |

### 2. PerformanceOptimization Module (60% Complete)

**Implemented Features (3/6)**:
- ✅ Event Log Cleanup (lines 9065-9199 in original)
- ✅ Event Log Size Validation (lines 8976-9063 in original)
- ✅ Memory Optimization (integrated from Common modules)

**Remaining Features (3/6)** - **Priority: HIGH**:

| Feature | Original Lines | Description | Implementation Notes |
|---------|----------------|-------------|----------------------|
| **Startup Performance Analysis** | 9201-9341 | WMI startup items, Registry detection, Impact categorization | High/Medium/Low impact analysis, File size check, Missing item detection |
| **Invalid Startup Items Cleanup** | 9343-9378 | Remove broken startup entries | Message box for significant cleanup (>5 items), Progress tracking |
| **System Resource Analysis** | 9380-9553 | Memory, CPU, Disk I/O metrics | 5-sample CPU average, Top 15 memory processes, Performance thresholds |

---

## 📋 Implementation Pattern

All developer tools follow this pattern (example from JDK - already implemented):

```powershell
# Tool Name Maintenance
if ($Config.DeveloperMaintenance.EnableToolName) {
    Invoke-SafeCommand -TaskName "Tool Name Maintenance" -Command {
        Write-MaintenanceLog -Message 'Processing Tool Name maintenance...' -Level PROGRESS

        # STEP 1: Multi-method detection
        $ToolFound = $false
        $ToolVersion = $null

        # Check for command
        if (Get-Command tool-command -ErrorAction SilentlyContinue) {
            $ToolFound = $true
            $ToolVersion = tool-command --version 2>&1 | Select-Object -First 1
            Write-DetailedOperation -Operation 'Tool Detection' -Details "Tool detected: $ToolVersion" -Result 'Available'
        }

        # Check for environment variables
        if ($env:TOOL_HOME -and (Test-Path $env:TOOL_HOME)) {
            $ToolFound = $true
            Write-DetailedOperation -Operation 'Tool Detection' -Details "TOOL_HOME detected: $env:TOOL_HOME" -Result 'Available'
        }

        # Check installation paths
        $CommonPaths = @("C:\Tool", "$env:ProgramFiles\Tool")
        foreach ($Path in $CommonPaths) {
            if (Test-Path $Path) {
                $ToolFound = $true
                Write-DetailedOperation -Operation 'Tool Detection' -Details "Installation at: $Path" -Result 'Found'
            }
        }

        if ($ToolFound) {
            $TotalCleaned = 0
            $TotalFiles = 0

            # STEP 2: Define cleanup paths with retention policies
            $CleanupPaths = @(
                @{ Path = "$env:USERPROFILE\.tool\cache"; Name = "Tool Cache"; RetentionDays = 30 },
                @{ Path = "$env:TEMP\tool_*"; Name = "Tool Temp Files"; RetentionDays = 7 }
            )

            # STEP 3: Process each cleanup path
            foreach ($CleanupPath in $CleanupPaths) {
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
                            Write-DetailedOperation -Operation 'Tool Analysis' -Details "Scanning $($CleanupPath.Name)" -Result 'Scanning'

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

                                    $CleanupDetails = "$($CleanupPath.Name): Cleaned $FileCount files ($([math]::Round($SizeCleaned / 1MB, 2))MB)"
                                    Write-DetailedOperation -Operation 'Tool Cleanup' -Details $CleanupDetails -Result 'Cleaned'
                                }
                            }
                            else {
                                Write-DetailedOperation -Operation 'Tool Analysis' -Details "$($CleanupPath.Name): No cleanup needed" -Result 'Clean'
                            }
                        }
                    }
                }
                catch {
                    Write-DetailedOperation -Operation 'Tool Cleanup' -Details "$($CleanupPath.Name): Error - $($_.Exception.Message)" -Result 'Error'
                }
            }

            # STEP 4: Run tool-specific CLI cleanup commands
            if (Get-Command tool-command -ErrorAction SilentlyContinue) {
                if (!$WhatIf) {
                    tool-command clear-cache 2>&1 | Out-Null
                }
                Write-DetailedOperation -Operation 'Tool CLI Cleanup' -Details "Ran tool-command clear-cache" -Result 'Complete'
            }

            # STEP 5: Report results
            if ($TotalCleaned -gt 0) {
                $CleanedMB = [math]::Round($TotalCleaned / 1MB, 2)
                Write-MaintenanceLog -Message "Tool maintenance completed - Cleaned $CleanedMB MB ($TotalFiles files)" -Level SUCCESS
            }
            else {
                Write-MaintenanceLog -Message 'Tool - no cleanup needed' -Level INFO
            }
        }
        else {
            Write-MaintenanceLog -Message 'Tool not found - skipping' -Level INFO
        }
    }
}
```

---

## 🚀 Quick Implementation Checklist

For each remaining developer tool:

1. **Read original script section** (line numbers in table above)
2. **Extract detection methods** (commands, paths, environment variables)
3. **Extract cleanup paths** with retention days
4. **Extract CLI cleanup commands** (if any)
5. **Follow the pattern above** - copy/paste JDK implementation as template
6. **Update configuration** option names in `if ($Config.DeveloperMaintenance.EnableToolName)`
7. **Test with WhatIf mode**: `Invoke-WindowsMaintenance -WhatIf`

---

## 📝 Configuration Updates Needed

After implementing each tool, ensure `config/maintenance-config.json` has the corresponding setting:

```json
{
  "DeveloperMaintenance": {
    "EnableMinGW": false,
    "EnableDotNetSDK": false,
    "EnableWindowsSDK": false,
    "EnableVCRedist": false,
    "EnableComposer": false,
    "EnablePostgreSQL": false,
    "EnableJetBrainsIDEs": false,
    "EnableVisualStudio2022": false,
    "EnableVSCode": false,
    "EnableDatabaseTools": false,
    "EnableAdobeTools": false,
    "EnableVersionControl": true,
    "EnableLegacyCppTools": false
  }
}
```

**Already added** ✅ - just update `false` to `true` when implementing each tool.

---

## 🎯 Next Steps - Recommended Order

### Phase 1: Complete DeveloperMaintenance (Priority: HIGH)
1. **VS Code** (very common, lines 8362-8437)
2. **.NET SDK** (very common, lines 7318-7510)
3. **JetBrains IDEs** (common, lines 8189-8282)
4. **Composer** (PHP devs, lines 7819-7991)
5. **Visual Studio 2022** (Windows devs, lines 8284-8360)
6. **MinGW** (C/C++ devs, lines 7183-7316)
7. **PostgreSQL** (database devs, lines 7993-8187)
8. **Version Control (Git)** (everyone, lines 8622-8705)
9. **Windows SDK** (Windows devs, lines 7511-7650)
10. **Database Tools** (database devs, lines 8439-8530)
11. **VC++ Redistributables** (less critical, lines 7651-7750)
12. **Adobe Tools** (designers, lines 8532-8620)
13. **Legacy C/C++ Tools** (rare, lines 8707-8795)

### Phase 2: Complete PerformanceOptimization (Priority: HIGH)
1. **Startup Performance Analysis** (lines 9201-9341)
2. **Invalid Startup Items Cleanup** (lines 9343-9378)
3. **System Resource Analysis** (lines 9380-9553)

### Phase 3: Verification & Cleanup
1. **Verify feature parity** with original script
2. **Deprecate original script** with migration notice
3. **Update main README.md**
4. **Create example configurations**
5. **Create standalone Run-Maintenance.ps1**

### Phase 4: GUI Implementation
1. **Design Windows Forms structure**
2. **Implement main window & module selector**
3. **Implement configuration editor**
4. **Implement progress monitor & log viewer**

---

##Files to Modify

### For Developer Tools:
- `WindowsMaintenance/Modules/DeveloperMaintenance.psm1` (add implementations before the NOTE section)
- `config/maintenance-config.json` (settings already added, just enable them)

### For Performance Features:
- `WindowsMaintenance/Modules/PerformanceOptimization.psm1` (add implementations before the NOTE section)

---

## 🧪 Testing Each Implementation

After adding each tool:

```powershell
# Test configuration validation
.\Scripts\Test-MaintenanceConfig.ps1

# Test with WhatIf mode
Import-Module .\WindowsMaintenance.psd1 -Force
Invoke-WindowsMaintenance -WhatIf

# Test specific module
Invoke-DeveloperMaintenance
```

---

## 📊 Progress Tracking

- **Overall Completion**: ~85%
- **DeveloperMaintenance**: 25% (4/14 tools)
- **PerformanceOptimization**: 60% (3/6 features)
- **Remaining work**: ~10-15 hours estimated

---

## 🔗 Reference

- **Original Script**: `scripts/Windows10-Maintenance-Script.ps1` (12,205 lines)
- **Module Location**: `WindowsMaintenance/Modules/DeveloperMaintenance.psm1`
- **Pattern Example**: JDK implementation (lines 394-515 in current module)
- **Configuration**: `config/maintenance-config.json`

---

**Last Updated**: 2025-10-26
**Version**: 4.0.0 (in progress)
**Next Priority**: VS Code, .NET SDK, JetBrains IDEs

