# Windows Maintenance Framework - Installation Guide

**Version:** 4.2.0
**Date:** February 2026
**Platform:** Windows 10/11 | PowerShell 5.1 & 7.4+

---

## Prerequisites

### System Requirements

- **Operating System**: Windows 10 (1809+) or Windows 11.
- **PowerShell**: 
  - **PowerShell 5.1** (Built-in) - Minimum requirement.
  - **PowerShell 7.4+** (Core) - **Recommended** for parallel performance.
- **Privileges**: Administrator access is required for most maintenance operations.
- **Disk Space**: 50 MB for framework, plus space for logs/reports.

### Checking Prerequisites

```powershell
# 1. Check PowerShell version
$PSVersionTable.PSVersion

# 2. Check Administrator status
$current = [Security.Principal.WindowsIdentity]::GetCurrent()
(New-Object Security.Principal.WindowsPrincipal($current)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
```

---

## Quick Installation

1. **Clone or Download**
   ```powershell
   git clone <repository-url> C:\Maintenance
   cd C:\Maintenance
   ```

2. **Set Execution Policy** (if not already set)
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

3. **Verify Configuration**
   ```powershell
   .\Tools\Test-MaintenanceConfig.ps1
   ```

4. **Dry Run (Safety First)**
   ```powershell
   .\Run-Maintenance.ps1 -WhatIf
   ```

---

## Detailed Installation

### Step 1: File Structure Verification
Ensure the following key directories exist:
- `Modules/`: Contains 13 feature modules and 10 common utilities.
- `Tools/`: Contains installer, GUI, and signer scripts.
- `Config/`: Contains `maintenance-config.json`.
- `Tests/`: Contains the Pester 5.x test suite.

### Step 2: Install Pester 5 (For Developers/Testers)
The framework is optimized for **Pester 5.x**.
```powershell
# Install for current user
Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser -MinimumVersion 5.0
```

### Step 3: Initial Configuration
Copy an example configuration to get started:
```powershell
# Copy the 'homeuser' example to the active config
Copy-Item .\Examples\config-homeuser.json .\Config\maintenance-config.json -Force
```

---

## Verification

### Test 1: Module Loading
```powershell
Import-Module .\WindowsMaintenance.psd1 -Force
Get-Command -Module WindowsMaintenance
```
*Expected: `Invoke-WindowsMaintenance` is listed.*

### Test 2: Multi-Version Check
If you have both PS 5.1 and PS 7 installed, run the test suite in both:
```powershell
# Test in standard PowerShell
powershell -File .\Tests\Invoke-Tests.ps1

# Test in PowerShell Core
pwsh -File .\Tests\Invoke-Tests.ps1
```

---

## Automated Maintenance

The framework includes a built-in installer for the Windows Task Scheduler.

```powershell
# Launches an interactive wizard to set up your schedule
.\Tools\Install-MaintenanceTask.ps1 -Interactive
```

**Manual CLI setup:**
```powershell
# Schedule for every Sunday at 3 AM
.\Tools\Install-MaintenanceTask.ps1 -Schedule Weekly -DaysOfWeek Sunday -Time "03:00"
```

---

## Uninstallation

1. **Remove Scheduled Task**
   ```powershell
   Unregister-ScheduledTask -TaskName "Windows Maintenance" -Confirm:$false
   ```

2. **Delete Files**
   Simply delete the installation folder.

---

## Troubleshooting

- **"Script not signed"**: Set your execution policy to `Bypass` or use `.\Tools\Sign-AllScripts.ps1` if you have a code-signing certificate.
- **"Access Denied"**: You must run the scripts from an elevated ("Run as Administrator") window.
- **"Module not found"**: Ensure you are in the project root before running `Import-Module`.

---

**Last Updated:** February 2026
**Author:** Miguel Velasco
