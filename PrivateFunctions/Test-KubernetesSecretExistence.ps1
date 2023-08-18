function Test-KubernetesSecretExistence {
    [CmdletBinding()]
    [OutputType([bool])]
    Param
    (
        [Parameter(Mandatory = $true)][String]$Namespace,
        [Parameter(Mandatory = $true)][String]$SecretName
    )
    PROCESS {
        [bool]$secretIsAccessible = $false

        if (($(kubectl auth can-i get secrets -n $Namespace).ToLower() -eq "yes") -and ($(kubectl auth can-i list secrets -n $Namespace).ToLower() -eq "yes")) {
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
        }

        return $secretIsAccessible
    }
}