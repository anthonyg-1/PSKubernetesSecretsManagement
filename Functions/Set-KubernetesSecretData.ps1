function Set-KubernetesSecretData {
    <#
    .SYNOPSIS
        Sets Kubernetes secret data.
    .DESCRIPTION
        Sets/updates a Kubernetes secret data for a generic secret. The intent of this function is to update the value of an existing key in a secret. If the key does not exist, the function will throw an exception.
    .PARAMETER Namespace
        The Kubernetes namespace that secret resides in.
    .PARAMETER SecretName
        The name of the Kubernetes secret.
    .PARAMETER SecretData
        The data for the Kubernetes secret as a PSCredential where the UserName will be the key and the Password will be the secret value.
    .PARAMETER Add
        Tells the function to ignore the existence check for the key passed to the SecretData parameter and adds the new key/value pair data to the existing secret object.
    .PARAMETER AsJson
        Returns the results as a serialized JSON string as opposed to the default object type.
    .EXAMPLE
        $secretDataName = "myapikey"
        $secretValue = '2@GaImh59O3C8!TMwLSf$gVrjsuiDZAEveKxkd'
        $secretDataValue = $secretValue | ConvertTo-SecureString -AsPlainText -Force
        $secretDataCred = New-Object -TypeName PSCredential -ArgumentList $secretDataName, $secretDataValue
        Set-KubernetesSecretData  -SecretName "my-secret" -SecretData $secretDataCred

        Sets a Kubernetes secret in the default namespace with a name of 'my-secret' with a key of 'myapikey' and a value of '2@GaImh59O3C8!TMwLSf$gVrjsuiDZAEveKxkd'.
    .EXAMPLE
        $secretDataName = "mysecondapikey"
        $secretDataCred = New-KubernetesSecretData -SecretDataKey $secretDataName -SecretDataValue 'NRHnXj#DG&sJA*7IYgl$r!aO'
        Set-KubernetesSecretData  -SecretName "my-secret" -SecretData $secretDataCred -Add

        Adds a Kubernetes secret in the default namespace with a name of 'my-secret' with a key of 'myapikey' and a value of 'NRHnXj#DG&sJA*7IYgl$r!aO' via the PSCredential object generate from New-KubernetesSecretData.
    .EXAMPLE
        $secretDataName = "myapikey"
        $secretValue = '2@GaImh59O3C8!TMwLSf$gVrjsuiDZAEveKxkd'
        $secretDataValue = $secretValue | ConvertTo-SecureString -AsPlainText -Force
        $secretDataCred = New-Object -TypeName PSCredential -ArgumentList $secretDataName, $secretDataValue
        sksd -s "my-secret" -d $secretDataCred

        Sets a Kubernetes secret in the default namespace with a name of 'my-secret' with a key of 'myapikey' and a value of '2@GaImh59O3C8!TMwLSf$gVrjsuiDZAEveKxkd'.
    .EXAMPLE
        $secretDataName = "myapikey"
        $secretValue = '2@GaImh59O3C8!TMwLSf$gVrjsuiDZAEveKxkd'
        $secretDataValue = $secretValue | ConvertTo-SecureString -AsPlainText -Force
        $secretDataCred = New-Object -TypeName PSCredential -ArgumentList $secretDataName, $secretDataValue
        sksd -s "my-secret" -d $secretDataCred -json

        Sets a Kubernetes secret in the default namespace with a name of 'my-secret' with a key of 'myapikey' and a value of '2@GaImh59O3C8!TMwLSf$gVrjsuiDZAEveKxkd' with the output rendered as JSON.
    .EXAMPLE
        $secretDataName = "myapikey"
        sksd -s "my-secret" -d (nksd -k $secretDataName -v '2@GaImh59O3C8!TMwLSf$gVrjsuiDZAEveKxkd') -json

        Sets a Kubernetes secret in the default namespace with a name of 'my-secret' with a key of 'myapikey' and a value of '2@GaImh59O3C8!TMwLSf$gVrjsuiDZAEveKxkd' with the output rendered as JSON.
    .LINK
        New-KubernetesSecretData
        ConvertTo-SecureString
        https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.pscredential
        https://kubernetes.io/docs/concepts/configuration/secret/
#>
    [CmdletBinding()]
    [Alias('sksd')]
    [OutputType([System.Management.Automation.PSCustomObject], [System.String])]
    Param
    (
        [Parameter(Mandatory = $false)][Alias('ns', 'n')][String]$Namespace = 'default',

        [Parameter(Mandatory = $true)][Alias('s', 'sn')][String]$SecretName,

        [Parameter(Mandatory = $true)][ValidateNotNull()][Alias('d', 'sd')]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]$SecretData,

        [Parameter(Mandatory = $false)][Alias('a')][Switch]$Add,

        [Parameter(Mandatory = $false)][Alias('json', 'j')][Switch]$AsJson
    )
    BEGIN {
        if (-not(Test-KubernetesNamespaceAccess -Namespace $Namespace)) {
            $ArgumentException = [Security.SecurityException]::new("The following namespace was either not found or inaccessible: $Namespace")
            Write-Error -Exception $ArgumentException -ErrorAction Stop
        }

        if ($(kubectl auth can-i update secret -n $Namespace).ToLower() -ne "yes") {
            $SecurityException = [Security.SecurityException]::new("Current context cannot set secret values within the $Namespace namespace.")
            Write-Error -Exception $SecurityException -ErrorAction Stop
        }
    }
    PROCESS {
        if (-not(Test-KubernetesSecretExistence -Namespace $Namespace -SecretName $SecretName)) {
            $argExceptionMessage = "The following secret was not found {0}:{1}" -f $Namespace, $SecretName
            $ArgumentException = [ArgumentException]::new($argExceptionMessage)
            Write-Error -Exception $ArgumentException -ErrorAction Stop
        }

        $secretKeyName = $SecretData.UserName
        $secretDataValue = $SecretData.GetNetworkCredential().Password

        [string[]]$existingSecretDataKeys = ""
        try {
            $existingSecretDataKeys = (($(kubectl get secret -n $Namespace $SecretName --output=json 2>&1) |
                    ConvertFrom-Json -ErrorAction Stop).data | Get-Member |
                Where-Object -Property MemberType -eq "NoteProperty") |
            Select-Object -ExpandProperty Name
        }
        catch {
            $parseExceptionMessage = "Unable to parse kubectl output from the following secret: {1}:{2}" -f $Namespace, $SecretName
            $ParseException = [Management.Automation.ParseException]::new($parseExceptionMessage)
            Write-Error -Exception $ParseException -ErrorAction Stop
        }

        if (-not($PSBoundParameters.ContainsKey("Add"))) {
            if (-not($secretKeyName -in $existingSecretDataKeys)) {
                $argExceptionMessage = "The key '{0}' does not exist in the following secret: {1}:{2}. If you wish to add a new key/value pair to {1}:{2}, use the Add parameter." -f $secretKeyName, $Namespace, $SecretName
                $ArgumentException = [ArgumentException]::new($argExceptionMessage)
                Write-Error -Exception $ArgumentException -ErrorAction Stop
            }
        }

        # Base64 encode the retrieved/generated secret, serialize hashtable to JSON and patch:
        $encodedSecretValue = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($secretDataValue))

        # Construct key value pairs and serialize to compressed JSON array for patch operation:
        $patchData = @{op = "replace"
            path          = "/data/$secretKeyName"
            value         = $encodedSecretValue
        } | ConvertTo-Json -AsArray -Compress

        [PSCustomObject]$patchResult = $null
        try {
            $patchResult = $(kubectl patch secret -n $Namespace $SecretName --type='json' -p $patchData --output=json 2>&1) | ConvertFrom-Json -ErrorAction Stop

            if ($patchResult.metadata.name -eq $SecretName) {
                Write-Verbose -Message ("Updated the following generic secret: {0}:{1}" -f $Namespace, $SecretName)
            }

            if (-not($PSBoundParameters.ContainsKey("Add"))) {
                Write-Verbose -Message ("Added new data with a key of {0} to the following generic secret: {1}:{2}" -f $secretKeyName, $Namespace, $SecretName)
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
            $ArgumentException = [ArgumentException]::new("Unable to update the following secret in the $Namespace namespace: $SecretName")
            Write-Error -Exception $ArgumentException -ErrorAction Stop
        }
    }
}