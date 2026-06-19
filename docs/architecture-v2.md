# Windows Enterprise Troubleshooting Framework v2 Architecture

## Executive overview

Version 2 changes the project from a fixed menu script into a plugin-based diagnostic platform. The framework separates orchestration, evidence collection, finding generation, reporting, configuration, and tests so that specialist diagnostics can be added without rewriting the core entry point.

## Design goals

- Preserve Windows PowerShell 5.1 compatibility
- Keep diagnostic operations read-only by default
- Normalize findings across technical domains
- Produce evidence suitable for L2/L3 escalation
- Support deterministic automated testing
- Make specialist modules independently versioned
- Keep repair actions outside the diagnostic plugin contract
- Redact sensitive data before portfolio or vendor sharing

## Component model

```text
Windows_Enterprise_Troubleshooter_v2.ps1
        |
        +-- Case metadata and configuration
        +-- Module import
        +-- Assessment orchestration
        +-- Executive HTML report
        |
modules/WindowsEnterpriseTroubleshooting/
        |
        +-- Plugin discovery and validation
        +-- Plugin execution isolation
        +-- Normalized finding model
        +-- Severity ranking
        +-- Redaction helpers
        +-- Case evidence export
        |
plugins/
        |
        +-- SystemHealth.plugin.ps1
        +-- NetworkDiagnostics.plugin.ps1
        +-- WindowsUpdate.plugin.ps1
        +-- EventCorrelation.plugin.ps1
```

## Plugin contract

Each plugin is a PowerShell file ending in `.plugin.ps1` that returns a hashtable containing:

| Key | Type | Required | Purpose |
|---|---|---:|---|
| `Name` | String | Yes | Unique plugin identifier |
| `Version` | String | Yes | Semantic version |
| `Description` | String | Yes | Human-readable scope |
| `RequiresAdmin` | Boolean | No | Indicates expected elevation |
| `SupportsRemote` | Boolean | No | Declares remote capability |
| `Invoke` | ScriptBlock | Yes | Executes collection and returns findings/evidence |

The `Invoke` block receives a case context and returns an object with `Findings` and `Evidence` collections.

## Normalized finding model

Every finding contains:

- Unique finding ID
- Plugin and target
- Title
- Severity and numeric severity rank
- Confidence percentage
- Evidence
- Business or technical impact
- Recommended action
- Optional reference
- UTC observation timestamp

This model supports consistent sorting, reporting, escalation, and future integration with ticketing or monitoring systems.

## Case lifecycle

1. Load validated configuration.
2. Create a unique case ID and evidence folder.
3. Discover plugins.
4. Validate each plugin contract.
5. Execute plugins independently.
6. Capture plugin failures without stopping the full assessment.
7. Normalize and rank findings.
8. Export JSON, CSV, and HTML evidence.
9. Preserve case metadata for auditability.

## Safety model

Version 2 plugins are diagnostic-only. Any future repair subsystem must:

- Be separate from diagnostic plugins
- Implement `SupportsShouldProcess`
- Require explicit operator confirmation
- Capture pre-change evidence
- Define rollback behavior
- Log the operator, target, timestamp, and result

## Compatibility

- Primary runtime: Windows PowerShell 5.1
- CI runtime: PowerShell 7 on `windows-latest`
- Windows-specific diagnostic plugins are tested for contract validity in CI and integration-tested on Windows lab systems.

## Future phases

### Phase 2

- PowerShell Remoting and CIM target adapters
- Parallel endpoint assessments with throttling
- Signed configuration profiles
- Richer executive risk scoring

### Phase 3

- Repair action provider contract
- Before-and-after snapshots
- Rollback packages
- Ticketing and RMM integration adapters
- Release signing and package verification

## Architecture decision records

Important design decisions should be added under `docs/adr/` using numbered Markdown files. Each record should include context, decision, consequences, rejected alternatives, and review date.