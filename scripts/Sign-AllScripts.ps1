<#
.SYNOPSIS
    Signs all PowerShell scripts in the Windows Maintenance Framework.

.DESCRIPTION
    This script will locate and sign all .ps1, .psm1, and .psd1 files in the framework
    using your code signing certificate. It provides interactive certificate selection
    and detailed progress reporting.

.PARAMETER CertificateThumbprint
    Thumbprint of the certificate to use for signing. If not specified, the script will
    prompt you to select from available code signing certificates.

.PARAMETER WhatIf
    Shows what files would be signed without actually performing the signing operation.
    Useful for testing and verification.

.PARAMETER Force
    Re-signs files even if they are already signed. By default, already-signed files
    are skipped unless this switch is provided.

.EXAMPLE
    .\Sign-AllScripts.ps1

    Interactive mode - prompts to select certificate and signs all unsigned scripts.

.EXAMPLE
    .\Sign-AllScripts.ps1 -CertificateThumbprint "1234567890ABCDEF1234567890ABCDEF12345678"

    Signs all unsigned scripts using the specified certificate.

.EXAMPLE
    .\Sign-AllScripts.ps1 -WhatIf

    Shows what files would be signed without actually signing them.

.EXAMPLE
    .\Sign-AllScripts.ps1 -Force

    Re-signs all scripts, including those already signed.

.NOTES
    File Name      : Sign-AllScripts.ps1
    Author         : Miguel Velasco
    Prerequisite   : Code signing certificate installed
    Version        : 1.0.0
    Last Updated   : October 2025

    Requirements:
    - Valid code signing certificate in Cert:\CurrentUser\My or Cert:\LocalMachine\My
    - Certificate must have Code Signing enhanced key usage
    - Certificate must not be expired
    - Certificate must be trusted (self-signed certs must be in Trusted Root)
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$false, HelpMessage="Thumbprint of certificate to use for signing")]
    [string]$CertificateThumbprint,

    [Parameter(Mandatory=$false, HelpMessage="Show what would be signed without signing")]
    [switch]$WhatIf,

    [Parameter(Mandatory=$false, HelpMessage="Re-sign files even if already signed")]
    [switch]$Force
)

# Script root
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$FrameworkRoot = Split-Path -Parent $ScriptRoot

# Display banner
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Framework Script Signing Utility" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Function to validate certificate
function Test-CodeSigningCertificate {
    param(
        [Parameter(Mandatory=$true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate
    )

    $issues = @()

    # Check if expired
    if ($Certificate.NotAfter -lt (Get-Date)) {
        $issues += "Certificate expired on $($Certificate.NotAfter)"
    }

    # Check if not yet valid
    if ($Certificate.NotBefore -gt (Get-Date)) {
        $issues += "Certificate not yet valid (valid from $($Certificate.NotBefore))"
    }

    # Check for Code Signing EKU
    $hasCodeSigning = $Certificate.EnhancedKeyUsageList |
        Where-Object { $_.ObjectId -eq "1.3.6.1.5.5.7.3.3" }

    if (-not $hasCodeSigning) {
        $issues += "Certificate does not have Code Signing enhanced key usage"
    }

    # Check for private key
    if (-not $Certificate.HasPrivateKey) {
        $issues += "Certificate does not have an associated private key"
    }

    return @{
        IsValid = ($issues.Count -eq 0)
        Issues = $issues
    }
}

# Get certificate
Write-Host "Locating code signing certificate..." -ForegroundColor Yellow
Write-Host ""

if ($CertificateThumbprint) {
    # Look for certificate by thumbprint in both stores
    $cert = Get-ChildItem -Path Cert:\CurrentUser\My -ErrorAction SilentlyContinue |
        Where-Object { $_.Thumbprint -eq $CertificateThumbprint }

    if (-not $cert) {
        $cert = Get-ChildItem -Path Cert:\LocalMachine\My -ErrorAction SilentlyContinue |
            Where-Object { $_.Thumbprint -eq $CertificateThumbprint }
    }

    if (-not $cert) {
        Write-Host "ERROR: Certificate with thumbprint '$CertificateThumbprint' not found!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Searched in:" -ForegroundColor Yellow
        Write-Host "  - Cert:\CurrentUser\My" -ForegroundColor Gray
        Write-Host "  - Cert:\LocalMachine\My" -ForegroundColor Gray
        Write-Host ""
        exit 1
    }
} else {
    # List available code signing certificates
    $certs = @()
    $certs += Get-ChildItem -Path Cert:\CurrentUser\My -CodeSigningCert -ErrorAction SilentlyContinue
    $certs += Get-ChildItem -Path Cert:\LocalMachine\My -CodeSigningCert -ErrorAction SilentlyContinue

    if ($certs.Count -eq 0) {
        Write-Host "ERROR: No code signing certificates found!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Searched in:" -ForegroundColor Yellow
        Write-Host "  - Cert:\CurrentUser\My" -ForegroundColor Gray
        Write-Host "  - Cert:\LocalMachine\My" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Please create or import a code signing certificate first." -ForegroundColor Yellow
        Write-Host "See CODE-SIGNING-GUIDE.md for detailed instructions." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Quick Start - Create Self-Signed Certificate:" -ForegroundColor Cyan
        Write-Host '  $cert = New-SelfSignedCertificate -Subject "CN=PowerShell Code Signing" `' -ForegroundColor Gray
        Write-Host '      -Type CodeSigning -CertStoreLocation Cert:\CurrentUser\My `' -ForegroundColor Gray
        Write-Host '      -NotAfter (Get-Date).AddYears(5)' -ForegroundColor Gray
        Write-Host ""
        exit 1
    }

    Write-Host "Available code signing certificates:" -ForegroundColor Yellow
    Write-Host ""

    for ($i = 0; $i -lt $certs.Count; $i++) {
        $c = $certs[$i]
        $validation = Test-CodeSigningCertificate -Certificate $c

        Write-Host "[$i] $($c.Subject)" -ForegroundColor Cyan
        Write-Host "    Thumbprint: $($c.Thumbprint)" -ForegroundColor Gray
        Write-Host "    Issuer:     $($c.Issuer)" -ForegroundColor Gray
        Write-Host "    Valid:      $($c.NotBefore.ToString('yyyy-MM-dd')) to $($c.NotAfter.ToString('yyyy-MM-dd'))" -ForegroundColor Gray
        Write-Host "    Store:      $(if ($c.PSPath -like '*CurrentUser*') { 'CurrentUser\My' } else { 'LocalMachine\My' })" -ForegroundColor Gray

        if (-not $validation.IsValid) {
            Write-Host "    Issues:     $($validation.Issues -join '; ')" -ForegroundColor Yellow
        } else {
            Write-Host "    Status:     Valid" -ForegroundColor Green
        }

        Write-Host ""
    }

    if ($certs.Count -eq 1) {
        $cert = $certs[0]
        Write-Host "Using the only available certificate." -ForegroundColor Green
    } else {
        $selection = Read-Host "Select certificate [0-$($certs.Count-1)]"

        if (-not ($selection -match '^\d+$') -or [int]$selection -lt 0 -or [int]$selection -ge $certs.Count) {
            Write-Host ""
            Write-Host "ERROR: Invalid selection '$selection'" -ForegroundColor Red
            Write-Host ""
            exit 1
        }

        $cert = $certs[[int]$selection]
    }
}

# Validate selected certificate
Write-Host ""
Write-Host "Validating certificate..." -ForegroundColor Yellow
$validation = Test-CodeSigningCertificate -Certificate $cert

if (-not $validation.IsValid) {
    Write-Host ""
    Write-Host "ERROR: Selected certificate is not valid for code signing!" -ForegroundColor Red
    Write-Host ""
    foreach ($issue in $validation.Issues) {
        Write-Host "  - $issue" -ForegroundColor Yellow
    }
    Write-Host ""
    exit 1
}

Write-Host "  Certificate is valid for code signing" -ForegroundColor Green
Write-Host ""

# Display certificate details
Write-Host "Using certificate:" -ForegroundColor Green
Write-Host "  Subject:    $($cert.Subject)" -ForegroundColor Gray
Write-Host "  Thumbprint: $($cert.Thumbprint)" -ForegroundColor Gray
Write-Host "  Issuer:     $($cert.Issuer)" -ForegroundColor Gray
Write-Host "  Valid until: $($cert.NotAfter.ToString('yyyy-MM-dd'))" -ForegroundColor Gray
Write-Host ""

# Find all PowerShell scripts
Write-Host "Scanning for PowerShell files..." -ForegroundColor Yellow

$filesToSign = @()
$filesToSign += Get-ChildItem -Path $FrameworkRoot -Filter "*.ps1" -File -ErrorAction SilentlyContinue
$filesToSign += Get-ChildItem -Path $FrameworkRoot -Filter "*.psm1" -Recurse -File -ErrorAction SilentlyContinue
$filesToSign += Get-ChildItem -Path $FrameworkRoot -Filter "*.psd1" -Recurse -File -ErrorAction SilentlyContinue

if ($filesToSign.Count -eq 0) {
    Write-Host ""
    Write-Host "No PowerShell files found to sign." -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

Write-Host "  Found $($filesToSign.Count) PowerShell files" -ForegroundColor Green
Write-Host ""

# Check current signature status
Write-Host "Checking current signature status..." -ForegroundColor Yellow

$unsigned = @()
$validSigned = @()
$invalidSigned = @()

foreach ($file in $filesToSign) {
    $sig = Get-AuthenticodeSignature -FilePath $file.FullName -ErrorAction SilentlyContinue

    switch ($sig.Status) {
        "Valid" { $validSigned += $file }
        "NotSigned" { $unsigned += $file }
        default { $invalidSigned += $file }
    }
}

Write-Host "  Not Signed:     $($unsigned.Count)" -ForegroundColor $(if ($unsigned.Count -gt 0) { "Yellow" } else { "Gray" })
Write-Host "  Valid Signed:   $($validSigned.Count)" -ForegroundColor $(if ($validSigned.Count -gt 0) { "Green" } else { "Gray" })
Write-Host "  Invalid Signed: $($invalidSigned.Count)" -ForegroundColor $(if ($invalidSigned.Count -gt 0) { "Red" } else { "Gray" })
Write-Host ""

# Determine what to sign
if ($Force) {
    $toSign = $filesToSign
    Write-Host "Force mode: Will re-sign all $($toSign.Count) files" -ForegroundColor Yellow
} else {
    $toSign = $unsigned + $invalidSigned
    if ($toSign.Count -eq 0) {
        Write-Host "All files are already validly signed!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Use -Force to re-sign all files." -ForegroundColor Gray
        Write-Host ""
        exit 0
    }
    Write-Host "Will sign $($toSign.Count) files (unsigned or invalid signatures)" -ForegroundColor Yellow
}

Write-Host ""

if ($WhatIf) {
    Write-Host "WhatIf Mode - Files that would be signed:" -ForegroundColor Cyan
    Write-Host ""

    foreach ($file in $toSign) {
        $relativePath = $file.FullName.Replace($FrameworkRoot, ".").TrimStart('\')
        Write-Host "  [WHATIF] $relativePath" -ForegroundColor Cyan
    }

    Write-Host ""
    Write-Host "Total files that would be signed: $($toSign.Count)" -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

# Confirm before signing (unless WhatIf)
Write-Host "Ready to sign $($toSign.Count) files." -ForegroundColor Yellow
$response = Read-Host "Continue? (Y/N)"

if ($response -ne 'Y' -and $response -ne 'y') {
    Write-Host ""
    Write-Host "Signing cancelled by user." -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

Write-Host ""
Write-Host "Signing files..." -ForegroundColor Yellow
Write-Host ""

# Sign each file
$successCount = 0
$failCount = 0
$failedFiles = @()

foreach ($file in $toSign) {
    $relativePath = $file.FullName.Replace($FrameworkRoot, ".").TrimStart('\')

    try {
        $signature = Set-AuthenticodeSignature -FilePath $file.FullName -Certificate $cert -ErrorAction Stop

        if ($signature.Status -eq "Valid") {
            Write-Host "  ✓ $relativePath" -ForegroundColor Green
            $successCount++
        } else {
            Write-Host "  ✗ $relativePath - $($signature.StatusMessage)" -ForegroundColor Red
            $failCount++
            $failedFiles += @{
                File = $relativePath
                Error = $signature.StatusMessage
            }
        }
    }
    catch {
        Write-Host "  ✗ $relativePath - $($_.Exception.Message)" -ForegroundColor Red
        $failCount++
        $failedFiles += @{
            File = $relativePath
            Error = $_.Exception.Message
        }
    }
}

# Display summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Signing Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Total Files:    $($toSign.Count)" -ForegroundColor Cyan
Write-Host "Successful:     $successCount" -ForegroundColor Green
Write-Host "Failed:         $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Gray" })
Write-Host ""

if ($failCount -gt 0) {
    Write-Host "Failed Files:" -ForegroundColor Red
    Write-Host ""

    foreach ($failed in $failedFiles) {
        Write-Host "  File:  $($failed.File)" -ForegroundColor Yellow
        Write-Host "  Error: $($failed.Error)" -ForegroundColor Gray
        Write-Host ""
    }
}

# Verification
Write-Host "Verifying signatures..." -ForegroundColor Yellow

$verifyFailed = 0
foreach ($file in $toSign) {
    $sig = Get-AuthenticodeSignature -FilePath $file.FullName -ErrorAction SilentlyContinue

    if ($sig.Status -ne "Valid") {
        $verifyFailed++
        $relativePath = $file.FullName.Replace($FrameworkRoot, ".").TrimStart('\')
        Write-Host "  ✗ Verification failed: $relativePath ($($sig.Status))" -ForegroundColor Red
    }
}

if ($verifyFailed -eq 0) {
    Write-Host "  All signed files verified successfully!" -ForegroundColor Green
} else {
    Write-Host "  $verifyFailed files failed verification!" -ForegroundColor Red
}

Write-Host ""

# Final status
if ($failCount -eq 0 -and $verifyFailed -eq 0) {
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Signing Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    exit 0
} else {
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "  Signing Completed with Errors" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please review the errors above and retry." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}
