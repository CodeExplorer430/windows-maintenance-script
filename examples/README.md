# Windows Maintenance Framework - Example Configurations

This directory contains example configuration files for different use cases. Copy and modify these files to suit your specific needs.

---

## Available Configurations

### 1. config-minimal.json
**Use Case:** Quick, basic maintenance

**Enabled Modules:**
- DiskMaintenance
- SystemUpdates

**Best For:**
- Quick cleanup runs
- Low-resource systems
- Emergency maintenance
- Testing the framework

**Execution Time:** ~5-10 minutes

---

### 2. config-homeuser.json
**Use Case:** Typical home/personal computer

**Enabled Modules:**
- SystemUpdates
- DiskMaintenance
- SystemHealthRepair
- SecurityScans
- PerformanceOptimization
- NetworkMaintenance

**Best For:**
- Personal computers
- Home office workstations
- Non-developer systems
- General purpose PCs

**Developer Tools:** Only VC++ Redistributables enabled
**Execution Time:** ~15-20 minutes

---

### 3. config-developer.json
**Use Case:** Software development workstation

**Enabled Modules:**
- DiskMaintenance
- DeveloperMaintenance
- PerformanceOptimization
- SystemUpdates

**Best For:**
- Software developers
- Full-stack engineers
- DevOps workstations
- Multi-language development

**Developer Tools Enabled:**
- NPM (Node.js)
- Python/pip
- Docker
- JDK/Maven/Gradle
- .NET SDK
- Windows SDK
- VC++ Redistributables
- JetBrains IDEs
- Visual Studio 2022
- VS Code
- Git/Version Control

**Execution Time:** ~15-25 minutes

---

### 4. config-enterprise.json
**Use Case:** Comprehensive monthly maintenance

**Enabled Modules:** ALL modules

**Best For:**
- Monthly deep maintenance
- Enterprise workstations
- Comprehensive cleanup
- Systems with all tools installed

**Developer Tools:** ALL 14 tools enabled
**Execution Time:** ~30-60 minutes

---

## How to Use These Configurations

### Method 1: Copy to Main Config

```powershell
# Replace the main configuration
Copy-Item .\examples\config-homeuser.json .\WindowsMaintenance\config\maintenance-config.json -Force

# Run maintenance
Import-Module .\WindowsMaintenance.psd1
Invoke-WindowsMaintenance
```

### Method 2: Use Directly

```powershell
# Use without copying
Invoke-WindowsMaintenance -ConfigPath ".\examples\config-developer.json"
```

### Method 3: Create Custom Configuration

```powershell
# Copy an example as starting point
Copy-Item .\examples\config-developer.json .\my-custom-config.json

# Edit to your needs
notepad .\my-custom-config.json

# Test the configuration
.\Scripts\Test-MaintenanceConfig.ps1 -ConfigPath ".\my-custom-config.json"

# Run with your custom config
Invoke-WindowsMaintenance -ConfigPath ".\my-custom-config.json"
```

---

## Configuration Comparison

| Feature | Minimal | Home User | Developer | Enterprise |
|---------|---------|-----------|-----------|------------|
| **Disk Cleanup** | Basic | Full | Full | Full |
| **Windows Updates** | ✅ | ✅ | ✅ | ✅ |
| **System Health** | ❌ | ✅ | ❌ | ✅ |
| **Security Scans** | ❌ | ✅ | ❌ | ✅ |
| **Developer Tools** | ❌ | ❌ | 11/14 | 14/14 |
| **Performance Optimization** | ❌ | ✅ | ✅ | ✅ |
| **Network Maintenance** | ❌ | ✅ | ❌ | ✅ |
| **Execution Time** | 5-10 min | 15-20 min | 15-25 min | 30-60 min |

---

## Customizing Configurations

### Common Customizations

#### 1. Change Log Locations

```json
{
  "LogsPath": "D:\\Logs\\Maintenance",
  "ReportsPath": "D:\\Reports\\Maintenance"
}
```

#### 2. Adjust Retention Days

```json
{
  "DiskMaintenance": {
    "TempFileRetentionDays": 3,
    "LogFileRetentionDays": 14
  },
  "DeveloperMaintenance": {
    "NPMCacheRetentionDays": 30,
    "DockerImageRetentionDays": 60
  }
}
```

#### 3. Enable/Disable Specific Tools

```json
{
  "DeveloperMaintenance": {
    "EnableNPM": true,
    "EnablePython": true,
    "EnableDocker": false,
    "EnableVSCode": true
  }
}
```

#### 4. Selective Module Execution

```json
{
  "EnabledModules": [
    "DiskMaintenance",
    "DeveloperMaintenance"
  ]
}
```

---

## Configuration Validation

Always validate your configuration before running:

```powershell
# Validate configuration
.\Scripts\Test-MaintenanceConfig.ps1 -ConfigPath ".\my-config.json"

# Test with WhatIf mode
Invoke-WindowsMaintenance -ConfigPath ".\my-config.json" -WhatIf
```

---

## Scheduled Task Configurations

### Daily Quick Cleanup

```powershell
# Use minimal config for daily runs
.\Scripts\Install-MaintenanceTask.ps1 `
  -TaskName "DailyCleanup" `
  -ConfigPath ".\examples\config-minimal.json" `
  -StartTime "03:00" `
  -RunDaily
```

### Weekly Standard Maintenance

```powershell
# Use home user or developer config
.\Scripts\Install-MaintenanceTask.ps1 `
  -TaskName "WeeklyMaintenance" `
  -ConfigPath ".\examples\config-homeuser.json" `
  -DayOfWeek Sunday `
  -StartTime "02:00"
```

### Monthly Full Maintenance

```powershell
# Use enterprise config for comprehensive cleanup
.\Scripts\Install-MaintenanceTask.ps1 `
  -TaskName "MonthlyMaintenance" `
  -ConfigPath ".\examples\config-enterprise.json" `
  -MonthlyDay 1 `
  -StartTime "01:00"
```

---

## Performance Tips

### Faster Execution
- Use `config-minimal.json` for quick runs
- Disable unused developer tools
- Set shorter retention days
- Use Quick security scans

### More Thorough Cleanup
- Use `config-enterprise.json`
- Set longer retention days (more aggressive cleanup)
- Enable all modules
- Run less frequently (monthly)

---

## Configuration Schema

All configurations must follow the JSON schema defined in the main configuration file. Required fields:

```json
{
  "EnabledModules": ["array", "of", "module", "names"],
  "LogsPath": "string",
  "ReportsPath": "string",
  "MaxEventLogSizeMB": 100,
  "DiskMaintenance": { "object" },
  "DeveloperMaintenance": { "object" },
  "PerformanceOptimization": { "object" }
}
```

For complete schema reference, see: **[WindowsMaintenance/CONFIG.md](../WindowsMaintenance/CONFIG.md)**

---

## Creating Your Own Configuration

### Step-by-Step Guide

1. **Choose a base configuration**
   ```powershell
   Copy-Item .\examples\config-homeuser.json .\my-config.json
   ```

2. **Edit module selection**
   ```json
   "EnabledModules": ["DiskMaintenance", "SystemUpdates", "..."]
   ```

3. **Configure each module**
   - Review options for each enabled module
   - Set retention days appropriately
   - Enable/disable specific features

4. **Validate configuration**
   ```powershell
   .\Scripts\Test-MaintenanceConfig.ps1 -ConfigPath ".\my-config.json"
   ```

5. **Test with WhatIf**
   ```powershell
   Invoke-WindowsMaintenance -ConfigPath ".\my-config.json" -WhatIf
   ```

6. **Run the maintenance**
   ```powershell
   Invoke-WindowsMaintenance -ConfigPath ".\my-config.json"
   ```

---

## Best Practices

1. **Start Conservative** - Begin with minimal or home user config
2. **Test with WhatIf** - Always test before real execution
3. **Monitor Execution Time** - Adjust modules based on available time
4. **Review Logs** - Check logs after each run to verify operation
5. **Adjust Retention** - Fine-tune retention days based on disk space
6. **Regular Updates** - Review and update config as tools change
7. **Version Control** - Keep configuration in version control
8. **Document Changes** - Add comments explaining customizations

---

## Troubleshooting

### Configuration Not Loading
```powershell
# Verify JSON syntax
Get-Content .\my-config.json | ConvertFrom-Json
```

### Module Not Executing
```powershell
# Check if module is in EnabledModules array
(Get-Content .\my-config.json | ConvertFrom-Json).EnabledModules
```

### Tool Not Cleaning
```powershell
# Verify tool is enabled in DeveloperMaintenance section
(Get-Content .\my-config.json | ConvertFrom-Json).DeveloperMaintenance
```

---

## Support

For configuration issues:
1. Validate with `Test-MaintenanceConfig.ps1`
2. Review [CONFIG.md](../WindowsMaintenance/CONFIG.md)
3. Check example configurations for reference
4. Use WhatIf mode to debug

---

**Last Updated:** October 2025
**Framework Version:** 4.0.0
