BeforeAll {
    $repositoryRoot = Split-Path -Parent $PSScriptRoot
    $manifest = Join-Path $repositoryRoot 'modules\WindowsEnterpriseTroubleshooting\WindowsEnterpriseTroubleshooting.psd1'
    Import-Module $manifest -Force
}

Describe 'WindowsEnterpriseTroubleshooting module' {
    It 'exports the expected public commands' {
        $expected = @(
            'Get-WetPlugin',
            'Test-WetPlugin',
            'Invoke-WetPlugin',
            'Invoke-WetAssessment',
            'New-WetFinding',
            'Protect-WetData',
            'Get-WetSeverityRank'
        )

        $commands = Get-Command -Module WindowsEnterpriseTroubleshooting | Select-Object -ExpandProperty Name
        foreach ($name in $expected) {
            $commands | Should -Contain $name
        }
    }

    It 'creates a normalized finding object' {
        $finding = New-WetFinding `
            -Plugin 'UnitTest' `
            -Title 'Test finding' `
            -Severity High `
            -Confidence 95 `
            -Evidence 'Synthetic evidence' `
            -Impact 'Synthetic impact' `
            -Recommendation 'Synthetic recommendation'

        $finding.PSTypeNames | Should -Contain 'WindowsEnterpriseTroubleshooting.Finding'
        $finding.Severity | Should -Be 'High'
        $finding.SeverityRank | Should -Be 3
        $finding.Confidence | Should -Be 95
        $finding.FindingId | Should -Not -BeNullOrEmpty
    }

    It 'orders severity values consistently' {
        Get-WetSeverityRank -Severity Informational | Should -Be 0
        Get-WetSeverityRank -Severity Low | Should -Be 1
        Get-WetSeverityRank -Severity Medium | Should -Be 2
        Get-WetSeverityRank -Severity High | Should -Be 3
        Get-WetSeverityRank -Severity Critical | Should -Be 4
    }

    It 'redacts common sensitive values' {
        $inputText = 'User path C:\Users\Dewald email dewald@example.com IP 192.168.1.10 token=abc123'
        $result = Protect-WetData -Text $inputText

        $result | Should -Match '\[REDACTED-USER\]'
        $result | Should -Match '\[REDACTED-EMAIL\]'
        $result | Should -Match '\[REDACTED-IP\]'
        $result | Should -Match 'token=\[REDACTED\]'
        $result | Should -Not -Match 'abc123'
    }

    It 'rejects a plugin without the required contract' {
        $validation = Test-WetPlugin -Plugin @{ Name='Broken' }
        $validation.IsValid | Should -BeFalse
        $validation.Errors.Count | Should -BeGreaterThan 0
    }
}