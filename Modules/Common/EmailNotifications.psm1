<#
.SYNOPSIS
    Email notification module for maintenance reporting.

.DESCRIPTION
    Provides SMTP integration for sending maintenance summaries and
    critical alerts to administrators.

.NOTES
    File Name      : EmailNotifications.psm1
#>

#Requires -Version 5.1

Import-Module "$PSScriptRoot\Logging.psm1" -Force
Import-Module "$PSScriptRoot\SecretManager.psm1" -Force

<#
.SYNOPSIS
    Sends a maintenance report via email.
#>
function Send-MaintenanceEmail {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ReportPath,

        [Parameter(Mandatory=$true)]
        [hashtable]$SmtpConfig
    )

    if (!$SmtpConfig.Enabled) { return }

    try {
        Write-MaintenanceLog -Message "Preparing to send maintenance report email..." -Level PROGRESS

        $Body = "Windows Maintenance session completed on $env:COMPUTERNAME.`n"
        $Body += "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n`n"
        $Body += "Please find the detailed report attached."

        $MailParams = @{
            To = $SmtpConfig.Recipient
            From = $SmtpConfig.Sender
            Subject = "Maintenance Report: $env:COMPUTERNAME"
            Body = $Body
            SmtpServer = $SmtpConfig.Server
            Port = $SmtpConfig.Port
            Attachments = $ReportPath
            ErrorAction = "Stop"
        }

        if ($SmtpConfig.UseSSL) { $MailParams.Add("UseSsl", $true) }

        # Secure credential retrieval
        if ($SmtpConfig.AuthRequired) {
            $Cred = Get-MaintenanceSecret -SecretName $SmtpConfig.Sender
            if ($Cred) {
                $MailParams.Add("Credential", $Cred)
            } else {
                Write-MaintenanceLog -Message "Email skipped: Could not retrieve credentials for $($SmtpConfig.Sender)" -Level WARNING
                return
            }
        }

        Send-MailMessage @MailParams

        Write-MaintenanceLog -Message "Maintenance report email sent successfully to $($SmtpConfig.Recipient)" -Level SUCCESS
    }
    catch {
        Write-MaintenanceLog -Message "Failed to send email notification: $($_.Exception.Message)" -Level ERROR
    }
}

Export-ModuleMember -Function Send-MaintenanceEmail
