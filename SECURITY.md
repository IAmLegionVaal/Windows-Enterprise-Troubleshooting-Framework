# Security Policy

## Supported versions

| Version | Supported |
|---|---:|
| 2.x | Yes |
| 1.x | Security fixes only where practical |

## Reporting a security concern

Do not open a public issue containing confidential case evidence, customer names, internal addresses, credentials, or sensitive logs.

Submit a private security report through GitHub Security Advisories when available. Include:

- A concise description
- Affected version or commit
- Reproduction steps using synthetic data
- Expected and actual behavior
- Security impact
- Suggested mitigation, when known

## Scope

Security concerns may include:

- Unsafe state-changing behavior
- Unintended collection of sensitive data
- Redaction failures
- Plugin loading or path validation problems
- Report content injection
- Insecure handling of configuration or output files
- CI or release integrity issues

## Diagnostic safety promise

Version 2 diagnostic plugins are intended to be read-only. A report that a diagnostic plugin changes endpoint state will be treated as a high-priority defect.

## Case evidence

Users are responsible for reviewing and sanitizing case folders before sharing them. The built-in redaction helper reduces common exposure but cannot identify every organization-specific sensitive value.

## Disclosure

Please allow reasonable time to investigate and prepare a fix before public disclosure. Confirmed issues will be documented in the changelog and release notes without exposing sensitive reproduction data.