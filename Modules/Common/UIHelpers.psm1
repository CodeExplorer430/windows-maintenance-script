<#
.SYNOPSIS
    User interface and interaction utilities for Windows Maintenance module.

.DESCRIPTION
    Provides sophisticated user interaction capabilities.
#>

#Requires -Version 5.1

# Import dependencies
Import-Module "$PSScriptRoot\Logging.psm1" -Force

# Load required .NET assemblies
try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop
}
catch {
    Write-MaintenanceLog -Message "Failed to load Windows Forms assemblies. UI dialogs may be unavailable: $($_.Exception.Message)" -Level WARNING
}

<#
.SYNOPSIS
    Displays a message box.
#>
function Show-MaintenanceMessageBox {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Message,

        [string] $Title = "Windows Maintenance Script",

        [ValidateSet("OK", "OKCancel", "YesNo", "YesNoCancel")]
        [string] $Buttons = "OK",

        [ValidateSet("Information", "Warning", "Error", "Question")]
        [string] $Icon = "Information"
    )

    # UI helpers now assume that if they are called, the caller has already
    # checked for silent mode or wants to force the display.
    # We log the message for audit regardless.
    Write-MaintenanceLog -Message "UI Message: $Message" -Level INFO

    try {
        $ButtonType = switch ($Buttons) {
            "OK" { [System.Windows.Forms.MessageBoxButtons]::OK }
            "OKCancel" { [System.Windows.Forms.MessageBoxButtons]::OKCancel }
            "YesNo" { [System.Windows.Forms.MessageBoxButtons]::YesNo }
            "YesNoCancel" { [System.Windows.Forms.MessageBoxButtons]::YesNoCancel }
        }

        $IconType = switch ($Icon) {
            "Information" { [System.Windows.Forms.MessageBoxIcon]::Information }
            "Warning" { [System.Windows.Forms.MessageBoxIcon]::Warning }
            "Error" { [System.Windows.Forms.MessageBoxIcon]::Error }
            "Question" { [System.Windows.Forms.MessageBoxIcon]::Question }
        }

        $Result = [System.Windows.Forms.MessageBox]::Show($Message, $Title, $ButtonType, $IconType)
        return $Result.ToString()
    }
    catch {
        return "OK"
    }
}

<#
.SYNOPSIS
    Risk confirmation dialog.
#>
function Confirm-RiskyOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Operation,

        [Parameter(Mandatory = $true)]
        [string] $RiskDescription,

        [string] $Recommendation = "Proceed with caution"
    )

    $Message = @"
ATTENTION: Risk Assessment Required

Operation: $Operation

Risk Description:
$RiskDescription

Recommendation: $Recommendation

Do you want to proceed?
"@

    $Result = Show-MaintenanceMessageBox -Message $Message -Title "Risk Confirmation Required" -Buttons "YesNo" -Icon "Warning"
    return ($Result -eq "Yes")
}

# Export public functions
Export-ModuleMember -Function @(
    'Show-MaintenanceMessageBox',
    'Confirm-RiskyOperation'
)
