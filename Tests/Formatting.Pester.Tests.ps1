
$ModuleName = $MyInvocation.MyCommand -replace '\..*' #-replace 'Pester\.' -replace 'Tests\.' -replace 'ps1$', 'psm1'
$ModulePath = "$PSScriptRoot\..\Public\$ModuleName"
Import-Module $ModulePath -Force


Describe $ModuleName {
    
    Context 'Functionality' {
        $MyObject = New-Object psobject -Property @{
            Material="Wood";
            Size=15;
            FearFactor=9;
            ComfortLevel=12;
            Id=(New-Guid).Guid
        }

        It 'Adds TypeName' {
            $MyObject | Add-DefaultMembers -TypeName 'Chair'
            $MyObject.PSTypeNames[0] | Should BeExactly 'Chair'
        }

        It 'Adds default display properties' {
            $MyObject | Add-DefaultMembers -DisplayProperties 'Material', 'Size'
            $MyObject.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames | Should BeExactly 'Material', 'Size'
        }


        It 'Adds default sort properties' -Pending {
            $MyObject | Add-DefaultMembers -SortProperties 'Material', 'Size'
            $MyObject.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames | Should BeExactly 'Material', 'Size'
        }


    }
}

Remove-Module $ModuleName
