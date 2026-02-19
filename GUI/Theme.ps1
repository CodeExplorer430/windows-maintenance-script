<#
.SYNOPSIS
    UI Theme and Styling for the Windows Maintenance Framework (WPF Edition).
#>

Add-Type -AssemblyName PresentationFramework

# Helper: Create Brush from Hex
function Get-SolidColorBrush {
    param([string]$Hex)
    try {
        [System.Windows.Media.BrushConverter]$Converter = New-Object System.Windows.Media.BrushConverter
        $Brush = $Converter.ConvertFromString($Hex)
        $Brush.Freeze() # Performance optimization for immutable brushes
        return $Brush
    } catch {
        Write-Warning "Invalid color hex: $Hex. Fallback to Black."
        return [System.Windows.Media.Brushes]::Black
    }
}

# Define Theme Resources (Brushes)
$UITheme = @{
    "Brush_Background" = Get-SolidColorBrush "#1E1E1E"
    "Brush_Foreground" = Get-SolidColorBrush "#D4D4D4"
    "Brush_Primary"    = Get-SolidColorBrush "#0078D7"
    "Brush_Success"    = Get-SolidColorBrush "#107C10"
    "Brush_Warning"    = Get-SolidColorBrush "#FFB900"
    "Brush_Error"      = Get-SolidColorBrush "#E81123"
    "Brush_Panel"      = Get-SolidColorBrush "#252526"
    "Brush_Border"     = Get-SolidColorBrush "#3E3E42"
    "Brush_ControlBg"  = Get-SolidColorBrush "#333333"
    "Brush_ControlHover" = Get-SolidColorBrush "#505050"
}

# Define Fonts
$UIFonts = @{
    "Font_Header"  = New-Object System.Windows.Media.FontFamily("Segoe UI")
    "Font_Console" = New-Object System.Windows.Media.FontFamily("Consolas")
}

# Export symbols to script scope
$script:UITheme = $UITheme
$script:UIFonts = $UIFonts
