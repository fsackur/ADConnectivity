#requires -Modules Formatting

$Script:PortQryPath = "$PSScriptRoot\PortQry.exe" | where {Test-Path $_ -PathType Leaf} | select -First 1


function Invoke-Portqry {
<#
    .Synopsis
    Tests connectivity to a TCP or UDP port on a remote machine
    .Description
    Invokes PortQry and returns a structured object
    .Parameter Path
    The path to PortQry.exe
    .Parameter Server
    The server to test connection to
    .Parameter Protocol
    Either TCP or UDP
    .Parameter Port
    TCP or UDP port to test connection to
    .Example
    PS C:\> Invoke-Portqry -Server 10.2.204.154 -Protocol TCP -Port 1433
    Success Summary                
    ------- -------                
       True Listening on TCP-1433
    Tests TCP connectivity to 10.2.204.154 on port 1433
    .Link
    https://www.microsoft.com/en-us/download/details.aspx?id=17148
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateScript({
            if ((Test-Path $_) -and
                ((Split-Path $_ -Leaf) -imatch "PortQry(.exe)?")) {
                $true
            } else {
                throw (New-Object System.ArgumentException ("PortQry.exe not found at path $_"))
            }
        })]
        [string]$Path = $PortQryPath,   #inherits from the module variable if not specified explicitly

        [Parameter(Mandatory=$true, Position=0)]
        [string]$Server,

        [Parameter(Mandatory=$true, Position=1)]
        [ValidateSet("TCP", "UDP")]
        [string]$Protocol,

        [Parameter(Mandatory=$true, Position=2)]
        [ValidateRange(1,65535)]
        [int]$Port
    )


    $Output = New-Object psobject -Property @{
        Protocol = $Protocol;
        Port = $Port;
        Server = $Server;
        Success = $null;
        Summary = "Test did not run";
        PortQryText = $null;
    }
    $Output | Add-Member -MemberType ScriptMethod -Name "ToString" -Force -Value {return $this.Summary}
    $Output | Add-DefaultMembers -DisplayProperties 'Success', 'Summary'

    $Output.PortQryText = (& $Path -n $Server -nr -p $Protocol -e $Port) -join "`n"

    if ($Output.PortQryText -match "LISTENING($|[^( or FILTERED)])") {    #contains 'LISTENING' but not 'LISTENING or FILTERED'
        $Output.Success = $true
        $Output.Summary = "Listening on " + $Output.Port
    } elseif (($Protocol -eq "UDP") -and ($Output.PortQryText -match "LISTENING")) {
        $Output.Summary = "No response from " + $Output.Port
    } else {
        $Output.Success = $false
        $Output.Summary = "Not listening on " + $Output.Port
    }

    $Output.Summary = [string]::Format(
        "{2} {0}-{1}",
        $Output.Protocol,
        $Output.Port,
        $(
            if ($true -eq $Output.Success) {"Listening on"}
            elseif ($null -eq $Output.Success) {"No response from"}
            else {"Not listening on"}
        )
    )
    return $Output
}

