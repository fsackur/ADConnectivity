<#
    .AUTHOR
    Copyright Freddie Sackur 2017
#>

function Add-DefaultMembers {
    <#
    .Synopsis
    Applies formatting data to a custom object
        
    .Description
    This works by pass-by-reference - the original object is updated. If you want to have an object returned, use the -PassThru switch.

    Please note that most default objects will not work if they are of a standard pre-defined type. You can convert them by piping them to a select statement.

        #This will throw an exception:
        Get-Process svchost | select * | Add-DefaultMembers -DisplayProperties 'ProcessName', 'Id'

        #This will work, but you will lose the built-in methods:
        Get-Process svchost | select * | Add-DefaultMembers -DisplayProperties 'ProcessName', 'Id' -PassThru


    .Parameter InputObject
    The object to be configured with custom properties

    .Parameter DisplayProperties
    An array of property names that will be displayed on the object by default

    .Parameter SortProperties
    An array of property names that will determine sorting, in order of precedence

    .Parameter PassThru
    specifies to return the updated object to the pipeline (by default it is not returned; either way, the original reference is updated)

    .Example
    PS C:\> $MyObject = New-Object psobject -Property @{
            Material="Wood"; Size=15; FearFactor=9; ComfortLevel=12; Id=(New-Guid).Guid}

    PS C:\> $MyObject


    Material     : Wood
    Id           : dfddc07a-73d7-4bf5-b772-c66a5b4bdf36
    FearFactor   : 9
    Size         : 15
    ComfortLevel : 12


    Note that the object will format as a list by default, due to having five properties.

    PS C:\> Add-DefaultMembers -InputObject $MyObject -DisplayProperties "Material", "Size"

    PS C:\> $MyObject

    Material Size
    -------- ----
    Wood       15


    Note that only the properties that are set as default display properties will be shown by default. Since this is less than 4 properties, the object will display as a table by default.

    Note that the other properties remain accessible:

    PS C:\> $MyObject.Id
    dfddc07a-73d7-4bf5-b772-c66a5b4bdf36

    PS C:\> $MyObject | Format-Table *

    Material Id                                   FearFactor Size ComfortLevel
    -------- --                                   ---------- ---- ------------
    Wood     dfddc07a-73d7-4bf5-b772-c66a5b4bdf36          9   15           12


    .Example
    PS C:\> $MyArray = @(
                (New-Object psobject -Property @{
                    Material="Wood"; Size=15; FearFactor=9; ComfortLevel=12; Id=(New-Guid).Guid}),
                (New-Object psobject -Property @{
                    Material="Steel"; Size=9; FearFactor=43; ComfortLevel=1; Id=(New-Guid).Guid}),
                (New-Object psobject -Property @{
                    Material="Cheese"; Size=60; FearFactor=0; ComfortLevel=99; Id=(New-Guid).Guid})
            )

    PS C:\> $MyArray


    Material     : Wood
    Id           : 356c9ae2-74be-4201-8df5-9aa586976a4f
    FearFactor   : 9
    Size         : 15
    ComfortLevel : 12

    Material     : Steel
    Id           : ca3872e5-d97a-4777-9627-67557edce106
    FearFactor   : 43
    Size         : 9
    ComfortLevel : 1

    Material     : Cheese
    Id           : a330a0e5-38c5-478d-9ec5-dfd9c9add010
    FearFactor   : 0
    Size         : 60
    ComfortLevel : 99




    PS C:\> $MyArray | Add-DefaultMembers `
                    -DisplayProperties "Material", "Size" `
                    -SortProperties "Size" `
                    -TypeName "Custom.Furniture.Chair" `
                    -PassThru

    Material Size
    -------- ----
    Wood       15
    Steel       9
    Cheese     60


    The above example demonstrates piping a collection to Add-DefaultMembers. The resulting objects format as a table due to the number of default dispaly properties being less than 4.

    PS C:\> $MyArray | sort

    Material Size
    -------- ----
    Steel       9
    Wood       15
    Cheese     60


    As you can see, sort now operates on the Size property. This also demonstrates that, even using the -PassThru switch, the original objects are modified.

    PS C:\> $MyArray[0] | Get-Member


        TypeName: Custom.Furniture.Chair

    Name              MemberType   Definition                                                          
    ----              ----------   ----------                                                          
    PSStandardMembers MemberSet    PSStandardMembers {DefaultDisplayPropertySet, DefaultKeyPropertySet}
    Equals            Method       bool Equals(System.Object obj)                                      
    GetHashCode       Method       int GetHashCode()                                                   
    GetType           Method       type GetType()                                                      
    ToString          Method       string ToString()                                                   
    ComfortLevel      NoteProperty int ComfortLevel=12                                                 
    FearFactor        NoteProperty int FearFactor=9                                                    
    Id                NoteProperty System.String Id=356c9ae2-74be-4201-8df5-9aa586976a4f               
    Material          NoteProperty string Material=Wood                                                
    Size              NoteProperty int Size=15                                                         


    The custom type name is visible with the Get-Member command. This does not change the true underlying type, which is still PSCustomObject.


    .Link
    https://learn-powershell.net/2013/08/03/quick-hits-set-the-default-property-display-in-powershell-on-custom-objects/

    .Link
    https://ramblingcookiemonster.github.io/Decorating-Objects/
    #>
    [CmdletBinding(DefaultParameterSetName='Default')]
    [OutputType([void], ParameterSetName='Default')]
    [OutputType([psobject], ParameterSetName='PassThru')]
    param(
        [Parameter(Position=0, ValueFromPipeline=$true)]
        [psobject]$InputObject,
        [Parameter(Position=1)]
        [string[]]$DisplayProperties,
        [Parameter(Position=2)]
        [string[]]$SortProperties,
        [string]$TypeName,
        [Parameter(Mandatory=$true, ParameterSetName='PassThru')]
        [switch]$PassThru
    )

    begin {

        #Bug in PS 2: https://stackoverflow.com/questions/1369542/can-you-set-an-objects-defaultdisplaypropertyset-in-a-powershell-v2-script
        #There's a possible workaround in that link but I don't think we want to expand the scope
        if ($PSVersionTable.PSVersion.Major -le 2) {
            Write-Warning "Formatting\Add-DefaultMembers: Powershell version is 2 or lower; object may not display correctly."
        }
    
        #Create a 'default members' object from the display and sort property sets
        [System.Management.Automation.PSMemberInfo[]]$PSStandardMembers = @()

        #Create a display property set
        if ($DisplayProperties) {
            $Display = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet', $DisplayProperties)
            $PSStandardMembers += $Display
        }

        #Create a sort property set
        if ($SortProperties) {
            $Sort = New-Object System.Management.Automation.PSPropertySet('DefaultKeyPropertySet', $SortProperties)
            $PSStandardMembers += $Sort
        }

    }

    process {
        #Add type name
        if ($TypeName) {$InputObject.PSTypeNames.Insert(0, $TypeName)}

        if ($PSStandardMembers) {
            try {
                #Add the default members
                Add-Member -InputObject $InputObject -MemberType MemberSet -Name PSStandardMembers -Value $PSStandardMembers -Force -ErrorAction Stop
            } catch {
                #Provide more helpful exception if we cannot override the display on a .NET type
                if ($_ -match 'Cannot force the member with name "PSStandardMembers" and type "MemberSet" to be added. A member with that name and type already exists, and the existing member is not an instance extension.') {
                    throw (New-Object System.ArgumentException (
                        "Cannot add new default members to a fixed object type. Try running your input object through a select statement first."
                    ))
                } else {
                    throw $_
                }
            }
        }

        #Return to pipeline; the original reference is updated, whether we return to pipeline or not
        if ($PassThru) {Write-Output $InputObject}
    }
}
