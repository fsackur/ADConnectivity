$DmDef = {
    param (
        [int]$i
    )


    function Geti() {
        return $i

    }

    function TestP {
        param (
            [Parameter(Mandatory=$true)][int]$P
        )

        return $P * $i

    }
}

$DomainMember = New-Module $DmDef -ArgumentList(3) -AsCustomObject
$DomainMember.Geti()
$DomainMember.TestP(4)


#$DcDef