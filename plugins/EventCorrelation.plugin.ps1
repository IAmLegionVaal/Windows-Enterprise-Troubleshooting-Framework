@{
    Name           = 'EventCorrelation'
    Version        = '2.0.0'
    Description    = 'Correlates recent critical, error, and warning events across core Windows logs.'
    RequiresAdmin  = $false
    SupportsRemote = $false
    Invoke         = {
        param($Context)

        $hours = 48
        if ($Context.Configuration.ContainsKey('EventHours')) {
            $hours = [int]$Context.Configuration.EventHours
        }

        $start = (Get-Date).AddHours(-1 * $hours)
        $events = foreach ($log in @('System','Application','Microsoft-Windows-PowerShell/Operational')) {
            Get-WinEvent -FilterHashtable @{ LogName=$log; StartTime=$start; Level=1,2,3 } -ErrorAction SilentlyContinue |
                Select-Object TimeCreated,LogName,Id,ProviderName,LevelDisplayName,Message
        }

        $events = @($events)
        $groups = @($events | Group-Object LogName,ProviderName,Id | Sort-Object Count -Descending | ForEach-Object {
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

        $findings = [System.Collections.Generic.List[object]]::new()
        foreach ($group in ($groups | Select-Object -First 20)) {
            $severity = if ($group.Level -eq 'Critical' -or $group.Count -ge 25) { 'High' } elseif ($group.Level -eq 'Error' -or $group.Count -ge 10) { 'Medium' } else { 'Low' }
            $findings.Add((New-WetFinding -Plugin 'EventCorrelation' -Title "Repeated event $($group.EventId) from $($group.ProviderName)" -Severity $severity -Confidence 80 -Evidence "$($group.Count) occurrence(s) in $hours hours; latest $($group.Latest)" -Impact 'Repeated events may identify a persistent service, application, hardware, or policy problem.' -Recommendation 'Correlate the event with the reported symptom, affected service, recent changes, and adjacent events.' -Reference "$($group.LogName):$($group.EventId)" -Target $Context.Target))
        }

        [PSCustomObject]@{
            Findings = @($findings)
            Evidence = @($groups | Select-Object -First 100)
        }
    }
}