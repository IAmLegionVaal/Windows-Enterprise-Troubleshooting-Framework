# Security and Data-Handling Model

## Security position

The v2 diagnostic framework is read-only by default. It collects technical evidence, creates normalized findings, and writes reports to a local case folder. Diagnostic plugins must not modify endpoint configuration.

## Trust boundaries

| Boundary | Risk | Control |
|---|---|---|
| Technician workstation | Unauthorized access to case evidence | Store reports in approved locations and apply normal workstation access controls |
| Target endpoint | Excessive data collection | Collect only evidence required for the diagnostic purpose |
| Plugin directory | Unreviewed plugin execution | Load only version-controlled plugins and validate the plugin contract |
| Report export | Exposure of identifying data | Apply redaction before external sharing |
| Configuration file | Unexpected behavior | Validate settings against the documented schema |
| Future remote transport | Credential and session risk | Use approved PowerShell Remoting or CIM controls and least privilege |

## Data classification

Case folders may contain:

- Computer names
- IP addresses
- Service and process names
- Event metadata
- User profile paths
- Update history
- Device information
- Diagnostic messages

Treat case folders as internal support data unless they have been reviewed and redacted.

## Redaction

The `Protect-WetData` helper masks common email addresses, IP addresses, sensitive assignment strings, and user-profile paths. Redaction is an assistance feature, not a substitute for technician review.

Before sharing evidence externally:

1. Copy the case folder to a review location.
2. Remove files not required for the escalation.
3. Apply redaction to free-text evidence.
4. Review screenshots manually.
5. Confirm that customer names, user identities, internal addresses, and case notes are appropriate to share.
6. Record who approved the evidence package.

## Privilege model

Plugins declare whether administrative access is expected. A plugin should still handle limited access gracefully and explain what evidence could not be collected.

Future repair providers must be separate from diagnostics and must support:

- Explicit operator approval
- Pre-change evidence
- Change logging
- Target validation
- Rollback instructions
- Post-change verification

## Secure development requirements

- Run PSScriptAnalyzer in CI
- Run Pester tests in CI
- Review changes through pull requests
- Pin third-party GitHub Actions to reviewed major versions or commit hashes where required by policy
- Do not commit real case evidence containing confidential data
- Keep sample data synthetic and clearly labelled
- Review generated reports before publication

## Reporting security issues

Do not publish a security issue containing sensitive customer evidence. Follow the process in `SECURITY.md` and provide only the minimum reproduction information required.