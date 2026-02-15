# Windows Maintenance Framework - AI Instructions (Claude)
# Optimized for Agentic Coding & AI-Assisted Development

## Core Principles
1. **Agentic Reasoning**: Think step-by-step. Before acting, state your intent, reasoning, and any identified risks. Use specific examples from the codebase to justify your approach.
2. **Deep Feedback**: When reviewing or proposing changes, highlight technical debt, security risks, or architectural misalignment. Don't just fix; explain *why* and suggest long-term improvements.
3. **Iterative Development**: Break large tasks into atomic, testable steps. Always verify changes with Pester tests.

## Technical Standards
1. **PowerShell Best Practices**: 
   - Adhere strictly to the modular architecture in `Modules/` and `Modules/Common/`.
   - Ensure all public functions have proper SYNOPSIS, DESCRIPTION, and PARAMETER documentation.
   - Use `Write-Information` with tags for logging, consistent with the `Logging.psm1` module.
2. **Coding Style & Linting**:
   - Follow `PSScriptAnalyzerSettings.psd1`. Zero-warning policy.
   - Use `Show-TestResult` in tests for console output to bypass `PSAvoidUsingWriteHost` warnings where appropriate.
   - Prefer CIM cmdlets over WMI.
3. **Testing (Pester 5.7.1+)**:
   - Use `New-PesterConfiguration` for all test executions.
   - Use Dash-based syntax (`Should -Be`, `Should -Not -Throw`). Legacy syntax is forbidden.
   - Mock system-altering commands (Registry, File System, CIM) unless performing an explicit integration test.

## Execution Workflow
1. **Understand**: Use `grep_search` and `read_file` to map dependencies.
2. **Plan**: Propose a plan. If a change is risky (e.g., modifying `SafeExecution.psm1`), ask for confirmation.
3. **Act**: Use atomic replacements or file writes.
4. **Verify**: Run `.\Tests\Invoke-Tests.ps1`. Ensure all 51+ tests pass.
5. **Analyze**: Run `Invoke-ScriptAnalyzer` (if available) or verify against `PSScriptAnalyzerSettings.psd1`.

## Commit Standard
Provide clear, concise commit messages focusing on "why".
Example: `fix: resolve race condition in Invoke-Parallel by synchronizing thread-safe collections`
