@{
    RootModule        = 'WindowsEnterpriseTroubleshooting.psm1'
    ModuleVersion     = '2.0.0'
    GUID              = '92dcf876-f14f-4f7f-9aaf-61f2a8dc66d7'
    Author            = 'Dewald Pretorius'
    CompanyName       = 'Community'
    Copyright         = '(c) 2026 Dewald Pretorius. All rights reserved.'
    Description       = 'Plugin-based Windows enterprise diagnostics, evidence collection, finding normalization, and technician reporting.'
    PowerShellVersion = '5.1'

    FunctionsToExport = @(
        'Get-WetPlugin',
        'Test-WetPlugin',
        'Invoke-WetPlugin',
        'Invoke-WetAssessment',
        'New-WetFinding',
        'Protect-WetData',
        'Get-WetSeverityRank'
    )

    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags         = @('Windows','Troubleshooting','Diagnostics','PowerShell','Enterprise','Support')
            LicenseUri   = 'https://github.com/IAmLegionVaal/Windows-Enterprise-Troubleshooting-Framework/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/IAmLegionVaal/Windows-Enterprise-Troubleshooting-Framework'
            ReleaseNotes = 'Version 2.0 introduces a plugin contract, normalized findings, configurable assessments, redaction helpers, tests, and CI.'
        }
    }
}