function Get-KubernetesSecretMetadata {
    <#
    .SYNOPSIS
        Gets a Kubernetes secret metadata.
    .DESCRIPTION
        Obtains a subset of Kubernetes secret metadata including annoations and create/update date times.
    .PARAMETER Namespace
        The Kubernetes namespace that the secret will be created in.
    .PARAMETER SecretName
        The name of the Kubernetes secret.
    .PARAMETER All
        Tells the function to obtain all secrets across all authorized namespaces.
    .PARAMETER AsJson
        Returns the results as a serialized JSON string as opposed to the default object type.
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
        Get-KubernetesSecretMetadata -All -AsJson

        Gets Kubernetes secret metadata all secrets across all authorized namespaces with the results returned as a JSON string.
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
    .EXAMPLE
        gksm -a -json

        Gets Kubernetes secret metadata all secrets across all authorized namespaces with the results returned as a JSON string.
    .INPUTS
        System.String

            A string value is received by the Namespace parameter
    .OUTPUTS
        System.Management.Automation.PSCustomObject or System.String
    #>
    [CmdletBinding(DefaultParameterSetName = "Default")]
    [Alias('gksm', 'gksd')]
    [OutputType([System.Management.Automation.PSCustomObject], [System.String])]
    Param
    (
        [Parameter(Mandatory = $true, ParameterSetName = "Default", ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)][ValidateLength(1, 63)][Alias('ns', 'n')][String]$Namespace,
        [Parameter(Mandatory = $false, ParameterSetName = "Default")][ValidateLength(1, 63)][Alias('s')][String]$SecretName,
        [Parameter(Mandatory = $true, ParameterSetName = "All")][Alias('a')][Switch]$All,
        [Parameter(Mandatory = $false)][Alias('json', 'j')][Switch]$AsJson
    )
    BEGIN {

        function _getK8sSecretMetadata([string]$targetNamespace, [string]$targetSecretName) {
            try {
                [PSCustomObject]$secretGetResult = $(kubectl get secrets --namespace=$targetNamespace $targetSecretName --output=json 2>&1) | ConvertFrom-Json -Depth 25 -ErrorAction Stop
                [PSCustomObject]$managedFieldValues = ($(kubectl get secrets --namespace=$targetNamespace $targetSecretName --show-managed-fields --output=json 2>&1) | ConvertFrom-Json -Depth 25 -ErrorAction Stop).metadata.managedFields

                $dataKeys = $null
                if ($null -ne $secretGetResult.data) {
                    $dataKeys = $secretGetResult.data | Get-Member | Where-Object -Property MemberType -eq NoteProperty | Select-Object -ExpandProperty Name
                }

                $deserializedGetOutput = [PSCustomObject]@{
                    Name        = $secretGetResult.metadata.name
                    Namespace   = $secretGetResult.metadata.namespace
                    Type        = $secretGetResult.type
                    DataCount   = $dataKeys.Count
                    DataKeys    = $dataKeys
                    CreatedOn   = $secretGetResult.metadata.creationTimestamp
                    UpdatedOn   = $managedFieldValues | Where-Object -Property Operation -eq Update | Sort-Object -Property time -Descending | Select-Object -ExpandProperty time -First 1
                    Annotations = $null -ne $secretGetResult.metadata.annotations ? $secretGetResult.metadata.annotations : ""
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

        if ($PSBoundParameters.ContainsKey("SecretName") -or $PSBoundParameters.ContainsKey("Namespace")) {
            if (-not(Test-KubernetesNamespaceAccess -Namespace $targetNamespace)) {
                $secretArgExceptionMessage = "The following secret was either not found or inaccessible. Check secret name, access rights for the specific secret and/or namespace, and try again: {0}:{1}" -f $targetNamespace, $SecretName
                $SecretArgumentException = [ArgumentException]::new($secretArgExceptionMessage)
                Write-Error -Exception $SecretArgumentException -ErrorAction Stop
            }
        }

        if ($PSBoundParameters.ContainsKey("SecretName")) {
            $targetSecretNames += $SecretName
        }
        elseIf ($PSBoundParameters.ContainsKey("Namespace")) {
            try {
                [PSCustomObject]$secretGetAllResults = $(kubectl get secrets --namespace=$targetNamespace --output=json 2>&1) | ConvertFrom-Json -Depth 25 -ErrorAction Stop
                $targetSecretNames += ($secretGetAllResults.items.metadata | Select-Object -ExpandProperty name)
            }
            catch {
                $ArgumentException = [ArgumentException]::new("Unable to get secrets in the $targetNamespace namespace.")
                Write-Error -Exception $ArgumentException -ErrorAction Stop
            }
        }

        if ($PSBoundParameters.ContainsKey("All")) {
            $allSecretObjects = @()

            # Determining if full enumeration of all secret in a namespace is allowed. If not, then enumeration without the -A switch is required:
            [bool]$allQueryFailed = $false
            try {
                $targetNamespace = ""
                $(kubectl get secrets -A --output=json 2>&1 | ConvertFrom-Json -Depth 25 -ErrorAction Stop).items.metadata | ForEach-Object {
                    $targetNamespace = $_.namespace
                    $k8sd = _getK8sSecretMetadata -targetNamespace $targetNamespace -targetSecretName $_.name
                    $allSecretObjects += $k8sd
                }
            }
            catch {
                $allQueryFailed = $true
            }

            try {
                $targetNamespace = ""
                if ($allQueryFailed) {
                    $(kubectl get secrets --output=json 2>&1 | ConvertFrom-Json).items.metadata | ForEach-Object {
                        $targetNamespace = $_.namespace
                        $k8sd = _getK8sSecretMetadata -targetNamespace $targetNamespace -targetSecretName $_.name
                        $allSecretObjects += $k8sd
                    }
                }

                if ($PSBoundParameters.ContainsKey("AsJson")) {
                    ($allSecretObjects | ConvertTo-Json -AsArray)
                }
                else {
                    ($allSecretObjects)
                }
            }
            catch {
                $ArgumentException = [ArgumentException]::new("Unable to get secrets in the $targetNamespace namespace.")
                Write-Error -Exception $ArgumentException -ErrorAction Stop
            }
        }
        else {
            foreach ($targetSecretName in $targetSecretNames) {
                try {
                    $k8sd = _getK8sSecretMetadata -targetNamespace $targetNamespace -targetSecretName $targetSecretName

                    if ($PSBoundParameters.ContainsKey("AsJson")) {
                        ($k8sd | ConvertTo-Json -AsArray)
                    }
                    else {
                        ($k8sd)
                    }
                }
                catch {
                    $argumentExceptionMessage = "Unable to find the following secret: {0}:{1}" -f $targetNamespace, $targetSecretName
                    $ArgumentException = [ArgumentException]::new($argumentExceptionMessage)
                    Write-Error -Exception $ArgumentException -ErrorAction Stop
                }
            }
        }
    }
}
