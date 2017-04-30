
$ModuleName = $MyInvocation.MyCommand -replace '\..*' #-replace 'Pester\.' -replace 'Tests\.' -replace 'ps1$', 'psm1'
$ModulePath = "$PSScriptRoot\..\Public\$ModuleName"
Import-Module $ModulePath -Force


Describe $ModuleName {
    
    #Integration test. Run on domain-joined machine
    Context 'Integration tests' {

        if ((Get-WmiObject Win32_ComputerSystem).DomainRole -in (0,2)) {
            Write-Host "Skipping tests; current host is not joined to a domain"
            $Pending = $true
        } else {
            $Site = Invoke-Nltest -GetSite
        }

        It 'Gets site' -Pending:$Pending {
            $Site | Should BeOfType string
            $Site.Length | Should Match '.'
        }

        It 'Gets DCs in site' -Pending:$Pending {
            $DCs = Invoke-Nltest -GetDcInSite -AdSite $Site
            $DCs | foreach {$_ | Should BeOfType ipaddress}
        }


    }
}

Remove-Module $ModuleName
