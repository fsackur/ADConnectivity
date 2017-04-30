#!/bin/sh
Set-Location $PSScriptRoot\..

$ManifestVersion = (Get-Module .\ADConnectivity.psd1 -ListAvailable).Version
if (-not $ManifestVersion) {exit 1}

$NewVersion = $ManifestVersion | %{New-Object version ($_.Major, $_.Minor, $_.Build, ($_.Revision+1))}
Write-Host $PSScriptRoot

Update-ModuleManifest -Path .\ADConnectivity.psd1 -ModuleVersion $NewVersion
