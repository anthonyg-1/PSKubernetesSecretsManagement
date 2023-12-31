<#
.SYNOPSIS
    This PowerShell module contains functions that facilitate the creation, rotation, and viewing the metadata of Kubernetes secrets.
#>



# Prerequisites:

try {
    Get-Command -Name kubectl -ErrorAction Stop | Out-Null
}
catch {
    $FileNotFoundException = [IO.FileNotFoundException]::new("Required binary kubectl not found in path. Module import failed.")
    throw $FileNotFoundException
}

$kubeConfigDefaultPath = "$HOME/.kube/config"
if (-not(Test-Path -Path $kubeConfigDefaultPath)) {
    $fileNotFoundMessage = "kubeconfig not found in the following default path: {0}" -f $kubeConfigDefaultPath
    $FileNotFoundException = [IO.FileNotFoundException]::new($fileNotFoundMessage)
    throw $FileNotFoundException
}



# Load Private Functions:

Get-ChildItem -Path $PSScriptRoot\PrivateFunctions\*.ps1 | Foreach-Object { . $_.FullName }



# Load Public Functions:

Get-ChildItem -Path $PSScriptRoot\Functions\*.ps1 | Foreach-Object { . $_.FullName }
