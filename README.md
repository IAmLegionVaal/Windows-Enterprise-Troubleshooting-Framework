# Windows Enterprise Troubleshooting Framework

A modular, menu-driven PowerShell framework for Windows diagnostics, guided repair, evidence collection and technician reporting.

## Core capabilities

- System health, performance, storage and service analysis
- Network, DNS and connectivity diagnostics
- Windows Update diagnostics and guided repair
- Event-log correlation and startup review
- Security context and consolidated case reporting
- Timestamped output with technician-friendly HTML reports

## Operating modes

- **Diagnostic** — read-only checks and evidence collection
- **Guided Repair** — selected repair actions with confirmation
- **Report Only** — consolidated case report generation

## Run

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Windows_Enterprise_Troubleshooter.ps1
```

Non-interactive diagnostic case:

```powershell
.\Windows_Enterprise_Troubleshooter.ps1 -Mode Diagnostic -RunAll
```

## Repository structure

```text
Windows_Enterprise_Troubleshooter.ps1
config/settings.json
modules/SystemHealth.psm1
modules/NetworkDiagnostics.psm1
modules/WindowsUpdate.psm1
modules/Reporting.psm1
docs/technician-guide.md
docs/safety-and-rollback.md
```

## Safety and validation

Guided repairs require confirmation unless force is explicitly selected. The framework avoids destructive account, encryption and disk operations. GitHub Actions parses every PowerShell script on each change so syntax failures are caught before release. Real repair behaviour must still be tested on suitable Windows lab systems.

## Author

Dewald Pretorius — L2 IT Support Engineer
