# GUI Unit Tests
# Ensures GUI components are correctly structured and loadable.

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$GuiDir = Join-Path $ProjectRoot "GUI"
$ToolsDir = Join-Path $ProjectRoot "Tools"

Describe "GUI Structure" {
    It "Should have the GUI directory at the correct location" {
        $GuiDir | Should -Exist
    }

    It "Should contain the core component files" {
        Join-Path $GuiDir "View.ps1" | Should -Exist
        Join-Path $GuiDir "Controller.ps1" | Should -Exist
        Join-Path $GuiDir "Theme.ps1" | Should -Exist
    }

    It "Should have the Launcher script in Tools" {
        Join-Path $ToolsDir "Start-MaintenanceGUI.ps1" | Should -Exist
    }
}

Describe "GUI Components Loading" {
    BeforeAll {
        # Mock Add-Type to avoid loading WPF assemblies during headless testing
        Mock Add-Type { }
    }

    Context "Theme.ps1" {
        It "Should define `$UITheme and `$UIFonts hashtables" {
            . (Join-Path $GuiDir "Theme.ps1")
            $UITheme | Should -BeOfType [System.Collections.Hashtable]
            $UIFonts | Should -BeOfType [System.Collections.Hashtable]
        }
    }

    Context "View.ps1" {
        It "Should define Get-MaintenanceView function" {
            . (Join-Path $GuiDir "View.ps1")
            Get-Command Get-MaintenanceView -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }

    Context "Controller.ps1" {
        It "Should define Initialize-MaintenanceUI function" {
            . (Join-Path $GuiDir "Controller.ps1")
            Get-Command Initialize-MaintenanceUI -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Launcher Path Resolution" {
    It "Should correctly resolve the GUI path relative to the script root" {
        # Extract the path logic from Start-MaintenanceGUI.ps1 to verify it matches our expectation
        # We read the file content and check if it uses the corrected logic: Join-Path (Split-Path $PSScriptRoot) "GUI"

        $LauncherContent = Get-Content (Join-Path $ToolsDir "Start-MaintenanceGUI.ps1") -Raw
        $LauncherContent | Should -Match 'Join-Path \(Split-Path \$PSScriptRoot\) "GUI"'
    }
}
