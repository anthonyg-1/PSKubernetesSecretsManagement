function Get-KubernetesSecretMetadata {
    <#
    .SYNOPSIS
        Gets a Kubernetes secret metadata.
    .DESCRIPTION
        Obtains a subset of Kubernetes secret metadata including creation and update date/times.
    .PARAMETER Namespace
        The Kubernetes namespace that the secret will be created in.
    .PARAMETER SecretName
        The name of the Kubernetes secret.
    .PARAMETER All
        Tells the function to obtain all secrets across all authorized namespaces.
    .EXAMPLE
        Get-KubernetesSecretMetadata -Namespace "apps"

        Gets Kubernetes secret metadata for all secrets in the 'apps' namespace.
    .EXAMPLE
        Get-KubernetesSecretMetadata -SecretName "my-secret"

        Gets Kubernetes secret metadata for the secret 'my-secret' in the default namespace.
    .EXAMPLE
        Get-KubernetesSecretMetadata -Namespace "apps" -SecretName "my-secret"

        Gets Kubernetes secret metadata for the secret 'my-secret' in the 'apps' namespace.
    .EXAMPLE
       Get-KubernetesSecretMetadata -All

        Gets Kubernetes secret metadata all secrets across all authorized namespaces.
    .EXAMPLE
        gksm -n "apps"

        Gets Kubernetes secret metadata for all secrets in the 'apps' namespace.
    .EXAMPLE
        gksm -s "my-secret"

        Gets Kubernetes secret metadata for the secret 'my-secret' in the default namespace.
    .EXAMPLE
        gksm -n "apps" -s "my-secret"

        Gets Kubernetes secret metadata for the secret 'my-secret' in the 'apps' namespace.
    .EXAMPLE
        gksm -a

        Gets Kubernetes secret metadata all secrets across all authorized namespaces.
    .LINK
        Get-KubernetesNamespaceMetadata
    #>
    [CmdletBinding()]
    [Alias('gksm', 'gksd')]
    [OutputType([PSCustomObject])]
    Param
    (
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)][Alias('ns', 'n')][String]$Namespace = 'default',
        [Parameter(Mandatory = $false)][Alias('s')][String]$SecretName,
        [Parameter(Mandatory = $false, ParameterSetName = "All")][Alias('a')][Switch]$All
    )
    BEGIN {
        if (-not(Test-KubernetesNamespaceAccess -Namespace $Namespace)) {
            $ArgumentException = [Security.SecurityException]::new("The following namespace was either not found or inaccessible: $Namespace")
            Write-Error -Exception $ArgumentException -ErrorAction Stop
        }

        function _getK8sSecretMetadata([string]$targetNamespace, [string]$targetSecretName) {
            try {
                [PSCustomObject]$secretGetResult = $(kubectl get secrets --namespace=$targetNamespace $targetSecretName --output=json 2>&1) | ConvertFrom-Json -ErrorAction Stop
                [PSCustomObject]$managedFieldValues = ($(kubectl get secrets --namespace=$targetNamespace $targetSecretName --show-managed-fields --output=json 2>&1) | ConvertFrom-Json -ErrorAction Stop).metadata.managedFields

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

                return $deserializedGetOutput
            }
            catch {
                $argExceptionMessage = "The following secret was not found {0}:{1}" -f $targetNamespace, $targetSecretName
                $ArgumentException = [ArgumentException]::new($argExceptionMessage)
                Write-Error -Exception $ArgumentException -ErrorAction Stop
            }
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

        if ($PSBoundParameters.ContainsKey("All")) {
            try {
                $(kubectl get secrets -A --output=json 2>&1 | ConvertFrom-Json -ErrorAction Stop).items.metadata | ForEach-Object {
                    _getK8sSecretMetadata -targetNamespace $_.namespace -targetSecretName $_.name
                }
            }
            catch {
                Write-Error -Exception $_-ErrorAction Stop
            }
        }
        else {
            foreach ($targetSecretName in $targetSecretNames) {
                try {
                    _getK8sSecretMetadata -targetNamespace $targetNamespace -targetSecretName $targetSecretName
                }
                catch {
                    Write-Error -Exception $_-ErrorAction Stop
                }
            }
        }
    }
}