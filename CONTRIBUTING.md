# Contributing to Windows Maintenance Framework

First off, thank you for considering contributing to the Windows Maintenance Framework! It's people like you that make this tool better for everyone.

## Code of Conduct

By participating in this project, you are expected to uphold our [Code of Conduct](CODE_OF_CONDUCT.md).

## How Can I Contribute?

### Reporting Bugs

- **Search first**: Check if the bug has already been reported.
- **Be specific**: Include your Windows version, PowerShell version, and Pester version.
- **Provide logs**: Attach relevant logs from your `LogsPath` directory.

### Suggesting Enhancements

- **Open an issue**: Describe the feature, why it's needed, and how it should work.
- **Keep it modular**: New features should follow the modular architecture in `Modules/`.

### Pull Requests

1. **Fork the repository**.
2. **Create a branch**: Use a descriptive name like `feature/new-cleanup-task` or `fix/reboot-check`.
3. **Follow the style guide**: 
   - Ensure your code passes `PSScriptAnalyzer`.
   - Use the settings in `PSScriptAnalyzerSettings.psd1`.
4. **Add tests**: Any new functionality MUST include Pester tests in `Tests/Unit/`.
5. **Verify**: Ensure all 51+ tests pass by running `.\Tests\Invoke-Tests.ps1`.
6. **Document**: Update relevant files in `docs/` if you change user-facing behavior.
7. **Submit**: Open a PR against the `develop` branch.

## Development Environment

- **PowerShell 7.4+** is recommended for development.
- **Pester 5.7.1+** is strictly required for running the test suite.
- **VS Code** with the **PowerShell extension** is the recommended editor.

## Coding Standards

- **Modular Design**: Feature logic goes in `Modules/`, shared utilities in `Modules/Common/`.
- **CIM over WMI**: Always use `Get-CimInstance` instead of `Get-WmiObject`.
- **Logging**: Use `Write-Information` with appropriate tags.
- **Safety**: Support `-WhatIf` and `-Confirm` for all system-altering functions.

Thank you for your contributions!
