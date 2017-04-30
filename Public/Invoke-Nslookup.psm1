

function Invoke-Nslookup {
<#
    .Synopsis
    Query DNS - for compatibility with versions that do not have the newer cmdlets
    .Description
    Query a DNS record 
    .Parameter Domain
    The name to resolve
            
    .Parameter DnsServer
    The server to query
    .Parameter RecordType
    The type of the record
    
    .Example
    PS C:\> Invoke-Nslookup -Domain 'corp.dustyfox.uk'
    Response       ConnectionSuccess
    --------       -----------------
    134.213.29.116              True
    Looks up the domain corp.dustyfox.uk
    
    .Example
    PS C:\> Invoke-Nslookup -Domain 'khjdfhjkdfakhjfdhjkfdaskj'
    Response ConnectionSuccess
    -------- -----------------
                          True
    Attempts to look up a non-existing domain
    .Example
    PS C:\> Invoke-Nslookup -Domain '_ldap._tcp.pdc._msdcs.corp.dustyfox.uk' -DnsServer 'corp.dustyfox.uk' -RecordType SRV
    Response             ConnectionSuccess
    --------             -----------------
    DC1.corp.dustyfox.uk              True
    Looks up the PDC of an AD domain against the DNS server corp.dustyfox.uk. Will use default resolvers first to find the DNS server
#>
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Domain,

        [Parameter(Mandatory=$false, Position=1)]
        [string]$DnsServer,

        [Parameter(Mandatory=$false, Position=2)]
        [ValidateSet("A","AAAA","SRV","CNAME","PTR","NS","SOA")]   #Just add them as you need them
        [string]$RecordType="A"

    )
        
    $Invocation = "nslookup -querytype=$RecordType $Domain $DnsServer"
    $EapPush = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    Write-Debug "Invoking: $Invocation"
    $Text = (Invoke-Expression "$Invocation 2>`$null") -join "`n"
    $ErrorActionPreference = $EapPush

    <#
        $Pattern = '\w.+?(?=$|\n\s*(\n|$))'
    
        first expression: '\w.+?'
            starts with a word character
            '.+' => any sequence of characters
            '?' => non-greedy; matches up until the next capture expression
        second expression: (?=$|\n\s*(\n|$))
            '?=' => look-ahead group. Defines the end of the previous expression, but doesn't go into the output
            matches either '$' or '\n\s*(\n|$)'
            subexpression: '\n\s*(\n|$)'
                matches a blank line.
                must start with a newline '\n'
                contains any number of whitespace characters '\s*'
                then matches either another newline '\n' or end-of-string '$'
    #>
    $Pattern = '\w.+?(?=$|\n\s*(\n|$))'

    $HeaderText, $ResponseText = (
        [regex]::Matches(
            $Text, 
            $Pattern, 
            [System.Text.RegularExpressions.RegexOptions]::Singleline
        )
    ) | select -ExpandProperty Value
      
    Write-Debug '------ Server header --------------'
    if ($null -eq $HeaderText) {Write-Debug 'null'} else {Write-Debug $HeaderText}
    Write-Debug '------ Response -------------------'
    if ($null -eq $ResponseText) {Write-Debug 'null'} else {Write-Debug $ResponseText}

    $HasTimedOut = (
        ($ResponseText -match "(request .* timed out|No response from server)") -or
        ($ResponseText -match "^(DNS request timed out\.\n\s*timeout was \d+ seconds\.(\n|$))+$")
    )

    Write-Debug "Server timed out: $HasTimedOut"
    if ($HasTimedOut) {Write-Verbose "$DnsServer timed out"}

    
    $Output = @{}
    $Output.ConnectionSuccess = -not $HasTimedOut

    $Output.Response = switch ($RecordType) {
        "A"     {[string[]]([regex]::Matches($ResponseText, '(?:\d{1,3}\.){3}(?:\d{1,3})') | select -ExpandProperty Value)}
        "SRV"   {[string[]]([regex]::Matches($ResponseText, '(?:svr hostname   = ([\S\.]*))') | select -ExpandProperty Groups | select -Skip 1 -ExpandProperty Value)}
        default {$ResponseText}
    }

    return [pscustomobject]$Output
}
