# Windows Maintenance Framework - REST API Endpoints

New-PSUEndpoint -Url "/maintenance/run" -Method "POST" -ScriptBlock {
    $BodyData = $Body | ConvertFrom-Json
    $ConfigPath = $BodyData.ConfigPath

    $Job = Start-Job -ScriptBlock {
        Import-Module (Join-Path $PSScriptRoot "..\WindowsMaintenance.psd1") -Force
        Invoke-WindowsMaintenance -ConfigPath $Using:ConfigPath -SilentMode
    }

    return @{ Message = "Maintenance job started"; JobId = $Job.Id }
}

New-PSUEndpoint -Url "/maintenance/history" -Method "GET" -ScriptBlock {
    Import-Module (Join-Path $PSScriptRoot "..\WindowsMaintenance.psd1") -Force
    $History = Invoke-SQLiteQuery -Query "SELECT * FROM MaintenanceHistory ORDER BY Timestamp DESC LIMIT 100"
    return $History
}

New-PSUEndpoint -Url "/maintenance/status" -Method "GET" -ScriptBlock {
    $OS = Get-CimInstance Win32_OperatingSystem
    return @{
        ComputerName = $env:COMPUTERNAME
        OS = $OS.Caption
        LastBoot = $OS.LastBootUpTime
    }
}
