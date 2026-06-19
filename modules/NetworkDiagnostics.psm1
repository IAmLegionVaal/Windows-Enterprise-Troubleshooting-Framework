#requires -Version 5.1
Set-StrictMode -Version Latest

function Get-NetworkSnapshot {
    [CmdletBinding()]
    param()

    $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Select-Object Name,InterfaceDescription,Status,LinkSpeed,MacAddress
    $config = Get-NetIPConfiguration -ErrorAction SilentlyContinue | ForEach-Object {
        [PSCustomObject]@{
            InterfaceAlias = $_.InterfaceAlias
            IPv4Address    = ($_.IPv4Address.IPAddress -join ', ')
            IPv4Gateway    = ($_.IPv4DefaultGateway.NextHop -join ', ')
            DnsServers     = ($_.DNSServer.ServerAddresses -join ', ')
        }
    }

    [PSCustomObject]@{
        Adapters      = $adapters
        Configuration = $config
        Generated     = Get-Date
    }
}

function Test-EnterpriseConnectivity {
    [CmdletBinding()]
    param([string[]]$Targets = @('8.8.8.8','1.1.1.1','www.microsoft.com','login.microsoftonline.com'))

    foreach ($target in $Targets) {
        $dnsSuccess = $false
        $addresses = $null
        try {
            $answers = Resolve-DnsName -Name $target -Type A -ErrorAction Stop
            $addresses = ($answers.IPAddress -join ', ')
            $dnsSuccess = $true
        } catch {}

        $pingSuccess = Test-Connection -ComputerName $target -Count 1 -Quiet -ErrorAction SilentlyContinue
        $https = $false
        if ($target -notmatch '^\d{1,3}(\.\d{1,3}){3}$') {
            $https = Test-NetConnection -ComputerName $target -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
        }

        [PSCustomObject]@{
            Target            = $target
            DnsSuccess        = $dnsSuccess
            Addresses         = $addresses
            PingSuccess       = $pingSuccess
            Https443Reachable = $https
            TestedAt          = Get-Date
        }
    }
}

function Get-DnsClientHealth {
    [CmdletBinding()]
    param()

    $cache = Get-DnsClientCache -ErrorAction SilentlyContinue | Select-Object -First 50 Entry,Name,Type,Data,Status
    $servers = Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Select-Object InterfaceAlias,InterfaceIndex,ServerAddresses

    [PSCustomObject]@{
        DnsServers = $servers
        Cache      = $cache
        Generated  = Get-Date
    }
}

function Invoke-NetworkRepair {
    [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Medium')]
    param([switch]$FlushDns,[switch]$RenewDhcp)

    $results = [System.Collections.Generic.List[object]]::new()

    if ($FlushDns -and $PSCmdlet.ShouldProcess('DNS client cache','Clear')) {
        try {
            Clear-DnsClientCache -ErrorAction Stop
            $results.Add([PSCustomObject]@{Action='Flush DNS cache';Status='Completed';Detail='DNS client cache cleared.'})
        } catch {
            $results.Add([PSCustomObject]@{Action='Flush DNS cache';Status='Failed';Detail=$_.Exception.Message})
        }
    }

    if ($RenewDhcp -and $PSCmdlet.ShouldProcess('DHCP leases','Renew')) {
        try {
            ipconfig.exe /renew | Out-Null
            $results.Add([PSCustomObject]@{Action='Renew DHCP leases';Status='Completed';Detail='Renew command completed.'})
        } catch {
            $results.Add([PSCustomObject]@{Action='Renew DHCP leases';Status='Failed';Detail=$_.Exception.Message})
        }
    }

    return $results
}

Export-ModuleMember -Function Get-NetworkSnapshot,Test-EnterpriseConnectivity,Get-DnsClientHealth,Invoke-NetworkRepair
