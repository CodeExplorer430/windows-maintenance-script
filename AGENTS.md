# Repository Guidelines

## Project Structure & Module Organization
- Root module and manifest: `WindowsMaintenance.psm1`, `WindowsMaintenance.psd1`.
- Entry points: `Run-Maintenance.ps1` (main), `Bootstrap.ps1` (install).
- Configuration: `Config/maintenance-config.json`.
- Modules: feature modules in `Modules/`, shared utilities in `Modules/Common/`.
- Tests: `Tests/Unit/`, `Tests/Integration/`, runner in `Tests/Invoke-Tests.ps1`.
- Supporting assets: `Tools/`, `GUI/`, `Lib/`, documentation in `docs/`, site config in `mkdocs.yml`.

## Build, Test, and Development Commands
- `pwsh .\Run-Maintenance.ps1` — run maintenance with PowerShell 7 (recommended).
- `Import-Module .\WindowsMaintenance.psd1; Invoke-WindowsMaintenance -WhatIf` — dry run without changes.
- `.\Tests\Invoke-Tests.ps1` — run all Pester tests.
- `.\Tests\Invoke-Tests.ps1 -CI -CodeCoverage` — CI mode with coverage report.
- `Invoke-Build` — run build pipeline (`Clean`, `Analyze`, `Test`, `Document`, `Site`, `Pack`).
- `Invoke-ScriptAnalyzer -Path . -Settings .\PSScriptAnalyzerSettings.psd1 -Recurse` — lint.

## Coding Style & Naming Conventions
- Indentation: 4 spaces; CRLF; trim trailing whitespace (`.editorconfig`).
- PowerShell files use PascalCase naming (e.g., `DiskMaintenance.psm1`).
- Prefer `Get-CimInstance` over legacy WMI.
- Use `Write-Information` with tags for logging.
- Support `-WhatIf` and `-Confirm` in state-changing functions.
- PSScriptAnalyzer settings live in `PSScriptAnalyzerSettings.psd1`.

## Testing Guidelines
- Pester 5.7.1+ is required.
- Test files follow `*.Tests.ps1` and live under `Tests/Unit/` or `Tests/Integration/`.
- Some tests require Administrator privileges; CI uses `-CI` for strict failure codes.

## Commit & Pull Request Guidelines
- Commit messages follow conventional prefixes: `feat:`, `fix:`, `docs:`, `style:`, `ci:`.
- Branch naming: `feature/...` or `fix/...`.
- Open PRs against `develop`.
- PRs should include: summary, relevant logs or screenshots (GUI changes), tests added for new features, and updates to `docs/` when behavior changes.

## Security & Configuration Tips
- Review `Config/maintenance-config.json` before running on new machines.
- Use `-WhatIf` for safety; run as Administrator for system-level actions.
