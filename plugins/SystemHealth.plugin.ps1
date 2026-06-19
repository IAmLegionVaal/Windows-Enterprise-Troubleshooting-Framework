@{
    Name           = 'SystemHealth'
    Version        = '2.0.0'
    Description    = 'Collects operating system, uptime, memory, disk, device, and process evidence.'
    RequiresAdmin  = $false
    SupportsRemote = $false
    Invoke         = {
        param($Context)

        $os = Get-CimInstance Win32_OperatingSystem
        $cs = Get-CimInstance Win32_ComputerSystem
        $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
        $disks = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object {
            [PSCustomObject]@{
                Drive       = $_.DeviceID
                FileSystem  = $_.FileSystem
                SizeGB      = [math]::Round($_.Size / 1GB, 2)
                FreeGB      = [math]::Round($_.FreeSpace / 1GB, 2)
                FreePercent = if ($_.Size) { [math]::Round(($_.FreeSpace / $_.Size) * 100, 2) } else { 0 }
            }
        })

        $findings = [System.Collections.Generic.List[object]]::new()
        foreach ($disk in $disks) {
            if ($disk.FreePercent -lt 5) {
                $findings.Add((New-WetFinding -Plugin 'SystemHealth' -Title "Critical disk capacity on $($disk.Drive)" -Severity Critical -Confidence 98 -Evidence "$($disk.FreeGB) GB free ($($disk.FreePercent)%)" -Impact 'Applications, updates, logging, and system stability may fail.' -Recommendation 'Free space immediately and investigate growth sources.' -Target $Context.Target))
            }
            elseif ($disk.FreePercent -lt 15) {
                $findings.Add((New-WetFinding -Plugin 'SystemHealth' -Title "Low disk capacity on $($disk.Drive)" -Severity Medium -Confidence 95 -Evidence "$($disk.FreeGB) GB free ($($disk.FreePercent)%)" -Impact 'Reduced capacity can cause performance and servicing problems.' -Recommendation 'Review large files, logs, temporary data, and retention settings.' -Target $Context.Target))
            }
        }

        $memoryFreePercent = [math]::Round(($os.FreePhysicalMemory / $os.TotalVisibleMemorySize) * 100, 2)
        if ($memoryFreePercent -lt 10) {
            $findings.Add((New-WetFinding -Plugin 'SystemHealth' -Title 'Low available physical memory' -Severity High -Confidence 90 -Evidence "$memoryFreePercent percent available" -Impact 'Sustained memory pressure can cause paging, latency, and application instability.' -Recommendation 'Review top memory consumers and validate workload sizing.' -Target $Context.Target))
        }

        $problemDevices = @(Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue | Where-Object ConfigManagerErrorCode -ne 0)
        if ($problemDevices.Count -gt 0) {
            $findings.Add((New-WetFinding -Plugin 'SystemHealth' -Title 'Devices reporting configuration errors' -Severity Medium -Confidence 95 -Evidence "$($problemDevices.Count) device(s) returned non-zero configuration codes" -Impact 'Affected hardware may be unavailable or unstable.' -Recommendation 'Review device status, driver version, firmware, and hardware health.' -Target $Context.Target))
        }

        $summary = [PSCustomObject]@{
            ComputerName      = $Context.Target
            OperatingSystem   = $os.Caption
            BuildNumber       = $os.BuildNumber
            LastBootTime      = $os.LastBootUpTime
            UptimeHours       = [math]::Round(((Get-Date) - $os.LastBootUpTime).TotalHours, 2)
            InstalledMemoryGB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
            FreeMemoryPercent = $memoryFreePercent
            Processor         = $cpu.Name
            LogicalProcessors = $cpu.NumberOfLogicalProcessors
            Manufacturer      = $cs.Manufacturer
            Model             = $cs.Model
        }

        [PSCustomObject]@{
            Findings = @($findings)
            Evidence = @($summary) + $disks + $problemDevices
        }
    }
}