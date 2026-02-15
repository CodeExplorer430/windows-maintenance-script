# Maintenance Tools

This directory contains standalone utility scripts, helpers, and maintenance tools that support the core framework but are not part of the main execution flow.

## Available Tools

### 1. GUI Launcher
- **File:** `Start-MaintenanceGUI.ps1`
- **Description:** A Windows Forms-based graphical interface for configuring and running maintenance tasks.

### 2. Task Installer
- **File:** `Install-MaintenanceTask.ps1`
- **Description:** Helper script to install the maintenance task into Windows Task Scheduler.

### 3. Config Validator
- **File:** `Test-MaintenanceConfig.ps1`
- **Description:** Validates your JSON configuration file against the schema.

### 4. Script Signer
- **File:** `Sign-AllScripts.ps1`
- **Description:** Batch signs all PowerShell scripts in the project using a code-signing certificate.

## Adding New Tools
Place any standalone scripts or binary tools here that are useful for debugging or extending the maintenance framework.
