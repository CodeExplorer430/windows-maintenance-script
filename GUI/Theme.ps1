<#
.SYNOPSIS
    UI Theme and Styling for the Windows Maintenance Framework.
#>

# Define Colors (Modern Palette)
$UITheme = @{
    Background = [System.Drawing.Color]::FromArgb(240, 240, 240)
    Foreground = [System.Drawing.Color]::FromArgb(33, 33, 33)
    Primary    = [System.Drawing.Color]::FromArgb(0, 120, 215) # Windows Blue
    Success    = [System.Drawing.Color]::FromArgb(16, 124, 16) # Office Green
    Warning    = [System.Drawing.Color]::FromArgb(255, 185, 0) # Gold
    Error      = [System.Drawing.Color]::FromArgb(232, 17, 35)  # Red
    ConsoleBg  = [System.Drawing.Color]::FromArgb(30, 30, 30)
    ConsoleFg  = [System.Drawing.Color]::FromArgb(204, 204, 204)
    Accent     = [System.Drawing.Color]::FromArgb(0, 153, 188)
}

# Define Fonts
$UIFonts = @{
    Header  = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
    SubHeader = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    Standard = New-Object System.Drawing.Font("Segoe UI", 10)
    Console  = New-Object System.Drawing.Font("Consolas", 10)
}

# Export symbols to script scope
$script:UITheme = $UITheme
$script:UIFonts = $UIFonts
