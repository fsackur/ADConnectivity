
$ModuleName = $MyInvocation.MyCommand -replace '\..*' #-replace 'Pester\.' -replace 'Tests\.' -replace 'ps1$', 'psm1'
$ModulePath = "$PSScriptRoot\..\Private\$ModuleName"
Import-Module $ModulePath -Force


Describe $ModuleName {
    
    #Integration test. Run on domain-joined machine or, at least, a machine with internet connectivity
    Context 'Integration tests' {

        if ((Get-WmiObject Win32_ComputerSystem).DomainRole -in (0,2)) {
            Write-Host "Skipping tests; current host is not joined to a domain"
            $DomainJoined = $false
        } else {
            $DomainJoined = $true
            $Domain = (Get-WmiObject Win32_ComputerSystem).Domain
        }

        if (-not $DomainJoined) {
            if (Test-Connection 8.8.8.8 -Quiet -Count 1) {
                $CanPing8888 = $true
            } else {
                Write-Host "Skipping tests; current host can't ping 8.8.8.8"
                $CanPing8888 = $false
            }
        }


        It 'Works for domain DNS' -Pending:(-not $DomainJoined) {
            $DomainResponse = Invoke-Nslookup -Domain $Domain -DnsServer $Domain
            $DomainResponse.ConnectionSuccess | Should Be $true
            $DomainResponse.Response | foreach {$_ | Should BeOfType ipaddress}

            $PdcResponse = Invoke-Nslookup -Domain "_ldap._tcp.pdc._msdcs.$Domain" -RecordType SRV
            $PdcResponse.ConnectionSuccess | Should Be $true
            $PdcResponse.Response | foreach {$_ | Should BeOfType string}
        }


        if (-not $DomainJoined) {
            It 'Works for Google DNS' -Pending:(-not $CanPing8888) {
                $GoogleResponse = Invoke-Nslookup -Domain 'google.com' -DnsServer 8.8.8.8
                $GoogleResponse.ConnectionSuccess | Should Be $true
                $GoogleResponse.Response | foreach {$_ | Should BeOfType ipaddress}
            }
        }

    }
}

Remove-Module $ModuleName
