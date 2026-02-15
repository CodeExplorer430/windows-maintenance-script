# External Libraries Directory (v4.1.0)

This directory contains external binary dependencies required by the Windows Maintenance Framework.

## Directory Structure

To support both **PowerShell 5.1** (.NET Framework) and **PowerShell 7.4+** (.NET Core), libraries should be organized as follows:

- `\Lib\System.Data.SQLite.dll` - Primary SQLite library.
- `\Lib\net46\` - Reserved for .NET Framework 4.6+ compatible DLLs (PS 5.1).
- `\Lib\net8.0\` - Reserved for .NET 8.0 compatible DLLs (PS 7.4).

## Current Usage

### SQLite Database Integration
The framework uses SQLite for persistent history tracking (`Modules/Common/Database.psm1`). 
- **Requirement**: `System.Data.SQLite.dll` must be present in the `Lib/` folder.
- **Auto-Detection**: The framework automatically detects the PowerShell edition and attempts to load the appropriate assembly.

## Future Integrations
- `Newtonsoft.Json.dll`: For advanced JSON schema validation if required.
- `Avalonia.*.dll`: For future XAML-based cross-platform UI components.
