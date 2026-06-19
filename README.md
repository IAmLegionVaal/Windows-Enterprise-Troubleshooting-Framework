# Windows Enterprise Troubleshooting Framework

A senior-level, plugin-based PowerShell platform for Windows diagnostics, evidence collection, normalized findings, guided support workflows, and technician reporting.

## Version 2 preview

Version 2 changes the project from a fixed menu tool into an extensible diagnostic framework.

### New v2 capabilities

- Validated plugin contract
- Independently versioned diagnostic plugins
- Normalized findings with severity, confidence, evidence, impact, and recommendations
- Isolated plugin failures
- Structured case metadata
- CSV and JSON evidence exports
- Executive and technician HTML reporting
- Sensitive-data redaction helper
- JSON configuration with schema
- Pester tests
- PSScriptAnalyzer policy
- GitHub Actions CI and preview packaging
- Architecture, security, and plugin-authoring documentation

## Built-in v2 plugins

| Plugin | Purpose |
|---|---|
| System Health | OS, uptime, memory, disk, hardware, and process context |
| Network Diagnostics | Adapters, IP configuration, routing, DNS, proxy, and connectivity |
| Windows Update | Services, reboot state, hotfix age, and servicing events |
| Event Correlation | Repeated critical, error, and warning event patterns |

## Run v2

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Windows_Enterprise_Troubleshooter_v2.ps1 -OpenReport
```

Run selected plugins and include case metadata:

```powershell
.\Windows_Enterprise_Troubleshooter_v2.ps1 `
    -CaseId 'CASE-20260619-001' `
    -TicketNumber 'INC-10427' `
    -Customer 'Contoso Branch Office' `
    -Technician 'Dewald Pretorius' `
    -Target $env:COMPUTERNAME `
    -Symptom 'Intermittent Microsoft 365 access and slow sign-in' `
    -PluginName SystemHealth,NetworkDiagnostics,WindowsUpdate,EventCorrelation `
    -OpenReport
```

## v2 output

Each case folder contains:

```text
CASE-YYYYMMDD-HHMMSS/
    case-metadata.json
    summary.json
    plugin-results.json
    findings.csv
    enterprise-case-report.html
```

## Repository structure

```text
Windows_Enterprise_Troubleshooter.ps1        Legacy v1 entry point
Windows_Enterprise_Troubleshooter_v2.ps1     Version 2 entry point
modules/
    Reporting.psm1                           Legacy v1 module
    SystemHealth.psm1                        Legacy v1 module
    NetworkDiagnostics.psm1                  Legacy v1 module
    WindowsUpdate.psm1                       Legacy v1 module
    WindowsEnterpriseTroubleshooting/
        WindowsEnterpriseTroubleshooting.psd1
        WindowsEnterpriseTroubleshooting.psm1
plugins/
    SystemHealth.plugin.ps1
    NetworkDiagnostics.plugin.ps1
    WindowsUpdate.plugin.ps1
    EventCorrelation.plugin.ps1
config/
    settings.json
    v2.settings.json
schemas/
    v2.settings.schema.json
tests/
docs/
sample-data/
sample-reports/
.github/workflows/ci.yml
```

## Finding model

Every v2 finding includes:

- Unique finding ID
- Plugin and target
- Severity
- Confidence score
- Supporting evidence
- Business or technical impact
- Recommended action
- Optional reference
- UTC observation timestamp

This makes findings suitable for escalation notes, ticket attachments, comparison, and future monitoring or RMM integrations.

## Safety

Version 2 diagnostic plugins are read-only by design. They collect evidence and produce findings without changing endpoint configuration.

Any future repair subsystem must remain separate and require explicit approval, pre-change evidence, rollback documentation, and post-change validation.

Review and sanitize case evidence before external sharing. See:

- [Security and data-handling model](docs/security-model.md)
- [Security policy](SECURITY.md)
- [Legacy safety and rollback guide](docs/safety-and-rollback.md)

## Documentation

- [v2 architecture](docs/architecture-v2.md)
- [Plugin authoring](docs/plugin-authoring.md)
- [Security model](docs/security-model.md)
- [Technician guide](docs/technician-guide.md)
- [Contributing](CONTRIBUTING.md)
- [Changelog](CHANGELOG.md)

## Testing

```powershell
Test-ModuleManifest .\modules\WindowsEnterpriseTroubleshooting\WindowsEnterpriseTroubleshooting.psd1
Invoke-ScriptAnalyzer -Path .\modules\WindowsEnterpriseTroubleshooting -Recurse -Settings .\PSScriptAnalyzerSettings.psd1
Invoke-ScriptAnalyzer -Path .\plugins -Recurse -Settings .\PSScriptAnalyzerSettings.psd1
Invoke-Pester -Path .\tests -Output Detailed
```

The GitHub Actions workflow runs manifest validation, static analysis, Pester tests, code coverage, and preview packaging on Windows.

## Legacy v1

The original menu-driven framework remains available:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Windows_Enterprise_Troubleshooter.ps1
```

It provides interactive diagnostics, guided low-risk repair actions, timestamped case folders, and HTML reporting.

## Roadmap

### Phase 2

- PowerShell Remoting and CIM target adapters
- Parallel fleet assessments with throttling
- Baseline comparison and drift detection
- Signed configuration profiles
- Expanded risk scoring

### Phase 3

- Separate repair provider contract
- Before-and-after snapshots
- Rollback packages
- Ticketing and RMM adapters
- Signed release packages

## Portfolio value

This project demonstrates modular PowerShell architecture, plugin contracts, defensive error handling, structured evidence, finding normalization, report engineering, CI/CD, automated testing, security-conscious data handling, and practical Windows support workflows.