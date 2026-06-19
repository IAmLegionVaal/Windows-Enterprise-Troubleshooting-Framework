# Windows Enterprise Troubleshooting Framework

A modular, menu-driven PowerShell framework for Windows diagnostics, guided repair, evidence collection, and technician reporting.

## Core capabilities

- System health and performance analysis
- Network, DNS, and connectivity diagnostics
- Windows Update diagnostics
- Event-log correlation
- Storage, services, startup, and security context
- Guided repair actions with confirmation prompts
- Timestamped case folders and technician-friendly HTML reports

## Operating modes

- **Diagnostic** — read-only checks and evidence collection
- **Guided Repair** — selected low-risk repair actions with confirmation
- **Report Only** — generates a consolidated case report

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

## Run

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Windows_Enterprise_Troubleshooter.ps1
```

Run a non-interactive diagnostic case:

```powershell
.\Windows_Enterprise_Troubleshooter.ps1 -Mode Diagnostic -RunAll
```

## Safety

Diagnostic checks are read-only. Guided repair actions require confirmation unless `-Force` is explicitly supplied. The framework does not perform destructive registry, account, encryption, or disk operations.

## Requirements

- Windows PowerShell 5.1 or later
- Administrator rights recommended for complete evidence collection

## Portfolio note

This repository demonstrates modular PowerShell design, defensive error handling, structured logging, report generation, and practical enterprise troubleshooting workflows.
