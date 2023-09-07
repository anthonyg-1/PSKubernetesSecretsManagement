
function New-KubernetesSecretData {
    <#
    .SYNOPSIS
       Generates a PSCredential object that will be used to populate a Kubernetes opaque secret.
    .DESCRIPTION
       The New-KubernetesSecretData function creates a PSCredential object that will be used to populate a Kubernetes opaque secret. The function also clears the PowerShell history to minimize the chance of accidental secrets exposure, but standard secrets management best practices still apply.
    .PARAMETER SecretDataKey
       The key for the Kubernetes opaque secret data.
    .PARAMETER SecretDataValue
       The value corresponding to the key (passed to the SecretDataKey parameter) for a Kubernetes opaque secret data.
    .EXAMPLE
       New-KubernetesSecretData -SecretDataKey "DatabasePassword" -SecretDataValue "mySecret123!"

       This example demonstrates how to create a PSCredential object with a SecretDataKey of "DatabasePassword" and a SecretDataValue of "mySecret123!".
    .EXAMPLE
        $secretDataName = "myapikey"
        $secretDataCred = New-KubernetesSecretData -SecretDataKey $secretDataName -SecretDataValue '9eC29a57e584426E960dv3f84aa154c13fS$%m'
        New-KubernetesEphemeralSecret -SecretName "my-secret" -SecretData $secretDataCred

        Creates a Kubernetes secret via New-KubernetesEphemeralSecret in the default namespace with a name of 'my-secret' with a key of 'myapikey' and a value of '9eC29a57e584426E960dv3f84aa154c13fS$%m' via the PSCredential object generate from New-KubernetesSecretData.
    .EXAMPLE
        $secretDataName = "mysecondapikey"
        $secretDataCred = New-KubernetesSecretData -SecretDataKey $secretDataName -SecretDataValue 'NRHnXj#DG&sJA*7IYgl$r!aO'
        Set-KubernetesSecretData -SecretName "my-secret" -SecretData $secretDataCred -Add

        Adds a Kubernetes secret via Set-KubernetesSecretData in the default namespace with a name of 'my-secret' with a key of 'myapikey' and a value of 'NRHnXj#DG&sJA*7IYgl$r!aO' via the PSCredential object generate from New-KubernetesSecretData.
    .EXAMPLE
       nksd -k "DatabasePassword" -v "mySecret123!"

       This example demonstrates how to create a PSCredential object with a SecretDataKey of "DatabasePassword" and a SecretDataValue of "mySecret123!".
    .EXAMPLE
        $secretDataName = "myapikey"
        sksd -s "my-secret" -d (nksd -k $secretDataName -v '2@GaImh59O3C8!TMwLSf$gVrjsuiDZAEveKxkd') -json

        Sets a Kubernetes secret via Set-KubernetesSecretData  (aliased as 'sksd') in the default namespace with a name of 'my-secret' with a key of 'myapikey' and a value of '2@GaImh59O3C8!TMwLSf$gVrjsuiDZAEveKxkd' with the output rendered as JSON.
    .NOTES
       To maintain security, after running this function, any trace of its execution is removed from the PowerShell history.
    .LINK
        New-KubernetesEphemeralSecret
        Set-KubernetesSecretData
        https://kubernetes.io/docs/concepts/configuration/secret/
        https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.pscredential
    #>
    [CmdletBinding()]
    [Alias('nksd')]
    [OutputType([System.Management.Automation.PSCredential])]
    Param
    (
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $false,
            Position = 0)]
        [Alias('k', 'sk', 'skd', 'key', 'SecretKey')]
        [ValidateLength(1, 253)]
        [String]$SecretDataKey,

        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $false,
            Position = 1)]
        [Alias('v', 'sv', 'skv', 'value', 'SecretValue')]
        [ValidateLength(1, 1073741823)]
        [String]$SecretDataValue
    )
    BEGIN {
        function Clear-FunctionHistory {
            <#
                This function will contain functionality to remove this function's calls to as many of
                the PowerShell logs as possible in order to avoid secret discovery.
            #>
            $functionName = $PSCmdlet.MyInvocation.MyCommand
            $functionAliases = Get-Alias -Definition $functionName

            try {
                Get-History |
                    Where-Object { ($_.CommandLine -match $functionName) -or ($_.CommandLine -match $functionAliases) } |
                        ForEach-Object {
                            Clear-History -Id $_.Id
                        }

                $cmdNames = @($functionName, $functionAliases) -join ", "
                $verboseMessage = "Events cleared with calls to the following: $cmdNames"
                Write-Verbose -Message $verboseMessage
            }
            catch {
                $InvalidOperationException = [System.Exception.InvalidOperationException]::new("Unable to clear PowerShell history. Clear log manually to avoid unintentional secret exposure.")
                Write-Error -Exception $InvalidOperationException -Category InvalidOperation -ErrorAction Continue
            }
        }
    }
    PROCESS {
        $secretDataValueSecureString = $SecretDataValue | ConvertTo-SecureString -AsPlainText -Force
        $SecretDataKeyValuePair = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $SecretDataKey, $secretDataValueSecureString

        Write-Output -InputObject $SecretDataKeyValuePair
    }
    END {
        # Remove function execution calls from history to mitigate potential secret exposure:
        Clear-FunctionHistory
    }
}
