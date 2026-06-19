@{
    Severity = @('Error','Warning')
    IncludeRules = @(
        'PSAvoidUsingCmdletAliases',
        'PSAvoidUsingPlainTextForPassword',
        'PSAvoidUsingInvokeExpression',
        'PSAvoidGlobalVars',
        'PSAvoidUsingWriteHost',
        'PSUseApprovedVerbs',
        'PSUseDeclaredVarsMoreThanAssignments',
        'PSUsePSCredentialType',
        'PSReviewUnusedParameter',
        'PSUseShouldProcessForStateChangingFunctions'
    )
    Rules = @{
        PSAvoidUsingWriteHost = @{
            Exclude = @(
                'Windows_Enterprise_Troubleshooter.ps1',
                'Windows_Enterprise_Troubleshooter_v2.ps1'
            )
        }
    }
}