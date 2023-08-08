<#
.SYNOPSIS
    This PowerShell module contains functions that facilitate the creation, rotation, and viewing the metadata of Kubernetes secrets.
#>


#region Load Private Functions

Get-ChildItem -Path $PSScriptRoot\PrivateFunctions\*.ps1 | Foreach-Object { . $_.FullName }

#endregion


#region Load Public Functions

Get-ChildItem -Path $PSScriptRoot\Functions\*.ps1 | Foreach-Object { . $_.FullName }

#endregion