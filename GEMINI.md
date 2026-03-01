# Windows Maintenance Framework - AI Instructions (Gemini)
# Optimized for Agentic Coding & AI-Assisted Development

## Strategic Guidance
1. **Architectural Integrity**: Maintain the decoupled, parameter-driven design. Avoid global variables; use the shared `$Config` object and dependency injection.
2. **Security-First Coding**: Never introduce code that bypasses UAC silently or logs sensitive information (Secrets, API keys). Use `SecretManager.psm1` for sensitive data.
3. **Transparent Execution**: Always provide a concise explanation before tool calls. Ensure the user understands the impact of filesystem or registry modifications.

## Framework Conventions
1. **Modular SQLite**: The `Database.psm1` module is the source of truth for history. Ensure `Invoke-SQLiteQuery` is used for all persistent metrics.
2. **Safe Operations**: All system-modifying modules MUST support `-WhatIf` and `-Confirm` via `ShouldProcess`.
3. **Environment Awareness**: Scripts must gracefully handle both PowerShell 5.1 (Desktop) and 7.4+ (Core). Use `$IsCoreCLR` or checking `$PSVersionTable.PSEdition` for branching logic.

## Quality Benchmarks
1. **Zero-Warning ScriptAnalyzer**: Respect the project's `.editorconfig` and `PSScriptAnalyzerSettings.psd1`.
2. **Modern Testing**: Mandate Pester 5.7.1+. Every new feature requires a corresponding `.Tests.ps1` in `Tests/Unit/`.
3. **Reporting**: All maintenance runs must contribute to the structured system report and the SQLite metrics database.

## Collaborative Workflow
- **Discovery**: Prioritize understanding existing patterns in `Modules/Common/` before implementing new utilities.
- **Refactoring**: When identifying redundant code, propose a consolidation into a Common module.
- **Verification**: Never consider a task complete until `.\Tests\Invoke-Tests.ps1` returns zero failures.

## Documentation
- Maintain `docs/` (MkDocs) alongside code changes.
- Update `testing-plan.md` if test strategies evolve.

## FOSS & Repository Standards
1. **Issue Management**: Utilize the YAML forms (`bug_report.yml`, `feature_request.yml`) for standardization. Always link Pull Requests to an existing issue (`Fixes #<issue_number>`).
2. **Pull Requests**: Every PR must fill out `.github/PULL_REQUEST_TEMPLATE.md` thoroughly, ensuring tests pass and docs are updated.
3. **Branching & Commits**: Use standard branching (`feature/*`, `fix/*`, `docs/*`) and Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`) to generate a clear history and Semantic Versioning.
4. **Pre-Commit Verification**: Before committing or pushing any changes, you **MUST** ensure that `Invoke-ScriptAnalyzer` and Pester (`.\Tests\Invoke-Tests.ps1`) have been executed with zero warnings and zero errors across the entire codebase.
