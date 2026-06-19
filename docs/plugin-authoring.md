# Plugin Authoring Guide

## Purpose

Plugins let each diagnostic area be developed and tested independently while returning consistent findings and evidence.

## Minimal plugin

```powershell
@{
    Name           = 'ExamplePlugin'
    Version        = '1.0.0'
    Description    = 'Demonstrates the v2 plugin contract.'
    RequiresAdmin  = $false
    SupportsRemote = $false
    Invoke         = {
        param($Context)

        $evidence = [PSCustomObject]@{
            Target    = $Context.Target
            CheckedAt = Get-Date
            Value     = 'Example'
        }

        $finding = New-WetFinding `
            -Plugin 'ExamplePlugin' `
            -Title 'Example finding' `
            -Severity Low `
            -Confidence 90 `
            -Evidence 'Example evidence' `
            -Impact 'Example impact' `
            -Recommendation 'Example recommendation' `
            -Target $Context.Target

        [PSCustomObject]@{
            Findings = @($finding)
            Evidence = @($evidence)
        }
    }
}
```

Save the file as `plugins/ExamplePlugin.plugin.ps1`.

## Contract requirements

A plugin must:

- Return a hashtable or ordered dictionary
- Use a unique name
- Use a semantic version such as `1.2.0`
- Provide a script block in the `Invoke` key
- Return `Findings` and `Evidence`
- Return structured objects rather than formatted text
- Keep diagnostic plugins read-only
- Handle unavailable data sources gracefully

## Severity guidance

| Severity | Meaning |
|---|---|
| Informational | Context or successful validation |
| Low | Minor condition with limited impact |
| Medium | Material issue that should be planned for remediation |
| High | Significant service, compliance, or security risk |
| Critical | Immediate outage, data-loss, or severe security risk |

## Confidence guidance

- `90-100` — Direct authoritative evidence
- `70-89` — Strong correlation with limited ambiguity
- `50-69` — Probable finding requiring confirmation
- Below `50` — Prefer recording the observation as evidence

## Evidence design

Evidence should use predictable properties so it can be exported to CSV, serialized to JSON, shown in HTML reports, compared between runs, and attached to support cases.

## Error handling

Throw only when the plugin cannot perform its primary purpose. Non-critical missing data should be represented as evidence or a low-confidence finding.

The core engine records a failed plugin and continues running the remaining plugins.

## Testing checklist

- Plugin is discovered
- Contract is valid
- Name is unique
- Version follows semantic versioning
- `Invoke` is a script block
- Findings use the normalized finding model
- Evidence can be serialized to JSON

## Review checklist

Before merge, verify that the plugin:

- Collects only data required for the diagnostic purpose
- Avoids unnecessary personally identifiable data
- Uses supported Windows interfaces
- Keeps diagnostic behavior read-only
- Records clear evidence and recommendations
- Supports redaction before external sharing