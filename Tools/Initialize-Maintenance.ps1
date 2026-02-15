<#
.SYNOPSIS
    Interactive setup wizard for the Windows Maintenance Framework.
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$InformationPreference = 'Continue'
$ModuleRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $ModuleRoot "WindowsMaintenance.psd1") -Force

Write-Information -MessageData "========================================" -Tags "Color:Cyan"
Write-Information -MessageData "  Framework Initialization Wizard" -Tags "Color:Cyan"
Write-Information -MessageData "========================================`n" -Tags "Color:Cyan"

# 1. Secret Management Setup
if (-not (Get-Module -ListAvailable "Microsoft.PowerShell.SecretManagement")) {
    Write-Information -MessageData "Installing SecretManagement modules..." -Tags "Color:Yellow"
    Install-Module Microsoft.PowerShell.SecretManagement, Microsoft.PowerShell.SecretStore -Force -Scope CurrentUser -AllowClobber
}

# 2. Vault Initialization
$VaultName = "WindowsMaintenanceVault"
if (-not (Get-SecretVault -Name $VaultName -ErrorAction SilentlyContinue)) {
    Write-Information -MessageData "Registering new local vault: $VaultName" -Tags "Color:Green"
    Register-SecretVault -Name $VaultName -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault
}

# 3. Interactive Configuration
$EnabledModules = @("SystemUpdates", "DiskMaintenance", "SystemHealthRepair", "SecurityScans", "SystemReporting")

if ((Read-Host "Enable Developer Tools maintenance? (y/n)") -eq 'y') { $EnabledModules += "DeveloperMaintenance" }
if ((Read-Host "Enable GPU Cache cleanup? (y/n)") -eq 'y') { $EnabledModules += "GPUMaintenance" }
if ((Read-Host "Enable Network diagnostics? (y/n)") -eq 'y') { $EnabledModules += "NetworkMaintenance" }

# 4. Path Configuration
$BaseDir = Join-Path $env:USERPROFILE "Documents\Maintenance"
$LogsPath = Join-Path $BaseDir "Logs"
$ReportsPath = Join-Path $BaseDir "Reports"

# 5. Generate Config Object
$Config = @{
    EnabledModules = $EnabledModules
    LogsPath = $LogsPath
    ReportsPath = $ReportsPath
    MaxEventLogSizeMB = 100
    ParallelProcessing = $true
}

# 6. Save Config
$ConfigPath = Join-Path $ModuleRoot "Config\maintenance-config.json"
$Config | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath -Force

Write-Information -MessageData "`nConfiguration saved to: $ConfigPath" -Tags "Color:Green"

# 7. Credential Setup (Optional)
if ((Read-Host "Configure SMTP credentials now? (y/n)") -eq 'y') {
    $SenderEmail = Read-Host "Enter Sender Email Address"
    $Pass = Read-Host "Enter Password/App Password" -AsSecureString
    Set-MaintenanceSecret -SecretName $SenderEmail -SecretValue $Pass
}

Write-Information -MessageData "`nSetup Complete! Run 'Invoke-WindowsMaintenance' to begin." -Tags "Color:Cyan"
