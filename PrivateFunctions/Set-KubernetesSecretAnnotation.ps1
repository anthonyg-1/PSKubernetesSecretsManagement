function Set-KubernetesSecretAnnotation {
    <##>
    [CmdletBinding()]
    [Alias('sksa')]
    [OutputType([void])]
    Param
    (
        [Parameter(Mandatory = $false)][Alias('ns', 'n')][String]$Namespace = 'default',

        [Parameter(Mandatory = $true)][Alias('s', 'sn')][String]$SecretName,

        [Parameter(Mandatory = $true)][ValidateNotNull()][Alias('an', 'Annotations')][System.Collections.Hashtable]$Annotation
    )
    BEGIN {
        if (-not(Test-KubernetesNamespaceAccess -Namespace $Namespace)) {
            $ArgumentException = [Security.SecurityException]::new("The following namespace was either not found or inaccessible: $Namespace")
            Write-Error -Exception $ArgumentException -ErrorAction Stop
        }

        if ($(kubectl auth can-i update secret -n $Namespace).ToLower() -ne "yes") {
            $SecurityException = [Security.SecurityException]::new("Current context cannot set secret annotations within the $Namespace namespace.")
            Write-Error -Exception $SecurityException -ErrorAction Stop
        }
    }
    PROCESS {
        if (-not(Test-KubernetesSecretExistence -Namespace $Namespace -SecretName $SecretName)) {
            $argExceptionMessage = "The following secret was not found {0}:{1}" -f $Namespace, $SecretName
            $ArgumentException = [ArgumentException]::new($argExceptionMessage)
            Write-Error -Exception $ArgumentException -ErrorAction Stop
        }

        $annotationResults = @()
        $Annotation.GetEnumerator() | ForEach-Object {
            $annotationKey = $_.Key
            $annotationValue = $_.Value
            $annotationResult = kubectl annotate secrets $SecretName -n $Namespace "$annotationKey=$annotationValue" --overwrite --output=json | ConvertFrom-Json -Depth 25 -ErrorAction Stop

            $annotationResults += $annotationResult.metadata.annotations
        }

        $resultingAnnotationHashtable = $annotationResults | Get-Unique | Convert-PSObjectToHashTable

        [bool]$resultingAnnotationsMatch = $false
        $Annotation.GetEnumerator() | ForEach-Object {
            if ($resultingAnnotationHashtable.ContainsKey($_.Key)) {
                if ($resultingAnnotationHashtable[$_.Key] -eq $Annotation[$_.Key]) {
                    $resultingAnnotationsMatch = $true
                }
                else {
                    $resultingAnnotationsMatch = $false
                    break
                }
            }
            else {
                $resultingAnnotationsMatch = $false
                break
            }
        }

        if ($resultingAnnotationsMatch) {
            $verboseMessage = "Annotations successfully set on the secret {0}:{1}" -f $Namespace, $SecretName
            Write-Verbose -Message $verboseMessage
        }
        else {
            $argExceptionMessage = "Unable to set annotations on the secret {0}:{1}" -f $Namespace, $SecretName
            $ArgumentException = [System.ArgumentException]::new($argExceptionMessage)
            Write-Error -Exception $ArgumentException -ErrorAction Stop
        }
    }
}