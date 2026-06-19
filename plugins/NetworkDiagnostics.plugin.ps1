@{
    Name           = 'NetworkDiagnostics'
    Version        = '2.0.1'
    Description    = 'Collects adapter, IP, route, DNS, proxy, and connectivity evidence.'
    RequiresAdmin  = $false
    SupportsRemote = $false
    Invoke         = {
        param($Context)

        $findings = [System.Collections.Generic.List[object]]::new()
        $adapters = @(Get-NetAdapter -ErrorAction SilentlyContinue |
            Select-Object Name,InterfaceDescription,Status,LinkSpeed,MacAddress,ifIndex,HardwareInterface)
        $ipConfig = @(Get-NetIPConfiguration -Detailed -ErrorAction SilentlyContinue |
            Select-Object InterfaceAlias,InterfaceIndex,NetProfile,IPv4Address,IPv6Address,IPv4DefaultGateway,DNSServer)
        $defaultRoutes = @(Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
            Where-Object State -eq 'Alive' |
            Sort-Object RouteMetric |
            Select-Object InterfaceAlias,NextHop,RouteMetric,State)
        $dnsServers = @(Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object ServerAddresses |
            Select-Object InterfaceAlias,ServerAddresses)
        $proxy = netsh winhttp show proxy | Out-String

        $upAdapters = @($adapters | Where-Object Status -eq 'Up')
        $activePhysicalAdapters = @($adapters | Where-Object { $_.Status -eq 'Up' -and $_.HardwareInterface })
        $defaultRouteAliases = @($defaultRoutes | Select-Object -ExpandProperty InterfaceAlias -Unique)
        $relevantAliases = @(
            @($activePhysicalAdapters | Select-Object -ExpandProperty Name) + $defaultRouteAliases |
            Sort-Object -Unique
        )

        if ($upAdapters.Count -eq 0) {
            $findings.Add((New-WetFinding -Plugin 'NetworkDiagnostics' -Title 'No active network adapters detected' -Severity Critical -Confidence 99 -Evidence 'No adapter returned Status=Up.' -Impact 'The endpoint cannot reach local or remote services.' -Recommendation 'Validate adapter state, cabling, Wi-Fi association, drivers, and switch connectivity.' -Target $Context.Target))
        }

        if ($defaultRoutes.Count -eq 0) {
            $findings.Add((New-WetFinding -Plugin 'NetworkDiagnostics' -Title 'No IPv4 default route detected' -Severity High -Confidence 98 -Evidence 'Get-NetRoute returned no active 0.0.0.0/0 route.' -Impact 'Traffic outside the local subnet will fail.' -Recommendation 'Validate DHCP options, static gateway configuration, VPN routes, and routing policy.' -Target $Context.Target))
        }

        $apipaEvidence = @(
            foreach ($config in $ipConfig) {
                foreach ($address in @($config.IPv4Address)) {
                    if ($address -and $address.IPAddress -like '169.254.*') {
                        $adapter = $adapters | Where-Object ifIndex -eq $config.InterfaceIndex | Select-Object -First 1
                        [PSCustomObject]@{
                            InterfaceAlias   = $config.InterfaceAlias
                            InterfaceIndex   = $config.InterfaceIndex
                            IPAddress        = $address.IPAddress
                            AdapterStatus    = $adapter.Status
                            HardwareInterface = [bool]$adapter.HardwareInterface
                            HasDefaultRoute  = $config.InterfaceAlias -in $defaultRouteAliases
                            Actionable       = (($adapter.Status -eq 'Up' -and $adapter.HardwareInterface) -or ($config.InterfaceAlias -in $defaultRouteAliases))
                        }
                    }
                }
            }
        )

        $actionableApipa = @($apipaEvidence | Where-Object Actionable)
        if ($actionableApipa.Count -gt 0) {
            $evidenceText = $actionableApipa | ForEach-Object { "$($_.InterfaceAlias)=$($_.IPAddress)" }
            $findings.Add((New-WetFinding -Plugin 'NetworkDiagnostics' -Title 'Automatic private IPv4 address detected on an active interface' -Severity High -Confidence 97 -Evidence ($evidenceText -join '; ') -Impact 'The active endpoint interface likely failed to obtain a usable DHCP lease.' -Recommendation 'Check DHCP availability, VLAN assignment, relay configuration, scope capacity, and adapter state.' -Target $Context.Target))
        }

        foreach ($dns in ($dnsServers | Where-Object InterfaceAlias -in $relevantAliases)) {
            foreach ($server in $dns.ServerAddresses) {
                if ($server -match '^(8\.8\.8\.8|8\.8\.4\.4|1\.1\.1\.1|9\.9\.9\.9)$') {
                    $findings.Add((New-WetFinding -Plugin 'NetworkDiagnostics' -Title 'Public DNS server configured on an active interface' -Severity Medium -Confidence 95 -Evidence "$($dns.InterfaceAlias): $server" -Impact 'Domain service discovery and internal name resolution may fail in managed environments.' -Recommendation 'Use approved internal DNS resolvers and document exceptions.' -Target $Context.Target))
                }
            }
        }

        $tests = [System.Collections.Generic.List[object]]::new()
        foreach ($target in @('127.0.0.1','1.1.1.1','www.microsoft.com')) {
            try {
                $result = Test-NetConnection -ComputerName $target -InformationLevel Detailed -WarningAction SilentlyContinue
                $tests.Add([PSCustomObject]@{
                    Target          = $target
                    NameResolution  = $result.NameResolutionSucceeded
                    PingSucceeded   = $result.PingSucceeded
                    RemoteAddress   = $result.RemoteAddress
                    InterfaceAlias  = $result.InterfaceAlias
                    SourceAddress   = $result.SourceAddress
                })
            }
            catch {
                $tests.Add([PSCustomObject]@{
                    Target=$target
                    NameResolution=$false
                    PingSucceeded=$false
                    RemoteAddress=$null
                    InterfaceAlias=$null
                    SourceAddress=$null
                })
            }
        }

        $microsoftTest = $tests | Where-Object Target -eq 'www.microsoft.com' | Select-Object -First 1
        if ($microsoftTest -and -not $microsoftTest.NameResolution) {
            $findings.Add((New-WetFinding -Plugin 'NetworkDiagnostics' -Title 'External DNS resolution failed' -Severity High -Confidence 90 -Evidence 'www.microsoft.com did not resolve during Test-NetConnection.' -Impact 'Web, update, sign-in, and cloud service access may fail.' -Recommendation 'Validate DNS server reachability, suffix policy, proxy settings, and upstream resolution.' -Target $Context.Target))
        }

        [PSCustomObject]@{
            Findings = @($findings)
            Evidence = @($adapters) + @($ipConfig) + @($defaultRoutes) + @($dnsServers) + @($apipaEvidence) + @($tests) + @([PSCustomObject]@{ WinHttpProxy = $proxy.Trim() })
        }
    }
}