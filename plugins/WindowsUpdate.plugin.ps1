@{
    Name           = 'WindowsUpdate'
    Version        = '2.0.0'
    Description    = 'Assesses Windows Update services, reboot state, hotfix age, and recent servicing events.'
    RequiresAdmin  = $false
    SupportsRemote = $false
    Invoke         = {
        param($Context)

        $findings = [System.Collections.Generic.List[object]]::new()
        $serviceNames = @('wuauserv','bits','cryptsvc','UsoSvc')
        $services = @(Get-Service -Name $serviceNames -ErrorAction SilentlyContinue | Select-Object Name,DisplayName,Status,StartType)

        foreach ($service in $services) {
            if ($service.StartType -ne 'Disabled' -and $service.Status -ne 'Running') {
                $findings.Add((New-WetFinding -Plugin 'WindowsUpdate' -Title "Update-related service not running: $($service.Name)" -Severity Medium -Confidence 85 -Evidence "Status=$($service.Status); StartType=$($service.StartType)" -Impact 'Update detection, download, installation, or signature validation may be interrupted.' -Recommendation 'Review the service, dependencies, update policy, event logs, and recent servicing operations.' -Target $Context.Target))
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

        $hotfixes = @(Get-HotFix -ErrorAction SilentlyContinue | Sort-Object InstalledOn -Descending | Select-Object -First 50 HotFixID,Description,InstalledOn,InstalledBy)
        $latestHotfix = $hotfixes | Where-Object InstalledOn | Select-Object -First 1
        if ($latestHotfix -and ((Get-Date) - $latestHotfix.InstalledOn).TotalDays -gt 90) {
            $findings.Add((New-WetFinding -Plugin 'WindowsUpdate' -Title 'No recent hotfix detected' -Severity High -Confidence 70 -Evidence "Latest visible hotfix: $($latestHotfix.HotFixID), installed $($latestHotfix.InstalledOn)" -Impact 'The endpoint may be missing security and reliability updates.' -Recommendation 'Validate update compliance through the authoritative management platform and review servicing failures.' -Target $Context.Target))
        }

        $start = (Get-Date).AddDays(-14)
        $events = @(Get-WinEvent -FilterHashtable @{ LogName='System'; ProviderName='Microsoft-Windows-WindowsUpdateClient'; StartTime=$start } -ErrorAction SilentlyContinue | Select-Object -First 200 TimeCreated,Id,LevelDisplayName,Message)
        $failedEvents = @($events | Where-Object { $_.LevelDisplayName -in @('Error','Critical') })
        if ($failedEvents.Count -gt 0) {
            $findings.Add((New-WetFinding -Plugin 'WindowsUpdate' -Title 'Recent Windows Update errors detected' -Severity High -Confidence 92 -Evidence "$($failedEvents.Count) error or critical event(s) in the last 14 days" -Impact 'Updates may be repeatedly failing or leaving the endpoint non-compliant.' -Recommendation 'Correlate event IDs, servicing logs, proxy state, disk capacity, and component-store health.' -Target $Context.Target))
        }

        [PSCustomObject]@{
            Findings = @($findings)
            Evidence = @($services) + @($hotfixes) + @($events) + @([PSCustomObject]$rebootIndicators)
        }
    }
}