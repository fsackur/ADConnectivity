Add-Type -TypeDefinition (Get-Content $PSScriptRoot\Class1.cs | Out-String)

$PortResult1 = New-Object Dusty.Net.PortResult ('Server1', 'TCP', 88, $true, 'ResponseData')
$PortResult2 = New-Object Dusty.Net.PortResult ('Server1', 'TCP', 389, $true, 'ResponseData')
$PortResult3 = New-Object Dusty.Net.PortResult ('Server1', 'TCP', 464, $false, 'ResponseData')
$PRC = New-Object Dusty.Net.PortResultCollection
$PRC.Add($PortResult1)
$PRC.Add($PortResult2)
$PRC.Add($PortResult3)

Update-FormatData -AppendPath .\Dusty.Net.format.ps1xml
Update-TypeData  -AppendPath .\Dusty.Net.types.ps1xml

