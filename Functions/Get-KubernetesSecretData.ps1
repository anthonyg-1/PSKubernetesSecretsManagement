function Get-KubernetesSecretData {
    <#
    .SYNOPSIS
        Gets a Kubernetes secret metadata.
    .DESCRIPTION
        Obtains a subset of Kubernetes secret metadata including creation and update date/times.
    .PARAMETER Namespace
        The Kubernetes namespace that the secret will be created in.
    .PARAMETER SecretName
        The name of the Kubernetes secret.
    .EXAMPLE
        Get-KubernetesSecretData -Namespace "apps"

        Gets Kubernetes secret data for all secrets in the 'apps' namespace.
    .EXAMPLE
        Get-KubernetesSecretData -SecretName "my-secret"

        Gets Kubernetes secret data for the secret 'my-secret' in the default namespace.
    .EXAMPLE
        Get-KubernetesSecretData -Namespace "apps" -SecretName "my-secret"

        Gets Kubernetes secret data for the secret 'my-secret' in the 'apps' namespace.
    .EXAMPLE
        Get-KubernetesNamespaceMetadata | Get-KubernetesSecretDat

        Gets Kubernetes secret data all secrets across all authorized namespaces.
    .EXAMPLE
        gksd -n "apps"

        Gets Kubernetes secret data for all secrets in the 'apps' namespace.
    .EXAMPLE
        gksd -s "my-secret"

        Gets Kubernetes secret data for the secret 'my-secret' in the default namespace.
    .EXAMPLE
        gksd -n "apps" -s "my-secret"

        Gets Kubernetes secret data for the secret 'my-secret' in the 'apps' namespace.
    .EXAMPLE
        gknm | gksd

        Gets Kubernetes secret data all secrets across all authorized namespaces.
    .LINK
        Get-KubernetesNamespaceMetadata
    #>
    [CmdletBinding()]
    [Alias('gksd')]
    [OutputType([PSCustomObject])]
    Param
    (
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)][Alias('ns', 'n')][String]$Namespace = 'default',
        [Parameter(Mandatory = $false)][Alias('s')][String]$SecretName
    )
    BEGIN {
        try {
            Get-Command -Name kubectl -ErrorAction Stop | Out-Null
        }
        catch {
            [IO.FileNotFoundException]::new("Unable to find kubectl. Execution halted.")
        }

        if (-not(Test-KubernetesNamespaceAccess -Namespace $Namespace)) {
            $ArgumentException = [Security.SecurityException]::new("The following namespace was either not found or inaccessible: $Namespace")
            Write-Error -Exception $ArgumentException -ErrorAction Stop
        }

    }
    PROCESS {
        $targetSecretNames = @()

        $targetNamespace = $Namespace

        if ($PSBoundParameters.ContainsKey("SecretName")) {
            if (-not(Test-KubernetesSecretAccess -Namespace $targetNamespace -SecretName $SecretName)) {
                $secretArgExceptionMessage = "The following secret was either not found or inaccessible. Check secret name, access rights for the specific secret and/or namespace, and try again: {0}:{1}" -f $targetNamespace, $SecretName
                $SecretArgumentException = [ArgumentException]::new($secretArgExceptionMessage)
                Write-Error -Exception $SecretArgumentException -ErrorAction Stop
            }

            $targetSecretNames += $SecretName
        }
        else {
            try {
                [PSCustomObject]$secretGetAllResults = $(kubectl get secrets --namespace=$targetNamespace --output=json 2>&1) | ConvertFrom-Json -ErrorAction Stop
                $targetSecretNames += ($secretGetAllResults.items.metadata | Select-Object -ExpandProperty name)
            }
            catch {
                $ArgumentException = [ArgumentException]::new("Unable to get secrets in the $targetNamespace namespace.")
                Write-Error -Exception $ArgumentException -ErrorAction Stop
            }
        }

        ## All secrets across all namespaces:
        #  $(kubectl get secrets -A --output=json 2>&1 | ConvertFrom-Json -ErrorAction Stop).items.metadata

        foreach ($targetSecretName in $targetSecretNames) {
            try {
                [PSCustomObject]$secretGetResult = $(kubectl get secrets --namespace=$targetNamespace $targetSecretName --output=json 2>&1) | ConvertFrom-Json -ErrorAction Stop
                [PSCustomObject]$managedFieldValues = $((kubectl get secrets --namespace=$targetNamespace $targetSecretName --show-managed-fields --output=json 2>&1) | ConvertFrom-Json -ErrorAction Stop).metadata.managedFields

                $dataKeys = $null
                if ($null -ne $secretGetResult.data) {
                    $dataKeys = $secretGetResult.data | Get-Member | Where-Object -Property MemberType -eq NoteProperty | Select-Object -ExpandProperty Name
                }

                $deserializedGetOutput = [PSCustomObject]@{
                    Name      = $secretGetResult.metadata.name
                    Namespace = $secretGetResult.metadata.namespace
                    Type      = $secretGetResult.type
                    DataCount = $dataKeys.Count
                    DataKeys  = $dataKeys
                    CreatedOn = $managedFieldValues | Where-Object -Property manager -eq "kubectl-create" | Select-Object -ExpandProperty time
                    UpdatedOn = $managedFieldValues | Where-Object -Property manager -eq "kubectl-patch" | Select-Object -ExpandProperty time
                }

                Write-Output -InputObject $deserializedGetOutput
            }
            catch {
                $argExceptionMessage = "The following secret was not found {0}:{1}" -f $targetNamespace, $SecretName
                $ArgumentException = [ArgumentException]::new($argExceptionMessage)
                Write-Error -Exception $ArgumentException -ErrorAction Stop
            }
        }
    }
}
