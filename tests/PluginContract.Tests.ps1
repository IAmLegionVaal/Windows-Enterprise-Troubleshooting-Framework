BeforeAll {
    $repositoryRoot = Split-Path -Parent $PSScriptRoot
    $manifest = Join-Path $repositoryRoot 'modules\WindowsEnterpriseTroubleshooting\WindowsEnterpriseTroubleshooting.psd1'
    $pluginPath = Join-Path $repositoryRoot 'plugins'
    Import-Module $manifest -Force
}

Describe 'Built-in plugin contract' {
    BeforeAll {
        $plugins = @(Get-WetPlugin -Path $pluginPath)
    }

    It 'discovers all initial v2 plugins' {
        $plugins.Name | Should -Contain 'SystemHealth'
        $plugins.Name | Should -Contain 'NetworkDiagnostics'
        $plugins.Name | Should -Contain 'WindowsUpdate'
        $plugins.Name | Should -Contain 'EventCorrelation'
    }

    It 'loads four valid plugins' {
        $plugins.Count | Should -Be 4
    }

    It 'provides unique plugin names' {
        @($plugins.Name | Select-Object -Unique).Count | Should -Be $plugins.Count
    }

    It 'provides semantic versions' {
        foreach ($plugin in $plugins) {
            $plugin.Version | Should -Match '^\d+\.\d+\.\d+$'
        }
    }

    It 'provides invokable script blocks' {
        foreach ($plugin in $plugins) {
            $plugin.Invoke | Should -BeOfType ([scriptblock])
        }
    }
}