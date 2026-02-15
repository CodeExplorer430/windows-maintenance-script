<#
.SYNOPSIS
    Cloud reporting integration for Windows Maintenance Framework.

.DESCRIPTION
    Provides functionality to upload maintenance reports to cloud storage providers.
    Currently supports Azure Blob Storage.

.NOTES
    Requires: Azure.Storage.Blobs (or REST API fallback)
#>

#Requires -Version 5.1

Import-Module "$PSScriptRoot\Logging.psm1" -Force
Import-Module "$PSScriptRoot\SecretManager.psm1" -Force

<#
.SYNOPSIS
    Uploads a maintenance report to a cloud provider.
#>
function Export-MaintenanceReportToCloud {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ReportPath,

        [Parameter(Mandatory=$true)]
        [hashtable]$CloudConfig
    )

    if (-not $CloudConfig.Enabled) { return }

    try {
        Write-MaintenanceLog -Message "Initiating cloud report upload to $($CloudConfig.Provider)..." -Level PROGRESS

        if ($CloudConfig.Provider -eq "Azure") {
            # Retrieve connection string securely from vault
            $ConnStringSecret = Get-MaintenanceSecret -SecretName "AzureStorageConnectionString"
            $ConnString = $ConnStringSecret.GetNetworkCredential().Password

            if (-not $ConnString) {
                Write-MaintenanceLog -Message "Cloud upload failed: Azure connection string not found in vault." -Level ERROR
                return
            }

            # For portability, we use a REST API approach or Az module if available
            if (Get-Module -ListAvailable Az.Storage) {
                # Use Az module
                $Ctx = New-AzStorageContext -ConnectionString $ConnString
                $BlobName = Split-Path $ReportPath -Leaf
                $Container = if ($null -ne $CloudConfig.Container) { $CloudConfig.Container } else { "maintenance-reports" }

                Set-AzStorageBlobContent -File $ReportPath -Container $Container -Blob $BlobName -Context $Ctx -Force | Out-Null
                Write-MaintenanceLog -Message "Report successfully uploaded to Azure Blob: $Container/$BlobName" -Level SUCCESS
            } else {
                Write-MaintenanceLog -Message "Az.Storage module not found. Skipping cloud upload." -Level WARNING
            }
        }
    }
    catch {
        Write-MaintenanceLog -Message "Cloud upload failed: $($_.Exception.Message)" -Level ERROR
    }
}

Export-ModuleMember -Function Export-MaintenanceReportToCloud
