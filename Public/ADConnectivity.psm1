
#requires -Modules Formatting, Invoke-Nltest, Invoke-Nslookup, Invoke-Portqry


function Test-DnsServer {
<#
    .Synopsis
    Tests DNS servers
    .Description
    Tests DNS servers for A records from an AD domain and the PDC locator SRV record.
    Returns psobject with valid servers, not-responding servers, and invalid servers (servers that did not return the expected records)
    .Parameter AdDomain
    Specify the DNS name of the AD domain to test. Default: the machine's domain (or workgroup name, which will usually not be valid)
    .Parameter DnsServers
    Specify the IP addresses of the DNS servers to test. Default: the DNS servers configured on the primary network adapter
    .Example
    PS C:\> Test-DnsServer
    ValidServers                             InvalidServers NonResponsiveServers Recommendations
    ------------                             -------------- -------------------- ---------------
    {10.2.204.154, 10.9.97.172, 10.9.97.179} {}             {}                                  
    Tests the configured DNS servers on the primary network adapter for ability to resolve the machines's AD domain and the PDC locator record.
#>
    param(
        [string]$AdDomain = ((Get-WmiObject Win32_ComputerSystem).Domain),
        [ipaddress[]]$DnsServers = $(Get-WmiObject Win32_NetworkAdapterConfiguration | 
                                        where {$_.DNSServerSearchOrder} | 
                                        foreach {$_.DNSServerSearchOrder}),
        [System.Collections.Generic.List[string]]$OutRecommendations
    )

    $DnsResult = New-Object psobject -Property @{
        ValidServers = @();
        InvalidServers = @();
        NonResponsiveServers = @();
        Recommmendations = @()
    }

    $DnsResult | Add-Member -MemberType ScriptProperty -Name ServersTested -Value {
        $this.ValidServers + $this.InvalidServers + $this.NonResponsiveServers
    }

    $DnsResult | Add-Member -MemberType ScriptMethod -Name ToString -Force -Value {
        [string]::Format(
            "{0}/{1} passed",
            $this.ValidServers.Count,
            $this.ServersTested.Count
        )
    }

    $DnsResult | Add-DefaultMembers -DisplayProperties 'ValidServers', 'InvalidServers', 'NonResponsiveServers', 'Recommendations'

    foreach ($DnsServer in $DnsServers) {
        $DomainA = Invoke-Nslookup $AdDomain $DnsServer
        if (-not $DomainA.ConnectionSuccess) {
            $DnsResult.NonResponsiveServers += $DnsServer; continue
        }
        if (-not $DomainA.Response) {
            $DnsResult.InvalidServers += $DnsServer; continue
        }
        
        $Pdc = Invoke-Nslookup "_ldap._tcp.pdc._msdcs.$AdDomain" $DnsServer "SRV"
        if ($Pdc.Response) {
            $DnsResult.ValidServers += $DnsServer
        } else {
            $DnsResult.InvalidServers += $DnsServer
        }
    }

    foreach ($InvalidServer in $DnsResults.InvalidServers) {
        $DnsResults.Recommendations += "Remove $InvalidServer from DNS server list"
    }

    foreach ($NonResponsiveServer in $DnsResults.NonResponsiveServers) {
        $DnsResults.Recommendations += "Check DNS service on and UDP-53 port access to $NonResponsiveServer or remove from DNS server list"
    }
    
    return $DnsResult
}



function Test-AdPorts {
<#
    .Synopsis
    Tests connectivity to a domain controller
    .Description
    Tests that a machine can reach a domain controller on the well-known ports for, e.g., LDAP, Kerberos, Rpc.
    Returns a structured object with information on how to remediate issues
    .Parameter DomainController
    The IP address of one or more domain controllers to test
    .Example
    PS C:\> Test-AdPorts -DomainController 172.24.0.28
    Success Summary                                     
    ------- -------                                     
       True 172.24.0.28 is reachable on all AD protocols
    Validates that 172.24.0.28 is accessible for all AD-related protocols
    .Link
    http://blogs.msmvps.com/acefekay/2011/11/01/active-directory-firewall-ports-let-s-try-to-make-this-simple/
#>
    param(
        [ipaddress[]]$DomainController
    )
    
    #http://blogs.msmvps.com/acefekay/2011/11/01/active-directory-firewall-ports-let-s-try-to-make-this-simple/
    #Disregard UDP ports; if it isn't listening on TCP, we call it a failure
    $ProtocolPorts = @{
        'RpcEpm'    = 'TCP-135';
        'Kerberos'  = 'TCP-88';
        'Kpasswd'   = 'TCP-464';
        'LDAP'      = 'TCP-389', 'TCP-636';
        'SMB'       = 'TCP-445';
        'GC'        = 'TCP-3268', 'TCP-3269';
    }

    #https://social.technet.microsoft.com/wiki/contents/articles/584.active-directory-replication-over-firewalls.aspx
    $RpcSamUuid      = '12345778-1234-abcd-ef00-0123456789ac'	 	 #UUID in RPC for Security Account Manager
    $RpcNetlogonUuid = '12345678-1234-abcd-ef00-01234567cffb'	 	 #UUID in RPC for Netlogon; secure channel and trusts; needed to PDC
    $RpcReplUuid     = 'e3514235-4b06-11d1-ab04-00c04fc2dcd2';	 	 #UUID in RPC for MS NT Directory DRS Interface; AD Replication



    if ($DomainController -is [System.Collections.ICollection] -and $DomainController.Count -gt 1) {
        #ICollection includes arrays, lists etc

        $DcResults = New-Object psobject -Property @{
            ServerResults = (New-Object 'System.Collections.Generic.List[psobject]' ($DomainController.Count));
            Success = $null;
            Summary = $null;
            Recommendations = @();
        }

        foreach ($DC in $DomainController) {
            $DcResult = Test-AdPorts -DomainController $DC
            $DcResults.ServerResults.Add($DcResult)
        }

        $FailedServers = $DcResults.ServerResults | where {-not $_.Success}
        $DcResults.Success = $null -eq $FailedServers
        $DcResults.Summary = [string]::Format(
            "{0}/{1} passed",
            ($DcResults.ServerResults.Count - $FailedServers.Count),
            $DcResults.ServerResults.Count
        )
        $DcResults.Recommendations = $DcResults.ServerResults | select -ExpandProperty Recommendations
        $DcResults | Add-Member -MemberType ScriptMethod -Name "ToString" -Force -Value {return $this.Summary}
        $DcResults | Add-DefaultMembers -DisplayProperties 'Success', 'Summary'

        return $DcResults
        

    } else {
        #$DomainController is a single item, not an ICollection

        $DC = $DomainController | select -First 1   #Unroll any single-item collection

        $DcResult = New-Object psobject -Property @{
            Server = $DC;
            ProtocolSuccess = @{'RpcSam' = $null};
            ProtocolPorts = $ProtocolPorts.Clone();
            FailedProtocols = @();
            Success = $null;
            Summary = $null;
            Recommendations = $null
        }
        $ProtocolPorts.Keys | foreach {$DcResult.ProtocolSuccess.Add($_, $null)}


        $RpcEpmText = $null
        foreach ($Protocol in $ProtocolPorts.Keys) {
            $Port = $ProtocolPorts[$Protocol] | select -First 1

            $Result = Invoke-Portqry -Server $DC -Protocol $Port.Split('-')[0] -Port $Port.Split('-')[1]

            #We'll need this to test RPC high ports
            if ($Protocol -eq 'RpcEpm') {$RpcEpmText = $Result.PortQryText}

            #Where multiple ports will work for a protocol, try the second one if needed
            $Port = $ProtocolPorts[$Protocol] | select -Skip 1
            if (($true -ne $Result.Success) -and ($null -ne $Port)) {
                $Result = Invoke-Portqry -Server $DC -Protocol $Port.Split('-')[0] -Port $Port.Split('-')[1]
            }

            $DcResult.ProtocolSuccess[$Protocol] = $Result.Success
        }

        if ($Matches) {$Matches.Clear()}
        if ($RpcEpmText -and $RpcEpmText -match "$RpcSamUuid.*\nncacn_ip_tcp:.*?\[(\d*)\]") {
            $RpcSamPort = [int]($Matches.1)
            $DcResult.ProtocolPorts.Add('RpcSam', $RpcSamPort)
            $Result = Invoke-Portqry -Server $DC -Protocol TCP -Port $RpcSamPort
            $DcResult.ProtocolSuccess['RpcSam'] = $Result.Success
        } else {
            $DcResult.ProtocolPorts.Add('RpcSam', 'Port not returned from RPC EPM')
        }

        $DcResult.FailedProtocols = $DcResult.ProtocolSuccess.Keys | where {$DcResult.ProtocolSuccess[$_] -ne $true}
        $DcResult.Success = ($null -eq $DcResult.FailedProtocols)
        
        if ($DcResult.Success) {
            $DcResult.Summary = [string]::Format("{0} is reachable on all AD protocols", $DcResult.Server)

        } elseif ($DcResult.FailedProtocols.Count -eq $DcResult.ProtocolSuccess.Keys.Count) {
            $DcResult.Recommendations = [string]::Format(
                "Verify {0} is a domain controller; open all AD ports",
                $DcResult.Server
            )
            $DcResult.Summary = [string]::Format(
                "{0} is not reachable on any AD protocols",
                $DcResult.Server
            )

        } else {
            $DcResult.Recommendations = [string]::Format(
                "Open port(s) {1} to {0}",
                $DcResult.Server,
                ((    #e.g.:  LDAP (TCP-389), Kerberos (TCP-88), GC (TCP-3268)
                    $DcResult.FailedProtocols | foreach {
                        [string]::Format("{0} ({1})", $_, ($DcResult.ProtocolPorts[$_] | select -First 1))
                    }
                ) -join ', ')
            )
            $DcResult.Summary = [string]::Format(
                "{0} is not reachable on {1}",
                $DcResult.Server,
                ($DcResult.FailedProtocols -join ', ')
            )
        }
        
        $DcResult | Add-Member -MemberType ScriptMethod -Name "ToString" -Force -Value {return $this.Summary}
        $DcResult | Add-DefaultMembers -DisplayProperties 'Success', 'Summary'

        return $DcResult
    }
}



function Test-ADConnectivity {
<#
    .Synopsis
    Runs a sequence of tests to determine whether connectivity supports correct AD operation
    
    .Description
    Full description: runs a sequence of tests on member servers or domain controllers to identify AD connectivity issues
     - Member server:
        - Enumerate DNS servers
            - Test each of them returns A records for machine's domain
            - Test each of them returns SRV records for PDC
            - Test returned records match from all DNS servers
        - Test machine is in an AD Site
        - Test secure channel
        - Test all known AD ports, and RPC ports for AD RPC apps, to all domain controllers in site
        - Test NTP to PDC
     - Domain Controller:
        - All of the above, plus:
        - Checks recent replication status
        - Identifies all potential replication partners, not just current ones
        - Tests RPC port for AD replication service to all potential partners
    .Example
    PS C:\> Test-ADConnectivity
    
    DcReplicationResult : 
    DnsResult           : 3/3 passed
    DomainRole          : Member
    DcResult            : 3/3 passed
    AdDomain            : 
    AdSite              : Svalbard-HQ
    Recommendations     : 
    Tests connectivity from the current machine to servers responsible for AD operation
#>
    param(
        #TODO: allow testing of specified servers, e.g. new domain controllers
        #$DomainController

        #TODO: allow skipping tests
    )

    $Script:AdReport = New-Object psobject -Property @{
        DomainRole = $null;
        AdDomain = $null;
        DnsResult = $null
        Recommendations = (New-Object 'System.Collections.Generic.List[string]' (20));
        AdSite = $null;
        DcResult = $null;
        DcReplicationResult = $null;
    }

    #TODO: implement recommended actions
    #$Recommendations = New-Object 'System.Collections.Generic.List[psobject]' (20)

    $WmiComputer = Get-WmiObject Win32_ComputerSystem

    $AdReport.DomainRole = switch ($WmiComputer.DomainRole) {
        0 {'Workgroup'}
        1 {'Member'}
        2 {'Workgroup'}
        3 {'Member'}
        4 {'DC'}
        5 {'PDC'}
    }
    
    if ($AdDomain.DomainRole -eq 'Workgroup') {
        return $AdReport
    } else {
        $AdDomain = $WmiComputer.Domain.ToLower()
        $AdReport.AdDomain = $AdDomain
    }

    [ipaddress[]]$DnsServers = $(
        Get-WmiObject Win32_NetworkAdapterConfiguration | 
            where {$_.DNSServerSearchOrder} | 
            foreach {$_.DNSServerSearchOrder}
    )

    $AdReport.DnsResult = Test-DnsServer -AdDomain $AdDomain -DnsServers $DnsServers -OutRecommendations $AdReport.Recommendations

    return $AdReport

    $AdSite = Invoke-Nltest -GetSite
    #TODO
    #if (-not $AdSite) {$Recommendations.Add("Verify that the machine's subnet is attached to a site in AD")}
    $AdReport.AdSite = $AdSite

    [ipaddress[]]$DCs = Invoke-Nltest -GetDcInSite -AdDomain $AdDomain -AdSite $AdSite

    #TODO: always test PDC
    $AdReport.DcResult = Test-AdPorts -DomainController $DCs

    $AdReport.Recommendations.AddRange(([psobject[]]$AdReport.DcResult.Recommendations))

    if ($AdReport.DomainRole -match 'DC') {
        #TODO: further tests if current machine is DC
    }


    return $AdReport
}

