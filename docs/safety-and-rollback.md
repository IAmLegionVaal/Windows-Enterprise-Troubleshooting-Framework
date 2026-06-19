# Safety and Rollback

## Diagnostic mode

Diagnostic workflows collect information only. They do not modify Windows configuration.

## Guided repair controls

Every guided repair uses PowerShell confirmation support. The current repair actions are deliberately limited to:

- Clearing the DNS client cache
- Renewing DHCP leases
- Restarting Windows Update support services

## Before repair

1. Record the user-reported symptom and start time.
2. Run the matching diagnostic workflow.
3. Save the first case report as the baseline.
4. Confirm that the planned repair matches the evidence.
5. Consider remote-session impact before renewing network configuration.

## Rollback considerations

- DNS cache clearing requires no rollback; cached records are rebuilt automatically.
- DHCP renewal may briefly interrupt network access. If connectivity does not return, review adapter configuration and DHCP availability.
- Service restart actions do not change service startup configuration. If a service fails to return, record the error and review dependent services and event logs.

## Explicit exclusions

The framework does not automatically:

- Delete registry keys
- Remove user profiles
- Reset passwords or accounts
- Disable security controls
- Decrypt or modify BitLocker volumes
- Format disks or remove partitions
- Reset Windows Update component folders

Higher-risk repairs should be implemented as separate, reviewed modules with backups, validation, and rollback procedures.
