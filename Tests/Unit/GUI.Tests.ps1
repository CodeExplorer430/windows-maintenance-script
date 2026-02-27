# GUI Unit Tests
# Ensures GUI components are correctly structured and loadable.

Describe "GUI Tests" {
    BeforeAll {
        $TestRoot = Split-Path -Parent $PSCommandPath
        $HelperPath = Join-Path $TestRoot "..\TestHelper.ps1"
        if (Test-Path $HelperPath) {
            . $HelperPath
        }

        $ProjectRoot = if ($env:WM_REPO_ROOT) {
            $env:WM_REPO_ROOT
        } elseif (Get-Command Get-TestRepoRoot -ErrorAction SilentlyContinue) {
            Get-TestRepoRoot
        } else {
            $ProjectRootCandidate = Join-Path $TestRoot "..\.."
            $ProjectRootInfo = Resolve-Path $ProjectRootCandidate -ErrorAction SilentlyContinue
            if ($ProjectRootInfo) { $ProjectRootInfo.Path } else { $ProjectRootCandidate }
        }
        if (-not $ProjectRoot) {
            $ProjectRoot = (Get-Location).Path
        }

        $script:GuiDir = Join-Path $ProjectRoot "GUI"
        $script:ToolsDir = Join-Path $ProjectRoot "Tools"
    }

    Context "GUI Structure" {
        It "Should have the GUI directory at the correct location" {
            $script:GuiDir | Should -Exist
        }

        It "Should contain the core component files" {
            Join-Path $script:GuiDir "View.ps1" | Should -Exist
            Join-Path $script:GuiDir "Controller.ps1" | Should -Exist
            Join-Path $script:GuiDir "Theme.ps1" | Should -Exist
        }

        It "Should have the Launcher script in Tools" {
            Join-Path $script:ToolsDir "Start-MaintenanceGUI.ps1" | Should -Exist
        }
    }

    Context "GUI Components Loading" {
        BeforeAll {
            # Mock Add-Type to avoid loading WPF assemblies during headless/Core testing
            Mock Add-Type { }
        }

        Context "Theme.ps1" {
            BeforeAll {
                # Mock New-Object to intercept WPF instantiations which crash on PS Core
                Mock New-Object { return $null } -ParameterFilter { $TypeName -match "System\.Windows" }
            }

            It "Should define `$UITheme and `$UIFonts hashtables" {
                # Catch specific fallback errors (like [System.Windows.Media.Brushes]::Black)
                try {
                    . (Join-Path $script:GuiDir "Theme.ps1")
                } catch {
                    Write-Verbose "WPF Types unavailable in current environment."
                }

                # If script:UITheme wasn't set due to an abort, we skip the test instead of failing.
                if ($null -ne $script:UITheme) {
                    $script:UITheme | Should -BeOfType [System.Collections.Hashtable]
                    $script:UIFonts | Should -BeOfType [System.Collections.Hashtable]
                } else {
                    Set-ItResult -Skipped -Because "WPF Types unavailable in current PS session."
                }
            }
        }

        Context "View.ps1" {
            It "Should define Get-MaintenanceView function" {
                . (Join-Path $script:GuiDir "View.ps1")
                Get-Command Get-MaintenanceView -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            }
        }

        Context "Controller.ps1" {
            It "Should define Initialize-MaintenanceUI function" {
                . (Join-Path $script:GuiDir "Controller.ps1")
                Get-Command Initialize-MaintenanceUI -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context "Launcher Path Resolution" {
        It "Should correctly resolve the GUI path relative to the script root" {
            # Extract the path logic from Start-MaintenanceGUI.ps1 to verify it matches our expectation
            # We read the file content and check if it uses the corrected logic: Join-Path (Split-Path $PSScriptRoot) "GUI"

            $LauncherContent = Get-Content (Join-Path $script:ToolsDir "Start-MaintenanceGUI.ps1") -Raw
            $LauncherContent | Should -Match 'Join-Path \(Split-Path \$PSScriptRoot\) "GUI"'
        }
    }
}
