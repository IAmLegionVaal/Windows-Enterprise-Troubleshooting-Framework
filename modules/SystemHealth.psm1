#requires -Version 5.1
Set-StrictMode -Version Latest

function Get-SystemHealthSnapshot {
    [CmdletBinding()]
    param()

    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $disks = Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object {
        [PSCustomObject]@{
            Drive       = $_.DeviceID
            FileSystem  = $_.FileSystem
            SizeGB      = [math]::Round($_.Size / 1GB, 2)
            FreeGB      = [math]::Round($_.FreeSpace / 1GB, 2)
            FreePercent = if ($_.Size) { [math]::Round(($_.FreeSpace / $_.Size) * 100, 2) } else { 0 }
        }
    }

    [PSCustomObject]@{
        ComputerName      = $env:COMPUTERNAME
        OperatingSystem   = $os.Caption
        BuildNumber       = $os.BuildNumber
        LastBootTime      = $os.LastBootUpTime
        UptimeHours       = [math]::Round(((Get-Date) - $os.LastBootUpTime).TotalHours, 2)
        InstalledMemoryGB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
        Processor         = $cpu.Name
        LogicalProcessors = $cpu.NumberOfLogicalProcessors
        Manufacturer      = $cs.Manufacturer
        Model             = $cs.Model
        Generated          = Get-Date
        Disks              = $disks
    }
}

function Get-SystemHealthFindings {
    [CmdletBinding()]
    param()

    $findings = [System.Collections.Generic.List[object]]::new()
    $os = Get-CimInstance Win32_OperatingSystem
    $freeMemoryPercent = [math]::Round(($os.FreePhysicalMemory / $os.TotalVisibleMemorySize) * 100, 2)

    $findings.Add([PSCustomObject]@{
        Area = 'Memory'; Status = $(if ($freeMemoryPercent -lt 10) { 'Warning' } else { 'OK' });
        Detail = "Free physical memory: $freeMemoryPercent%"
    })

    foreach ($disk in Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3') {
        $free = if ($disk.Size) { [math]::Round(($disk.FreeSpace / $disk.Size) * 100, 2) } else { 0 }
        $findings.Add([PSCustomObject]@{
            Area = "Disk $($disk.DeviceID)"; Status = $(if ($free -lt 10) { 'Warning' } else { 'OK' });
            Detail = "Free space: $free%"
        })
    }

    $problemDevices = Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue | Where-Object { $_.ConfigManagerErrorCode -ne 0 }
    $findings.Add([PSCustomObject]@{
        Area = 'Devices'; Status = $(if ($problemDevices) { 'Warning' } else { 'OK' });
        Detail = "Problem devices: $(@($problemDevices).Count)"
    })

    return $findings
}

function Get-TopResourceProcesses {
    [CmdletBinding()]
    param([int]$Top = 15)

    Get-Process -ErrorAction SilentlyContinue |
        Sort-Object WorkingSet64 -Descending |
        Select-Object -First $Top Name, Id, CPU,
            @{Name='MemoryMB';Expression={[math]::Round($_.WorkingSet64 / 1MB, 2)}}
}

Export-ModuleMember -Function Get-SystemHealthSnapshot,Get-SystemHealthFindings,Get-TopResourceProcesses
