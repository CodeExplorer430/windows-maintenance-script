
<#
.SYNOPSIS
    Unit tests for AppInventory helpers.
#>

$ModulePath = Join-Path $PSScriptRoot "..\..\Modules\Common\AppInventory.psm1"
Import-Module $ModulePath -Force

Describe "AppInventory" {
    BeforeAll {
        $TestRoot = Split-Path -Parent $PSCommandPath
        $HelperPath = Join-Path $TestRoot "..\TestHelper.ps1"
        if (Test-Path $HelperPath) { . $HelperPath }
    }

    InModuleScope AppInventory {
        It "merges catalog and installed apps" {
            $Catalog = @(
                [pscustomobject]@{
                    Id = "vscode"
                    DisplayName = "Visual Studio Code"
                    Tags = @("Developer")
                    ModuleMappings = @()
                    DefaultEnabled = $true
                    SourceHints = @()
                }
            )

            $Installed = @(
                [pscustomobject]@{ Id = "vscode"; DisplayName = "Visual Studio Code"; Source = "Winget" },
                [pscustomobject]@{ Id = "notincatalog"; DisplayName = "Other App"; Source = "Registry" }
            )

            $Result = Merge-AppCatalog -Catalog $Catalog -InstalledApps $Installed
            $Result.Count | Should -Be 2

            ($Result | Where-Object { $_.Id -eq "vscode" }).CatalogMatch | Should -BeTrue
            ($Result | Where-Object { $_.Id -eq "notincatalog" }).CatalogMatch | Should -BeFalse
        }

        It "applies app selections to module config" {
            $CatalogPath = Join-Path $TestDrive "catalog.json"
            @(
                @{
                    Id = "vscode"
                    DisplayName = "Visual Studio Code"
                    Tags = @("Developer")
                    DefaultEnabled = $true
                    ModuleMappings = @(
                        @{ Module = "DeveloperMaintenance"; ConfigKey = "EnableVSCode" }
                    )
                },
                @{
                    Id = "docker"
                    DisplayName = "Docker"
                    Tags = @("Developer")
                    DefaultEnabled = $false
                    ModuleMappings = @(
                        @{ Module = "DeveloperMaintenance"; ConfigKey = "EnableDocker" }
                    )
                }
            ) | ConvertTo-Json -Depth 6 | Set-Content -Path $CatalogPath -Encoding UTF8

            $Config = @{
                AppSelections = @{
                    DeveloperMaintenance = @("vscode")
                }
                DeveloperMaintenance = @{}
            }

            $Updated = Set-AppSelectionConfig -Config $Config -CatalogPath $CatalogPath
            $Updated.DeveloperMaintenance.EnableVSCode | Should -BeTrue
            $Updated.DeveloperMaintenance.EnableDocker | Should -BeFalse
        }

        It "selects default apps when no selections are present" {
            $CatalogPath = Join-Path $TestDrive "catalog-default.json"
            @(
                @{
                    Id = "vscode"
                    DisplayName = "Visual Studio Code"
                    Tags = @("Developer")
                    DefaultEnabled = $true
                    ModuleMappings = @()
                }
            ) | ConvertTo-Json -Depth 6 | Set-Content -Path $CatalogPath -Encoding UTF8

            $Config = @{ AppSelections = @{} }
            $Model = @(Get-AppSelectionModel -Config $Config -CatalogPath $CatalogPath -Sources @{ Winget = $false; Registry = $false; Store = $false })

            $Model.Count | Should -Be 1
            $Model[0].Selected | Should -BeTrue
        }
    }
}

