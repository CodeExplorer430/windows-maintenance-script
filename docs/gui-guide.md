# Windows Maintenance Framework - GUI User Guide

**Version:** 4.2.0
**Last Updated:** February 2026

---

## Overview

The Windows Maintenance Framework GUI provides a user-friendly graphical interface for managing system maintenance tasks. It is designed to be responsive, asynchronous, and fully compatible with both PowerShell 5.1 and PowerShell 7.4+.

---

## Getting Started

### Prerequisites

- **Windows 10/11**
- **PowerShell**: 5.1 or 7.4 (Core)
- **Privileges**: Administrator (Required for execution)

### Launching the GUI

**Method 1: Direct Run**
Right-click `Tools/Start-MaintenanceGUI.ps1` and select "Run with PowerShell".

**Method 2: From Terminal**
```powershell
.\Tools\Start-MaintenanceGUI.ps1
```

---

## Main Window Components

### 1. Status Dashboard
- **Admin Status**: Displays a Green checkmark if running elevated. Red warning if not.
- **Environment**: Displays the detected PowerShell version (5.1 or 7.4).
- **Config Path**: Shows the currently active settings file.

### 2. Module Selection
Check the modules you wish to run. New in v4.2.0:
- **Parallel Optimization**: Automatically enabled if running on PowerShell 7.
- **Tool Selection**: Choose from 13 different maintenance areas.

### 2b. Application Selection
Use the **Apps** tab to enable or disable maintenance toggles for detected software:
- **Search + Filter**: Quickly locate apps and show only installed items.
- **Select All / None**: Bulk selection for large lists.
- **Save App Selections**: Persists overrides to `config/maintenance-config.user.json`.

Selections map to module-specific toggles (e.g., Developer and Multimedia apps) and do not uninstall software.

### 3. Execution Options
- **Simulation Mode (WhatIf)**: **HIGHLY RECOMMENDED.** Shows what will happen without making changes.
- **Silent Mode**: Suppresses all pop-ups and message boxes.
- **Detailed Output**: Enables maximum verbosity in the GUI console and log files.

---

## Real-Time Monitoring

The GUI features a **Non-Blocking Architecture**:
- The main window remains responsive while maintenance runs.
- **Status Console**: Displays live output from `Write-Information` streams.
- **Progress Bar**: Shows granular progress for individual module tasks.
- **Stop Button**: Allows for safe termination of background maintenance jobs.

---

## Post-Maintenance Actions

### Log Viewing
Click **"View Logs"** to open the integrated Log Viewer.
- **Filter**: Search logs by Level (ERROR, SUCCESS) or Module name.
- **Open Folder**: Quickly browse the log directory in Windows Explorer.

### Results Analysis
Reports are automatically saved to your configured `ReportsPath`. These provide a hardware health summary and detailed execution metrics.

---

## Troubleshooting the GUI

- **Window Freezing**: If the window becomes unresponsive, check if a sub-task (like a legacy installer) is waiting for input in a hidden window.
- **Missing Modules**: Ensure your `maintenance-config.json` is valid by running `.\Tools\Test-MaintenanceConfig.ps1`.
- **No Console Output**: Ensure `$InformationPreference` is not being overridden in your user profile.

---

**Version**: 4.2.0
**Author**: Miguel Velasco
