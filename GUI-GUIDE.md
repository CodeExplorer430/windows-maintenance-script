# Windows Maintenance Framework - GUI User Guide

**Version:** 4.0.0
**Last Updated:** October 2025

---

## Overview

The Windows Maintenance Framework GUI provides a user-friendly graphical interface for managing system maintenance tasks. No command-line experience is required - all features are accessible through intuitive point-and-click operations.

---

## Table of Contents

- [Getting Started](#getting-started)
- [Main Window](#main-window)
- [Configuration Editor](#configuration-editor)
- [Log Viewer](#log-viewer)
- [Schedule Maintenance](#schedule-maintenance)
- [Common Tasks](#common-tasks)
- [Troubleshooting](#troubleshooting)

---

## Getting Started

### Prerequisites

- Windows 10/11
- PowerShell 5.1 or later (built-in)
- .NET Framework 4.5+ (built-in)
- Administrator privileges

### Launching the GUI

**Method 1: Double-Click**
1. Navigate to the framework directory
2. Right-click `Start-MaintenanceGUI.ps1`
3. Select "Run with PowerShell"

**Method 2: From PowerShell**
```powershell
.\Start-MaintenanceGUI.ps1
```

**Method 3: With Custom Configuration**
```powershell
.\Start-MaintenanceGUI.ps1 -ConfigPath ".\examples\config-developer.json"
```

### First Launch

When you first launch the GUI:

1. **Check Administrator Status**
   - Top of window shows privilege status
   - Green ✓ = Administrator (required for execution)
   - Red ⚠ = Not Administrator (can view/configure only)

2. **Verify Configuration**
   - Configuration path is shown below status
   - Default: `WindowsMaintenance\config\maintenance-config.json`

3. **Review Modules**
   - All available modules are listed
   - Checked modules will be executed

---

## Main Window

![Main Window Components]

### Window Sections

#### 1. Menu Bar

**File Menu**
- **Load Configuration...** - Load a different configuration file
- **Save Configuration** - Save current settings
- **Exit** - Close the application

**Tools Menu**
- **Configuration Editor...** - Open advanced configuration
- **Log Viewer...** - View maintenance logs
- **Schedule Maintenance Task...** - Set up automated tasks

**Help Menu**
- **About** - Version and author information

#### 2. Status Area

**Administrator Privileges Indicator**
- ✅ Green: Running with Administrator privileges
- ⚠️ Red: NOT running as Administrator (must restart)

**Configuration Path**
- Shows currently loaded configuration file
- Click File → Load Configuration to change

#### 3. Module Selection

**Available Modules:**

| Module | Description | Typical Time |
|--------|-------------|--------------|
| **SystemUpdates** | Windows Updates, app updates | 5-10 min |
| **DiskMaintenance** | Cleanup temp files, caches | 3-8 min |
| **SystemHealthRepair** | DISM, SFC system checks | 10-20 min |
| **SecurityScans** | Windows Defender scans | 5-30 min |
| **DeveloperMaintenance** | Dev tool cache cleanup | 5-15 min |
| **PerformanceOptimization** | Startup analysis, resource check | 5-10 min |
| **NetworkMaintenance** | Network diagnostics, reset | 2-5 min |

**Selecting Modules:**
- ✅ Check boxes for modules you want to run
- ❌ Uncheck to skip modules
- Select All/None using Ctrl+Click

#### 4. Execution Options

**🔸 Simulation Mode (WhatIf)**
- ✅ **IMPORTANT**: Test mode - no changes made
- ❌ Normal mode - changes will be applied
- **Recommendation**: Always test with WhatIf first!

**🔸 Detailed Output**
- Enables comprehensive logging
- Creates detailed log files
- Useful for troubleshooting

**🔸 Manage Event Logs**
- Automatically optimize event logs
- Archive large logs
- Cleanup old entries

**🔸 Silent Mode**
- No user prompts during execution
- Useful for scheduled tasks
- All actions logged

**🔸 Fast Mode**
- Reduced operation timeouts
- Skips non-critical checks
- Faster but less thorough

**🔸 Security Scan Level**
- **Quick**: 5-10 minute scan (default)
- **Full**: 30-60 minute comprehensive scan
- **Custom**: User-defined settings

**⏱️ Estimated Time**
- Updates automatically based on selected modules
- Accounts for Fast Mode if enabled
- Actual time may vary

#### 5. Progress Area

**Progress Bar**
- Shows overall completion percentage
- Updates during execution
- Green when complete

**Status Console**
- Real-time status messages
- Scrollable output
- Auto-updates during execution

#### 6. Action Buttons

**▶ Start Maintenance**
- Begins maintenance with current settings
- Disabled while running
- Requires Administrator privileges

**■ Stop**
- Emergency stop (not always immediate)
- Enabled during execution
- Some operations may complete

**📄 View Logs**
- Opens log viewer
- Access to all past logs
- Filter and search capabilities

**✖ Exit**
- Closes the application
- Prompts if maintenance is running

---

## Configuration Editor

Access via: **Tools → Configuration Editor...**

### General Tab

**Logs Path**
- Where maintenance logs are saved
- Default: `C:\Temp\MaintenanceLogs`
- Click to edit path

**Reports Path**
- Where analysis reports are saved
- Default: `C:\Temp\MaintenanceReports`
- Click to edit path

**Max Event Log Size (MB)**
- Threshold for event log warnings
- Range: 10-1000 MB
- Default: 100 MB

### Disk Maintenance Tab

Configure which cleanup operations to perform:

- ✅ **Recycle Bin Cleanup** - Empty recycle bin
- ✅ **Temp File Cleanup** - User temp files
- ✅ **Windows Temp Cleanup** - System temp files
- ✅ **Browser Cache Cleanup** - Browser caches
- ✅ **Windows Update Cleanup** - Update files
- ✅ **Thumbnail Cache Cleanup** - Thumbnail database
- ✅ **Error Report Cleanup** - Crash dumps
- ✅ **Prefetch Cleanup** - Prefetch files
- ✅ **Log File Cleanup** - Old log files
- ✅ **Delivery Optimization** - Windows delivery cache

**Retention Days:**
- **Temp File Retention**: Days to keep temp files (1-365)
- **Log File Retention**: Days to keep logs (1-365)

### Developer Tools Tab

Enable/disable cleanup for development tools:

**Languages & Runtimes:**
- NPM (Node.js)
- Python/pip
- JDK/Maven/Gradle
- .NET SDK
- Composer (PHP)
- PostgreSQL

**IDEs & Editors:**
- VS Code
- Visual Studio 2022
- JetBrains IDEs (IntelliJ, PyCharm, etc.)

**Build Tools:**
- Docker
- MinGW (GCC/G++)
- Windows SDK

**Other Tools:**
- Git/Version Control
- Database Tools
- Adobe Creative Suite
- VC++ Redistributables
- Legacy C/C++ Tools

**Saving Changes:**
1. Make your changes
2. Click **Save** button
3. Changes take effect immediately

---

## Log Viewer

Access via: **Tools → Log Viewer...** or **📄 View Logs** button

### Features

**🗂️ Log File Selector**
- Dropdown shows all log files
- Sorted by date (newest first)
- Auto-detects logs in configured path

**🔄 Refresh Button**
- Reload log file list
- Use after maintenance completes

**📁 Open Folder Button**
- Opens log directory in Explorer
- Quick access to all logs

**🔍 Filter Function**
- Enter search text or regex
- Click **Filter** to apply
- Shows only matching lines

**📄 Log Content**
- Read-only text view
- Monospace font for alignment
- Scroll bars for navigation

### Using the Log Viewer

**To view the latest log:**
1. Open Log Viewer
2. Top entry is most recent
3. Click to load

**To search logs:**
1. Enter search term in Filter box
2. Click Filter button
3. Results show only matching lines

**Examples:**
- `ERROR` - Show only errors
- `SUCCESS` - Show successful operations
- `DiskMaintenance` - Show disk cleanup logs
- `\d+ MB` - Show size information (regex)

---

## Schedule Maintenance

Access via: **Tools → Schedule Maintenance Task...**

### Creating a Scheduled Task

**Task Name**
- Unique identifier for the task
- Default: `WindowsMaintenance`
- Example: `WeeklyMaintenance`

**Frequency**
- **Daily**: Runs every day
- **Weekly**: Runs on specific day of week
- **Monthly**: Runs on specific day of month

**Day of Week** (Weekly only)
- Monday through Sunday
- Default: Sunday

**Start Time**
- 24-hour format (HH:MM)
- Default: 02:00 (2 AM)
- Recommended: Off-hours (1-4 AM)

**Creating the Task:**
1. Configure settings
2. Click **Create Task**
3. UAC prompt (requires Administrator)
4. Task created in Windows Task Scheduler

**Managing Scheduled Tasks:**
- Open Task Scheduler (taskschd.msc)
- Navigate to Task Scheduler Library
- Find your task by name
- Edit, disable, or delete as needed

---

## Common Tasks

### Quick Cleanup (5-10 minutes)

1. Launch GUI
2. Select only:
   - DiskMaintenance
   - SystemUpdates
3. Enable **Fast Mode**
4. Click **▶ Start Maintenance**

### Full System Maintenance (30-60 minutes)

1. Launch GUI as Administrator
2. Select all modules
3. Set Scan Level to **Full**
4. Enable **Detailed Output**
5. Click **▶ Start Maintenance**

### Testing Before First Run

1. Launch GUI
2. Select desired modules
3. Enable **Simulation Mode (WhatIf)**
4. Click **▶ Start Maintenance**
5. Review status output
6. Run again without WhatIf

### Developer Workstation Cleanup

1. Load **config-developer.json**
   - File → Load Configuration
   - Select `examples\config-developer.json`
2. Verify developer tools are selected
3. Click **▶ Start Maintenance**

### Schedule Weekly Maintenance

1. Tools → Schedule Maintenance Task
2. Task Name: `WeeklyMaintenance`
3. Frequency: **Weekly**
4. Day: **Sunday**
5. Time: **02:00**
6. Click **Create Task**

---

## Troubleshooting

### GUI Won't Launch

**PowerShell Execution Policy Error**
```powershell
# Run as Administrator
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**.NET Framework Error**
- Windows 10/11 includes .NET 4.5+
- Update Windows if missing
- Download .NET Framework 4.8 from Microsoft

### "Not Running as Administrator" Warning

**Problem**: Red warning at top of GUI

**Solution**:
1. Close the GUI
2. Right-click `Start-MaintenanceGUI.ps1`
3. Select "Run with PowerShell" as Administrator
4. Or: Run PowerShell as Administrator first, then launch

### Modules Not Appearing

**Problem**: Module checklist is empty

**Solution**:
1. Check configuration file exists
2. File → Load Configuration
3. Verify JSON syntax
4. Use `Test-MaintenanceConfig.ps1` to validate

### Maintenance Fails to Start

**Check:**
- ✅ Administrator privileges
- ✅ At least one module selected
- ✅ Configuration file valid
- ✅ WindowsMaintenance module exists

**View Error Details**:
1. Open Log Viewer
2. Check latest log
3. Search for "ERROR"

### GUI Freezes During Execution

**Expected Behavior**:
- GUI will freeze during maintenance
- This is normal (synchronous execution)
- Progress updates may be delayed
- Wait for completion message

**If Stuck**:
- Wait 10-15 minutes
- Check Task Manager for PowerShell activity
- If no activity, close and retry

### Configuration Changes Not Saved

**Solution**:
1. Make changes in Configuration Editor
2. Click **Save** button (bottom right)
3. Check for success message
4. Verify with File → Load Configuration

### Logs Not Showing in Log Viewer

**Check**:
1. Verify Logs Path in Configuration Editor
2. Ensure path exists
3. Check folder permissions
4. Click **Refresh** button
5. Use **Open Folder** to verify location

### Scheduled Task Not Created

**Common Issues**:
1. UAC was denied (click Yes on prompt)
2. Not running as Administrator
3. `Install-MaintenanceTask.ps1` not found

**Manual Creation**:
1. Open Task Scheduler (taskschd.msc)
2. Create Basic Task
3. Program: `powershell.exe`
4. Arguments: `-File "C:\path\to\Run-Maintenance.ps1"`
5. Run with highest privileges

---

## Best Practices

### For First-Time Users

1. **Always test with WhatIf first**
   - Enable Simulation Mode
   - Review what would happen
   - Then run for real

2. **Start with fewer modules**
   - Try DiskMaintenance only
   - Add modules gradually
   - Build confidence

3. **Review logs after each run**
   - Check for errors
   - Verify expected results
   - Learn what each module does

### For Regular Maintenance

1. **Schedule weekly maintenance**
   - Sunday nights recommended
   - 2-4 AM when computer idle
   - Use config-homeuser.json

2. **Monthly deep cleaning**
   - Use config-enterprise.json
   - Enable all modules
   - Full security scan

3. **Monitor disk space**
   - Check before and after
   - Review cleanup amounts
   - Adjust retention days if needed

### For Developer Workstations

1. **Use config-developer.json**
   - Optimized for dev tools
   - Balanced retention days
   - Performance focused

2. **Run after major updates**
   - After SDK updates
   - After IDE updates
   - After package updates

3. **Customize tool selection**
   - Only enable tools you use
   - Disable unused tools
   - Saves execution time

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Alt+F` | Open File menu |
| `Alt+T` | Open Tools menu |
| `Alt+H` | Open Help menu |
| `Ctrl+L` | Open Log Viewer |
| `Ctrl+E` | Open Configuration Editor |
| `Ctrl+Q` | Exit application |
| `Space` | Toggle selected module (when focused) |

---

## Tips and Tricks

### Quick Module Selection

- **Ctrl+Click** on checklist to toggle all
- **Click and drag** to select multiple
- **Space bar** to toggle focused item

### Faster Execution

- Enable **Fast Mode**
- Use **Quick** scan level
- Select fewer modules
- Disable **Detailed Output**

### Better Logging

- Enable **Detailed Output**
- Keep **Manage Event Logs** on
- Regular

ly view logs
- Archive important logs

### Configuration Management

- Keep multiple configs for different scenarios
- Use examples as templates
- Name configs descriptively
- Backup working configurations

---

## Advanced Features

### Custom Configuration Profiles

Create multiple configurations for different needs:

**Quick Daily** (`config-daily.json`)
- DiskMaintenance only
- Fast Mode enabled
- Quick scan

**Weekly Standard** (`config-weekly.json`)
- All modules except heavy ones
- Normal settings
- Quick scan

**Monthly Deep** (`config-monthly.json`)
- All modules
- Detailed output
- Full scan

**Load in GUI**: File → Load Configuration

### Command-Line Launch with Config

```powershell
# Launch GUI with specific config
.\Start-MaintenanceGUI.ps1 -ConfigPath ".\config-daily.json"
```

### Integration with Other Tools

**Task Scheduler**:
- Schedule GUI launch (automated)
- Use Silent Mode for unattended

**Monitoring Tools**:
- Parse log files
- Alert on errors
- Track disk space

---

## FAQ

**Q: Can I run this while working?**
A: Yes, but performance may be impacted. Fast Mode helps. Recommended during off-hours.

**Q: How often should I run maintenance?**
A: Weekly for general use, monthly for deep cleaning. Daily for high-use systems.

**Q: Will this delete my files?**
A: No, only temporary files, caches, and system cleanup. Your documents are safe.

**Q: Do I need to run as Administrator?**
A: Yes, for execution. You can view/configure without Administrator.

**Q: Can I schedule this to run automatically?**
A: Yes, use Tools → Schedule Maintenance Task.

**Q: What if maintenance fails?**
A: Check logs, verify Administrator privileges, try WhatIf mode, review error messages.

**Q: How much disk space will this free?**
A: Varies widely. Typically 1-10 GB. Check logs for details.

**Q: Is this safe for my computer?**
A: Yes, uses only Windows built-in tools and safe cleanup operations.

---

## Support and Resources

- **Main Documentation**: README.md
- **Configuration Reference**: WindowsMaintenance/CONFIG.md
- **Feature Details**: FEATURE_PARITY.md
- **Command-Line**: Run-Maintenance.ps1 documentation

---

**Version**: 4.0.0
**Last Updated**: October 2025
**Author**: Miguel Velasco
