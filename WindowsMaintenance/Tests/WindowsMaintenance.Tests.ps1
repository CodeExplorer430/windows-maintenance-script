<#
.SYNOPSIS
    Pester tests for Windows Maintenance Framework main module.

.DESCRIPTION
    Comprehensive Pester tests for validating the Windows Maintenance Framework
    module structure, configuration loading, and core functionality.

.NOTES
    File Name      : WindowsMaintenance.Tests.ps1
    Author         : Miguel Velasco
    Prerequisite   : Pester 5.x, PowerShell 5.1+
    Version        : 1.0.0
    Last Updated   : October 2025
#>

#Requires -Module Pester

BeforeAll {
    # Set up test environment
    $ModuleRoot = Split-Path -Parent $PSScriptRoot
    $ModulePath = Join-Path $ModuleRoot "WindowsMaintenance.psd1"
    $ConfigPath = Join-Path (Split-Path $ModuleRoot) "config\maintenance-config.json"

    # Import module
    Import-Module $ModulePath -Force -ErrorAction Stop
}

Describe "WindowsMaintenance Module" {
    Context "Module Structure" {
        It "Module manifest file exists" {
            $ModulePath | Should -Exist
        }

        It "Module loads successfully" {
            { Import-Module $ModulePath -Force } | Should -Not -Throw
        }

        It "Module exports Invoke-WindowsMaintenance function" {
            $Commands = Get-Command -Module WindowsMaintenance
            $Commands.Name | Should -Contain 'Invoke-WindowsMaintenance'
        }

        It "Module has valid version" {
            $Manifest = Test-ModuleManifest -Path $ModulePath -ErrorAction Stop
            $Manifest.Version | Should -Not -BeNullOrEmpty
            $Manifest.Version.ToString() | Should -Match '^\d+\.\d+\.\d+$'
        }

        It "Module has required metadata" {
            $Manifest = Test-ModuleManifest -Path $ModulePath -ErrorAction Stop
            $Manifest.Author | Should -Not -BeNullOrEmpty
            $Manifest.Description | Should -Not -BeNullOrEmpty
        }
    }

    Context "Nested Modules" {
        BeforeAll {
            $Manifest = Test-ModuleManifest -Path $ModulePath -ErrorAction Stop
            $NestedModules = $Manifest.NestedModules
        }

        It "Contains Common modules" {
            $NestedModules | Should -Contain 'Modules\Common\Logging.psm1'
            $NestedModules | Should -Contain 'Modules\Common\StringFormatting.psm1'
            $NestedModules | Should -Contain 'Modules\Common\SystemDetection.psm1'
            $NestedModules | Should -Contain 'Modules\Common\MemoryManagement.psm1'
        }

        It "Contains Feature modules" {
            $NestedModules | Should -Contain 'Modules\SystemUpdates.psm1'
            $NestedModules | Should -Contain 'Modules\DiskMaintenance.psm1'
            $NestedModules | Should -Contain 'Modules\SystemHealthRepair.psm1'
            $NestedModules | Should -Contain 'Modules\SecurityScans.psm1'
            $NestedModules | Should -Contain 'Modules\DeveloperMaintenance.psm1'
            $NestedModules | Should -Contain 'Modules\PerformanceOptimization.psm1'
            $NestedModules | Should -Contain 'Modules\NetworkMaintenance.psm1'
        }

        It "All nested module files exist" {
            foreach ($NestedModule in $NestedModules) {
                $ModuleFilePath = Join-Path $ModuleRoot $NestedModule
                $ModuleFilePath | Should -Exist
            }
        }
    }

    Context "Configuration" {
        It "Default configuration file exists" {
            $ConfigPath | Should -Exist
        }

        It "Configuration file is valid JSON" {
            { Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json } | Should -Not -Throw
        }

        It "Configuration has required fields" {
            $Config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
            $Config.EnabledModules | Should -Not -BeNullOrEmpty
            $Config.LogsPath | Should -Not -BeNullOrEmpty
            $Config.ReportsPath | Should -Not -BeNullOrEmpty
        }

        It "EnabledModules contains only valid module names" {
            $Config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
            $ValidModules = @(
                'SystemUpdates', 'DiskMaintenance', 'SystemHealthRepair',
                'SecurityScans', 'DeveloperMaintenance', 'PerformanceOptimization',
                'NetworkMaintenance'
            )

            foreach ($Module in $Config.EnabledModules) {
                $Module | Should -BeIn $ValidModules
            }
        }
    }

    Context "Module Files" {
        It "Root module file exists" {
            $RootModulePath = Join-Path $ModuleRoot "WindowsMaintenance.psm1"
            $RootModulePath | Should -Exist
        }

        It "Root module contains Invoke-WindowsMaintenance function" {
            $RootModulePath = Join-Path $ModuleRoot "WindowsMaintenance.psm1"
            $Content = Get-Content -Path $RootModulePath -Raw
            $Content | Should -Match 'function Invoke-WindowsMaintenance'
        }

        It "Root module exports functions correctly" {
            $RootModulePath = Join-Path $ModuleRoot "WindowsMaintenance.psm1"
            $Content = Get-Content -Path $RootModulePath -Raw
            $Content | Should -Match 'Export-ModuleMember'
        }
    }
}

Describe "Common Modules" {
    Context "Logging Module" {
        It "Logging module file exists" {
            $LoggingPath = Join-Path $ModuleRoot "Modules\Common\Logging.psm1"
            $LoggingPath | Should -Exist
        }

        It "Logging module exports required functions" {
            $LoggingPath = Join-Path $ModuleRoot "Modules\Common\Logging.psm1"
            $Content = Get-Content -Path $LoggingPath -Raw
            $Content | Should -Match 'function Write-MaintenanceLog'
            $Content | Should -Match 'Export-ModuleMember'
        }
    }

    Context "SystemDetection Module" {
        It "SystemDetection module file exists" {
            $DetectionPath = Join-Path $ModuleRoot "Modules\Common\SystemDetection.psm1"
            $DetectionPath | Should -Exist
        }
    }

    Context "SafeExecution Module" {
        It "SafeExecution module file exists" {
            $SafeExecPath = Join-Path $ModuleRoot "Modules\Common\SafeExecution.psm1"
            $SafeExecPath | Should -Exist
        }

        It "SafeExecution module exports Invoke-SafeCommand" {
            $SafeExecPath = Join-Path $ModuleRoot "Modules\Common\SafeExecution.psm1"
            $Content = Get-Content -Path $SafeExecPath -Raw
            $Content | Should -Match 'function Invoke-SafeCommand'
        }
    }
}

Describe "Feature Modules" {
    Context "SystemUpdates Module" {
        It "SystemUpdates module file exists" {
            $ModulePath = Join-Path $ModuleRoot "Modules\SystemUpdates.psm1"
            $ModulePath | Should -Exist
        }

        It "SystemUpdates module has Invoke function" {
            $ModulePath = Join-Path $ModuleRoot "Modules\SystemUpdates.psm1"
            $Content = Get-Content -Path $ModulePath -Raw
            $Content | Should -Match 'function Invoke-SystemUpdates'
        }
    }

    Context "DiskMaintenance Module" {
        It "DiskMaintenance module file exists" {
            $ModulePath = Join-Path $ModuleRoot "Modules\DiskMaintenance.psm1"
            $ModulePath | Should -Exist
        }

        It "DiskMaintenance module has Invoke function" {
            $ModulePath = Join-Path $ModuleRoot "Modules\DiskMaintenance.psm1"
            $Content = Get-Content -Path $ModulePath -Raw
            $Content | Should -Match 'function Invoke-DiskMaintenance'
        }
    }

    Context "SystemHealthRepair Module" {
        It "SystemHealthRepair module file exists" {
            $ModulePath = Join-Path $ModuleRoot "Modules\SystemHealthRepair.psm1"
            $ModulePath | Should -Exist
        }

        It "SystemHealthRepair module has Invoke function" {
            $ModulePath = Join-Path $ModuleRoot "Modules\SystemHealthRepair.psm1"
            $Content = Get-Content -Path $ModulePath -Raw
            $Content | Should -Match 'function Invoke-SystemHealthRepair'
        }
    }

    Context "SecurityScans Module" {
        It "SecurityScans module file exists" {
            $ModulePath = Join-Path $ModuleRoot "Modules\SecurityScans.psm1"
            $ModulePath | Should -Exist
        }

        It "SecurityScans module has Invoke function" {
            $ModulePath = Join-Path $ModuleRoot "Modules\SecurityScans.psm1"
            $Content = Get-Content -Path $ModulePath -Raw
            $Content | Should -Match 'function Invoke-SecurityScans'
        }
    }

    Context "DeveloperMaintenance Module" {
        It "DeveloperMaintenance module file exists" {
            $ModulePath = Join-Path $ModuleRoot "Modules\DeveloperMaintenance.psm1"
            $ModulePath | Should -Exist
        }

        It "DeveloperMaintenance module has Invoke function" {
            $ModulePath = Join-Path $ModuleRoot "Modules\DeveloperMaintenance.psm1"
            $Content = Get-Content -Path $ModulePath -Raw
            $Content | Should -Match 'function Invoke-DeveloperMaintenance'
        }
    }

    Context "PerformanceOptimization Module" {
        It "PerformanceOptimization module file exists" {
            $ModulePath = Join-Path $ModuleRoot "Modules\PerformanceOptimization.psm1"
            $ModulePath | Should -Exist
        }

        It "PerformanceOptimization module has Invoke function" {
            $ModulePath = Join-Path $ModuleRoot "Modules\PerformanceOptimization.psm1"
            $Content = Get-Content -Path $ModulePath -Raw
            $Content | Should -Match 'function Invoke-PerformanceOptimization'
        }
    }

    Context "NetworkMaintenance Module" {
        It "NetworkMaintenance module file exists" {
            $ModulePath = Join-Path $ModuleRoot "Modules\NetworkMaintenance.psm1"
            $ModulePath | Should -Exist
        }

        It "NetworkMaintenance module has Invoke function" {
            $ModulePath = Join-Path $ModuleRoot "Modules\NetworkMaintenance.psm1"
            $Content = Get-Content -Path $ModulePath -Raw
            $Content | Should -Match 'function Invoke-NetworkMaintenance'
        }

        It "NetworkMaintenance exports network functions" {
            $ModulePath = Join-Path $ModuleRoot "Modules\NetworkMaintenance.psm1"
            $Content = Get-Content -Path $ModulePath -Raw
            $Content | Should -Match 'function Clear-DNSCache'
            $Content | Should -Match 'function Test-NetworkConnectivity'
        }
    }
}

Describe "Utility Scripts" {
    Context "Install-MaintenanceTask Script" {
        It "Install-MaintenanceTask script exists" {
            $ScriptPath = Join-Path $ModuleRoot "Scripts\Install-MaintenanceTask.ps1"
            $ScriptPath | Should -Exist
        }

        It "Install-MaintenanceTask has proper parameters" {
            $ScriptPath = Join-Path $ModuleRoot "Scripts\Install-MaintenanceTask.ps1"
            $Content = Get-Content -Path $ScriptPath -Raw
            $Content | Should -Match '\[CmdletBinding\(\)\]'
            $Content | Should -Match 'param\s*\('
        }
    }

    Context "Test-MaintenanceConfig Script" {
        It "Test-MaintenanceConfig script exists" {
            $ScriptPath = Join-Path $ModuleRoot "Scripts\Test-MaintenanceConfig.ps1"
            $ScriptPath | Should -Exist
        }

        It "Test-MaintenanceConfig validates configuration" {
            $ScriptPath = Join-Path $ModuleRoot "Scripts\Test-MaintenanceConfig.ps1"
            $Content = Get-Content -Path $ScriptPath -Raw
            $Content | Should -Match 'EnabledModules'
            $Content | Should -Match 'ValidationErrors'
        }
    }

    Context "TaskScheduler Module" {
        It "TaskScheduler module file exists" {
            $ModulePath = Join-Path $ModuleRoot "Modules\TaskScheduler.psm1"
            $ModulePath | Should -Exist
        }

        It "TaskScheduler exports task management functions" {
            $ModulePath = Join-Path $ModuleRoot "Modules\TaskScheduler.psm1"
            $Content = Get-Content -Path $ModulePath -Raw
            $Content | Should -Match 'function New-MaintenanceTask'
            $Content | Should -Match 'function Remove-MaintenanceTask'
            $Content | Should -Match 'function Get-MaintenanceTask'
        }
    }
}

AfterAll {
    # Cleanup
    Remove-Module WindowsMaintenance -ErrorAction SilentlyContinue
}
