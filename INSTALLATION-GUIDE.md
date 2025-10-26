# Windows Maintenance Framework - Installation Guide

**Version:** 4.0.0
**Date:** October 2025
**Platform:** Windows 10/11

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Installation](#quick-installation)
- [Detailed Installation](#detailed-installation)
- [Configuration](#configuration)
- [Verification](#verification)
- [First Run](#first-run)
- [Scheduled Tasks](#scheduled-tasks)
- [Troubleshooting](#troubleshooting)
- [Uninstallation](#uninstallation)

---

## Prerequisites

### System Requirements

**Operating System:**
- Windows 10 version 1809 or later
- Windows 11 (all versions)
- Windows Server 2019/2022 (supported but not primary target)

**PowerShell:**
- PowerShell 5.1 or later (built-in to Windows 10/11)
- PowerShell 7.x (optional, not required)

**Privileges:**
- Administrator access required for execution
- Standard user can view documentation and configure

**Disk Space:**
- 50 MB for framework files
- 100-500 MB for logs and reports (grows over time)

**Optional Components:**
- Pester 5.x for running tests (optional)
- Git for version control (optional)

### Checking Prerequisites

```powershell
# Check PowerShell version
$PSVersionTable.PSVersion
# Should show: 5.1.x or higher

# Check if running as Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Write-Host "Administrator: $isAdmin"
# Should show: True

# Check disk space
Get-PSDrive C | Select-Object Used,Free
# Should have at least 1 GB free
```

---

## Quick Installation

For users who want to get started quickly:

### Option 1: Download and Extract

1. **Download the framework**
   ```powershell
   # If using Git
   git clone <repository-url> C:\MaintenanceFramework
   cd C:\MaintenanceFramework
   ```

2. **Verify download**
   ```powershell
   Test-Path .\WindowsMaintenance.psd1
   # Should return: True
   ```

3. **Run first-time setup**
   ```powershell
   # Test configuration
   .\Scripts\Test-MaintenanceConfig.ps1

   # Test with WhatIf (recommended)
   .\Run-Maintenance.ps1 -WhatIf
   ```

4. **Ready to use!**
   ```powershell
   # Run actual maintenance
   .\Run-Maintenance.ps1

   # Or use GUI
   .\Start-MaintenanceGUI.ps1
   ```

---

## Detailed Installation

### Step 1: Download Framework

**Method A: Git Clone (Recommended)**
```powershell
# Open PowerShell as Administrator
# Navigate to desired installation location
cd C:\
git clone <repository-url> MaintenanceFramework
cd MaintenanceFramework
```

**Method B: Manual Download**
1. Download ZIP file from repository
2. Extract to `C:\MaintenanceFramework`
3. Open PowerShell as Administrator
4. Navigate to extracted folder
   ```powershell
   cd C:\MaintenanceFramework
   ```

### Step 2: Verify File Structure

```powershell
# Check main components
Test-Path .\WindowsMaintenance.psd1      # Module manifest
Test-Path .\WindowsMaintenance.psm1      # Root module
Test-Path .\WindowsMaintenance\Modules   # Modules directory
Test-Path .\config\maintenance-config.json # Configuration
Test-Path .\Run-Maintenance.ps1          # Standalone launcher
Test-Path .\Start-MaintenanceGUI.ps1     # GUI application
```

**Expected Output:** All should return `True`

**Directory Structure:**
```
C:\MaintenanceFramework\
├── WindowsMaintenance.psd1          # Module manifest
├── WindowsMaintenance.psm1          # Root orchestrator
├── Run-Maintenance.ps1              # Standalone launcher
├── Start-MaintenanceGUI.ps1         # GUI application
├── README.md                        # Main documentation
├── CONFIG.md                        # Configuration guide
├── INSTALLATION-GUIDE.md            # This file
├── WindowsMaintenance\
│   ├── Modules\
│   │   ├── Common\                  # 8 utility modules
│   │   ├── SystemUpdates.psm1
│   │   ├── DiskMaintenance.psm1
│   │   ├── SystemHealthRepair.psm1
│   │   ├── SecurityScans.psm1
│   │   ├── DeveloperMaintenance.psm1
│   │   ├── PerformanceOptimization.psm1
│   │   └── NetworkMaintenance.psm1
│   ├── config\
│   │   └── maintenance-config.json  # Main configuration
│   └── Tests\                       # Test suite
├── Scripts\
│   ├── Install-MaintenanceTask.ps1  # Task scheduler
│   └── Test-MaintenanceConfig.ps1   # Config validation
└── examples\                        # Example configurations
    ├── config-minimal.json
    ├── config-homeuser.json
    ├── config-developer.json
    └── config-enterprise.json
```

### Step 3: Configure Execution Policy

PowerShell's execution policy must allow script execution.

**Check Current Policy:**
```powershell
Get-ExecutionPolicy
```

**If Restricted or Undefined:**
```powershell
# Option 1: Set for current user (recommended)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Option 2: Set for entire machine (requires Administrator)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
```

**Verify:**
```powershell
Get-ExecutionPolicy
# Should show: RemoteSigned or Unrestricted
```

### Step 4: Install Pester (Optional, for Testing)

```powershell
# Check if Pester is installed
Get-Module -ListAvailable -Name Pester

# Install Pester 5.x if not present
Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser

# Verify installation
Import-Module Pester
$PesterVersion = (Get-Module Pester).Version
Write-Host "Pester version: $PesterVersion"
```

---

## Configuration

### Option 1: Use Example Configuration (Recommended for First-Time)

```powershell
# Copy an example configuration
Copy-Item .\examples\config-homeuser.json .\WindowsMaintenance\config\maintenance-config.json -Force
```

### Option 2: Customize Configuration

```powershell
# Edit configuration file
notepad .\WindowsMaintenance\config\maintenance-config.json
```

**Key Settings to Configure:**

1. **Logs Path**
   ```json
   "LogsPath": "C:\\Temp\\MaintenanceLogs"
   ```
   Change to your preferred log location.

2. **Reports Path**
   ```json
   "ReportsPath": "C:\\Temp\\MaintenanceReports"
   ```
   Change to your preferred reports location.

3. **Enabled Modules**
   ```json
   "EnabledModules": [
     "SystemUpdates",
     "DiskMaintenance",
     "SecurityScans"
   ]
   ```
   Enable only modules you want to run.

4. **Developer Tools** (if applicable)
   ```json
   "DeveloperMaintenance": {
     "EnableNPM": true,
     "EnablePython": true,
     "EnableDocker": true
   }
   ```
   Enable tools you have installed.

### Validate Configuration

```powershell
# Validate configuration syntax and structure
.\Scripts\Test-MaintenanceConfig.ps1

# Should output: "Configuration is valid"
```

---

## Verification

### Test 1: Module Import

```powershell
# Import the module
Import-Module .\WindowsMaintenance.psd1 -Force

# Verify module loaded
Get-Module WindowsMaintenance

# Check exported functions
Get-Command -Module WindowsMaintenance
```

**Expected Output:**
- Module loads without errors
- `Invoke-WindowsMaintenance` function available
- Individual module functions available

### Test 2: WhatIf Mode (Dry Run)

```powershell
# Run in simulation mode
Import-Module .\WindowsMaintenance.psd1 -Force
Invoke-WindowsMaintenance -WhatIf
```

**Expected Behavior:**
- All enabled modules execute
- No actual changes made
- Log file created
- No errors reported

### Test 3: Standalone Script

```powershell
# Test standalone launcher
.\Run-Maintenance.ps1 -WhatIf
```

**Expected Behavior:**
- Administrator check passes
- Module loads successfully
- Maintenance executes in WhatIf mode
- Summary displayed

### Test 4: GUI Application

```powershell
# Launch GUI
.\Start-MaintenanceGUI.ps1
```

**Expected Behavior:**
- GUI window opens
- Modules listed
- Configuration loaded
- All buttons functional

---

## First Run

### Recommended First Run Procedure

**Step 1: Test with Minimal Configuration**
```powershell
# Use minimal config for first run
.\Run-Maintenance.ps1 -ConfigPath ".\examples\config-minimal.json" -WhatIf
```

**Step 2: Review Logs**
```powershell
# Check log file
$latestLog = Get-ChildItem C:\Temp\MaintenanceLogs\maintenance_*.log |
             Sort-Object LastWriteTime -Descending |
             Select-Object -First 1
Get-Content $latestLog.FullName
```

**Step 3: Run for Real (Minimal)**
```powershell
# Confirm prompt appears
.\Run-Maintenance.ps1 -ConfigPath ".\examples\config-minimal.json"
```

**Step 4: Gradually Enable More Modules**
```powershell
# Try home user config
.\Run-Maintenance.ps1 -ConfigPath ".\examples\config-homeuser.json" -WhatIf

# If successful, run for real
.\Run-Maintenance.ps1 -ConfigPath ".\examples\config-homeuser.json"
```

### Using the GUI for First Run

1. **Launch GUI as Administrator**
   ```powershell
   .\Start-MaintenanceGUI.ps1
   ```

2. **Select Minimal Modules**
   - Check only: DiskMaintenance
   - Leave other modules unchecked

3. **Enable WhatIf Mode**
   - Check "Simulation Mode (WhatIf)"

4. **Click "Start Maintenance"**
   - Watch progress
   - Review status output

5. **Review Results**
   - Tools → Log Viewer
   - Check latest log

6. **Run Again Without WhatIf**
   - Uncheck "Simulation Mode"
   - Click "Start Maintenance"

---

## Scheduled Tasks

### Create Automated Weekly Maintenance

**Method 1: Using GUI**
1. Launch `Start-MaintenanceGUI.ps1`
2. Tools → Schedule Maintenance Task
3. Configure:
   - Task Name: `WeeklyMaintenance`
   - Frequency: Weekly
   - Day: Sunday
   - Time: 02:00
4. Click "Create Task"
5. Approve UAC prompt

**Method 2: Using Script**
```powershell
# Create weekly task
.\Scripts\Install-MaintenanceTask.ps1 `
  -TaskName "WeeklyMaintenance" `
  -DayOfWeek Sunday `
  -StartTime "02:00" `
  -ConfigPath ".\examples\config-homeuser.json"
```

**Method 3: Using Task Scheduler GUI**
1. Open Task Scheduler (taskschd.msc)
2. Create Basic Task
3. Configure:
   - Name: `WindowsMaintenance`
   - Trigger: Weekly, Sunday, 2:00 AM
   - Action: Start a program
   - Program: `powershell.exe`
   - Arguments: `-ExecutionPolicy Bypass -File "C:\MaintenanceFramework\Run-Maintenance.ps1"`
   - Run with highest privileges: ✅ Checked

### Verify Scheduled Task

```powershell
# Check task exists
Get-ScheduledTask -TaskName "WeeklyMaintenance"

# View task details
Get-ScheduledTaskInfo -TaskName "WeeklyMaintenance"

# Test task (run immediately)
Start-ScheduledTask -TaskName "WeeklyMaintenance"
```

---

## Troubleshooting

### Issue: "Execution Policy Error"

**Error Message:**
```
File cannot be loaded because running scripts is disabled on this system.
```

**Solution:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Issue: "Module Not Found"

**Error Message:**
```
Import-Module : The specified module 'WindowsMaintenance.psd1' was not loaded
```

**Solution:**
```powershell
# Ensure you're in correct directory
cd C:\MaintenanceFramework
Test-Path .\WindowsMaintenance.psd1

# Use full path
Import-Module "C:\MaintenanceFramework\WindowsMaintenance.psd1" -Force
```

### Issue: "Access Denied"

**Error Message:**
```
Access to the path is denied.
```

**Solution:**
```powershell
# Run PowerShell as Administrator
# Right-click PowerShell → Run as Administrator
```

### Issue: "Configuration File Not Found"

**Error Message:**
```
Configuration file not found at: ...
```

**Solution:**
```powershell
# Check config exists
Test-Path .\WindowsMaintenance\config\maintenance-config.json

# Copy example if missing
Copy-Item .\examples\config-homeuser.json `
          .\WindowsMaintenance\config\maintenance-config.json
```

### Issue: "Pester Tests Fail"

**Error Message:**
```
Module 'Pester' version '3.x.x' is currently loaded...
```

**Solution:**
```powershell
# Uninstall old Pester
Get-Module Pester -ListAvailable | Uninstall-Module -Force

# Install Pester 5.x
Install-Module -Name Pester -Force -SkipPublisherCheck
```

### Issue: GUI Won't Launch

**Solutions:**
```powershell
# Check .NET Framework
# Windows 10/11 includes .NET 4.5+ by default
[System.Environment]::Version

# Try with explicit PowerShell
powershell.exe -File .\Start-MaintenanceGUI.ps1

# Check for errors
.\Start-MaintenanceGUI.ps1 -Verbose
```

### Issue: Scheduled Task Doesn't Run

**Check:**
```powershell
# Verify task exists
Get-ScheduledTask -TaskName "WeeklyMaintenance"

# Check task history
Get-ScheduledTask -TaskName "WeeklyMaintenance" | Get-ScheduledTaskInfo

# Check Event Viewer
# Event Viewer → Windows Logs → Application
# Look for Task Scheduler errors
```

**Common Causes:**
- Task not set to "Run with highest privileges"
- Incorrect path to script
- Computer was off/asleep at scheduled time
- PowerShell execution policy

---

## Advanced Installation

### Multi-Computer Deployment

**Using Group Policy:**
1. Create Group Policy Object
2. Computer Configuration → Policies → Windows Settings → Scripts
3. Add startup/shutdown scripts
4. Deploy `Run-Maintenance.ps1` to network share

**Using PowerShell Remoting:**
```powershell
# Deploy to multiple computers
$computers = @("PC1", "PC2", "PC3")

foreach ($computer in $computers) {
    $session = New-PSSession -ComputerName $computer

    # Copy files
    Copy-Item -Path ".\*" -Destination "C:\MaintenanceFramework" `
              -ToSession $session -Recurse

    # Create scheduled task
    Invoke-Command -Session $session -ScriptBlock {
        C:\MaintenanceFramework\Scripts\Install-MaintenanceTask.ps1 `
          -TaskName "WeeklyMaintenance" `
          -DayOfWeek Sunday `
          -StartTime "02:00"
    }

    Remove-PSSession $session
}
```

### Network Share Installation

```powershell
# Install to network share
$networkPath = "\\FileServer\MaintenanceFramework"

# Copy files
Copy-Item -Path ".\*" -Destination $networkPath -Recurse

# Create scheduled task pointing to network share
schtasks /create /tn "WeeklyMaintenance" `
  /tr "powershell.exe -ExecutionPolicy Bypass -File '\\FileServer\MaintenanceFramework\Run-Maintenance.ps1'" `
  /sc weekly /d SUN /st 02:00 /ru SYSTEM
```

### Silent Installation

```powershell
# Unattended installation script
$installPath = "C:\MaintenanceFramework"

# Create directory
New-Item -Path $installPath -ItemType Directory -Force

# Copy files (assuming current directory has files)
Copy-Item -Path ".\*" -Destination $installPath -Recurse -Force

# Set execution policy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force

# Copy default configuration
Copy-Item "$installPath\examples\config-homeuser.json" `
          "$installPath\WindowsMaintenance\config\maintenance-config.json" -Force

# Create scheduled task
& "$installPath\Scripts\Install-MaintenanceTask.ps1" `
  -TaskName "WeeklyMaintenance" `
  -DayOfWeek Sunday `
  -StartTime "02:00"

Write-Host "Installation complete!"
```

---

## Uninstallation

### Remove Scheduled Tasks

```powershell
# List maintenance tasks
Get-ScheduledTask | Where-Object { $_.TaskName -like "*Maintenance*" }

# Remove specific task
Unregister-ScheduledTask -TaskName "WeeklyMaintenance" -Confirm:$false
```

### Remove Files

```powershell
# Remove framework directory
Remove-Item -Path "C:\MaintenanceFramework" -Recurse -Force

# Remove logs (optional)
Remove-Item -Path "C:\Temp\MaintenanceLogs" -Recurse -Force
Remove-Item -Path "C:\Temp\MaintenanceReports" -Recurse -Force
```

### Restore Execution Policy (Optional)

```powershell
# Restore to default (optional)
Set-ExecutionPolicy -ExecutionPolicy Restricted -Scope CurrentUser
```

---

## Post-Installation Checklist

- [ ] PowerShell version 5.1+ verified
- [ ] Administrator privileges confirmed
- [ ] Files extracted to installation directory
- [ ] File structure verified
- [ ] Execution policy configured
- [ ] Configuration file customized
- [ ] Configuration validated
- [ ] WhatIf mode test successful
- [ ] First real run successful
- [ ] Logs reviewed
- [ ] GUI tested (if using GUI)
- [ ] Scheduled task created (if desired)
- [ ] Documentation reviewed

---

## Getting Help

### Documentation
- **README.md** - Overview and quick start
- **CONFIG.md** - Configuration reference
- **GUI-GUIDE.md** - GUI user guide
- **FEATURE_PARITY.md** - Feature details

### Testing
```powershell
# Validate installation
.\Scripts\Test-MaintenanceConfig.ps1

# Run comprehensive tests
cd WindowsMaintenance\Tests
.\Invoke-Tests.ps1
```

### Support Resources
- Check log files in configured LogsPath
- Review error messages carefully
- Use WhatIf mode for testing
- Consult troubleshooting section above

---

**Version:** 4.0.0
**Last Updated:** October 2025
**Platform:** Windows 10/11
**Author:** Miguel Velasco
