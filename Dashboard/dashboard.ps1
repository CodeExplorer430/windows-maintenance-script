# Windows Maintenance Framework - PowerShell Universal Dashboard (v4.2.0)

$ModuleRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Import-Module (Join-Path $ModuleRoot "WindowsMaintenance.psd1") -Force

New-UDDashboard -Title "Windows Maintenance Dashboard" -Content {
    # Header Section
    New-UDRow {
        New-UDColumn -LargeSize 12 {
            New-UDTypography -Text "Framework Control Plane" -Variant h2 -Align center
        }
    }

    # Live Metrics Row
    New-UDRow {
        New-UDDynamic -Id 'MetricsRegion' -Iteration 5000 -Content {
            $OS = Get-CimInstance Win32_OperatingSystem
            $MemFree = [math]::Round($OS.FreePhysicalMemory / 1MB, 2)
            $MemTotal = [math]::Round($OS.TotalVisibleMemorySize / 1MB, 2)
            $MemUsed = $MemTotal - $MemFree

            New-UDColumn -LargeSize 4 {
                New-UDCounter -Title "Memory Usage (GB)" -Value $MemUsed -Icon (New-UDIcon -Icon 'Memory')
            }
            New-UDColumn -LargeSize 4 {
                $Disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"
                $DiskFree = [math]::Round($Disk.FreeSpace / 1GB, 1)
                New-UDCounter -Title "System Drive Free (GB)" -Value $DiskFree -Icon (New-UDIcon -Icon 'Hdd')
            }
            New-UDColumn -LargeSize 4 {
                $History = Invoke-SQLiteQuery -Query "SELECT COUNT(*) as Count FROM MaintenanceHistory WHERE Result = 'Success'"
                $SuccessCount = if ($null -ne $History.Count) { $History.Count } else { 0 }
                New-UDCounter -Title "Successful Tasks" -Value $SuccessCount -Icon (New-UDIcon -Icon 'CheckCircle')
            }
        }
    }

    # Main Content Area
    New-UDRow {
        # Control Panel
        New-UDColumn -LargeSize 4 {
            New-UDCard -Title "Operations" -Content {
                New-UDButton -Text "Execute Standard Maintenance" -FullWidth -Icon (New-UDIcon -Icon 'Play') -OnClick {
                    Invoke-WindowsMaintenance -SilentMode
                    Show-UDToast -Message "Standard Maintenance Job Started" -Severity 'Info'
                }
                New-UDElement -Tag 'div' -Attributes @{ style = @{ marginTop = '10px' } } -Content {
                    New-UDButton -Text "Dry Run (WhatIf)" -FullWidth -Variant 'outlined' -OnClick {
                        Invoke-WindowsMaintenance -WhatIf
                        Show-UDToast -Message "Simulation complete. Check logs." -Severity 'Success'
                    }
                }
            }

            New-UDCard -Title "Active Configuration" -Content {
                $Config = Get-Content (Join-Path $ModuleRoot "Config\maintenance-config.json") | ConvertFrom-Json
                New-UDList -Content {
                    foreach ($Module in $Config.EnabledModules) {
                        New-UDListItem -Label $Module -Icon (New-UDIcon -Icon 'Box')
                    }
                }
            }
        }

        # Real-Time Log Stream
        New-UDColumn -LargeSize 8 {
            New-UDCard -Title "Real-Time Log Stream" -Content {
                New-UDDynamic -Id 'LogStream' -Iteration 2000 -Content {
                    $LogDir = "$env:TEMP\WindowsMaintenance\Logs"
                    $LatestLog = Get-ChildItem -Path $LogDir -Filter "*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

                    if ($LatestLog) {
                        $Content = Get-Content $LatestLog.FullName -Tail 20
                        New-UDElement -Tag 'pre' -Attributes @{
                            style = @{
                                backgroundColor = '#1e1e1e';
                                color = '#d4d4d4';
                                padding = '10px';
                                borderRadius = '5px';
                                overflowY = 'auto';
                                height = '400px';
                                fontSize = '12px'
                            }
                        } -Content {
                            $Content -join "`n"
                        }
                    } else {
                        New-UDTypography -Text "No active logs found in $LogDir"
                    }
                }
            }
        }
    }

    # History Table
    New-UDRow {
        New-UDColumn -LargeSize 12 {
            New-UDCard -Title "Execution History (SQLite)" -Content {
                $HistoryData = Invoke-SQLiteQuery -Query "SELECT Timestamp, ModuleName, TaskName, Result, Details FROM MaintenanceHistory ORDER BY Timestamp DESC LIMIT 100"
                New-UDTable -Data $HistoryData -Columns @(
                    New-UDTableColumn -Property "Timestamp" -Title "Date"
                    New-UDTableColumn -Property "ModuleName" -Title "Module"
                    New-UDTableColumn -Property "TaskName" -Title "Task"
                    New-UDTableColumn -Property "Result" -Title "Result" -Render {
                        if ($EventData.Result -eq 'Success') {
                            New-UDBadge -Text "Success" -Color 'green'
                        } else {
                            New-UDBadge -Text $EventData.Result -Color 'orange'
                        }
                    }
                ) -Paging -PageSize 10
            }
        }
    }
}
