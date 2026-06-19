# ADR 0001: Adopt a Plugin-Based Diagnostic Architecture

- Status: Accepted
- Date: 2026-06-19
- Decision owner: Dewald Pretorius

## Context

Version 1 coordinates fixed system, network, Windows Update, event, and reporting modules through a menu-driven entry point. Adding another diagnostic domain requires changing the main script and increases coupling between collection, orchestration, and reporting.

The project needs to support additional senior-level capabilities such as independent module versioning, automated contract tests, normalized findings, evidence exports, future remote targets, and specialist diagnostic packages.

## Decision

Adopt a file-based plugin architecture for version 2.

Each plugin returns a validated metadata dictionary and an invocation script block. The core framework discovers plugins, validates their contract, executes them independently, and collects normalized findings and structured evidence.

Diagnostic plugins remain read-only. State-changing repair providers will use a separate future contract.

## Consequences

### Positive

- New diagnostic domains can be added without modifying the core engine.
- Plugin failures do not terminate the entire assessment.
- Findings use a consistent schema.
- Plugins can be tested and versioned independently.
- The architecture supports future target adapters and fleet orchestration.

### Negative

- Plugin authors must follow a stricter contract.
- The framework needs discovery, validation, and compatibility tests.
- Windows-specific integration testing still requires a Windows lab or runner with the relevant services.

## Alternatives considered

### Continue expanding the main menu script

Rejected because it increases coupling, makes testing harder, and creates merge conflicts as the project grows.

### Convert every diagnostic area into one large PowerShell module

Rejected because a single monolithic module would still couple unrelated domains and make specialist ownership difficult.

### Use external executable plugins

Deferred because PowerShell-native plugins are easier to inspect, test, and distribute for the current target audience.

## Review trigger

Review this decision when remote execution, third-party plugins, or signed plugin packages become part of a stable release.