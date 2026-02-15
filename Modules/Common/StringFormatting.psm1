<#
.SYNOPSIS
    String formatting and sanitization utilities for the Windows Maintenance module.

.DESCRIPTION
    Provides enterprise-grade string formatting with comprehensive error handling,
    parameter validation, and security protections against format string vulnerabilities.

    This module is designed to be lightweight and dependency-free to serve as a
    foundational component for other modules.

.NOTES
    File Name      : StringFormatting.psm1
    Author         : Miguel Velasco
    Prerequisite   : PowerShell 5.1+
    Version        : 4.0.0
    Last Updated   : October 2025
    Module Type    : Common Utility Module
#>

#Requires -Version 5.1

<#
.SYNOPSIS
    Safely formats strings with parameter substitution and error handling.

.DESCRIPTION
    Provides enterprise-grade string formatting with comprehensive error handling,
    parameter validation, and security protections against format string vulnerabilities.

    Security Features:
    - Parameter sanitization to prevent injection attacks
    - Length limits to prevent buffer overflow scenarios
    - Null and type validation for all parameters
    - Safe handling of numeric types including NaN and Infinity

    Performance Features:
    - Efficient parameter processing with minimal allocations
    - Optimized for repeated calls during maintenance operations
    - Graceful handling of complex objects with automatic string conversion

.PARAMETER Template
    String template with numbered placeholders (e.g., "Value: {0}, Status: {1}")

.PARAMETER Arguments
    Array of arguments to substitute into the template placeholders

.OUTPUTS
    [string] Safely formatted string with all parameters substituted

.EXAMPLE
    Format-SafeString -Template "Drive: {0}, Size: {1}GB" -Arguments @("C:", 250.5)
    Returns: "Drive: C:, Size: 250.5GB"

.EXAMPLE
    Format-SafeString -Template "Status: {0}" -Arguments @($null)
    Returns: "Status: N/A"

.NOTES
    Security: All input parameters are sanitized to prevent format string attacks
    Performance: Optimized for frequent use during maintenance operations
    Reliability: Handles edge cases like null values, NaN, and infinity gracefully
#>
function Format-SafeString {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true, HelpMessage="String template with numbered placeholders")]
        [string]$Template,

        [Parameter(Mandatory=$false, HelpMessage="Arguments for placeholder substitution")]
        [object[]]$Arguments
    )

    try {
        # Validate template parameter
        if ([string]::IsNullOrWhiteSpace($Template)) {
            return "Empty template provided"
        }

        # Handle empty or null arguments
        if (-not $Arguments -or $Arguments.Count -eq 0) {
            return $Template
        }

        # Sanitize all arguments to prevent formatting errors and security issues
        $SafeArgs = @()
        foreach ($arg in $Arguments) {
            if ($null -eq $arg) {
                $SafeArgs += "N/A"
            }
            elseif ($arg -is [double] -or $arg -is [decimal] -or $arg -is [float]) {
                # Handle special numeric values (NaN, Infinity)
                if ([double]::IsNaN($arg) -or [double]::IsInfinity($arg)) {
                    $SafeArgs += "0"
                }
                else {
                    # Apply appropriate precision based on magnitude
                    if ([Math]::Abs($arg) -gt 1000000) {
                        $SafeArgs += $arg.ToString("F1")
                    } else {
                        $SafeArgs += $arg.ToString("F2")
                    }
                }
            }
            elseif ($arg -is [long] -or $arg -is [int]) {
                $SafeArgs += $arg.ToString()
            }
            elseif ($arg -is [string]) {
                if ([string]::IsNullOrWhiteSpace($arg)) {
                    $SafeArgs += "N/A"
                }
                else {
                    # Security: Truncate very long strings to prevent memory issues
                    if ($arg.Length -gt 500) {
                        $SafeArgs += $arg.Substring(0, 497) + "..."
                    } else {
                        $SafeArgs += $arg.ToString()
                    }
                }
            }
            else {
                # Handle complex objects with safe string conversion
                try {
                    $stringValue = $arg.ToString()
                    if ($stringValue.Length -gt 500) {
                        $SafeArgs += $stringValue.Substring(0, 497) + "..."
                    } else {
                        $SafeArgs += $stringValue
                    }
                } catch {
                    $SafeArgs += "ToString Error"
                }
            }
        }

        # Validate placeholder count and indices for security
        $PlaceholderMatches = [regex]::Matches($Template, '\{\d+\}')
        $PlaceholderCount = $PlaceholderMatches.Count

        # Ensure we have enough arguments for all placeholders
        while ($SafeArgs.Count -lt $PlaceholderCount) {
            $SafeArgs += "Missing"
        }

        # Security: Validate that all placeholder indices are within bounds
        foreach ($Match in $PlaceholderMatches) {
            $IndexStr = $Match.Value -replace '\{|\}', ''
            if ([int]$IndexStr -ge $SafeArgs.Count) {
                # Use Write-Warning instead of Write-MaintenanceLog to avoid circular dependency
                Write-Warning "String formatting warning: Placeholder {$IndexStr} exceeds argument count ($($SafeArgs.Count))"
                return "String formatting error - placeholder index out of range"
            }
        }

        # Perform safe string formatting
        return $Template -f $SafeArgs
    }
    catch {
        # Use Write-Warning instead of Write-MaintenanceLog to avoid circular dependency
        Write-Warning "String formatting error with template '$Template': $($_.Exception.Message)"
        return "String formatting error - see logs for details"
    }
}

<#
.SYNOPSIS
    Safely converts byte values to human-readable size format.

.DESCRIPTION
    Converts raw byte values to formatted size strings with proper units
    and error handling for invalid or extreme values.

.PARAMETER SizeInBytes
    Size value in bytes to be converted

.PARAMETER Unit
    Target unit for conversion (KB, MB, GB)

.OUTPUTS
    [string] Formatted size string with units

.EXAMPLE
    Get-SafeFileSize -SizeInBytes 1073741824 -Unit "GB"
    Returns: "1.00 GB"

.NOTES
    Performance: Optimized for frequent file size calculations
    Security: Handles null and invalid values safely
#>
function Get-SafeFileSize {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true, HelpMessage="Size in bytes to convert")]
        $SizeInBytes,

        [Parameter(Mandatory=$false, HelpMessage="Target unit for conversion")]
        [string]$Unit = "MB"
    )

    try {
        if ($null -eq $SizeInBytes -or $SizeInBytes -eq 0) {
            return "0 $Unit"
        }

        $Divisor = switch ($Unit) {
            "KB" { 1KB }
            "MB" { 1MB }
            "GB" { 1GB }
            default { 1MB }
        }

        $Result = [math]::Round($SizeInBytes / $Divisor, 2)
        return "$Result $Unit"
    }
    catch {
        return "0 $Unit"
    }
}

# Export public functions
Export-ModuleMember -Function @(
    'Format-SafeString',
    'Get-SafeFileSize'
)
