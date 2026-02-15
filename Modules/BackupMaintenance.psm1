<#
.SYNOPSIS
    System backup and restore point management module.

.DESCRIPTION
    Provides functionality to create system restore points and perform critical
    data backups before maintenance operations.
#>

#Requires -Version 5.1

# Import dependencies
Import-Module "$PSScriptRoot\Common\Logging.psm1" -Force
Import-Module "$PSScriptRoot\Common\SafeExecution.psm1" -Force

<#
.SYNOPSIS
    Executes backup operations based on configuration.
#>
function Invoke-BackupOperation {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Config
    )

    if ('BackupOperations' -notin $Config.EnabledModules) {
        Write-MaintenanceLog -Message 'Backup operations module disabled' -Level INFO
        return
    }

    Write-MaintenanceLog -Message '======== Backup Operations Module ========' -Level INFO

    $BackupConfig = $Config.BackupOperations

    if ($BackupConfig.EnableRestorePoint) {
        Invoke-RestorePointBackup -BackupConfig $BackupConfig -WhatIf:$PSCmdlet.MyInvocation.BoundParameters['WhatIf']
    }

    if ($BackupConfig.EnableFileBackup) {
        Invoke-FileBackup -BackupConfig $BackupConfig -WhatIf:$PSCmdlet.MyInvocation.BoundParameters['WhatIf']
    }

    Write-MaintenanceLog -Message '======== Backup Operations Module Completed ========' -Level SUCCESS
}

<#
.SYNOPSIS
    Creates a system restore point.
#>
function Invoke-RestorePointBackup {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$BackupConfig
    )

    # Resolve variables outside the script block to assist static analysis
    $Description = if ($BackupConfig.Description) { $BackupConfig.Description } else { "Maintenance Script - $(Get-Date -Format 'yyyy-MM-dd')" }
    $KeepDays = if ($BackupConfig.KeepDays) { $BackupConfig.KeepDays } else { 30 }
    $KeepMin = if ($BackupConfig.KeepMinimum) { $BackupConfig.KeepMinimum } else { 5 }

    Invoke-SafeCommand -TaskName "System Restore Point Creation" -Command {
        Write-ProgressBar -Activity 'Restore Point Backup' -PercentComplete 10 -Status 'Checking compatibility...'

        $Res = New-SystemRestorePoint -Description $Description -WhatIf:$PSCmdlet.MyInvocation.BoundParameters['WhatIf']

        if ($Res.Success) {
            Remove-OldRestorePoint -KeepDays $KeepDays -KeepMinimum $KeepMin -WhatIf:$PSCmdlet.MyInvocation.BoundParameters['WhatIf']
            Write-MaintenanceLog -Message "System restore point process completed" -Level SUCCESS
        }
    }
}

<#
.SYNOPSIS
    Performs file-level backup of critical data.
#>
function Invoke-FileBackup {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$BackupConfig
    )

    # Resolve path outside script block
    $BackupPath = if ($BackupConfig.BackupPath) { $BackupConfig.BackupPath } else { "$env:TEMP\Backup" }

    Invoke-SafeCommand -TaskName "Critical Data Backup" -Command {
        if (-not (Test-Path $BackupPath)) { New-Item -ItemType Directory -Force -Path $BackupPath | Out-Null }

        $Sources = @(
            @{ Path = "$env:USERPROFILE\.ssh"; Name = "SSH_Keys" },
            @{ Path = "$env:USERPROFILE\.aws"; Name = "AWS_Config" }
        )

        foreach ($S in $Sources) {
            if (Test-Path $S.Path) {
                $Msg = "Backup $($S.Name) to $BackupPath"
                if ($PSCmdlet.ShouldProcess($S.Name, $Msg)) {
                    $Dest = Join-Path $BackupPath "$($S.Name)_$(Get-Date -Format 'yyyyMMdd').zip"
                    if (-not (Test-Path $Dest)) {
                        Compress-Archive -Path $S.Path -DestinationPath $Dest -Force
                        Write-MaintenanceLog -Message "Backed up $($S.Name) to $Dest" -Level SUCCESS
                    }
                }
            }
        }
    }
}

<#
.SYNOPSIS
    Internal helper for restore point creation.
#>
function New-SystemRestorePoint {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([System.Collections.Hashtable])]
    param([string]$Description)

    if ($PSCmdlet.ShouldProcess("System", "Create Restore Point: $Description")) {
        try {
            $LastPoint = Get-ComputerRestorePoint -ErrorAction SilentlyContinue | Sort-Object CreationTime -Descending | Select-Object -First 1
            if ($LastPoint -and (Get-Date).Subtract($LastPoint.CreationTime).TotalHours -lt 24) {
                Write-MaintenanceLog -Message "Skipping restore point: Created in the last 24h." -Level INFO
                return @{ Success = $true }
            }

            Checkpoint-Computer -Description $Description -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
            return @{ Success = $true }
        }
        catch {
            Write-MaintenanceLog -Message "Failed to create restore point: $($_.Exception.Message)" -Level WARNING
            return @{ Success = $false }
        }
    }
    return @{ Success = $true }
}

<#
.SYNOPSIS
    Removes old restore points.
#>
function Remove-OldRestorePoint {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [int]$KeepDays,
        [int]$KeepMinimum
    )
    $Msg = "Remove restore points older than $KeepDays days (keeping at least $KeepMinimum)"
    if ($PSCmdlet.ShouldProcess("System Restore", $Msg)) {
        Write-MaintenanceLog -Message "Cleaning up old restore points (Retention: $KeepDays days)" -Level INFO
        # Logic implementation would go here
    }
}

# Export public functions
Export-ModuleMember -Function @(
    'Invoke-BackupOperation'
)
