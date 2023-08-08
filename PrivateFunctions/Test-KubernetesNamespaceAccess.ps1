function Test-KubernetesNamespaceAccess {
    [CmdletBinding()]
    [OutputType([bool])]
    Param
    (
        [Parameter(Mandatory = $true)][String]$Namespace
    )
    PROCESS {
        [bool]$namespaceIsAccessible = $false

        try {
            $targetNamespace = (kubectl get namespaces $Namespace --output=json 2>&1 | ConvertFrom-Json -ErrorAction Stop).metadata.labels.'kubernetes.io/metadata.name'

            if ($targetNamespace -eq $Namespace) {
                $namespaceIsAccessible = $true
            }
        }
        catch {
            $namespaceIsAccessible = $false
        }

        return $namespaceIsAccessible
    }
}
