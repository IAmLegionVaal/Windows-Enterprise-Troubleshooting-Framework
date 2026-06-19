#requires -Version 5.1
<#
.SYNOPSIS
    Windows Enterprise Troubleshooting Framework.
.DESCRIPTION
    Modular diagnostic and guided-repair framework for Windows support technicians.
#>
[CmdletBinding()]
param(
    [ValidateSet('Interactive','Diagnostic','GuidedRepair','ReportOnly')]
    [string]$Mode = 'Interactive',
    [switch]$RunAll,
    [switch]$Force,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulePath = Join-Path $scriptRoot 'modules'

foreach ($module in 'Reporting','SystemHealth','NetworkDiagnostics','WindowsUpdate') {
    Import-Module (Join-Path $modulePath "$module.psm1") -Force -ErrorAction Stop
}

$context = New-CaseContext -RootPath $OutputPath
Write-CaseLog -Context $context -Message "Case started in mode: $Mode"

function Invoke-SystemWorkflow {
    Write-CaseLog -Context $context -Message 'Running system health workflow.'
    try {
        $snapshot = Get-SystemHealthSnapshot
        $summary = $snapshot | Select-Object ComputerName,OperatingSystem,BuildNumber,LastBootTime,UptimeHours,InstalledMemoryGB,Processor,LogicalProcessors,Manufacturer,Model,Generated
        Export-CaseData -Context $context -Name 'system_summary' -Data $summary
        Export-CaseData -Context $context -Name 'disk_capacity' -Data $snapshot.Disks
        Export-CaseData -Context $context -Name 'system_findings' -Data (Get-SystemHealthFindings)
        Export-CaseData -Context $context -Name 'top_resource_processes' -Data (Get-TopResourceProcesses)
        Write-CaseLog -Context $context -Message 'System health workflow completed.' -Level OK
    } catch {
        Write-CaseLog -Context $context -Message $_.Exception.Message -Level ERROR
    }
}

function Invoke-NetworkWorkflow {
    Write-CaseLog -Context $context -Message 'Running network diagnostic workflow.'
    try {
        $snapshot = Get-NetworkSnapshot
        Export-CaseData -Context $context -Name 'network_adapters' -Data $snapshot.Adapters
        Export-CaseData -Context $context -Name 'network_configuration' -Data $snapshot.Configuration
        Export-CaseData -Context $context -Name 'connectivity_tests' -Data (Test-EnterpriseConnectivity)
        $dns = Get-DnsClientHealth
        Export-CaseData -Context $context -Name 'dns_servers' -Data $dns.DnsServers
        Write-CaseLog -Context $context -Message 'Network workflow completed.' -Level OK
    } catch {
        Write-CaseLog -Context $context -Message $_.Exception.Message -Level ERROR
    }
}

function Invoke-UpdateWorkflow {
    Write-CaseLog -Context $context -Message 'Running Windows Update workflow.'
    try {
        $snapshot = Get-WindowsUpdateSnapshot
        Export-CaseData -Context $context -Name 'update_services' -Data $snapshot.Services
        Export-CaseData -Context $context -Name 'installed_hotfixes' -Data $snapshot.Hotfixes
        Export-CaseData -Context $context -Name 'update_events' -Data $snapshot.Events
        Export-CaseData -Context $context -Name 'update_findings' -Data (Get-WindowsUpdateFindings)
        Write-CaseLog -Context $context -Message 'Windows Update workflow completed.' -Level OK
    } catch {
        Write-CaseLog -Context $context -Message $_.Exception.Message -Level ERROR
    }
}

function Invoke-EventWorkflow {
    Write-CaseLog -Context $context -Message 'Running event correlation workflow.'
    try {
        $start = (Get-Date).AddHours(-48)
        $events = foreach ($log in 'System','Application') {
            Get-WinEvent -FilterHashtable @{LogName=$log;StartTime=$start;Level=1,2,3} -ErrorAction SilentlyContinue |
                Select-Object TimeCreated,LogName,Id,ProviderName,LevelDisplayName,Message
        }
        $correlation = $events | Group-Object LogName,ProviderName,Id | Sort-Object Count -Descending | ForEach-Object {
            [PSCustomObject]@{
                Count        = $_.Count
                LogName      = $_.Group[0].LogName
                ProviderName = $_.Group[0].ProviderName
                EventId      = $_.Group[0].Id
                Level        = $_.Group[0].LevelDisplayName
                Latest       = ($_.Group | Sort-Object TimeCreated -Descending | Select-Object -First 1).TimeCreated
            }
        }
        Export-CaseData -Context $context -Name 'event_correlation' -Data ($correlation | Select-Object -First 100)
        Write-CaseLog -Context $context -Message 'Event correlation completed.' -Level OK
    } catch {
        Write-CaseLog -Context $context -Message $_.Exception.Message -Level ERROR
    }
}

function Invoke-GuidedRepairMenu {
    do {
        Clear-Host
        Write-Host '=== Guided Repair ===' -ForegroundColor Cyan
        Write-Host '1. Flush DNS client cache'
        Write-Host '2. Renew DHCP leases'
        Write-Host '3. Restart Windows Update services'
        Write-Host '0. Back'
        $choice = Read-Host 'Choose an action'

        switch ($choice) {
            '1' {
                $result = Invoke-NetworkRepair -FlushDns -Confirm:(-not $Force)
                Export-CaseData -Context $context -Name 'repair_flush_dns' -Data $result
                Read-Host 'Press Enter'
            }
            '2' {
                $result = Invoke-NetworkRepair -RenewDhcp -Confirm:(-not $Force)
                Export-CaseData -Context $context -Name 'repair_renew_dhcp' -Data $result
                Read-Host 'Press Enter'
            }
            '3' {
                $result = Invoke-WindowsUpdateRepair -RestartServices -Confirm:(-not $Force)
                Export-CaseData -Context $context -Name 'repair_update_services' -Data $result
                Read-Host 'Press Enter'
            }
        }
    } while ($choice -ne '0')
}

function Show-MainMenu {
    do {
        Clear-Host
        Write-Host '============================================================' -ForegroundColor DarkCyan
        Write-Host ' WINDOWS ENTERPRISE TROUBLESHOOTING FRAMEWORK' -ForegroundColor Cyan
        Write-Host '============================================================' -ForegroundColor DarkCyan
        Write-Host '1. System health and performance'
        Write-Host '2. Network and DNS diagnostics'
        Write-Host '3. Windows Update diagnostics'
        Write-Host '4. Event-log correlation'
        Write-Host '5. Run complete diagnostic case'
        Write-Host '6. Guided repair'
        Write-Host '7. Generate case report'
        Write-Host '0. Exit'
        $choice = Read-Host 'Choice'

        switch ($choice) {
            '1' { Invoke-SystemWorkflow; Read-Host 'Press Enter' }
            '2' { Invoke-NetworkWorkflow; Read-Host 'Press Enter' }
            '3' { Invoke-UpdateWorkflow; Read-Host 'Press Enter' }
            '4' { Invoke-EventWorkflow; Read-Host 'Press Enter' }
            '5' { Invoke-SystemWorkflow; Invoke-NetworkWorkflow; Invoke-UpdateWorkflow; Invoke-EventWorkflow; Read-Host 'Press Enter' }
            '6' { Invoke-GuidedRepairMenu }
            '7' {
                $report = New-CaseReport -Context $context
                Write-CaseLog -Context $context -Message "Report created: $report" -Level OK
                Read-Host 'Press Enter'
            }
        }
    } while ($choice -ne '0')
}

switch ($Mode) {
    'Interactive' { Show-MainMenu }
    'Diagnostic' {
        if ($RunAll) { Invoke-SystemWorkflow; Invoke-NetworkWorkflow; Invoke-UpdateWorkflow; Invoke-EventWorkflow }
        else { Invoke-SystemWorkflow }
    }
    'GuidedRepair' { Invoke-GuidedRepairMenu }
    'ReportOnly' { }
}

$reportPath = New-CaseReport -Context $context
Write-CaseLog -Context $context -Message "Case complete. Report: $reportPath" -Level OK
Write-Host "Case folder: $($context.CasePath)" -ForegroundColor Green
