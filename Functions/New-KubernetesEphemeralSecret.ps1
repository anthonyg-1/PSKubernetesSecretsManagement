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
    .PARAMETER AsJson
        Returns the results as a serialized JSON string as opposed to the default object type.
    .EXAMPLE
        $secretDataName = "myapikey"
        $secretValue = '9eC29a57e584426E960dv3f84aa154c13fS$%m'
        $secretDataValue = $secretValue | ConvertTo-SecureString -AsPlainText -Force
        $secretDataCred = New-Object -TypeName PSCredential -ArgumentList $secretDataName, $secretDataValue
        New-KubernetesEphemeralSecret -SecretName "my-secret" -SecretData $secretDataCred

        Creates a Kubernetes secret in the default namespace with a name of 'my-secret' with a key of 'myapikey' and a value of '9eC29a57e584426E960dv3f84aa154c13fS$%m'.
    .EXAMPLE
        $secretDataName = "mypassword"
        $secretValue = 'A4458fcaT334f46c4bE4d46R564220b3bTb3'
        $secretDataValue = $secretValue | ConvertTo-SecureString -AsPlainText -Force
        $secretDataCred = New-Object -TypeName PSCredential -ArgumentList $secretDataName, $secretDataValue
        New-KubernetesEphemeralSecret -Namespace "apps" -SecretName "my-password" -SecretData $secretDataCred

        Creates a Kubernetes secret in the apps namespace with a name of 'my-password' with a key of 'mypassword' and a value of 'A4458fcaT334f46c4bE4d46R564220b3bTb3'.
    .EXAMPLE
        $secretDataName = "myapikey"
        $secretValue = '9eC29a57e584426E960dv3f84aa154c13fS$%m'
        $secretDataValue = $secretValue | ConvertTo-SecureString -AsPlainText -Force
        $secretDataCred = New-Object -TypeName PSCredential -ArgumentList $secretDataName, $secretDataValue
        nkes -s "my-secret" -d $secretDataCred

        Creates a Kubernetes secret in the default namespace with a name of 'my-secret' with a key of 'myapikey' and a value of '9eC29a57e584426E960dv3f84aa154c13fS$%m'.
    .EXAMPLE
        $secretDataName = "mypassword"
        $secretValue = 'A4458fcaT334f46c4bE4d46R564220b3bTb3'
        $secretDataValue = $secretValue | ConvertTo-SecureString -AsPlainText -Force
        $secretDataCred = New-Object -TypeName PSCredential -ArgumentList $secretDataName, $secretDataValue
        nkes -n apps -s "my-secret" -d $secretDataCred

        Creates a Kubernetes secret in the apps namespace with a name of 'my-password' with a key of 'mypassword' and a value of 'A4458fcaT334f46c4bE4d46R564220b3bTb3'.
    .EXAMPLE
        $secretDataName = "mypassword"
        $secretValue = 'A4458fcaT334f46c4bE4d46R564220b3bTb3'
        $secretDataValue = $secretValue | ConvertTo-SecureString -AsPlainText -Force
        $secretDataCred = New-Object -TypeName PSCredential -ArgumentList $secretDataName, $secretDataValue
        nkes -n apps -s "my-secret" -d $secretDataCred -json

        Creates a Kubernetes secret in the apps namespace with a name of 'my-password' with a key of 'mypassword' and a value of 'A4458fcaT334f46c4bE4d46R564220b3bTb3' with the output rendered as JSON.
#>
    [CmdletBinding()]
    [Alias('nkes')]
    [OutputType([System.Management.Automation.PSCustomObject], [System.String])]
    Param
    (
        [Parameter(Mandatory = $false)][Alias('ns', 'n')][String]$Namespace = 'default',

        [Parameter(Mandatory = $true)][Alias('s')][String]$SecretName,

        [Parameter(Mandatory = $true)][ValidateNotNull()][Alias('d')]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]$SecretData,

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
        if (Test-KubernetesSecretAccess -Namespace $Namespace -SecretName $SecretName) {
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