#requires -Version 5.1
Set-StrictMode -Version Latest

function Get-WindowsUpdateSnapshot {
    [CmdletBinding()]
    param([int]$Days = 90)

    $hotfixes = Get-HotFix -ErrorAction SilentlyContinue |
        Sort-Object InstalledOn -Descending |
        Select-Object HotFixID,Description,InstalledBy,InstalledOn

    $services = 'wuauserv','bits','cryptsvc','msiserver' | ForEach-Object {
        Get-Service -Name $_ -ErrorAction SilentlyContinue |
            Select-Object Name,DisplayName,Status,StartType
    }

    $start = (Get-Date).AddDays(-1 * $Days)
    $events = Get-WinEvent -FilterHashtable @{
        LogName   = 'Microsoft-Windows-WindowsUpdateClient/Operational'
        StartTime = $start
    } -ErrorAction SilentlyContinue | Select-Object -First 250 TimeCreated,Id,LevelDisplayName,Message

    [PSCustomObject]@{
        Services = $services
        Hotfixes = $hotfixes
        Events   = $events
        Generated = Get-Date
    }
}

function Get-WindowsUpdateFindings {
    [CmdletBinding()]
    param([int]$Days = 90)

    $snapshot = Get-WindowsUpdateSnapshot -Days $Days
    $latest = $snapshot.Hotfixes | Select-Object -First 1
    $failedEvents = @($snapshot.Events | Where-Object { $_.LevelDisplayName -in @('Error','Critical') })

    @(
        [PSCustomObject]@{
            Area='Windows Update Service'
            Status=$(if (($snapshot.Services | Where-Object Name -eq 'wuauserv').Status -eq 'Running') {'OK'} else {'Warning'})
            Detail="wuauserv status: $(($snapshot.Services | Where-Object Name -eq 'wuauserv').Status)"
        },
        [PSCustomObject]@{
            Area='Recent Update'
            Status=$(if ($latest) {'OK'} else {'Warning'})
            Detail=$(if ($latest) { "Latest hotfix $($latest.HotFixID) installed $($latest.InstalledOn)" } else { 'No hotfix history returned.' })
        },
        [PSCustomObject]@{
            Area='Update Errors'
            Status=$(if ($failedEvents.Count -gt 0) {'Warning'} else {'OK'})
            Detail="Errors in last $Days days: $($failedEvents.Count)"
        }
    )
}

function Invoke-WindowsUpdateRepair {
    [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Medium')]
    param([switch]$RestartServices)

    $results = [System.Collections.Generic.List[object]]::new()
    if ($RestartServices -and $PSCmdlet.ShouldProcess('Windows Update support services','Restart')) {
        foreach ($name in 'bits','wuauserv') {
            try {
                Restart-Service -Name $name -Force -ErrorAction Stop
                $results.Add([PSCustomObject]@{Action="Restart $name";Status='Completed';Detail='Service restarted.'})
            } catch {
                $results.Add([PSCustomObject]@{Action="Restart $name";Status='Failed';Detail=$_.Exception.Message})
            }
        }
    }
    return $results
}

Export-ModuleMember -Function Get-WindowsUpdateSnapshot,Get-WindowsUpdateFindings,Invoke-WindowsUpdateRepair
