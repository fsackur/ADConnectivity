
<#
    Contents of .git\hooks\pre-commit (no file extension):

    powershell -NoProfile -ExecutionPolicy Bypass -File '$GIT_DIR\..\Private\Pre-Commit.ps1'

    (This expects this file to be in Private subfolder of repo. Update accordingly)

    $GIT_DIR is a bash environment variable pointing to the .git folder. 'pre-commit' is a bash script.

    The git hook fails the commit if exit code from this PS is non-zero.
#>

$ModuleName = 'ADConnectivity'

#Script expects to be in subfolder of repo
Set-Location $PSScriptRoot\..
if (-not (Test-Path .git)) {
    Write-Output "Pre-Commit.ps1: not in expected location"
    exit 1
}

#Add pre-commit hook if not present; there's no way to automatically update this in a cloned repo.
if (-not (Test-Path .\.git\hooks\pre-commit)) {
@'
#!/bin/sh
powershell -NoProfile -ExecutionPolicy Bypass -File '$GIT_DIR\..\Hooks\Pre-Commit.ps1'
'@ | Out-File .\.git\hooks\pre-commit -Encoding ascii
}


$ManifestPath = ".\$ModuleName.psd1"

#Get staged changes in .psd1 file
$StatusDiff = (git status $ManifestPath -v) -join "`n"

if ($StatusDiff -match "-ModuleVersion = '[\d\.]+?'\n\+ModuleVersion = '[\d\.]+?'") {
    Write-Output 'Pre-Commit.ps1: ModuleVersion has already been changed in manifest file; skipping auto-increment'
    exit 0


} else {
    #Auto-increment version
    try {
        $Manifest = (Get-Module $ManifestPath -ListAvailable)
    } catch {
        Write-Output "Pre-Commit.ps1: module manifest not in expected location"
    }

    $ManifestVersion = $Manifest.Version
    if (-not $ManifestVersion) {
        Write-Output "Pre-Commit.ps1: version not present in module manifest"
        exit 1

    } else {
        $NewVersion = $ManifestVersion | %{New-Object version ($_.Major, $_.Minor, $_.Build, ($_.Revision+1))}
        Write-Output 'Pre-Commit.ps1: Incremented manifest version'
        Update-ModuleManifest -Path $ManifestPath -ModuleVersion $NewVersion
        git add $ManifestPath
    }
}
