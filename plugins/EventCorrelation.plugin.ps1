@{
    Name           = 'EventCorrelation'
    Version        = '2.0.1'
    Description    = 'Correlates recent Windows events with event-specific tuning and noise suppression.'
    RequiresAdmin  = $false
    SupportsRemote = $false
    Invoke         = {
        param($Context)

        $hours = 48
        if ($Context.Configuration.ContainsKey('EventHours')) {
            $hours = [int]$Context.Configuration.EventHours
        }

        $profiles = @{
            'Microsoft-Windows-DistributedCOM|10016' = @{
                Action='EvidenceOnly'
                Reason='Frequently observed permission telemetry; retain as evidence unless it directly matches the reported symptom.'
            }
            'Microsoft-Windows-PowerShell|4100' = @{
                Action='EvidenceOnly'
                Reason='PowerShell operational telemetry can be produced by legitimate administration and by this diagnostic run.'
            }
            'Microsoft-Windows-PowerShell|4104' = @{
                Action='EvidenceOnly'
                Reason='Script block logging is valuable evidence but repetition alone does not establish a fault.'
            }
            'VBScriptDeprecationAlert|4096' = @{
                Action='EvidenceOnly'
                Reason='Deprecation telemetry should be reviewed as compatibility evidence, not promoted solely by count.'
            }
            'Microsoft-Windows-WindowsUpdateClient|20' = @{
                Severity='High'
                Confidence=92
                Impact='Repeated update installation failures may leave the endpoint non-compliant.'
                Recommendation='Review update history, servicing logs, proxy access, free space, and component-store health.'
            }
            '.NET Runtime|1022' = @{
                Severity='Medium'
                Confidence=82
                Impact='A .NET runtime condition may affect an application or service.'
                Recommendation='Correlate the event message and timestamps with the affected application and recent changes.'
            }
            'Microsoft-Windows-NDIS|10317' = @{
                Severity='Medium'
                Confidence=82
                Impact='Repeated network stack or adapter telemetry may align with connectivity instability.'
                Recommendation='Review adapter state, driver and firmware versions, power management, and adjacent network events.'
            }
            'Netwtw12|6062' = @{
                Severity='Low'
                Confidence=75
                Impact='Wireless adapter telemetry may indicate a transient driver or radio event.'
                Recommendation='Correlate with user-reported disconnects before escalating severity.'
            }
            'Microsoft-Windows-Time-Service|134' = @{
                Severity='Low'
                Confidence=78
                Impact='Time source discovery or synchronization may have been temporarily unavailable.'
                Recommendation='Validate the current time source, offset, service state, and domain hierarchy.'
            }
            'Microsoft-Windows-Kernel-Processor-Power|37' = @{
                Severity='Medium'
                Confidence=85
                Impact='Firmware or power policy may be limiting processor performance.'
                Recommendation='Review firmware, thermal state, power policy, and whether performance symptoms are present.'
            }
            'Microsoft-Windows-Hyper-V-VmSwitch|22' = @{
                Severity='Low'
                Confidence=75
                Impact='Virtual switch telemetry may indicate a transient virtual networking condition.'
                Recommendation='Correlate with affected VMs, adapter state, switch configuration, and connectivity symptoms.'
            }
        }

        $start = (Get-Date).AddHours(-1 * $hours)
        $events = foreach ($log in @('System','Application','Microsoft-Windows-PowerShell/Operational')) {
            Get-WinEvent -FilterHashtable @{ LogName=$log; StartTime=$start; Level=1,2,3 } -ErrorAction SilentlyContinue |
                Select-Object TimeCreated,LogName,Id,ProviderName,LevelDisplayName,Message
        }

        $events = @($events)
        $rawGroups = @($events |
            Group-Object LogName,ProviderName,Id |
            Sort-Object Count -Descending |
            ForEach-Object {
                [PSCustomObject]@{
                    Count        = $_.Count
                    LogName      = $_.Group[0].LogName
                    ProviderName = $_.Group[0].ProviderName
                    EventId      = $_.Group[0].Id
                    Level        = $_.Group[0].LevelDisplayName
                    FirstSeen    = ($_.Group | Sort-Object TimeCreated | Select-Object -First 1).TimeCreated
                    Latest       = ($_.Group | Sort-Object TimeCreated -Descending | Select-Object -First 1).TimeCreated
                    Sample       = ($_.Group | Select-Object -First 1).Message
                }
            })

        $groups = @(
            foreach ($group in $rawGroups) {
                $key = "$($group.ProviderName)|$($group.EventId)"
                $profile = $profiles[$key]
                $suppressed = $profile -and $profile.Action -eq 'EvidenceOnly'

                [PSCustomObject]@{
                    Count             = $group.Count
                    LogName           = $group.LogName
                    ProviderName      = $group.ProviderName
                    EventId           = $group.EventId
                    Level             = $group.Level
                    FirstSeen         = $group.FirstSeen
                    Latest            = $group.Latest
                    Sample            = $group.Sample
                    Suppressed         = [bool]$suppressed
                    TuningReason       = if ($profile -and $profile.Reason) { $profile.Reason } else { $null }
                    SeverityOverride   = if ($profile -and $profile.Severity) { $profile.Severity } else { $null }
                    ConfidenceOverride = if ($profile -and $profile.Confidence) { $profile.Confidence } else { $null }
                    ImpactOverride     = if ($profile -and $profile.Impact) { $profile.Impact } else { $null }
                    RecommendationOverride = if ($profile -and $profile.Recommendation) { $profile.Recommendation } else { $null }
                }
            }
        )

        $findings = [System.Collections.Generic.List[object]]::new()
        foreach ($group in ($groups | Where-Object { -not $_.Suppressed } | Select-Object -First 20)) {
            if ($group.SeverityOverride) {
                $severity = $group.SeverityOverride
                $confidence = [int]$group.ConfidenceOverride
                $impact = $group.ImpactOverride
                $recommendation = $group.RecommendationOverride
            }
            else {
                $severity = switch ($group.Level) {
                    'Critical' { 'High' }
                    'Error'    { if ($group.Count -ge 10) { 'High' } else { 'Medium' } }
                    default    { if ($group.Count -ge 20) { 'Medium' } else { 'Low' } }
                }
                $confidence = 75
                $impact = 'Repeated events may identify a persistent service, application, hardware, or policy condition.'
                $recommendation = 'Correlate the event with the reported symptom, affected service, recent changes, and adjacent events.'
            }

            $findings.Add((New-WetFinding -Plugin 'EventCorrelation' -Title "Repeated event $($group.EventId) from $($group.ProviderName)" -Severity $severity -Confidence $confidence -Evidence "$($group.Count) occurrence(s) in $hours hours; latest $($group.Latest)" -Impact $impact -Recommendation $recommendation -Reference "$($group.LogName):$($group.EventId)" -Target $Context.Target))
        }

        [PSCustomObject]@{
            Findings = @($findings)
            Evidence = @($groups | Select-Object -First 100)
        }
    }
}