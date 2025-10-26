# Windows Maintenance Framework

**Enterprise-Grade Windows System Maintenance and Optimization**

Version 4.0.0 | October 2025 | PowerShell 5.1+

---

## Overview

The Windows Maintenance Framework provides comprehensive, automated system maintenance for Windows 10/11 workstations and developer environments. Implementing enterprise-grade best practices from ITIL, ISO 27001, NIST Cybersecurity Framework, and Microsoft Security Baselines.

### Key Features

- **Modular Architecture** - Clean separation of concerns with 7 core modules
- **Configuration-Driven** - JSON-based configuration with schema validation
- **Test Coverage** - Comprehensive Pester 5.x test suite
- **Task Scheduling** - Built-in Windows Task Scheduler integration
- **Safe Execution** - WhatIf mode, timeouts, and intelligent error recovery
- **Detailed Reporting** - Enterprise-grade audit trails and performance analysis
- **Developer-Friendly** - Support for 14+ development tool ecosystems

---

## Quick Start

### Prerequisites

- Windows 10/11 Pro or Enterprise
- PowerShell 5.1 or later
- Administrator privileges

### Installation

1. **Clone or download this repository**
   ```powershell
   git clone <repository-url>
   cd windows-maintenance-script
   ```

2. **Review and configure settings**
   ```powershell
   notepad WindowsMaintenance\config\maintenance-config.json
   ```

3. **Test the configuration (recommended)**
   ```powershell
   # Run in WhatIf mode to see what would happen
   Import-Module .\WindowsMaintenance.psd1
   Invoke-WindowsMaintenance -WhatIf
   ```

4. **Execute maintenance**
   ```powershell
   # Run as Administrator
   Invoke-WindowsMaintenance
   ```

### Scheduled Maintenance

Set up automatic weekly maintenance:

```powershell
# Install scheduled task (requires Administrator)
.\Scripts\Install-MaintenanceTask.ps1 -TaskName "WeeklyMaintenance"
```

---

## Architecture

The framework is organized into modular components:

```
windows-maintenance-script/
├── WindowsMaintenance/          # Main framework directory
│   ├── WindowsMaintenance.psm1  # Root orchestrator module
│   ├── WindowsMaintenance.psd1  # Module manifest
│   ├── Modules/
│   │   ├── Common/              # Shared utilities (8 modules)
│   │   ├── SystemUpdates.psm1   # Windows Update management
│   │   ├── DiskMaintenance.psm1 # Disk cleanup & optimization
│   │   ├── SystemHealthRepair.psm1  # DISM/SFC repairs
│   │   ├── SecurityScans.psm1   # Windows Defender scans
│   │   ├── DeveloperMaintenance.psm1  # 14 dev tool cleanups
│   │   ├── PerformanceOptimization.psm1  # Performance tuning
│   │   └── NetworkMaintenance.psm1  # Network diagnostics
│   ├── config/
│   │   └── maintenance-config.json  # Main configuration
│   └── Tests/                   # Pester test suite
├── Scripts/
│   ├── Install-MaintenanceTask.ps1  # Task scheduler setup
│   └── Test-MaintenanceConfig.ps1   # Config validation
└── scripts/
    └── Windows10-Maintenance-Script.ps1  # ⚠️ DEPRECATED legacy script
```

---

## Modules

### Common Utilities (8 modules)

Shared infrastructure used across all feature modules:

- **Logging** - Comprehensive logging with levels (INFO, SUCCESS, WARNING, ERROR, PROGRESS, DEBUG)
- **StringFormatting** - Safe string interpolation with error prevention
- **SystemDetection** - OS/PowerShell version detection, admin checks
- **MemoryManagement** - Memory optimization and garbage collection
- **SafeExecution** - Command execution with timeouts and error recovery
- **UIHelpers** - Progress bars, message boxes, user interaction
- **RealTimeProgressOutput** - Detailed operation tracking
- **DriveAnalysis** - Drive space monitoring and formatting

### Feature Modules

#### SystemUpdates
- Windows Update check and installation
- Update history reporting
- Windows Store app updates
- Pending reboot detection
- Update service management

#### DiskMaintenance
- Recycle Bin cleanup
- Temporary file cleanup (Windows, User, Browser caches)
- Windows Update cleanup
- Thumbnail cache cleanup
- Error report cleanup
- Prefetch cleanup
- Log file cleanup
- Delivery Optimization cleanup
- Disk Cleanup utility integration

#### SystemHealthRepair
- DISM health checks (CheckHealth, ScanHealth, RestoreHealth)
- SFC system file scanner
- Component store cleanup
- Image health verification
- Comprehensive repair reporting

#### SecurityScans
- Windows Defender quick/full scans
- Signature updates
- Threat detection and reporting
- Security baseline verification
- Firewall status checks
- UAC verification

#### DeveloperMaintenance (14 Tools)

Automated cleanup for development environments:

| Tool | What It Cleans |
|------|----------------|
| **NPM** | npm cache, node_modules, package caches |
| **Python/pip** | pip cache, __pycache__, dist/build folders |
| **Docker** | Unused images, containers, volumes, build cache |
| **JDK/Maven/Gradle** | Maven repository, Gradle cache, JVM temp files |
| **MinGW** | GCC temp files, object files, compilation cache |
| **.NET SDK** | NuGet cache, template engine, compilation artifacts |
| **Windows SDK** | SDK cache, debug symbols, temp files |
| **VC++ Redistributables** | Installation logs, temp files |
| **Composer (PHP)** | Package cache, vendor directories |
| **PostgreSQL** | Server logs, temp files, command history |
| **JetBrains IDEs** | IntelliJ/PyCharm/WebStorm/CLion/Rider caches |
| **Visual Studio 2022** | Cache, temp files, NuGet, IntelliCode logs |
| **VS Code** | Logs, extension cache, VSIX, workspace storage |
| **Git** | Git garbage collection, object optimization |
| **Database Tools** | MySQL Workbench, XAMPP, WAMP, SSMS logs |
| **Adobe Tools** | Photoshop, Illustrator, Figma caches |
| **Legacy C/C++ Tools** | Dev-C++, Code::Blocks, Arduino IDE |

#### PerformanceOptimization
- Event log analysis and management
- Startup performance analysis (WMI + Registry)
- Invalid startup item cleanup
- System resource analysis (CPU, Memory, Disk I/O)
- Top process monitoring
- Performance threshold alerts

#### NetworkMaintenance
- DNS cache flush
- Network adapter reset
- Winsock reset
- IP configuration renewal
- Network diagnostics

---

## Configuration

The framework uses JSON-based configuration located at:
`WindowsMaintenance/config/maintenance-config.json`

### Configuration Structure

```json
{
  "EnabledModules": [
    "SystemUpdates",
    "DiskMaintenance",
    "SystemHealthRepair",
    "SecurityScans",
    "DeveloperMaintenance",
    "PerformanceOptimization",
    "NetworkMaintenance"
  ],
  "LogsPath": "C:\\Temp\\MaintenanceLogs",
  "ReportsPath": "C:\\Temp\\MaintenanceReports",
  "MaxEventLogSizeMB": 100,

  "DiskMaintenance": {
    "EnableRecycleBinCleanup": true,
    "EnableTempFileCleanup": true,
    "EnableBrowserCacheCleanup": true,
    "TempFileRetentionDays": 7
  },

  "DeveloperMaintenance": {
    "EnableNPM": true,
    "EnablePython": true,
    "EnableDocker": true,
    "EnableJDK": true,
    "EnableVSCode": true,
    "EnableDotNetSDK": true
    // ... and 8 more dev tools
  },

  "PerformanceOptimization": {
    "EnableEventLogAnalysis": true,
    "EnableStartupAnalysis": true,
    "EnableResourceAnalysis": true
  }
}
```

For complete configuration options, see: **[CONFIG.md](WindowsMaintenance/CONFIG.md)**

---

## Usage

### Basic Usage

```powershell
# Import the module
Import-Module .\WindowsMaintenance.psd1

# Run all enabled modules
Invoke-WindowsMaintenance

# Test without making changes
Invoke-WindowsMaintenance -WhatIf

# Run specific module only
Invoke-DiskMaintenance
Invoke-DeveloperMaintenance
Invoke-SecurityScans
```

### Advanced Options

```powershell
# Run with custom configuration
Invoke-WindowsMaintenance -ConfigPath "C:\custom-config.json"

# Enable detailed logging
Invoke-WindowsMaintenance -DetailedOutput

# Manage event logs automatically
Invoke-WindowsMaintenance -ManageEventLogs

# Full security scan
Invoke-WindowsMaintenance -ScanLevel Full

# Silent mode (no user interaction)
Invoke-WindowsMaintenance -SilentMode
```

### Configuration Validation

```powershell
# Validate configuration file
.\Scripts\Test-MaintenanceConfig.ps1

# Validate with specific path
.\Scripts\Test-MaintenanceConfig.ps1 -ConfigPath "C:\custom-config.json"
```

### Task Scheduling

```powershell
# Install weekly maintenance task
.\Scripts\Install-MaintenanceTask.ps1 -TaskName "WeeklyMaintenance"

# Install with custom schedule
.\Scripts\Install-MaintenanceTask.ps1 -TaskName "DailyMaintenance" -StartTime "03:00"

# Uninstall task
.\Scripts\Install-MaintenanceTask.ps1 -TaskName "WeeklyMaintenance" -Uninstall
```

---

## Testing

The framework includes a comprehensive Pester 5.x test suite.

```powershell
# Run all tests
cd WindowsMaintenance\Tests
.\Invoke-Tests.ps1

# Run with code coverage
.\Invoke-Tests.ps1 -CodeCoverage

# Run in CI mode
.\Invoke-Tests.ps1 -CI

# Run specific test file
.\Invoke-Tests.ps1 -TestPath ".\WindowsMaintenance.Tests.ps1"
```

For testing documentation, see: **[Tests/README.md](WindowsMaintenance/Tests/README.md)**

---

## Documentation

| Document | Description |
|----------|-------------|
| [CONFIG.md](WindowsMaintenance/CONFIG.md) | Complete configuration reference |
| [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md) | Development and implementation tracking |
| [FEATURE_PARITY.md](FEATURE_PARITY.md) | Feature comparison with legacy script |
| [Tests/README.md](WindowsMaintenance/Tests/README.md) | Testing guide and coverage |

---

## Migration from Legacy Script

If you're currently using the old `Windows10-Maintenance-Script.ps1`:

### ⚠️ The legacy script is DEPRECATED as of Version 4.0.0

**Migration Steps:**

1. **Review your current parameters**
   ```powershell
   # Old way:
   .\Windows10-Maintenance-Script.ps1 -WhatIf -DetailedOutput -BackupMode Both

   # New way:
   Invoke-WindowsMaintenance -WhatIf -DetailedOutput
   ```

2. **Configure the new framework**
   - Edit `WindowsMaintenance/config/maintenance-config.json`
   - Enable/disable modules as needed
   - Set tool-specific options

3. **Test the migration**
   ```powershell
   Import-Module .\WindowsMaintenance.psd1
   Invoke-WindowsMaintenance -WhatIf
   ```

4. **Update scheduled tasks**
   ```powershell
   # Remove old scheduled task
   Unregister-ScheduledTask -TaskName "OldMaintenanceTask" -Confirm:$false

   # Install new task
   .\Scripts\Install-MaintenanceTask.ps1 -TaskName "WeeklyMaintenance"
   ```

See **[FEATURE_PARITY.md](FEATURE_PARITY.md)** for detailed feature mapping.

---

## Benefits of the Modular Framework

### Over the Legacy Script

✅ **Maintainability** - Clean module separation vs. 12,000-line monolith
✅ **Testability** - Comprehensive Pester test suite
✅ **Configurability** - JSON config vs. script parameters
✅ **Reliability** - Enhanced error handling and recovery
✅ **Extensibility** - Easy to add new modules/features
✅ **Performance** - Optimized execution and resource management
✅ **Enterprise Features** - Task scheduling, validation, reporting

### New Capabilities

- **Configuration Validation** - Schema-based config validation
- **Module Isolation** - Run individual modules independently
- **Test Framework** - Automated testing with Pester 5.x
- **Task Scheduler Integration** - Built-in scheduling support
- **Enhanced Reporting** - Detailed analysis reports with timestamps
- **Progress Tracking** - Real-time operation feedback
- **WhatIf Mode** - Safe testing across all modules
- **Better Logging** - Structured logging with multiple levels

---

## Requirements

### System Requirements
- Windows 10 version 1809 or later
- Windows 11 (all versions)
- Windows 10/11 Pro or Enterprise recommended
- PowerShell 5.1 or later
- Administrator privileges for most operations

### Optional Requirements
- **Pester 5.x** - For running tests (`Install-Module -Name Pester`)
- **Git** - For version control operations
- **Development Tools** - For developer maintenance features

---

## Performance

Typical execution times (varies by system and enabled modules):

| Configuration | Execution Time |
|--------------|----------------|
| Minimal (Updates + Cleanup) | 5-10 minutes |
| Standard (All modules, Quick scan) | 15-25 minutes |
| Full (All modules, Full scan) | 30-60 minutes |
| Developer Heavy (All dev tools) | 10-20 minutes |

Tips for faster execution:
- Use `-FastMode` for reduced timeouts
- Disable unused modules in configuration
- Use Quick security scans for routine maintenance
- Schedule Full scans during off-hours

---

## Security

The framework implements security best practices:

- ✅ Requires Administrator privileges validation
- ✅ Input validation and sanitization
- ✅ Secure string handling
- ✅ Timeout mechanisms prevent hanging
- ✅ WhatIf mode for safe testing
- ✅ Comprehensive audit trails
- ✅ No external network dependencies (except Windows Update)
- ✅ Code signing recommended for production deployments

---

## Troubleshooting

### Common Issues

**"Module not found" error**
```powershell
# Ensure you're in the correct directory
cd path\to\windows-maintenance-script
Import-Module .\WindowsMaintenance.psd1 -Force
```

**"Access Denied" errors**
```powershell
# Run PowerShell as Administrator
# Right-click PowerShell -> Run as Administrator
```

**Configuration validation fails**
```powershell
# Check JSON syntax
.\Scripts\Test-MaintenanceConfig.ps1
# Fix any reported issues in maintenance-config.json
```

**Modules not executing**
```powershell
# Check if module is enabled in config
notepad WindowsMaintenance\config\maintenance-config.json
# Verify "EnabledModules" array includes the module name
```

### Debug Mode

```powershell
# Enable verbose output
$VerbosePreference = "Continue"
Invoke-WindowsMaintenance -Verbose

# Check logs
Get-Content C:\Temp\MaintenanceLogs\maintenance_*.log
```

---

## Contributing

Contributions are welcome! To contribute:

1. Fork the repository
2. Create a feature branch
3. Add/modify code with appropriate tests
4. Run the test suite: `.\WindowsMaintenance\Tests\Invoke-Tests.ps1`
5. Update documentation as needed
6. Submit a pull request

### Development Guidelines

- Follow PowerShell best practices
- Add Pester tests for new features
- Update CONFIG.md for new configuration options
- Maintain backward compatibility where possible
- Use consistent code formatting
- Add comprehensive inline comments

---

## License

MIT License - See LICENSE file for details

---

## Support

For issues, questions, or feature requests:

1. Check the documentation in `WindowsMaintenance/` directory
2. Review [FEATURE_PARITY.md](FEATURE_PARITY.md) for feature mapping
3. Check [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md) for implementation details
4. Review closed/open issues in the repository

---

## Roadmap

### Future Enhancements

- [ ] GUI application for non-technical users
- [ ] PowerShell 7.x support
- [ ] Linux/macOS support (where applicable)
- [ ] Cloud-based configuration management
- [ ] Advanced reporting with graphs and charts
- [ ] Integration with monitoring tools
- [ ] Container support for isolated execution

---

## Changelog

### Version 4.0.0 (October 2025)
- ✅ Complete modular architecture implementation
- ✅ All 14 developer tools implemented
- ✅ All 6 performance optimization features
- ✅ Comprehensive test suite (Pester 5.x)
- ✅ JSON-based configuration system
- ✅ Task scheduler integration
- ✅ Enhanced error handling and logging
- ✅ WhatIf mode across all modules
- ✅ Feature parity with legacy script achieved
- ⚠️ Legacy script deprecated

### Version 3.0.0 (Previous)
- Original monolithic script implementation
- 12,000+ lines in single file
- Parameter-based configuration

---

## Acknowledgments

Built with enterprise best practices from:
- Microsoft Security Baselines
- NIST Cybersecurity Framework
- ISO 27001 standards
- ITIL v4 guidelines
- PowerShell community best practices

---

**Last Updated:** October 2025
**Version:** 4.0.0
**Author:** Miguel Velasco
**PowerShell Version:** 5.1+
**Platform:** Windows 10/11
