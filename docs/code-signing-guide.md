# Windows Maintenance Framework - Code Signing Guide

**Version:** 4.0.0
**Last Updated:** October 2025

---

## Table of Contents

- [Overview](#overview)
- [PowerShell Script Signing Basics](#powershell-script-signing-basics)
- [Certificate Management](#certificate-management)
- [Signing the Framework](#signing-the-framework)
- [Execution Policy Configuration](#execution-policy-configuration)
- [Deployment Scenarios](#deployment-scenarios)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)
- [Appendix](#appendix)

---

## Overview

### What is Code Signing?

Code signing is a security mechanism that uses digital signatures to verify the authenticity and integrity of PowerShell scripts. When you sign a script:

- **Authentication**: Confirms the script's author identity
- **Integrity**: Ensures the script hasn't been modified since signing
- **Trust**: Allows execution based on execution policy settings

### Why Sign PowerShell Scripts?

**Security Benefits:**
- Prevents execution of tampered or malicious scripts
- Establishes chain of trust in enterprise environments
- Meets compliance and security audit requirements
- Provides non-repudiation (proof of authorship)

**Operational Benefits:**
- Enables stricter execution policies (AllSigned, RemoteSigned)
- Supports enterprise Group Policy configurations
- Facilitates secure script distribution
- Professional appearance and credibility

### Do You Need to Sign This Framework?

**Personal Use - Generally NO**
- RemoteSigned policy allows local scripts
- No signing required for testing/development
- Can use Bypass or Unrestricted policies

**Enterprise/Production Use - YES**
- Required for AllSigned policy environments
- Best practice for security compliance
- Necessary for distribution to multiple users
- Required if scripts will be downloaded from internet

---

## PowerShell Script Signing Basics

### How PowerShell Signing Works

1. **Certificate Creation/Acquisition**
   - Obtain a code signing certificate from trusted CA
   - Or create self-signed certificate for testing

2. **Signing Process**
   - Use `Set-AuthenticodeSignature` cmdlet
   - Certificate embeds digital signature in script
   - Signature block appended to file

3. **Verification**
   - PowerShell verifies signature before execution
   - Checks certificate validity and trust chain
   - Enforces based on execution policy

### Signature Format

When signed, scripts contain a signature block:

```powershell
# SIG # Begin signature block
# MIIFfwYJKoZIhvcNAQcCoIIFcDCCBWwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUxYC9MdMZrF0+5D0JnJGzQqL5
# ...
# SIG # End signature block
```

**Important:** Any modification to the script (even a single space) invalidates the signature.

### Certificate Types

**Self-Signed Certificates**
- Free and easy to create
- Good for development/testing
- Not trusted by other computers (without manual trust)
- 1-5 year validity typical

**Trusted CA Certificates**
- Issued by Certificate Authorities (Sectigo, DigiCert, etc.)
- Trusted across organizations
- Required for public distribution
- Annual cost: $100-$500+
- 1-3 year validity typical

**Enterprise CA Certificates**
- Issued by internal Active Directory CA
- Free for domain members
- Automatically trusted within organization
- Validity configurable (1-5 years typical)

---

## Certificate Management

### Creating a Self-Signed Certificate (Development)

#### Method 1: Using New-SelfSignedCertificate (PowerShell 5.1+)

```powershell
# Run as Administrator
$certParams = @{
    Subject = "CN=Windows Maintenance Framework Code Signing"
    Type = "CodeSigning"
    CertStoreLocation = "Cert:\CurrentUser\My"
    KeyExportPolicy = "Exportable"
    KeySpec = "Signature"
    KeyLength = 2048
    KeyAlgorithm = "RSA"
    HashAlgorithm = "SHA256"
    NotAfter = (Get-Date).AddYears(5)
}

$cert = New-SelfSignedCertificate @certParams

# Display certificate details
$cert | Format-List Subject, Thumbprint, NotBefore, NotAfter

# Output:
# Subject    : CN=Windows Maintenance Framework Code Signing
# Thumbprint : 1234567890ABCDEF1234567890ABCDEF12345678
# NotBefore  : 10/26/2025 12:00:00 AM
# NotAfter   : 10/26/2030 12:00:00 AM
```

#### Method 2: Using makecert (Legacy, pre-PowerShell 5.1)

```cmd
REM Requires Windows SDK
makecert -n "CN=Windows Maintenance Framework Code Signing" ^
         -r -sv CodeSigningCert.pvk CodeSigningCert.cer ^
         -b 10/26/2025 -e 10/26/2030 ^
         -eku 1.3.6.1.5.5.7.3.3

pvk2pfx -pvk CodeSigningCert.pvk -spc CodeSigningCert.cer ^
        -pfx CodeSigningCert.pfx -po YourPassword
```

### Trusting Your Self-Signed Certificate

For the certificate to be trusted, it must be in the Trusted Root Certification Authorities store:

```powershell
# Run as Administrator

# Get your certificate
$cert = Get-ChildItem -Path Cert:\CurrentUser\My -CodeSigningCert |
    Where-Object { $_.Subject -like "*Windows Maintenance Framework*" }

# Export to Trusted Root
$rootStore = [System.Security.Cryptography.X509Certificates.X509Store]::new(
    "Root",
    "CurrentUser"
)
$rootStore.Open("ReadWrite")
$rootStore.Add($cert)
$rootStore.Close()

Write-Host "Certificate trusted successfully!" -ForegroundColor Green
```

**Important:** This only trusts the certificate on YOUR computer. Other computers will require the same process.

### Obtaining a Trusted CA Certificate

#### Option 1: Public Certificate Authorities

**Popular CAs for Code Signing:**
- **DigiCert** - $474/year (EV), $359/year (Standard)
- **Sectigo** - $215/year
- **GlobalSign** - $319/year
- **SSL.com** - $174/year

**Acquisition Process:**
1. Visit CA website
2. Request code signing certificate
3. Verify identity (email, phone, business documents)
4. Download certificate (.pfx file)
5. Install to Personal store (Cert:\CurrentUser\My)

#### Option 2: Enterprise Certificate Authority

If your organization has Active Directory Certificate Services:

```powershell
# Request certificate from enterprise CA
# Method 1: Certificate Manager (certmgr.msc)
# 1. Open certmgr.msc
# 2. Navigate to Personal → Certificates
# 3. Right-click → All Tasks → Request New Certificate
# 4. Select "Code Signing" template
# 5. Enroll

# Method 2: PowerShell (requires certificate request template)
$certRequest = Get-Certificate -Template "CodeSigning" `
    -CertStoreLocation Cert:\CurrentUser\My `
    -SubjectName "CN=$env:USERNAME Code Signing"

# Verify
$certRequest.Certificate | Format-List Subject, Issuer, NotAfter
```

### Certificate Storage Locations

**CurrentUser vs. LocalMachine:**

```powershell
# Personal certificates (recommended for development)
Cert:\CurrentUser\My

# Machine-level certificates (enterprise deployment)
Cert:\LocalMachine\My

# Trusted Root Certification Authorities
Cert:\CurrentUser\Root
Cert:\LocalMachine\Root
```

### Viewing Your Certificates

```powershell
# List all code signing certificates
Get-ChildItem -Path Cert:\CurrentUser\My -CodeSigningCert

# Detailed view
Get-ChildItem -Path Cert:\CurrentUser\My -CodeSigningCert |
    Format-List Subject, Thumbprint, NotBefore, NotAfter, Issuer

# Check certificate validity
$cert = Get-ChildItem -Path Cert:\CurrentUser\My -CodeSigningCert | Select-Object -First 1
if ($cert.NotAfter -lt (Get-Date)) {
    Write-Host "Certificate EXPIRED on $($cert.NotAfter)" -ForegroundColor Red
} else {
    Write-Host "Certificate valid until $($cert.NotAfter)" -ForegroundColor Green
}
```

### Backing Up Certificates

**Critical:** Always backup your code signing certificate!

```powershell
# Export certificate with private key (password protected)
$cert = Get-ChildItem -Path Cert:\CurrentUser\My -CodeSigningCert |
    Where-Object { $_.Subject -like "*Windows Maintenance Framework*" }

$password = Read-Host -AsSecureString -Prompt "Enter export password"
$backupPath = "C:\Backup\CodeSigningCert.pfx"

Export-PfxCertificate -Cert $cert -FilePath $backupPath -Password $password

Write-Host "Certificate backed up to: $backupPath" -ForegroundColor Green
```

**Security Best Practices:**
- Store backup .pfx file in secure location (encrypted drive, password manager)
- Use strong password (20+ characters recommended)
- Consider hardware security module (HSM) for production
- Never commit .pfx files to version control

### Importing Certificates

```powershell
# Import from backup
$password = Read-Host -AsSecureString -Prompt "Enter certificate password"
$pfxPath = "C:\Backup\CodeSigningCert.pfx"

Import-PfxCertificate -FilePath $pfxPath `
    -CertStoreLocation Cert:\CurrentUser\My `
    -Password $password

Write-Host "Certificate imported successfully!" -ForegroundColor Green
```

---

## Signing the Framework

### Prerequisites

Before signing:
1. Have a valid code signing certificate installed
2. Verify certificate is in `Cert:\CurrentUser\My` (or `LocalMachine\My`)
3. Certificate must have "Code Signing" purpose
4. Certificate must not be expired

### Signing Individual Scripts

```powershell
# Get your code signing certificate
$cert = Get-ChildItem -Path Cert:\CurrentUser\My -CodeSigningCert |
    Where-Object { $_.Subject -like "*Windows Maintenance Framework*" }

if (-not $cert) {
    Write-Host "ERROR: No code signing certificate found!" -ForegroundColor Red
    exit 1
}

# Sign a single script
$scriptPath = ".\Run-Maintenance.ps1"
$signature = Set-AuthenticodeSignature -FilePath $scriptPath -Certificate $cert

# Verify result
if ($signature.Status -eq "Valid") {
    Write-Host "✓ Successfully signed: $scriptPath" -ForegroundColor Green
} else {
    Write-Host "✗ Signing failed: $($signature.StatusMessage)" -ForegroundColor Red
}
```

### Batch Signing All Framework Scripts

Create a signing script to sign all PowerShell files in the framework:

**Scripts/Sign-AllScripts.ps1:**

```powershell
<#
.SYNOPSIS
    Signs all PowerShell scripts in the Windows Maintenance Framework.

.DESCRIPTION
    This script will locate and sign all .ps1 and .psm1 files in the framework
    using your code signing certificate.

.PARAMETER CertificateThumbprint
    Thumbprint of the certificate to use. If not specified, will prompt to select.

.PARAMETER WhatIf
    Shows what would be signed without actually signing.

.EXAMPLE
    .\Sign-AllScripts.ps1

.EXAMPLE
    .\Sign-AllScripts.ps1 -CertificateThumbprint "1234567890ABCDEF..."

.EXAMPLE
    .\Sign-AllScripts.ps1 -WhatIf
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$false)]
    [string]$CertificateThumbprint,

    [Parameter(Mandatory=$false)]
    [switch]$WhatIf
)

# Script root
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$FrameworkRoot = Split-Path -Parent $ScriptRoot

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Framework Script Signing Utility" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get certificate
if ($CertificateThumbprint) {
    $cert = Get-ChildItem -Path Cert:\CurrentUser\My |
        Where-Object { $_.Thumbprint -eq $CertificateThumbprint }

    if (-not $cert) {
        Write-Host "ERROR: Certificate with thumbprint '$CertificateThumbprint' not found!" -ForegroundColor Red
        exit 1
    }
} else {
    # List available code signing certificates
    $certs = Get-ChildItem -Path Cert:\CurrentUser\My -CodeSigningCert

    if ($certs.Count -eq 0) {
        Write-Host "ERROR: No code signing certificates found in Cert:\CurrentUser\My" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please create or import a code signing certificate first." -ForegroundColor Yellow
        Write-Host "See code-signing-guide.md for instructions." -ForegroundColor Yellow
        exit 1
    }

    Write-Host "Available code signing certificates:" -ForegroundColor Yellow
    Write-Host ""

    for ($i = 0; $i -lt $certs.Count; $i++) {
        $c = $certs[$i]
        Write-Host "[$i] $($c.Subject)" -ForegroundColor Cyan
        Write-Host "    Thumbprint: $($c.Thumbprint)" -ForegroundColor Gray
        Write-Host "    Issuer:     $($c.Issuer)" -ForegroundColor Gray
        Write-Host "    Valid:      $($c.NotBefore) to $($c.NotAfter)" -ForegroundColor Gray
        Write-Host ""
    }

    $selection = Read-Host "Select certificate [0-$($certs.Count-1)]"
    $cert = $certs[[int]$selection]
}

Write-Host "Using certificate:" -ForegroundColor Green
Write-Host "  Subject:    $($cert.Subject)" -ForegroundColor Gray
Write-Host "  Thumbprint: $($cert.Thumbprint)" -ForegroundColor Gray
Write-Host "  Valid until: $($cert.NotAfter)" -ForegroundColor Gray
Write-Host ""

# Find all PowerShell scripts
$filesToSign = @()
$filesToSign += Get-ChildItem -Path $FrameworkRoot -Filter "*.ps1" -File
$filesToSign += Get-ChildItem -Path $FrameworkRoot -Filter "*.psm1" -Recurse -File
$filesToSign += Get-ChildItem -Path $FrameworkRoot -Filter "*.psd1" -Recurse -File

Write-Host "Found $($filesToSign.Count) files to sign:" -ForegroundColor Yellow
Write-Host ""

# Sign each file
$successCount = 0
$failCount = 0
$skippedCount = 0

foreach ($file in $filesToSign) {
    $relativePath = $file.FullName.Replace($FrameworkRoot, ".")

    if ($WhatIf) {
        Write-Host "[WHATIF] Would sign: $relativePath" -ForegroundColor Cyan
        $skippedCount++
        continue
    }

    try {
        $signature = Set-AuthenticodeSignature -FilePath $file.FullName -Certificate $cert -ErrorAction Stop

        if ($signature.Status -eq "Valid") {
            Write-Host "✓ $relativePath" -ForegroundColor Green
            $successCount++
        } else {
            Write-Host "✗ $relativePath - $($signature.StatusMessage)" -ForegroundColor Red
            $failCount++
        }
    }
    catch {
        Write-Host "✗ $relativePath - $($_.Exception.Message)" -ForegroundColor Red
        $failCount++
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Signing Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($WhatIf) {
    Write-Host "WhatIf Mode: $skippedCount files would be signed" -ForegroundColor Yellow
} else {
    Write-Host "Successful: $successCount" -ForegroundColor Green
    Write-Host "Failed:     $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Gray" })
    Write-Host "Total:      $($filesToSign.Count)" -ForegroundColor Cyan
}

Write-Host ""

if ($failCount -gt 0) {
    exit 1
} else {
    exit 0
}
```

**Usage:**

```powershell
# Sign all scripts (interactive certificate selection)
.\Scripts\Sign-AllScripts.ps1

# Sign with specific certificate
.\Scripts\Sign-AllScripts.ps1 -CertificateThumbprint "1234567890ABCDEF..."

# Test without signing
.\Scripts\Sign-AllScripts.ps1 -WhatIf
```

### Verifying Signatures

```powershell
# Verify a single script
$signature = Get-AuthenticodeSignature -FilePath ".\Run-Maintenance.ps1"

Write-Host "Status:  $($signature.Status)" -ForegroundColor $(
    switch ($signature.Status) {
        "Valid" { "Green" }
        "NotSigned" { "Yellow" }
        default { "Red" }
    }
)
Write-Host "Signer:  $($signature.SignerCertificate.Subject)"
Write-Host "Issuer:  $($signature.SignerCertificate.Issuer)"
Write-Host "Valid:   $($signature.SignerCertificate.NotBefore) to $($signature.SignerCertificate.NotAfter)"

# Possible Status values:
# - Valid: Signature is valid and trusted
# - NotSigned: File is not signed
# - HashMismatch: File was modified after signing
# - NotTrusted: Certificate is not trusted
# - UnknownError: Other error occurred
```

**Batch Verification:**

```powershell
# Verify all scripts in framework
Get-ChildItem -Path . -Include *.ps1,*.psm1,*.psd1 -Recurse | ForEach-Object {
    $sig = Get-AuthenticodeSignature -FilePath $_.FullName
    $status = $sig.Status
    $color = switch ($status) {
        "Valid" { "Green" }
        "NotSigned" { "Yellow" }
        default { "Red" }
    }

    Write-Host "[$status] $($_.Name)" -ForegroundColor $color
}
```

### Maintaining Signatures

**When to Re-Sign:**
- After ANY modification to a signed script
- When certificate expires or is renewed
- When deploying to new environment with different trust requirements

**Automated Re-Signing:**
Consider integrating signing into your development workflow:

```powershell
# Git pre-commit hook example
# Place in .git/hooks/pre-commit

#!/bin/sh
# Sign all modified PowerShell scripts before commit

echo "Signing modified PowerShell scripts..."
powershell.exe -ExecutionPolicy Bypass -File Scripts/Sign-AllScripts.ps1

if [ $? -eq 0 ]; then
    echo "Signing successful!"
else
    echo "Signing failed! Aborting commit."
    exit 1
fi
```

---

## Execution Policy Configuration

### Understanding Execution Policies

PowerShell execution policies control which scripts can run:

| Policy | Description | Use Case |
|--------|-------------|----------|
| **Restricted** | No scripts allowed | Maximum security (default on Server 2012+) |
| **AllSigned** | Only signed scripts by trusted publisher | Enterprise environments |
| **RemoteSigned** | Signed if from internet, local scripts OK | Most common for development |
| **Unrestricted** | All scripts, warns for internet scripts | Testing (not recommended) |
| **Bypass** | No restrictions, no warnings | Automation scripts only |
| **Undefined** | No policy set (inherits from parent scope) | Default state |

### Checking Current Policy

```powershell
# Current user's effective policy
Get-ExecutionPolicy

# All scopes
Get-ExecutionPolicy -List

# Output example:
#         Scope ExecutionPolicy
#         ----- ---------------
# MachinePolicy       Undefined
#    UserPolicy       Undefined
#       Process       Undefined
#   CurrentUser    RemoteSigned
#  LocalMachine       Undefined
```

### Setting Execution Policy

**For Current User (Recommended):**

```powershell
# Does not require Administrator
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Confirmation
Get-ExecutionPolicy -Scope CurrentUser
```

**For Local Machine (Requires Administrator):**

```powershell
# Run PowerShell as Administrator
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine

# Affects all users on the computer
```

**Temporary for Current Session:**

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# Only lasts for current PowerShell session
# Useful for testing
```

### Recommended Policies by Scenario

#### Development Workstation

```powershell
# RemoteSigned allows local scripts without signing
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Why:** Balances security with convenience for development.

#### Enterprise with Signed Scripts

```powershell
# Requires all scripts to be signed
Set-ExecutionPolicy -ExecutionPolicy AllSigned -Scope LocalMachine
```

**Why:** Maximum security, ensures all code is from trusted sources.

#### Automated/Scheduled Tasks

```powershell
# In the scheduled task configuration
powershell.exe -ExecutionPolicy Bypass -File "C:\Path\To\Run-Maintenance.ps1"
```

**Why:** Bypass policy only for specific task, doesn't affect system-wide policy.

#### Testing Environment

```powershell
# Unrestricted for testing
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser
```

**Why:** Allows easy testing without signing concerns. **Don't use in production!**

### Group Policy Configuration (Enterprise)

For domain environments, use Group Policy to enforce execution policies:

1. **Open Group Policy Management Console (gpmc.msc)**

2. **Navigate to:**
   ```
   Computer Configuration
     → Policies
       → Administrative Templates
         → Windows Components
           → Windows PowerShell
   ```

3. **Configure "Turn on Script Execution":**
   - **Enabled**
   - **Execution Policy:** AllSigned or RemoteSigned
   - **Scope:** All scripts or Both

4. **Link GPO to appropriate OU**

**PowerShell to check GPO-enforced policy:**

```powershell
# Check if Group Policy is enforcing policy
Get-ExecutionPolicy -List

# If MachinePolicy or UserPolicy shows policy, it's enforced by GPO
# These CANNOT be overridden by local settings
```

### Bypassing Execution Policy (For Testing Only)

**Method 1: -ExecutionPolicy Parameter**
```powershell
powershell.exe -ExecutionPolicy Bypass -File ".\Run-Maintenance.ps1"
```

**Method 2: Read and Pipe**
```powershell
Get-Content .\Run-Maintenance.ps1 | PowerShell.exe -NoProfile -
```

**Method 3: Unblock Downloaded Files**
```powershell
# Remove "Zone.Identifier" alternate data stream
Unblock-File -Path ".\Run-Maintenance.ps1"

# Or batch unblock
Get-ChildItem -Path . -Recurse | Unblock-File
```

**⚠️ Security Warning:** These methods bypass security controls. Use only for testing!

---

## Deployment Scenarios

### Scenario 1: Personal Development Machine

**Setup:**
- Self-signed certificate
- RemoteSigned execution policy
- CurrentUser scope

**Steps:**

```powershell
# 1. Create self-signed certificate
$cert = New-SelfSignedCertificate -Subject "CN=My Code Signing Cert" `
    -Type CodeSigning -CertStoreLocation Cert:\CurrentUser\My `
    -NotAfter (Get-Date).AddYears(5)

# 2. Trust the certificate
$rootStore = [System.Security.Cryptography.X509Certificates.X509Store]::new("Root", "CurrentUser")
$rootStore.Open("ReadWrite")
$rootStore.Add($cert)
$rootStore.Close()

# 3. Set execution policy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# 4. Sign scripts (optional for local scripts with RemoteSigned)
# Only needed if scripts are downloaded or marked as from internet
.\Scripts\Sign-AllScripts.ps1
```

### Scenario 2: Enterprise with Internal CA

**Setup:**
- Certificate from Active Directory Certificate Services
- AllSigned execution policy via Group Policy
- LocalMachine scope

**Steps:**

```powershell
# 1. Request certificate from enterprise CA
# Use Certificate Manager (certmgr.msc) or:
$cert = Get-Certificate -Template "CodeSigning" `
    -CertStoreLocation Cert:\CurrentUser\My `
    -SubjectName "CN=$env:USERNAME Code Signing"

# 2. Group Policy sets execution policy (AllSigned)
# Verify:
Get-ExecutionPolicy -List

# 3. Sign all scripts (required with AllSigned)
.\Scripts\Sign-AllScripts.ps1 -CertificateThumbprint $cert.Certificate.Thumbprint

# 4. Distribute to users
# Scripts are trusted because certificate is from domain CA
```

### Scenario 3: Public Distribution

**Setup:**
- Certificate from public CA (DigiCert, Sectigo, etc.)
- Users have RemoteSigned or AllSigned policy
- Scripts distributed via download/GitHub

**Steps:**

```powershell
# 1. Purchase and install certificate from CA
# Download .pfx file and import:
$password = Read-Host -AsSecureString
Import-PfxCertificate -FilePath ".\CodeSignCert.pfx" `
    -CertStoreLocation Cert:\CurrentUser\My -Password $password

# 2. Sign all scripts
.\Scripts\Sign-AllScripts.ps1

# 3. Verify signatures
Get-ChildItem -Include *.ps1,*.psm1 -Recurse | ForEach-Object {
    $sig = Get-AuthenticodeSignature $_.FullName
    if ($sig.Status -ne "Valid") {
        Write-Warning "$($_.Name): $($sig.Status)"
    }
}

# 4. Distribute (GitHub release, download, etc.)
# Users with RemoteSigned/AllSigned will trust your scripts
```

### Scenario 4: Automated CI/CD Pipeline

**Azure DevOps Example:**

```yaml
# azure-pipelines.yml
steps:
- task: PowerShell@2
  displayName: 'Install Code Signing Certificate'
  inputs:
    targetType: 'inline'
    script: |
      $pfxPassword = ConvertTo-SecureString -String "$(CodeSigningPassword)" -AsPlainText -Force
      Import-PfxCertificate -FilePath "$(System.DefaultWorkingDirectory)\cert.pfx" `
        -CertStoreLocation Cert:\CurrentUser\My `
        -Password $pfxPassword

- task: PowerShell@2
  displayName: 'Sign PowerShell Scripts'
  inputs:
    targetType: 'filePath'
    filePath: 'Scripts/Sign-AllScripts.ps1'
    arguments: '-CertificateThumbprint $(CertThumbprint)'

- task: PowerShell@2
  displayName: 'Verify Signatures'
  inputs:
    targetType: 'inline'
    script: |
      $failed = 0
      Get-ChildItem -Include *.ps1,*.psm1 -Recurse | ForEach-Object {
        $sig = Get-AuthenticodeSignature $_.FullName
        if ($sig.Status -ne "Valid") {
          Write-Error "$($_.Name): $($sig.Status)"
          $failed++
        }
      }
      if ($failed -gt 0) { exit 1 }
```

**GitHub Actions Example:**

```yaml
# .github/workflows/sign-scripts.yml
name: Sign PowerShell Scripts

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  sign:
    runs-on: windows-latest
    steps:
    - uses: actions/checkout@v3

    - name: Import Code Signing Certificate
      shell: pwsh
      env:
        CERT_PASSWORD: ${{ secrets.CERT_PASSWORD }}
        CERT_BASE64: ${{ secrets.CERT_BASE64 }}
      run: |
        $certBytes = [Convert]::FromBase64String($env:CERT_BASE64)
        $certPath = "$env:TEMP\cert.pfx"
        [IO.File]::WriteAllBytes($certPath, $certBytes)

        $password = ConvertTo-SecureString $env:CERT_PASSWORD -AsPlainText -Force
        Import-PfxCertificate -FilePath $certPath -CertStoreLocation Cert:\CurrentUser\My -Password $password

    - name: Sign Scripts
      shell: pwsh
      run: |
        .\Scripts\Sign-AllScripts.ps1

    - name: Verify Signatures
      shell: pwsh
      run: |
        $errors = 0
        Get-ChildItem -Include *.ps1,*.psm1 -Recurse | ForEach-Object {
          $sig = Get-AuthenticodeSignature $_.FullName
          if ($sig.Status -ne "Valid") {
            Write-Error "$($_.Name): $($sig.Status)"
            $errors++
          }
        }
        if ($errors -gt 0) { exit 1 }
```

### Scenario 5: Scheduled Tasks

When creating scheduled tasks with signed scripts:

```powershell
# Option 1: System execution policy allows signed scripts
# Configure task normally:
.\Scripts\Install-MaintenanceTask.ps1

# Option 2: Bypass execution policy in task
$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -File `"C:\MaintenanceFramework\Run-Maintenance.ps1`""

$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 2am

Register-ScheduledTask -TaskName "WindowsMaintenance" `
    -Action $action -Trigger $trigger `
    -RunLevel Highest -Force
```

---

## Best Practices

### Certificate Management Best Practices

1. **Use Strong Passwords**
   ```powershell
   # Generate strong password for .pfx export
   Add-Type -AssemblyName System.Web
   $password = [System.Web.Security.Membership]::GeneratePassword(32, 8)
   $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
   ```

2. **Regular Certificate Backups**
   ```powershell
   # Automated monthly backup
   $date = Get-Date -Format "yyyy-MM"
   $backupPath = "C:\SecureBackup\CodeSignCert-$date.pfx"
   Export-PfxCertificate -Cert $cert -FilePath $backupPath -Password $securePassword
   ```

3. **Monitor Certificate Expiration**
   ```powershell
   # Check certificate expiration (add to monitoring)
   $cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert | Select-Object -First 1
   $daysUntilExpiry = ($cert.NotAfter - (Get-Date)).Days

   if ($daysUntilExpiry -lt 30) {
       Write-Warning "Certificate expires in $daysUntilExpiry days!"
       # Send email notification
   }
   ```

4. **Restrict Private Key Access**
   ```powershell
   # Export without private key for distribution
   Export-Certificate -Cert $cert -FilePath "PublicKey.cer"
   # Share PublicKey.cer, keep .pfx secure
   ```

5. **Use Hardware Security Modules (HSM) for Production**
   - YubiKey 5 Series (~$50)
   - Nitrokey HSM (~$50)
   - Enterprise HSM solutions (Thales, SafeNet)

### Signing Best Practices

1. **Sign During Development**
   - Integrate signing into build process
   - Sign before committing to version control (if using AllSigned)
   - Automated signing in CI/CD pipeline

2. **Verify Signatures Regularly**
   ```powershell
   # Add to test suite
   Describe "Script Signatures" {
       $scripts = Get-ChildItem -Include *.ps1,*.psm1 -Recurse
       foreach ($script in $scripts) {
           It "$($script.Name) should be signed" {
               $sig = Get-AuthenticodeSignature $script.FullName
               $sig.Status | Should -Be "Valid"
           }
       }
   }
   ```

3. **Document Signing Procedures**
   - Maintain this guide with your framework
   - Document certificate renewal process
   - Train team members on signing workflow

4. **Separate Development and Production Certificates**
   - Development: Self-signed for testing
   - Production: Trusted CA for distribution
   - Never use production certificates in version control

### Execution Policy Best Practices

1. **Use Least Restrictive Policy That Meets Security Requirements**
   - Development: RemoteSigned (CurrentUser)
   - Production: AllSigned (LocalMachine or GPO)
   - Automation: Bypass (only for specific scripts via parameter)

2. **Enforce via Group Policy in Enterprise**
   - Prevents users from changing policy
   - Centralized management
   - Audit compliance

3. **Document Policy Requirements**
   ```powershell
   # Add to README.md
   ## Execution Policy Requirements

   **Minimum:** RemoteSigned
   **Recommended:** AllSigned (with signed scripts)

   Set with:
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

4. **Never Permanently Disable Execution Policy**
   - Avoid: `Set-ExecutionPolicy Unrestricted`
   - Security risk
   - Use Bypass parameter for specific needs instead

---

## Troubleshooting

### "Cannot be loaded because running scripts is disabled"

**Error:**
```
.\Run-Maintenance.ps1 : File C:\...\Run-Maintenance.ps1 cannot be loaded because
running scripts is disabled on this system.
```

**Cause:** Execution policy is Restricted or AllSigned, and script is not signed.

**Solutions:**

```powershell
# Solution 1: Change execution policy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Solution 2: Sign the script
$cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert | Select-Object -First 1
Set-AuthenticodeSignature -FilePath ".\Run-Maintenance.ps1" -Certificate $cert

# Solution 3: Bypass for this execution only
powershell.exe -ExecutionPolicy Bypass -File ".\Run-Maintenance.ps1"
```

### "File is not digitally signed"

**Error:**
```
File .\Run-Maintenance.ps1 cannot be loaded. The file .\Run-Maintenance.ps1
is not digitally signed. You cannot run this script on the current system.
```

**Cause:** Execution policy is AllSigned, script is not signed.

**Solution:**

```powershell
# Sign the script
$cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert | Select-Object -First 1
Set-AuthenticodeSignature -FilePath ".\Run-Maintenance.ps1" -Certificate $cert

# If certificate not found
New-SelfSignedCertificate -Subject "CN=PowerShell Code Signing" `
    -Type CodeSigning -CertStoreLocation Cert:\CurrentUser\My
```

### "Cannot be loaded. The signature hash does not match"

**Error:**
```
The signature of the script is invalid. The script has been modified after it was signed.
```

**Cause:** Script was modified after signing, invalidating signature.

**Solution:**

```powershell
# Re-sign the script
$cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert | Select-Object -First 1
Set-AuthenticodeSignature -FilePath ".\Run-Maintenance.ps1" -Certificate $cert -Force
```

### "A certificate chain could not be built to a trusted root"

**Error:**
```
Set-AuthenticodeSignature : The specified signature certificate could not be used for signing.
A certificate chain could not be built to a trusted root authority.
```

**Cause:** Certificate or its issuer is not in Trusted Root store.

**Solution:**

```powershell
# For self-signed certificates, add to Trusted Root
$cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert | Select-Object -First 1

$rootStore = [System.Security.Cryptography.X509Certificates.X509Store]::new("Root", "CurrentUser")
$rootStore.Open("ReadWrite")
$rootStore.Add($cert)
$rootStore.Close()

Write-Host "Certificate added to Trusted Root" -ForegroundColor Green
```

### "The signer's certificate is not valid for signing"

**Error:**
```
Set-AuthenticodeSignature : The specified certificate is not suitable for code signing.
```

**Cause:** Certificate does not have "Code Signing" enhanced key usage.

**Solution:**

```powershell
# Create new certificate with Code Signing purpose
New-SelfSignedCertificate -Subject "CN=PowerShell Code Signing" `
    -Type CodeSigning `
    -CertStoreLocation Cert:\CurrentUser\My `
    -KeyExportPolicy Exportable `
    -HashAlgorithm SHA256 `
    -NotAfter (Get-Date).AddYears(5)
```

### "The signer's certificate has expired"

**Error:**
```
The signature of the script is invalid because the certificate has expired.
```

**Cause:** Code signing certificate has expired.

**Solution:**

```powershell
# Check certificate expiration
$cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert

foreach ($c in $cert) {
    Write-Host "$($c.Subject)" -ForegroundColor Cyan
    Write-Host "  Expires: $($c.NotAfter)" -ForegroundColor Gray

    if ($c.NotAfter -lt (Get-Date)) {
        Write-Host "  Status: EXPIRED" -ForegroundColor Red
    } else {
        Write-Host "  Status: Valid" -ForegroundColor Green
    }
}

# Create new certificate or renew from CA
# Then re-sign all scripts
.\Scripts\Sign-AllScripts.ps1
```

### Set-AuthenticodeSignature Fails Silently

**Problem:** `Set-AuthenticodeSignature` returns but Status is not "Valid".

**Diagnosis:**

```powershell
$signature = Set-AuthenticodeSignature -FilePath ".\test.ps1" -Certificate $cert

Write-Host "Status: $($signature.Status)"
Write-Host "Status Message: $($signature.StatusMessage)"

# Check for common issues:
# - Status: HashMismatch = File changed during signing
# - Status: NotSigned = Certificate issue
# - Status: UnknownError = Check $signature.StatusMessage
```

### Unable to Import Certificate

**Error:**
```
Import-PfxCertificate : Cannot find the path because it does not exist.
```

**Solution:**

```powershell
# Verify file exists
Test-Path "C:\Path\To\Certificate.pfx"

# Check file permissions
Get-Acl "C:\Path\To\Certificate.pfx" | Format-List

# Ensure correct password
$password = Read-Host -AsSecureString -Prompt "Certificate Password"
Import-PfxCertificate -FilePath "C:\Path\To\Certificate.pfx" `
    -CertStoreLocation Cert:\CurrentUser\My `
    -Password $password -Verbose
```

---

## Appendix

### A. PowerShell Cmdlets Quick Reference

```powershell
# Certificate Management
New-SelfSignedCertificate    # Create self-signed certificate
Import-PfxCertificate         # Import certificate from .pfx file
Export-PfxCertificate         # Export certificate to .pfx file
Export-Certificate            # Export public key only (.cer)
Get-ChildItem Cert:\          # List certificates
Remove-Item Cert:\...         # Delete certificate

# Signing
Set-AuthenticodeSignature     # Sign a script
Get-AuthenticodeSignature     # Verify signature

# Execution Policy
Get-ExecutionPolicy           # View current policy
Get-ExecutionPolicy -List     # View all scopes
Set-ExecutionPolicy           # Change policy

# File Operations
Unblock-File                  # Remove Zone.Identifier (internet mark)
```

### B. Certificate File Formats

| Format | Extension | Description | Contains Private Key? |
|--------|-----------|-------------|----------------------|
| **PFX/PKCS#12** | .pfx, .p12 | Personal Information Exchange | ✅ Yes (password protected) |
| **CER** | .cer, .crt | Certificate only (DER encoded) | ❌ No |
| **PEM** | .pem | Certificate only (Base64) | ❌ No |
| **PVK** | .pvk | Private Key (legacy) | ✅ Yes |

### C. Execution Policy Scope Precedence

Execution policy is determined by precedence (highest to lowest):

1. **MachinePolicy** - Set by Group Policy (Computer Configuration)
2. **UserPolicy** - Set by Group Policy (User Configuration)
3. **Process** - Set for current PowerShell session only
4. **CurrentUser** - Set for current user
5. **LocalMachine** - Set for all users on computer

**Example:**

```powershell
Get-ExecutionPolicy -List

#         Scope ExecutionPolicy
#         ----- ---------------
# MachinePolicy       AllSigned  ← ENFORCED (cannot override)
#    UserPolicy       Undefined
#       Process       Undefined
#   CurrentUser    RemoteSigned  ← Ignored (MachinePolicy wins)
#  LocalMachine       Undefined
```

### D. Certificate Validation Checklist

Before using a certificate for signing:

```powershell
$cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert | Select-Object -First 1

# 1. Certificate exists
if (-not $cert) { Write-Host "❌ Certificate not found" -ForegroundColor Red }

# 2. Has Code Signing EKU
$hasCodeSigning = $cert.EnhancedKeyUsageList | Where-Object { $_.ObjectId -eq "1.3.6.1.5.5.7.3.3" }
if (-not $hasCodeSigning) { Write-Host "❌ Certificate not valid for code signing" -ForegroundColor Red }

# 3. Not expired
if ($cert.NotAfter -lt (Get-Date)) { Write-Host "❌ Certificate expired" -ForegroundColor Red }

# 4. Not yet valid
if ($cert.NotBefore -gt (Get-Date)) { Write-Host "❌ Certificate not yet valid" -ForegroundColor Red }

# 5. Has private key
if (-not $cert.HasPrivateKey) { Write-Host "❌ Private key not available" -ForegroundColor Red }

# 6. Trusted root
# (Complex check - attempt to sign a test file and verify)
$testFile = "$env:TEMP\test.ps1"
"# Test" | Out-File $testFile
$sig = Set-AuthenticodeSignature -FilePath $testFile -Certificate $cert
if ($sig.Status -ne "Valid") { Write-Host "❌ Certificate not trusted: $($sig.StatusMessage)" -ForegroundColor Red }
Remove-Item $testFile

Write-Host "✅ Certificate is valid for code signing" -ForegroundColor Green
```

### E. Resources and Further Reading

**Official Microsoft Documentation:**
- [about_Execution_Policies](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies)
- [about_Signing](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_signing)
- [Set-AuthenticodeSignature](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.security/set-authenticodesignature)
- [New-SelfSignedCertificate](https://docs.microsoft.com/en-us/powershell/module/pki/new-selfsignedcertificate)

**Certificate Authorities:**
- [DigiCert Code Signing](https://www.digicert.com/signing/code-signing-certificates)
- [Sectigo Code Signing](https://sectigo.com/ssl-certificates-tls/code-signing)
- [GlobalSign Code Signing](https://www.globalsign.com/en/code-signing-certificate)
- [SSL.com Code Signing](https://www.ssl.com/certificates/code-signing/)

**Security Best Practices:**
- [NIST Special Publication 800-57 - Key Management](https://csrc.nist.gov/publications/detail/sp/800-57-part-1/rev-5/final)
- [CA/Browser Forum Code Signing Guidelines](https://cabforum.org/code-signing/)

**Community Resources:**
- [PowerShell.org](https://powershell.org/)
- [PowerShell Gallery](https://www.powershellgallery.com/)
- [GitHub - PowerShell](https://github.com/PowerShell/PowerShell)

---

**Document Version:** 1.0
**Last Updated:** October 2025
**Author:** Miguel Velasco
**Framework Version:** 4.0.0

For questions or issues with code signing, please refer to the [INSTALLATION-GUIDE.md](INSTALLATION-GUIDE.md) and [testing-plan.md](testing-plan.md).
