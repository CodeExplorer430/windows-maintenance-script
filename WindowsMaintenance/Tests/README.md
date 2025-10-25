# Windows Maintenance Framework - Tests

This directory contains Pester tests for the Windows Maintenance Framework.

## Prerequisites

- **PowerShell 5.1+**
- **Pester 5.x** - Install using:
  ```powershell
  Install-Module -Name Pester -Force -SkipPublisherCheck
  ```

## Running Tests

### Run All Tests
```powershell
.\Invoke-Tests.ps1
```

### Run with Detailed Output
```powershell
.\Invoke-Tests.ps1 -OutputFormat Detailed
```

### Run with Code Coverage
```powershell
.\Invoke-Tests.ps1 -CodeCoverage
```

### Run in CI Mode
```powershell
.\Invoke-Tests.ps1 -CI
```

### Run Specific Test File
```powershell
.\Invoke-Tests.ps1 -TestPath ".\WindowsMaintenance.Tests.ps1"
```

## Test Structure

### WindowsMaintenance.Tests.ps1
Main test suite covering:

#### Module Structure Tests
- Module manifest validation
- Module loading
- Function exports
- Metadata verification
- Version validation

#### Nested Modules Tests
- Common module presence (Logging, StringFormatting, SystemDetection, MemoryManagement, etc.)
- Feature module presence (SystemUpdates, DiskMaintenance, etc.)
- Module file existence

#### Configuration Tests
- Configuration file existence
- JSON validity
- Required fields presence
- Module name validation

#### Common Modules Tests
- **Logging Module**: Write-MaintenanceLog function
- **SystemDetection Module**: File existence
- **SafeExecution Module**: Invoke-SafeCommand function

#### Feature Modules Tests
- **SystemUpdates Module**: Invoke function and structure
- **DiskMaintenance Module**: Invoke function and structure
- **SystemHealthRepair Module**: Invoke function and structure
- **SecurityScans Module**: Invoke function and structure
- **DeveloperMaintenance Module**: Invoke function and structure
- **PerformanceOptimization Module**: Invoke function and structure
- **NetworkMaintenance Module**: Invoke function and network-specific functions

#### Utility Scripts Tests
- **Install-MaintenanceTask**: Script existence and parameters
- **Test-MaintenanceConfig**: Script existence and validation logic
- **TaskScheduler Module**: Task management functions

## Test Coverage

Current test coverage includes:
- ✅ Module structure and manifest
- ✅ All nested modules presence
- ✅ Configuration validation
- ✅ Core function exports
- ✅ Utility scripts
- ✅ Task scheduler integration

## Adding New Tests

To add new tests:

1. Create a new `.Tests.ps1` file in this directory
2. Follow the Pester 5.x syntax:
   ```powershell
   BeforeAll {
       # Setup code
   }

   Describe "YourFeature" {
       Context "SpecificScenario" {
           It "Should do something" {
               # Test code
               $result | Should -Be $expected
           }
       }
   }

   AfterAll {
       # Cleanup code
   }
   ```
3. Run tests using `Invoke-Tests.ps1`

## Continuous Integration

For CI/CD pipelines, use:
```powershell
.\Invoke-Tests.ps1 -CI -CodeCoverage
```

This will:
- Exit with non-zero code on failure
- Generate code coverage report (CodeCoverage.xml)
- Provide detailed test output

## Test Output Formats

### Normal
Basic pass/fail information

### Detailed (Default)
- Test names and results
- Timing information
- Summary statistics

### Diagnostic
- All Detailed information
- Internal Pester diagnostics
- Verbose output

## Common Issues

### Pester Not Found
```powershell
Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser
```

### Module Import Errors
Ensure you run tests from the Tests directory or provide correct paths.

### Permission Errors
Some tests may require Administrator privileges. Run PowerShell as Administrator if needed.

## Best Practices

1. **Test in Isolation**: Each test should be independent
2. **Use BeforeAll/AfterAll**: Setup and cleanup properly
3. **Descriptive Names**: Use clear, descriptive test names
4. **Test One Thing**: Each test should verify one specific behavior
5. **Mock External Dependencies**: Use Pester mocking for external calls
6. **Keep Tests Fast**: Tests should execute quickly

## Future Test Coverage

Planned additions:
- Integration tests for full maintenance runs
- Mock-based tests for system operations
- Performance benchmarking tests
- Configuration validation tests
- Error handling tests
- WhatIf mode tests
- Logging output verification
- Network connectivity tests
- Disk operation tests

## Contributing

When adding new features to the Windows Maintenance Framework:
1. Write tests first (TDD approach when possible)
2. Ensure all existing tests pass
3. Add tests for new functionality
4. Update this README if adding new test files

## Resources

- [Pester Documentation](https://pester.dev)
- [PowerShell Testing Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/test/testing-with-pester)
- [Pester GitHub](https://github.com/pester/Pester)

