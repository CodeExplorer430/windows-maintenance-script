@{
    ExcludeRules = @('PSAvoidUsingInvokeExpression')
    Rules = @{
        PSAvoidUsingWriteHost = @{
            Enable = $false
        }
        PSUseShouldProcessForStateChangingFunctions = @{
            Enable = $false
        }
        PSAvoidTrailingWhitespace = @{
            Enable = $true
        }
        PSAvoidUsingInvokeExpression = @{
            Enable = $false
        }
    }
}
