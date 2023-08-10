function Get-KubernetesNamespaceMetadata {
    <#
    .SYNOPSIS
        Gets a Kubernetes namespace metadata.
    .DESCRIPTION
        Obtains a subset of Kubernetes namespace metadata including creation and labels.
    .PARAMETER Namespace
        The target namespace to obtain metadata from.
    .EXAMPLE
        Get-KubernetesNamespaceMetadata

        Gets metadata for all Kubernetes namespaces that the authenticated principal has access to.
    .EXAMPLE
        Get-KubernetesNamespaceMetadata -Namespace "apps"

        Gets metadata for the "apps" Kubernetes namespace.
    .EXAMPLE
        gknm

        Gets metadata for all Kubernetes namespaces that the authenticated principal has access to.
    .EXAMPLE
        gknm -n "apps"

        Gets metadata for the "apps" Kubernetes namespace.
    #>
    [CmdletBinding()]
    [Alias('gknm')]
    [OutputType([PSCustomObject])]
    Param
    (
        [Parameter(Mandatory = $false)][Alias('ns', 'n')][String]$Namespace = 'default'
    )
    PROCESS {
        $NamespaceName = @{Name = "Namespace"; Expression = { $_.name } }
        $CreatedOn = @{Name = "CreatedOn"; Expression = { $_.creationTimestamp } }
        $Labels = @{Name = "Labels"; Expression = { $_.Labels } }

        try {
            if ($PSBoundParameters.ContainsKey("Namespace")) {
                $(kubectl get namespaces $Namespace --output=json 2>&1 | ConvertFrom-Json -ErrorAction Stop).items.metadata | Select-Object -Property $NamespaceName, $CreatedOn, $Labels
            }
            else {
                $(kubectl get namespaces --output=json 2>&1 | ConvertFrom-Json -ErrorAction Stop).items.metadata | Select-Object -Property $NamespaceName, $CreatedOn, $Labels
            }
        }
        catch {
            [string]$argExceptionMessage = "Unable to obtain namespace metadata."
            if ($PSBoundParameters.ContainsKey("Namespace")) {
                $argExceptionMessage = "Unable to namespace metadata for the following namespace: $Namespace."
            }

            $ArgumentException = [ArgumentException]::new($argExceptionMessage)
            Write-Error -Exception $ArgumentException -ErrorAction Stop
        }
    }
}
