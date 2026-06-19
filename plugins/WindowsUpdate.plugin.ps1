@{
    Name           = 'WindowsUpdate'
    Version        = '2.0.1'
    Description    = 'Assesses Windows Update services, reboot state, hotfix age, and recent servicing events.'
    RequiresAdmin  = $false
    SupportsRemote = $false
    Invoke         = {
        param($Context)

        $findings = [System.Collections.Generic.List[object]]::new()
        $serviceNames = @('wuauserv','bits','cryptsvc','UsoSvc')
        $services = @(Get-Service -Name $serviceNames -ErrorAction SilentlyContinue |
            Select-Object Name,DisplayName,Status,StartType)

        foreach ($service in $services) {
            if ($service.StartType -eq 'Disabled') {
                $findings.Add((New-WetFinding -Plugin 'WindowsUpdate' -Title "Update-related service disabled: $($service.Name)" -Severity High -Confidence 95 -Evidence "Status=$($service.Status); StartType=$($service.StartType)" -Impact 'Update detection, download, installation, or signature validation may be blocked.' -Recommendation 'Confirm whether the service was disabled by policy or troubleshooting activity and restore the approved configuration.' -Target $Context.Target))
            }
            elseif ($service.StartType -eq 'Automatic' -and $service.Status -ne 'Running') {
                $findings.Add((New-WetFinding -Plugin 'WindowsUpdate' -Title "Automatic update-related service not running: $($service.Name)" -Severity Medium -Confidence 88 -Evidence "Status=$($service.Status); StartType=$($service.StartType)" -Impact 'A required servicing dependency may be unavailable.' -Recommendation 'Review the service, dependencies, policy, and related event logs.' -Target $Context.Target))
            }
        }

        $rebootIndicators = [ordered]@{
            ComponentBasedServicing = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
            WindowsUpdate           = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
            PendingFileRename       = $null -ne (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue)
        }

        if ($rebootIndicators.Values -contains $true) {
            $findings.Add((New-WetFinding -Plugin 'WindowsUpdate' -Title 'Pending reboot detected' -Severity Low -Confidence 95 -Evidence (($rebootIndicators.GetEnumerator() | Where-Object Value | ForEach-Object Key) -join ', ') -Impact 'Servicing operations may remain incomplete and produce misleading diagnostic results.' -Recommendation 'Schedule and complete a controlled restart, then rerun the assessment.' -Target $Context.Target))
        }

        $hotfixes = @(Get-HotFix -ErrorAction SilentlyContinue |
            Sort-Object InstalledOn -Descending |
            Select-Object -First 50 HotFixID,Description,InstalledOn,InstalledBy)
        $latestHotfix = $hotfixes | Where-Object InstalledOn | Select-Object -First 1
        if ($latestHotfix -and ((Get-Date) - $latestHotfix.InstalledOn).TotalDays -gt 90) {
            $findings.Add((New-WetFinding -Plugin 'WindowsUpdate' -Title 'No recent hotfix detected' -Severity High -Confidence 70 -Evidence "Latest visible hotfix: $($latestHotfix.HotFixID), installed $($latestHotfix.InstalledOn)" -Impact 'The endpoint may be missing security and reliability updates.' -Recommendation 'Validate update compliance through the authoritative management platform and review servicing failures.' -Target $Context.Target))
        }

        $fourteenDaysAgo = (Get-Date).AddDays(-14)
        $seventyTwoHoursAgo = (Get-Date).AddHours(-72)
        $events = @(Get-WinEvent -FilterHashtable @{ LogName='System'; ProviderName='Microsoft-Windows-WindowsUpdateClient'; StartTime=$fourteenDaysAgo } -ErrorAction SilentlyContinue |
            Select-Object -First 200 TimeCreated,Id,LevelDisplayName,Message)
        $failedEvents = @($events | Where-Object { $_.LevelDisplayName -in @('Error','Critical') })
        $recentFailedEvents = @($failedEvents | Where-Object TimeCreated -ge $seventyTwoHoursAgo)

        if ($recentFailedEvents.Count -ge 3) {
            $findings.Add((New-WetFinding -Plugin 'WindowsUpdate' -Title 'Repeated recent Windows Update errors detected' -Severity High -Confidence 94 -Evidence "$($recentFailedEvents.Count) error or critical event(s) in the last 72 hours; $($failedEvents.Count) in 14 days" -Impact 'Updates may be repeatedly failing or leaving the endpoint non-compliant.' -Recommendation 'Correlate event IDs, servicing logs, proxy state, disk capacity, and component-store health.' -Target $Context.Target))
        }
        elseif ($recentFailedEvents.Count -gt 0) {
            $findings.Add((New-WetFinding -Plugin 'WindowsUpdate' -Title 'Recent Windows Update error detected' -Severity Medium -Confidence 90 -Evidence "$($recentFailedEvents.Count) error or critical event(s) in the last 72 hours" -Impact 'A current update attempt may have failed.' -Recommendation 'Review the specific event, update history, servicing logs, proxy state, and available disk space.' -Target $Context.Target))
        }
        elseif ($failedEvents.Count -gt 0) {
            $findings.Add((New-WetFinding -Plugin 'WindowsUpdate' -Title 'Historical Windows Update errors detected' -Severity Low -Confidence 75 -Evidence "$($failedEvents.Count) error or critical event(s) between 72 hours and 14 days old" -Impact 'Older failures may already be resolved but remain relevant to trend analysis.' -Recommendation 'Confirm current update compliance and retain the events as historical context.' -Target $Context.Target))
        }

        [PSCustomObject]@{
            Findings = @($findings)
            Evidence = @($services) + @($hotfixes) + @($events) + @([PSCustomObject]$rebootIndicators)
        }
    }
}