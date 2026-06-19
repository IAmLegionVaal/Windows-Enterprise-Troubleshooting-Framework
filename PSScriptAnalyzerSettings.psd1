@{
    Severity = @('Error','Warning')
    IncludeRules = @(
        'PSAvoidUsingCmdletAliases',
        'PSAvoidUsingPlainTextForPassword',
        'PSAvoidUsingInvokeExpression',
        'PSAvoidGlobalVars',
        'PSUseApprovedVerbs',
        'PSUseDeclaredVarsMoreThanAssignments',
        'PSUsePSCredentialType',
        'PSReviewUnusedParameter',
        'PSUseShouldProcessForStateChangingFunctions'
    )
}