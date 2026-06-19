# Changelog

All notable changes to this project are documented here.

The project follows Semantic Versioning.

## [Unreleased]

### Added

- First sanitized Windows PowerShell 5.1 validation record under `docs/validation/`
- Successful Windows CI validation record covering manifest, analyzer, Pester, redaction, coverage, and packaging

### Changed

- Network Diagnostics now limits APIPA findings to active physical or routing-relevant interfaces.
- Public DNS checks now focus on active or routing-relevant interfaces.
- Windows Update no longer treats normally stopped manual or trigger-start services as faults.
- Windows Update error severity now considers recency and repetition.
- Event Correlation now uses event-specific tuning profiles and conservative generic severity.
- DistributedCOM 10016, PowerShell 4100/4104, and VBScript deprecation telemetry remain evidence-only unless additional context makes them actionable.
- PSScriptAnalyzer policy is aligned with the read-only diagnostic API surface.

### Planned

- Remote target adapters for PowerShell Remoting and CIM
- Parallel fleet assessments with throttling
- Signed release packages
- Repair provider contract with pre-change and rollback evidence
- Baseline comparison between assessment runs

## [2.0.0-preview.1] - 2026-06-19

### Added

- Plugin-based diagnostic architecture
- PowerShell module manifest and public API
- Plugin discovery and contract validation
- Normalized findings with severity, confidence, impact, evidence, and recommendations
- Sensitive-data redaction helper
- Built-in System Health plugin
- Built-in Network Diagnostics plugin
- Built-in Windows Update plugin
- Built-in Event Correlation plugin
- Version 2 command-line entry point
- Case metadata and machine-readable evidence exports
- Senior-level HTML case report
- JSON configuration and schema
- Pester contract and module tests
- PSScriptAnalyzer configuration
- GitHub Actions CI and preview packaging
- Architecture, plugin authoring, and security documentation
- Simulated case data and sample-report guidance

### Changed

- Diagnostics are now orchestrated through independently versioned plugins.
- Findings are normalized instead of being stored only as domain-specific tables.
- Plugin failures are isolated so one collection failure does not terminate the full assessment.

### Compatibility

- Windows PowerShell 5.1 remains the primary supported runtime.
- CI also validates the module on the current Windows-hosted PowerShell runtime.

## [1.0.0] - 2026-06-18

### Added

- Menu-driven diagnostics
- System health checks
- Network and DNS checks
- Windows Update checks
- Event correlation
- Guided low-risk repairs
- Timestamped case folders
- CSV, JSON, and HTML reporting
