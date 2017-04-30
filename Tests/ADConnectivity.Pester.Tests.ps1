
$ModuleName = $MyInvocation.MyCommand -replace '\..*' #-replace 'Pester\.' -replace 'Tests\.' -replace 'ps1$', 'psm1'
$ModulePath = "$PSScriptRoot\..\$ModuleName"
Import-Module $ModulePath -Force


Describe $ModuleName {
    
    Context 'Functionality' {

        It 'Works' {
        }






    }
}

Remove-Module $ModuleName
