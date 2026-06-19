# Contributing

## Development principles

Contributions should preserve:

- Windows PowerShell 5.1 compatibility
- Read-only diagnostic behavior
- Structured evidence and normalized findings
- Clear error handling
- Least-privilege operation
- Synthetic or sanitized examples
- Automated tests

## Workflow

1. Create a focused branch.
2. Make one coherent change.
3. Add or update Pester tests.
4. Run PSScriptAnalyzer.
5. Update documentation and changelog entries.
6. Open a pull request with validation evidence.

## Local validation

```powershell
Install-Module Pester -MinimumVersion 5.5.0 -Scope CurrentUser
Install-Module PSScriptAnalyzer -Scope CurrentUser

Test-ModuleManifest .\modules\WindowsEnterpriseTroubleshooting\WindowsEnterpriseTroubleshooting.psd1
Invoke-ScriptAnalyzer -Path .\modules\WindowsEnterpriseTroubleshooting -Recurse -Settings .\PSScriptAnalyzerSettings.psd1
Invoke-ScriptAnalyzer -Path .\plugins -Recurse -Settings .\PSScriptAnalyzerSettings.psd1
Invoke-Pester -Path .\tests -Output Detailed
```

## Pull request checklist

- [ ] Scope and purpose are clear
- [ ] Safety impact reviewed
- [ ] Tests added or updated
- [ ] Analyzer results reviewed
- [ ] Documentation updated
- [ ] Changelog updated
- [ ] Example data is synthetic or sanitized
- [ ] No private case evidence is included
- [ ] Backward compatibility considered

## Plugin contributions

Follow `docs/plugin-authoring.md`. A plugin must pass contract tests and return structured findings and evidence.

## Commit messages

Use clear imperative messages, for example:

- `Add DNS diagnostics plugin`
- `Improve finding severity scoring`
- `Document remote assessment security model`
- `Fix plugin error isolation`

## Review expectations

Reviewers should examine correctness, safety, data handling, PowerShell compatibility, test quality, documentation, and maintainability—not only whether the script runs on one machine.