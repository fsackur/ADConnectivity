Add-Type -TypeDefinition (Get-Content $PSScriptRoot\TestClass.cs | Out-String)

$P = New-Object Dusty.Net.P

$P.GetName()
