function New-KubernetesEphemeralSecret {
    <#
    .SYNOPSIS
        Generates a Kubernetes secret.
    .DESCRIPTION
        Generates a "ephemeral" Kubernetes secret in that if an existing secret with the same name exists, it will be deleted and recreated.
    .PARAMETER Namespace
        The Kubernetes namespace that the secret will be created in.
    .PARAMETER SecretName
        The name of the Kubernetes secret.
    .PARAMETER SecretData
        The data for the Kubernetes secret as a PSCredential where the UserName will be the key and the Password will be the secret value.
    .PARAMETER Annotation
        Annotations to be applied to the secret object.
    .PARAMETER AsJson
        Returns the results as a serialized JSON string as opposed to the default object type.
    .EXAMPLE
        $secretDataName = "myapikey"
        $secretDataCred = New-KubernetesSecretData -SecretDataKey $secretDataName -SecretDataValue '9eC29a57e584426E960dv3f84aa154c13fS$%m'
        New-KubernetesEphemeralSecret -SecretName "my-secret" -SecretData $secretDataCred

        Creates a Kubernetes secret in the default namespace with a name of 'my-secret' with a key of 'myapikey' and a value of '9eC29a57e584426E960dv3f84aa154c13fS$%m' via the PSCredential object generate from New-KubernetesSecretData.
    .EXAMPLE
        $secretDataName = "myapikey"
        $secretValue = '9eC29a57e584426E960dv3f84aa154c13fS$%m'
        $secretDataValue = $secretValue | ConvertTo-SecureString -AsPlainText -Force
        $secretDataCred = New-Object -TypeName PSCredential -ArgumentList $secretDataName, $secretDataValue
        New-KubernetesEphemeralSecret -SecretName "my-secret" -SecretData $secretDataCred

        Creates a Kubernetes secret in the default namespace with a name of 'my-secret' with a key of 'myapikey' and a value of '9eC29a57e584426E960dv3f84aa154c13fS$%m'.
    .EXAMPLE
        $secretDataName = "myapikey"
        $secretValue = '9eC29a57e584426E960dv3f84aa154c13fS$%m'
        $secretDataValue = $secretValue | ConvertTo-SecureString -AsPlainText -Force
        $secretDataCred = New-Object -TypeName PSCredential -ArgumentList $secretDataName, $secretDataValue
        nkes -s "my-secret" -d $secretDataCred

        Creates a Kubernetes secret in the default namespace with a name of 'my-secret' with a key of 'myapikey' and a value of '9eC29a57e584426E960dv3f84aa154c13fS$%m'.
    .EXAMPLE
        $secret = "my-secret"
        $annotations = @{"config-management.tool/version" = "1.2.3"; "config-management.tool/managed" = $true }
        $sd = New-KubernetesSecretData -SecretDataKey "myapikey" -SecretDataValue '$U#C9nGDiXJ6To3SY78NZjlr'
        New-KubernetesEphemeralSecret -SecretName $secret -SecretData $sd -Annotation $annotations

        Creates a Kubernetes secret in the default namespace with a name of 'my-secret' with a key of 'myapikey' and a value of '$U#C9nGDiXJ6To3SY78NZjlr' with the following annotations:
            config-management.tool/version: 1.2.3
            config-management.tool/managed: true
    .EXAMPLE
        nkes -s "my-secret" -d (nksd -k "myapikey" -v '9eC29a57e584426E960dv3f84aa154c13fS$%m')

        Creates a Kubernetes secret in the default namespace with a name of 'my-secret' with a key of 'myapikey' and a value of '9eC29a57e584426E960dv3f84aa154c13fS$%m' via the PSCredential object generate from New-KubernetesSecretData.
    .LINK
        New-KubernetesSecretData
        ConvertTo-SecureString
        https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.pscredential
        https://kubernetes.io/docs/concepts/configuration/secret/
#>
    [CmdletBinding()]
    [Alias('nkes')]
    [OutputType([System.Management.Automation.PSCustomObject], [System.String])]
    Param
    (
        [Parameter(Mandatory = $false)][Alias('ns', 'n')][String]$Namespace = 'default',

        [Parameter(Mandatory = $true)][Alias('s', 'sn', 'Name')][String]$SecretName,

        [Parameter(Mandatory = $true)][ValidateNotNull()][Alias('d', 'sd')]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]$SecretData,

        [Parameter(Mandatory = $false)][ValidateNotNull()][Alias('an', 'Annotations')][System.Collections.Hashtable]$Annotation,

        [Parameter(Mandatory = $false)][Alias('json', 'j')][Switch]$AsJson
    )
    BEGIN {
        if (-not(Test-KubernetesNamespaceAccess -Namespace $Namespace)) {
            $ArgumentException = [Security.SecurityException]::new("The following namespace was either not found or inaccessible: $Namespace")
            Write-Error -Exception $ArgumentException -ErrorAction Stop
        }

        if ($(kubectl auth can-i create secret -n $Namespace).ToLower() -ne "yes") {
            $SecurityException = [Security.SecurityException]::new("Current context cannot create secrets within the $Namespace namespace.")
            Write-Error -Exception $SecurityException -ErrorAction Stop
        }

        if ($(kubectl auth can-i delete secret -n $Namespace).ToLower() -ne "yes") {
            $SecurityException = [Security.SecurityException]::new("Current context cannot delete secrets within the $Namespace namespace.")
            Write-Error -Exception $SecurityException -ErrorAction Stop
        }
    }
    PROCESS {
        if (Test-KubernetesSecretExistence -Namespace $Namespace -SecretName $SecretName) {
            $(kubectl delete secret --namespace=$Namespace $SecretName 2>&1) | Out-Null
        }

        $secretKeyName = $SecretData.UserName
        $secretDataValue = $SecretData.GetNetworkCredential().Password

        [PSCustomObject]$creationResult = $null
        try {
            $creationResult = $(kubectl create secret generic --namespace=$Namespace $SecretName --from-literal=$secretKeyName=$secretDataValue --output=json 2>&1) | ConvertFrom-Json -ErrorAction Stop

            if ($creationResult.metadata.name -eq $SecretName) {
                Write-Verbose -Message ("Created the following generic secret: {0}:{1}" -f $Namespace, $SecretName)
            }

            $secretObjectMetadata = $null

            if ($PSBoundParameters.ContainsKey("Annotation")) {
                Start-Sleep -Seconds 2
                try {
                    Set-KubernetesSecretAnnotation -Namespace $Namespace -SecretName $SecretName -Annotation $Annotation -ErrorAction Stop | Out-Null
                }
                catch {
                    Write-Error -Exception $_.Exception -ErrorAction Stop
                }
            }

            if ($PSBoundParameters.ContainsKey("AsJson")) {
                $secretObjectMetadata = Get-KubernetesSecretMetadata -Namespace $Namespace -SecretName $SecretName -AsJson
            }
            else {
                $secretObjectMetadata = Get-KubernetesSecretMetadata -Namespace $Namespace -SecretName $SecretName
            }

            Write-Output -InputObject $secretObjectMetadata
        }
        catch {
            $ArgumentException = [ArgumentException]::new("Unable to create secret in the $Namespace namespace.")
            Write-Error -Exception $ArgumentException -ErrorAction Stop
        }
    }
}