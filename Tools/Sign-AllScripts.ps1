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

# Set information preference for UI output
$InformationPreference = 'Continue'

# Script root
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$FrameworkRoot = Split-Path -Parent $ScriptRoot

# Display banner
Write-Information -MessageData "" -Tags "Color:White"
Write-Information -MessageData "========================================" -Tags "Color:Cyan"
Write-Information -MessageData "  Framework Script Signing Utility" -Tags "Color:Cyan"
Write-Information -MessageData "========================================" -Tags "Color:Cyan"
Write-Information -MessageData "" -Tags "Color:White"

# Function to validate certificate
function Test-CodeSigningCertificate {
    [OutputType([hashtable])]
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
Write-Information -MessageData "Locating code signing certificate..." -Tags "Color:Yellow"
Write-Information -MessageData "" -Tags "Color:White"

if ($CertificateThumbprint) {
    # Look for certificate by thumbprint in both stores
    $cert = Get-ChildItem -Path Cert:\CurrentUser\My -ErrorAction SilentlyContinue |
        Where-Object { $_.Thumbprint -eq $CertificateThumbprint }

    if (-not $cert) {
        $cert = Get-ChildItem -Path Cert:\LocalMachine\My -ErrorAction SilentlyContinue |
            Where-Object { $_.Thumbprint -eq $CertificateThumbprint }
    }

    if (-not $cert) {
        Write-Error "Certificate with thumbprint '$CertificateThumbprint' not found!"
        exit 1
    }
} else {
    # List available code signing certificates
    $certs = @()
    $certs += Get-ChildItem -Path Cert:\CurrentUser\My -CodeSigningCert -ErrorAction SilentlyContinue
    $certs += Get-ChildItem -Path Cert:\LocalMachine\My -CodeSigningCert -ErrorAction SilentlyContinue

    if ($certs.Count -eq 0) {
        Write-Error "No code signing certificates found!"
        Write-Information -MessageData "Please create or import a code signing certificate first." -Tags "Color:Yellow"
        Write-Information -MessageData "See CODE-SIGNING-GUIDE.md for detailed instructions." -Tags "Color:Yellow"
        exit 1
    }

    Write-Information -MessageData "Available code signing certificates:" -Tags "Color:Yellow"
    Write-Information -MessageData "" -Tags "Color:White"

    for ($i = 0; $i -lt $certs.Count; $i++) {
        $c = $certs[$i]
        $validation = Test-CodeSigningCertificate -Certificate $c

        Write-Information -MessageData "[$i] $($c.Subject)" -Tags "Color:Cyan"
        Write-Information -MessageData "    Thumbprint: $($c.Thumbprint)" -Tags "Color:Gray"
        Write-Information -MessageData "    Issuer:     $($c.Issuer)" -Tags "Color:Gray"
        Write-Information -MessageData "    Valid:      $($c.NotBefore.ToString('yyyy-MM-dd')) to $($c.NotAfter.ToString('yyyy-MM-dd'))" -Tags "Color:Gray"
        Write-Information -MessageData "    Store:      $(if ($c.PSPath -like '*CurrentUser*') { 'CurrentUser\My' } else { 'LocalMachine\My' })" -Tags "Color:Gray"

        if (-not $validation.IsValid) {
            Write-Information -MessageData "    Issues:     $($validation.Issues -join '; ')" -Tags "Color:Yellow"
        } else {
            Write-Information -MessageData "    Status:     Valid" -Tags "Color:Green"
        }

        Write-Information -MessageData "" -Tags "Color:White"
    }

    if ($certs.Count -eq 1) {
        $cert = $certs[0]
        Write-Information -MessageData "Using the only available certificate." -Tags "Color:Green"
    } else {
        $selection = Read-Host "Select certificate [0-$($certs.Count-1)]"

        if (-not ($selection -match '^\d+$') -or [int]$selection -lt 0 -or [int]$selection -ge $certs.Count) {
            Write-Error "Invalid selection '$selection'"
            exit 1
        }

        $cert = $certs[[int]$selection]
    }
}

# Validate selected certificate
Write-Information -MessageData "" -Tags "Color:White"
Write-Information -MessageData "Validating certificate..." -Tags "Color:Yellow"
$validation = Test-CodeSigningCertificate -Certificate $cert

if (-not $validation.IsValid) {
    Write-Error "Selected certificate is not valid for code signing!"
    foreach ($issue in $validation.Issues) {
        Write-Information -MessageData "  - $issue" -Tags "Color:Yellow"
    }
    exit 1
}

Write-Information -MessageData "  Certificate is valid for code signing" -Tags "Color:Green"
Write-Information -MessageData "" -Tags "Color:White"

# Display certificate details
Write-Information -MessageData "Using certificate:" -Tags "Color:Green"
Write-Information -MessageData "  Subject:    $($cert.Subject)" -Tags "Color:Gray"
Write-Information -MessageData "  Thumbprint: $($cert.Thumbprint)" -Tags "Color:Gray"
Write-Information -MessageData "  Issuer:     $($cert.Issuer)" -Tags "Color:Gray"
Write-Information -MessageData "  Valid until: $($cert.NotAfter.ToString('yyyy-MM-dd'))" -Tags "Color:Gray"
Write-Information -MessageData "" -Tags "Color:White"

# Find all PowerShell scripts
Write-Information -MessageData "Scanning for PowerShell files..." -Tags "Color:Yellow"

$filesToSign = @()
$filesToSign += Get-ChildItem -Path $FrameworkRoot -Filter "*.ps1" -File -ErrorAction SilentlyContinue
$filesToSign += Get-ChildItem -Path $FrameworkRoot -Filter "*.psm1" -Recurse -File -ErrorAction SilentlyContinue
$filesToSign += Get-ChildItem -Path $FrameworkRoot -Filter "*.psd1" -Recurse -File -ErrorAction SilentlyContinue

if ($filesToSign.Count -eq 0) {
    Write-Information -MessageData "" -Tags "Color:White"
    Write-Information -MessageData "No PowerShell files found to sign." -Tags "Color:Yellow"
    Write-Information -MessageData "" -Tags "Color:White"
    exit 0
}

Write-Information -MessageData "  Found $($filesToSign.Count) PowerShell files" -Tags "Color:Green"
Write-Information -MessageData "" -Tags "Color:White"

# Check current signature status
Write-Information -MessageData "Checking current signature status..." -Tags "Color:Yellow"

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

$unsignedColor = if ($unsigned.Count -gt 0) { "Yellow" } else { "Gray" }
$validSignedColor = if ($validSigned.Count -gt 0) { "Green" } else { "Gray" }
$invalidSignedColor = if ($invalidSigned.Count -gt 0) { "Red" } else { "Gray" }

Write-Information -MessageData "  Not Signed:     $($unsigned.Count)" -Tags "Color:$unsignedColor"
Write-Information -MessageData "  Valid Signed:   $($validSigned.Count)" -Tags "Color:$validSignedColor"
Write-Information -MessageData "  Invalid Signed: $($invalidSigned.Count)" -Tags "Color:$invalidSignedColor"
Write-Information -MessageData "" -Tags "Color:White"

# Determine what to sign
if ($Force) {
    $toSign = $filesToSign
    Write-Information -MessageData "Force mode: Will re-sign all $($toSign.Count) files" -Tags "Color:Yellow"
} else {
    $toSign = $unsigned + $invalidSigned
    if ($toSign.Count -eq 0) {
        Write-Information -MessageData "All files are already validly signed!" -Tags "Color:Green"
        Write-Information -MessageData "" -Tags "Color:White"
        Write-Information -MessageData "Use -Force to re-sign all files." -Tags "Color:Gray"
        Write-Information -MessageData "" -Tags "Color:White"
        exit 0
    }
    Write-Information -MessageData "Will sign $($toSign.Count) files (unsigned or invalid signatures)" -Tags "Color:Yellow"
}

Write-Information -MessageData "" -Tags "Color:White"

if ($WhatIf) {
    Write-Information -MessageData "WhatIf Mode - Files that would be signed:" -Tags "Color:Cyan"
    Write-Information -MessageData "" -Tags "Color:White"

    foreach ($file in $toSign) {
        $relativePath = $file.FullName.Replace($FrameworkRoot, ".").TrimStart('\')
        Write-Information -MessageData "  [WHATIF] $relativePath" -Tags "Color:Cyan"
    }

    Write-Information -MessageData "" -Tags "Color:White"
    Write-Information -MessageData "Total files that would be signed: $($toSign.Count)" -Tags "Color:Yellow"
    Write-Information -MessageData "" -Tags "Color:White"
    exit 0
}

# Confirm before signing (unless WhatIf)
Write-Information -MessageData "Ready to sign $($toSign.Count) files." -Tags "Color:Yellow"
$response = Read-Host "Continue? (Y/N)"

if ($response -ne 'Y' -and $response -ne 'y') {
    Write-Information -MessageData "" -Tags "Color:White"
    Write-Information -MessageData "Signing cancelled by user." -Tags "Color:Yellow"
    Write-Information -MessageData "" -Tags "Color:White"
    exit 0
}

Write-Information -MessageData "" -Tags "Color:White"
Write-Information -MessageData "Signing files..." -Tags "Color:Yellow"
Write-Information -MessageData "" -Tags "Color:White"

# Sign each file
$successCount = 0
$failCount = 0
$failedFiles = @()

foreach ($file in $toSign) {
    $relativePath = $file.FullName.Replace($FrameworkRoot, ".").TrimStart('\')

    if ($PSCmdlet.ShouldProcess($relativePath, "Sign file with certificate $($cert.Thumbprint)")) {
        try {
            $signature = Set-AuthenticodeSignature -FilePath $file.FullName -Certificate $cert -ErrorAction Stop

            if ($signature.Status -eq "Valid") {
                Write-Information -MessageData "  ✓ $relativePath" -Tags "Color:Green"
                $successCount++
            } else {
                Write-Information -MessageData "  ✗ $relativePath - $($signature.StatusMessage)" -Tags "Color:Red"
                $failCount++
                $failedFiles += @{
                    File = $relativePath
                    Error = $signature.StatusMessage
                }
            }
        }
        catch {
            Write-Information -MessageData "  ✗ $relativePath - $($_.Exception.Message)" -Tags "Color:Red"
            $failCount++
            $failedFiles += @{
                File = $relativePath
                Error = $_.Exception.Message
            }
        }
    }
}

# Display summary
Write-Information -MessageData "" -Tags "Color:White"
Write-Information -MessageData "========================================" -Tags "Color:Cyan"
Write-Information -MessageData "  Signing Summary" -Tags "Color:Cyan"
Write-Information -MessageData "========================================" -Tags "Color:Cyan"
Write-Information -MessageData "" -Tags "Color:White"

Write-Information -MessageData "Total Files:    $($toSign.Count)" -Tags "Color:Cyan"
Write-Information -MessageData "Successful:     $successCount" -Tags "Color:Green"
$failColor = if ($failCount -gt 0) { "Red" } else { "Gray" }
Write-Information -MessageData "Failed:         $failCount" -Tags "Color:$failColor"
Write-Information -MessageData "" -Tags "Color:White"

if ($failCount -gt 0) {
    Write-Information -MessageData "Failed Files:" -Tags "Color:Red"
    Write-Information -MessageData "" -Tags "Color:White"

    foreach ($failed in $failedFiles) {
        Write-Information -MessageData "  File:  $($failed.File)" -Tags "Color:Yellow"
        Write-Information -MessageData "  Error: $($failed.Error)" -Tags "Color:Gray"
        Write-Information -MessageData "" -Tags "Color:White"
    }
}

# Verification
Write-Information -MessageData "Verifying signatures..." -Tags "Color:Yellow"

$verifyFailed = 0
foreach ($file in $toSign) {
    $sig = Get-AuthenticodeSignature -FilePath $file.FullName -ErrorAction SilentlyContinue

    if ($sig.Status -ne "Valid") {
        $verifyFailed++
        $relativePath = $file.FullName.Replace($FrameworkRoot, ".").TrimStart('\')
        Write-Information -MessageData "  ✗ Verification failed: $relativePath ($($sig.Status))" -Tags "Color:Red"
    }
}

if ($verifyFailed -eq 0) {
    Write-Information -MessageData "  All signed files verified successfully!" -Tags "Color:Green"
} else {
    Write-Information -MessageData "  $verifyFailed files failed verification!" -Tags "Color:Red"
}

Write-Information -MessageData "" -Tags "Color:White"

# Final status
if ($failCount -eq 0 -and $verifyFailed -eq 0) {
    Write-Information -MessageData "========================================" -Tags "Color:Green"
    Write-Information -MessageData "  Signing Complete!" -Tags "Color:Green"
    Write-Information -MessageData "========================================" -Tags "Color:Green"
    Write-Information -MessageData "" -Tags "Color:White"
    exit 0
} else {
    Write-Information -MessageData "========================================" -Tags "Color:Red"
    Write-Information -MessageData "  Signing Completed with Errors" -Tags "Color:Red"
    Write-Information -MessageData "========================================" -Tags "Color:Red"
    Write-Information -MessageData "" -Tags "Color:White"
    Write-Information -MessageData "Please review the errors above and retry." -Tags "Color:Yellow"
    Write-Information -MessageData "" -Tags "Color:White"
    exit 1
}


