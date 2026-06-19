#requires -Version 5.1
Set-StrictMode -Version Latest

function New-CaseContext {
    [CmdletBinding()]
    param([string]$RootPath)

    if ([string]::IsNullOrWhiteSpace($RootPath)) {
        $RootPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Enterprise_Troubleshooting_Cases'
    }

    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $casePath = Join-Path $RootPath "Case_$env:COMPUTERNAME`_$stamp"
    New-Item -Path $casePath -ItemType Directory -Force | Out-Null

    [PSCustomObject]@{
        Computer = $env:COMPUTERNAME
        Created  = Get-Date
        CasePath = $casePath
        LogPath  = Join-Path $casePath 'technician.log'
        Data     = [ordered]@{}
    }
}

function Write-CaseLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO','OK','WARN','ERROR')][string]$Level = 'INFO'
    )

    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Add-Content -Path $Context.LogPath -Value $line -Encoding UTF8
    switch ($Level) {
        'OK'    { Write-Host $line -ForegroundColor Green }
        'WARN'  { Write-Host $line -ForegroundColor Yellow }
        'ERROR' { Write-Host $line -ForegroundColor Red }
        default { Write-Host $line }
    }
}

function Export-CaseData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)]$Data
    )

    $Context.Data[$Name] = @($Data)
    @($Data) | Export-Csv -Path (Join-Path $Context.CasePath "$Name.csv") -NoTypeInformation -Encoding UTF8
    @($Data) | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $Context.CasePath "$Name.json") -Encoding UTF8
}

function New-CaseReport {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Context)

    $sections = foreach ($entry in $Context.Data.GetEnumerator()) {
        "<h2>$($entry.Key)</h2>$(@($entry.Value) | ConvertTo-Html -Fragment)"
    }

    $body = @"
<h1>Windows Enterprise Troubleshooting Report</h1>
<p><strong>Computer:</strong> $($Context.Computer)</p>
<p><strong>Generated:</strong> $(Get-Date)</p>
$($sections -join "`n")
"@

    $reportPath = Join-Path $Context.CasePath 'case-report.html'
    $body | ConvertTo-Html -Title 'Enterprise Troubleshooting Report' | Set-Content -Path $reportPath -Encoding UTF8
    return $reportPath
}

Export-ModuleMember -Function New-CaseContext,Write-CaseLog,Export-CaseData,New-CaseReport
