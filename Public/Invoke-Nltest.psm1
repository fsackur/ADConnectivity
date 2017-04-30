

$Script:NltestPath = "C:\Windows\system32\nltest.exe","$PSScriptRoot\nltest.exe" | where {Test-Path $_ -PathType Leaf} | select -First 1


function Invoke-Nltest {
<#
    .Synopsis
    Gets AD-related information using nltest.exe
    .Description
    Wraps nltest.exe to provide psobject output. Outputs string for simple queries, structured object for more complex queries
    .Parameter Path
    Specifies the path to nltest.exe
    .Parameter GetSite
    Get the machine's AD site
    .Parameter GetDcInSite
    Get the domain controllers in an AD site
    .Parameter AdDomain
    Specifies the domain for the query
    .Parameter AdSite
    Specifies the AD site for the query
    .Example
    PS C:\> Invoke-Nltest -Site
    Svalbard-HQ
    Returns the machine's AD site
#>
    [CmdletBinding(DefaultParameterSetName='NoParams')]
    [OutputType([string], ParameterSetName='Site')]
    param(
        [Parameter()]
        [ValidateScript({
            if (-not (
                (Test-Path $_) -and
                ((Split-Path $_ -Leaf) -match 'nltest(\.exe)?')
            )) {throw (New-Object System.ArgumentException ("Specified path to nltest.exe $_ is invalid"))}
            return $true
        })]
        $Path = $NltestPath,   #inherits from the module variable if not specified explicitly

        [Parameter(Mandatory=$true, ParameterSetName='GetSite')]
        [switch]$GetSite,

        [Parameter(Mandatory=$true, ParameterSetName='GetDcInSite')]
        [switch]$GetDcInSite,

        [Parameter(Mandatory=$true, ParameterSetName='GetDcInSite')]
        [string]$AdDomain,

        [Parameter(Mandatory=$false, ParameterSetName='GetDcInSite')]
        [string]$AdSite
    )

    if ($PSCmdlet.ParameterSetName -eq 'NoParams') {
        throw (New-Object System.Management.Automation.ParameterBindingValidationException ("No parameter specified to Invoke-Nltest"))
    }

    $ErrorActionPreferencePop = $ErrorActionPreference; $ErrorActionPreference = 'SilentlyContinue'
    if ($Matches) {$Matches.Clear()}
    #Remove-Variable Matches -ErrorAction SilentlyContinue
    $Output = $null

    switch ($PSCmdlet.ParameterSetName) {

        'GetSite' {
            $Text = (& $Path /DSGETSITE) -join "`n"
            [void]($Text -match '(?<Site>.+)')
            $Output = $Matches.Site
        }
    
        'GetDcInSite' {
            if (-not $Site) {$Site = Invoke-Nltest -Path $Path -GetSite}
            $Text = (& $Path /DNSGETDC:$AdDomain /SITE:$AdSite) -join "`n"
            $Pattern = '(?<=Site specific:\n).*(?=\nNon-Site specific:)'
            $Match = [regex]::Match($Text, $Pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
            if ($Match) {
                $Output = $Match.Value -split '\n' | foreach {$_ -replace '^\s*\S*\s*'}
            }

        }
    }

    $ErrorActionPreference = $ErrorActionPreferencePop
    return $Output
}

