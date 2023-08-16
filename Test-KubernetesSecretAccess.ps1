function Test-KubernetesSecretAccess {
    [CmdletBinding()]
    [OutputType([bool])]
    Param
    (
        [Parameter(Mandatory = $true)][String]$Namespace,
        [Parameter(Mandatory = $true)][String]$SecretName
    )
    PROCESS {
        [bool]$secretIsAccessible = $false

        if (Test-KubernetesNamespaceAccess -Namespace $Namespace) {
            try {
                $allSecrets = $(kubectl get secrets -n $Namespace --output=json | ConvertFrom-Json).items.metadata.name

                if ($SecretName -in $allSecrets) {
                    $secretIsAccessible = $true
                }
            }
            catch {
                $secretIsAccessible = $false
            }
        }

        return $secretIsAccessible
    }
}