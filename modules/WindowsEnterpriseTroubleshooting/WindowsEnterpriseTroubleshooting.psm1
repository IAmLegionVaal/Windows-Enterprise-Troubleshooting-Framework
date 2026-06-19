#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-WetSeverityRank {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Informational','Low','Medium','High','Critical')]
        [string]$Severity
    )

    switch ($Severity) {
        'Informational' { 0 }
        'Low'           { 1 }
        'Medium'        { 2 }
        'High'          { 3 }
        'Critical'      { 4 }
    }
}

function New-WetFinding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Plugin,
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][ValidateSet('Informational','Low','Medium','High','Critical')][string]$Severity,
        [Parameter(Mandatory)][ValidateRange(0,100)][int]$Confidence,
        [Parameter(Mandatory)][string]$Evidence,
        [Parameter(Mandatory)][string]$Impact,
        [Parameter(Mandatory)][string]$Recommendation,
        [string]$Reference,
        [string]$Target = $env:COMPUTERNAME
    )

    [PSCustomObject]@{
        PSTypeName     = 'WindowsEnterpriseTroubleshooting.Finding'
        FindingId      = [guid]::NewGuid().Guid
        Plugin         = $Plugin
        Target         = $Target
        Title          = $Title
        Severity       = $Severity
        SeverityRank   = Get-WetSeverityRank -Severity $Severity
        Confidence     = $Confidence
        Evidence       = $Evidence
        Impact         = $Impact
        Recommendation = $Recommendation
        Reference      = $Reference
        ObservedAtUtc  = [DateTime]::UtcNow
    }
}

function Protect-WetData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [AllowEmptyString()]
        [string]$Text,

        [string[]]$AdditionalPatterns = @()
    )

    process {
        $redacted = $Text

        $patterns = @(
            @{ Pattern = '(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b'; Replacement = '[REDACTED-EMAIL]' },
            @{ Pattern = '(?<!\d)(?:\d{1,3}\.){3}\d{1,3}(?!\d)'; Replacement = '[REDACTED-IP]' },
            @{ Pattern = '(?i)(password|passwd|pwd|secret|token)\s*[:=]\s*[^\s,;]+'; Replacement = '$1=[REDACTED]' },
            @{ Pattern = '(?i)C:\\Users\\[^\\\s]+'; Replacement = 'C:\Users\[REDACTED-USER]' }
        )

        foreach ($item in $patterns) {
            $redacted = [regex]::Replace($redacted, $item.Pattern, $item.Replacement)
        }

        foreach ($pattern in $AdditionalPatterns) {
            if (-not [string]::IsNullOrWhiteSpace($pattern)) {
                $redacted = [regex]::Replace($redacted, $pattern, '[REDACTED]')
            }
        }

        $redacted
    }
}

function Test-WetPlugin {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        $Plugin
    )

    process {
        $required = @('Name','Version','Description','Invoke')
        $errors = [System.Collections.Generic.List[string]]::new()

        if (-not ($Plugin -is [System.Collections.IDictionary])) {
            $errors.Add('Plugin must return a hashtable or ordered dictionary.')
        }
        else {
            foreach ($key in $required) {
                if (-not $Plugin.Contains($key)) {
                    $errors.Add("Missing required key: $key")
                }
            }

            if ($Plugin.Contains('Invoke') -and -not ($Plugin.Invoke -is [scriptblock])) {
                $errors.Add('Invoke must be a script block.')
            }
        }

        [PSCustomObject]@{
            PSTypeName = 'WindowsEnterpriseTroubleshooting.PluginValidation'
            IsValid    = ($errors.Count -eq 0)
            Errors     = @($errors)
        }
    }
}

function Get-WetPlugin {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [string]$Path
    )

    foreach ($file in Get-ChildItem -Path $Path -Filter '*.plugin.ps1' -File | Sort-Object Name) {
        try {
            $plugin = & $file.FullName
            $validation = Test-WetPlugin -Plugin $plugin

            if (-not $validation.IsValid) {
                Write-Warning "Plugin '$($file.Name)' failed validation: $($validation.Errors -join '; ')"
                continue
            }

            [PSCustomObject]@{
                PSTypeName = 'WindowsEnterpriseTroubleshooting.Plugin'
                Name       = [string]$plugin.Name
                Version    = [string]$plugin.Version
                Description = [string]$plugin.Description
                RequiresAdmin = [bool]$(if ($plugin.Contains('RequiresAdmin')) { $plugin.RequiresAdmin } else { $false })
                SupportsRemote = [bool]$(if ($plugin.Contains('SupportsRemote')) { $plugin.SupportsRemote } else { $false })
                Invoke     = $plugin.Invoke
                SourcePath = $file.FullName
            }
        }
        catch {
            Write-Warning "Plugin '$($file.Name)' could not be loaded: $($_.Exception.Message)"
        }
    }
}

function Invoke-WetPlugin {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Plugin,
        [Parameter(Mandatory)]$Context
    )

    $started = Get-Date
    try {
        $result = & $Plugin.Invoke $Context
        [PSCustomObject]@{
            PSTypeName = 'WindowsEnterpriseTroubleshooting.PluginResult'
            Plugin     = $Plugin.Name
            Version    = $Plugin.Version
            Target     = $Context.Target
            Succeeded  = $true
            Started    = $started
            Completed  = Get-Date
            DurationMs = [math]::Round(((Get-Date) - $started).TotalMilliseconds, 0)
            Findings   = @($result.Findings)
            Evidence   = @($result.Evidence)
            Error      = $null
        }
    }
    catch {
        [PSCustomObject]@{
            PSTypeName = 'WindowsEnterpriseTroubleshooting.PluginResult'
            Plugin     = $Plugin.Name
            Version    = $Plugin.Version
            Target     = $Context.Target
            Succeeded  = $false
            Started    = $started
            Completed  = Get-Date
            DurationMs = [math]::Round(((Get-Date) - $started).TotalMilliseconds, 0)
            Findings   = @()
            Evidence   = @()
            Error      = $_.Exception.Message
        }
    }
}

function Invoke-WetAssessment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$PluginPath,
        [string[]]$PluginName,
        [string]$Target = $env:COMPUTERNAME,
        [string]$CaseId = ('CASE-{0}' -f (Get-Date -Format 'yyyyMMdd-HHmmss')),
        [hashtable]$Configuration = @{},
        [string]$OutputPath
    )

    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        $OutputPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Enterprise_Troubleshooting_Cases'
    }

    $casePath = Join-Path $OutputPath $CaseId
    New-Item -Path $casePath -ItemType Directory -Force | Out-Null

    $context = [PSCustomObject]@{
        PSTypeName    = 'WindowsEnterpriseTroubleshooting.Context'
        CaseId        = $CaseId
        Target        = $Target
        CasePath      = $casePath
        Configuration = $Configuration
        StartedUtc    = [DateTime]::UtcNow
    }

    $plugins = @(Get-WetPlugin -Path $PluginPath)
    if ($PluginName) {
        $plugins = @($plugins | Where-Object { $_.Name -in $PluginName })
    }

    $results = foreach ($plugin in $plugins) {
        Invoke-WetPlugin -Plugin $plugin -Context $context
    }

    $findings = @($results | ForEach-Object Findings | Sort-Object SeverityRank -Descending)
    $summary = [PSCustomObject]@{
        CaseId          = $CaseId
        Target          = $Target
        StartedUtc      = $context.StartedUtc
        CompletedUtc    = [DateTime]::UtcNow
        PluginCount     = $plugins.Count
        SuccessfulCount = @($results | Where-Object Succeeded).Count
        FailedCount     = @($results | Where-Object { -not $_.Succeeded }).Count
        FindingCount    = $findings.Count
        CriticalCount   = @($findings | Where-Object Severity -eq 'Critical').Count
        HighCount       = @($findings | Where-Object Severity -eq 'High').Count
        MediumCount     = @($findings | Where-Object Severity -eq 'Medium').Count
    }

    $results | ConvertTo-Json -Depth 12 | Set-Content -Path (Join-Path $casePath 'plugin-results.json') -Encoding UTF8
    $findings | Export-Csv -Path (Join-Path $casePath 'findings.csv') -NoTypeInformation -Encoding UTF8
    $summary | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $casePath 'summary.json') -Encoding UTF8

    [PSCustomObject]@{
        PSTypeName = 'WindowsEnterpriseTroubleshooting.Assessment'
        Context    = $context
        Summary    = $summary
        Results    = $results
        Findings   = $findings
    }
}

Export-ModuleMember -Function Get-WetPlugin,Test-WetPlugin,Invoke-WetPlugin,Invoke-WetAssessment,New-WetFinding,Protect-WetData,Get-WetSeverityRank