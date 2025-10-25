@{
    # Script module or binary module file associated with this manifest
    RootModule = 'WindowsMaintenance.psm1'

    # Version number of this module
    ModuleVersion = '4.0.0'

    # ID used to uniquely identify this module
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'

    # Author of this module
    Author = 'Miguel Velasco'

    # Company or vendor of this module
    CompanyName = 'Personal'

    # Copyright statement for this module
    Copyright = '(c) 2025 Miguel Velasco. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'Comprehensive Windows maintenance and optimization framework with modular architecture. Provides automated maintenance across system updates, disk management, security, performance optimization, system health, and developer tools.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Processor architecture (None, X86, Amd64) required by this module
    ProcessorArchitecture = 'None'

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @()

    # Assemblies that must be loaded prior to importing this module
    RequiredAssemblies = @()

    # Script files (.ps1) that are run in the caller's environment prior to importing this module
    ScriptsToProcess = @()

    # Type files (.ps1xml) to be loaded when importing this module
    TypesToProcess = @()

    # Format files (.ps1xml) to be loaded when importing this module
    FormatsToProcess = @()

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    NestedModules = @(
        'Modules\Common\Logging.psm1',
        'Modules\Common\StringFormatting.psm1',
        'Modules\Common\SystemDetection.psm1',
        'Modules\Common\MemoryManagement.psm1',
        'Modules\Common\SafeExecution.psm1',
        'Modules\Common\UIHelpers.psm1',
        'Modules\Common\RealTimeProgressOutput.psm1',
        'Modules\Common\DriveAnalysis.psm1',
        'Modules\SystemUpdates.psm1',
        'Modules\DiskMaintenance.psm1',
        'Modules\SystemHealthRepair.psm1',
        'Modules\SecurityScans.psm1',
        'Modules\DeveloperMaintenance.psm1',
        'Modules\PerformanceOptimization.psm1'
    )

    # Functions to export from this module
    FunctionsToExport = @(
        'Invoke-WindowsMaintenance'
    )

    # Cmdlets to export from this module
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport = @()

    # List of all modules packaged with this module
    ModuleList = @()

    # List of all files packaged with this module
    FileList = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{
        PSData = @{
            # Tags applied to this module to aid module discovery
            Tags = @('Windows', 'Maintenance', 'Optimization', 'System', 'Automation', 'Admin', 'Updates', 'Security', 'Performance')

            # URL to the license for this module
            LicenseUri = ''

            # URL to the main website for this project
            ProjectUri = ''

            # URL to an icon representing this module
            IconUri = ''

            # Release notes of this module
            ReleaseNotes = @'
# Windows Maintenance Module v4.0.0

## New Features
- Modular architecture for better maintainability
- Enhanced logging and reporting framework
- Comprehensive developer tools maintenance
- Performance optimization with startup item management
- Real-time progress output for long-running operations
- Improved error handling and recovery

## Modules Included
- **SystemUpdates**: Windows Update, WinGet, Chocolatey package management
- **DiskMaintenance**: Disk cleanup, optimization, defragmentation, TRIM operations
- **SystemHealthRepair**: DISM, SFC, CHKDSK system health repairs
- **SecurityScans**: Windows Defender scans with conflict detection
- **DeveloperMaintenance**: NPM, Python, Docker, JDK, .NET, and IDE maintenance
- **PerformanceOptimization**: Event log management, startup item cleanup, resource analysis

## Common Modules
- Logging: Enterprise-grade logging with multiple levels
- MemoryManagement: Intelligent memory optimization
- SafeExecution: Safe command execution with timeout protection
- UIHelpers: User interface and message box management
- StringFormatting: Safe string operations
- SystemDetection: Hardware and system detection
- RealTimeProgressOutput: Real-time command output streaming
- DriveAnalysis: Comprehensive drive analysis and caching

## Requirements
- PowerShell 5.1 or higher
- Administrator privileges
- Windows 10/11 or Windows Server 2016+

## Usage
```powershell
Import-Module WindowsMaintenance
Invoke-WindowsMaintenance -ConfigPath ".\Config\maintenance-config.json"
```
'@
        }
    }

    # HelpInfo URI of this module
    HelpInfoURI = ''

    # Default prefix for commands exported from this module
    DefaultCommandPrefix = ''
}
