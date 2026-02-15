<#
.SYNOPSIS
    Secret Management wrapper for Windows Maintenance Framework.

.DESCRIPTION
    Abstracts the Microsoft.PowerShell.SecretManagement module to provide secure
    credential storage and retrieval for maintenance tasks (SMTP, Database, etc.).
    Falls back to secure string prompts if the SecretManagement module is missing.

.NOTES
    File Name      : SecretManager.psm1
    Author         : Miguel Velasco
    Prerequisite   : Microsoft.PowerShell.SecretManagement
#>

#Requires -Version 5.1

# Import dependencies
Import-Module "$PSScriptRoot\Logging.psm1" -Force

<#
.SYNOPSIS
    Retrieves a secret from the vault.
#>
function Get-MaintenanceSecret {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCredential])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$SecretName,

        [Parameter(Mandatory=$false)]
        [string]$VaultName = "WindowsMaintenanceVault"
    )

    try {
        # Check if SecretManagement is available
        if (Get-Module -ListAvailable "Microsoft.PowerShell.SecretManagement") {
            # Try to get secret
            $Secret = Get-Secret -Name $SecretName -Vault $VaultName -ErrorAction SilentlyContinue

            if ($Secret) {
                Write-MaintenanceLog -Message "Successfully retrieved secret '$SecretName' from vault '$VaultName'" -Level DEBUG
                return $Secret
            }
        }

        Write-MaintenanceLog -Message "Secret '$SecretName' not found in vault. Requesting manual input." -Level WARNING

        # Fallback to manual entry
        $Cred = Get-Credential -UserName $SecretName -Message "Enter credentials for $SecretName"
        return $Cred
    }
    catch {
        Write-MaintenanceLog -Message "Error retrieving secret: $($_.Exception.Message)" -Level ERROR
        return $null
    }
}

<#
.SYNOPSIS
    Saves a secret to the vault.
#>
function Set-MaintenanceSecret {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$SecretName,

        [Parameter(Mandatory=$true)]
        [securestring]$SecretValue,

        [Parameter(Mandatory=$false)]
        [string]$VaultName = "WindowsMaintenanceVault"
    )

    try {
        if (-not (Get-Module -ListAvailable "Microsoft.PowerShell.SecretManagement")) {
            Write-Error "Microsoft.PowerShell.SecretManagement module is required to save secrets."
            return
        }

        if ($PSCmdlet.ShouldProcess("Secret Vault: $VaultName", "Set secret: $SecretName")) {
            # Check if vault exists, create if not (using local SecretStore by default)
            if (-not (Get-SecretVault -Name $VaultName -ErrorAction SilentlyContinue)) {
                Write-MaintenanceLog -Message "Vault '$VaultName' admitting Creation local SecretStore vault..." -Level INFO
                Register-SecretVault -Name $VaultName -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault
            }

            Set-Secret -Name $SecretName -Vault $VaultName -Secret $SecretValue -ErrorAction Stop
            Write-MaintenanceLog -Message "Successfully saved secret '$SecretName'" -Level SUCCESS
        }
    }
    catch {
        Write-MaintenanceLog -Message "Failed to save secret: $($_.Exception.Message)" -Level ERROR
        throw
    }
}

Export-ModuleMember -Function Get-MaintenanceSecret, Set-MaintenanceSecret
