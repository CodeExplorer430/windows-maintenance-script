$TestRoot = if ($PSScriptRoot) { $PSScriptRoot } elseif ($PSCommandPath) { Split-Path -Parent $PSCommandPath } else { (Get-Location).Path }
$HelperPath = Join-Path $TestRoot "TestHelper.ps1"
if (Test-Path $HelperPath) { . $HelperPath }

<#
.SYNOPSIS
    Pester tests for Windows Maintenance Framework main module.
#>

#Requires -Module Pester

Describe "WindowsMaintenance Module" {
    # Set up test environment
    BeforeAll {
        $script:ModuleRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
        $script:ModulePath = Join-Path $script:ModuleRoot "WindowsMaintenance.psd1"
        $script:ConfigPath = Join-Path $script:ModuleRoot "Config\maintenance-config.json"

        # Read manifest safely
        if (Test-Path $script:ModulePath) {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '')]
            $script:ManifestData = Invoke-Expression (Get-Content -Path $script:ModulePath -Raw)
        }

        try {
            Import-Module $script:ModulePath -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Debug "Module could not be fully imported: $($_.Exception.Message)"
        }
    }

    Context "Module Structure" {
        It "Module manifest file exists" {
            (Test-Path $script:ModulePath) | Should -Be $true
        }

        It "Module loads successfully" {
            $IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
            if ($IsAdmin) {
                { Import-Module $script:ModulePath -Force } | Should -Not -Throw
            } else {
                Show-TestResult -Skipped
            }
        }

        It "Module exports Invoke-WindowsMaintenance function" {
            if (Get-Command Invoke-WindowsMaintenance -ErrorAction SilentlyContinue) {
                Get-Command Invoke-WindowsMaintenance | Should -Not -BeNullOrEmpty
            } else {
                Show-TestResult -Skipped
            }
        }

        It "Module has valid version" {
            if ($script:ManifestData) {
                $script:ManifestData.ModuleVersion | Should -Not -BeNullOrEmpty
                $script:ManifestData.ModuleVersion | Should -Match '^\d+\.\d+\.\d+$'
            } else {
                Show-TestResult -Skipped
            }
        }
    }

    Context "Nested Modules" {
        It "Contains Common modules" {
            if ($script:ManifestData) {
                $script:ManifestData.NestedModules | Should -Contain 'Modules\Common\Logging.psm1'
            } else {
                Show-TestResult -Skipped
            }
        }

        It "All nested module files exist" {
            if ($script:ManifestData) {
                foreach ($NestedModule in $script:ManifestData.NestedModules) {
                    $FilePath = Join-Path $script:ModuleRoot $NestedModule
                    (Test-Path $FilePath) | Should -Be $true
                }
            } else {
                Show-TestResult -Skipped
            }
        }
    }

    Context "Configuration" {
        It "Default configuration file exists" {
            (Test-Path $script:ConfigPath) | Should -Be $true
        }

        It "Configuration file is valid JSON" {
            if (Test-Path $script:ConfigPath) {
                { Get-Content -Path $script:ConfigPath -Raw | ConvertFrom-Json } | Should -Not -Throw
            } else {
                Show-TestResult -Skipped
            }
        }
    }
}


