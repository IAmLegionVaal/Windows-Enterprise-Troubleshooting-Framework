# Technician Guide

## Recommended workflow

1. Run the framework as Administrator.
2. Start with the complete diagnostic case.
3. Review `system_findings.csv`, `connectivity_tests.csv`, `update_findings.csv`, and `event_correlation.csv`.
4. Use Guided Repair only after the evidence supports a specific action.
5. Re-run the affected workflow after repair.
6. Attach `case-report.html` and `technician.log` to the support ticket.

## Commands

Interactive mode:

```powershell
.\Windows_Enterprise_Troubleshooter.ps1
```

Complete non-interactive diagnostic:

```powershell
.\Windows_Enterprise_Troubleshooter.ps1 -Mode Diagnostic -RunAll
```

Custom report location:

```powershell
.\Windows_Enterprise_Troubleshooter.ps1 -Mode Diagnostic -RunAll -OutputPath C:\SupportCases
```

## Interpreting findings

- **OK** means no obvious issue was detected by that check.
- **Warning** means the technician should investigate further.
- **Failed** means an action or check could not complete.

A clean diagnostic result does not prove the absence of a problem. Use the report together with user symptoms, timelines, monitoring data, and environment-specific logs.
