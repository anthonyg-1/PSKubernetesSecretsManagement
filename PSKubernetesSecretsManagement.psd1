#
# Module manifest for module 'PSKubernetesSecretsManagement'
#
# Generated by: Tony Guimelli
#
# Generated on: 8/08/2023
#

@{

    # Script module or binary module file associated with this manifest.
    RootModule           = '.\PSKubernetesSecretsManagement.psm1'

    # Version number of this module.
    ModuleVersion        = '0.5.0'

    # Compatibility
    CompatiblePSEditions = 'Desktop', 'Core'

    # ID used to uniquely identify this module
    GUID                 = '33f023aa-0bea-46e0-ad16-9f880fd7f701'

    # Author of this module
    Author               = 'Tony Guimelli'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion    = '7.1'

    # Description of the functionality provided by this module
    Description          = 'This PowerShell module contains functions that facilitate the creation, rotation, and viewing the metadata of Kubernetes secrets.'

    # Functions to export from this module
    FunctionsToExport    = 'Get-KubernetesSecretMetadata', 'New-KubernetesEphemeralSecret', 'Set-KubernetesSecretValue'

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport      = 'gksm', 'gksd', 'nkes', 'sksv'

    # List of all files packaged with this module
    FileList             = 'PSKubernetesSecretsManagement.psd1', 'PSKubernetesSecretsManagement.psm1'

    PrivateData          = @{
        PSData = @{
            Tags       = @('kubernetes', 'k8s', 'secrets')
            LicenseUri = 'https://github.com/anthonyg-1/PSKubernetesSecretsManagement/blob/main/LICENSE'
            ProjectUri = 'https://github.com/anthonyg-1/PSKubernetesSecretsManagement'
        }
    }
}