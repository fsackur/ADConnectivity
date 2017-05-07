
$ModuleName = $MyInvocation.MyCommand -replace '\..*' #-replace 'Pester\.' -replace 'Tests\.' -replace 'ps1$', 'psm1'
$ModulePath = "$PSScriptRoot\..\Private\$ModuleName.psm1"
$RequiresLine = Get-Content $ModulePath | where {$_ -match '#requires'} | select -First 1
$RequiredModuleNames = ($RequiresLine -replace '.*-Modules ' -replace ' -\w.*') -split ',\s*'
$RequiredModuleNames | %{
    Import-Module -Scope Local -Name $ModulePath\..\$_
}
Import-Module $ModulePath -Force



Describe $ModuleName {
    
    #Integration test. Run on domain-joined machine
    Context 'Integration tests' {

        if ((Get-WmiObject Win32_ComputerSystem).DomainRole -in (0,2)) {
            Write-Host "Skipping tests; current host is not joined to a domain"
            $DomainJoined = $false
        } else {
            $DomainJoined = $true
            $Domain = (Get-WmiObject Win32_ComputerSystem).Domain
            $Response = Invoke-Portqry -Server $Domain -Port 88 -Protocol TCP
        }


        It 'Tests TCP 88 to domain FQDN' -Pending:(-not $DomainJoined) {
            $Response.Success | Should Be $true
            $Response.Summary | Should BeExactly 'Listening on TCP-88'
            $Response.PortQryText | Should BeOfType string
        }



    }
}

Remove-Module $ModuleName
$RequiredModuleNames | Remove-Module
