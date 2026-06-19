#requires -Version 5.1
<#
.SYNOPSIS
    Windows Enterprise Troubleshooting Framework v2.
.DESCRIPTION
    Runs plugin-based diagnostics, normalizes findings, exports evidence, and
    creates a technician and executive HTML report.
#>
[CmdletBinding()]
param(
    [string]$CaseId,
    [string]$TicketNumber,
    [string]$Customer = 'Internal Lab',
    [string]$Technician = $env:USERNAME,
    [string]$Symptom = 'General endpoint health assessment',
    [string[]]$PluginName,
    [string]$Target = $env:COMPUTERNAME,
    [string]$OutputPath,
    [string]$ConfigurationPath,
    [switch]$OpenReport
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleManifest = Join-Path $root 'modules\WindowsEnterpriseTroubleshooting\WindowsEnterpriseTroubleshooting.psd1'
$pluginPath = Join-Path $root 'plugins'

Import-Module $moduleManifest -Force -ErrorAction Stop

if ([string]::IsNullOrWhiteSpace($CaseId)) {
    $CaseId = 'CASE-{0}' -f (Get-Date -Format 'yyyyMMdd-HHmmss')
}

$config = @{}
if ([string]::IsNullOrWhiteSpace($ConfigurationPath)) {
    $ConfigurationPath = Join-Path $root 'config\v2.settings.json'
}

if (Test-Path $ConfigurationPath) {
    $jsonConfig = Get-Content -Path $ConfigurationPath -Raw | ConvertFrom-Json
    foreach ($property in $jsonConfig.PSObject.Properties) {
        $config[$property.Name] = $property.Value
    }
}

$assessmentParameters = @{
    PluginPath   = $pluginPath
    Target       = $Target
    CaseId       = $CaseId
    Configuration = $config
    OutputPath   = $OutputPath
}
if ($PluginName) { $assessmentParameters.PluginName = $PluginName }

Write-Host "Starting Windows Enterprise assessment: $CaseId" -ForegroundColor Cyan
$assessment = Invoke-WetAssessment @assessmentParameters
$casePath = $assessment.Context.CasePath

$metadata = [PSCustomObject]@{
    CaseId       = $CaseId
    TicketNumber = $TicketNumber
    Customer     = $Customer
    Technician   = $Technician
    Target       = $Target
    Symptom      = $Symptom
    StartedUtc   = $assessment.Summary.StartedUtc
    CompletedUtc = $assessment.Summary.CompletedUtc
}
$metadata | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $casePath 'case-metadata.json') -Encoding UTF8

$summaryCards = @"
<div class='cards'>
  <div class='card'><span>Plugins</span><strong>$($assessment.Summary.PluginCount)</strong></div>
  <div class='card'><span>Findings</span><strong>$($assessment.Summary.FindingCount)</strong></div>
  <div class='card critical'><span>Critical</span><strong>$($assessment.Summary.CriticalCount)</strong></div>
  <div class='card high'><span>High</span><strong>$($assessment.Summary.HighCount)</strong></div>
  <div class='card medium'><span>Medium</span><strong>$($assessment.Summary.MediumCount)</strong></div>
</div>
"@

$findingsTable = if ($assessment.Findings.Count -gt 0) {
    $assessment.Findings |
        Select-Object Severity,Confidence,Plugin,Title,Evidence,Impact,Recommendation |
        ConvertTo-Html -Fragment
}
else {
    '<p>No findings were generated.</p>'
}

$pluginTable = $assessment.Results |
    Select-Object Plugin,Version,Succeeded,DurationMs,Error |
    ConvertTo-Html -Fragment

$style = @'
body{font-family:Segoe UI,Arial,sans-serif;background:#f5f7fa;color:#1f2937;margin:0}
header{background:#0f2747;color:white;padding:28px 36px}
main{padding:28px 36px}
h1,h2{margin-top:0}.meta{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px 24px;background:white;padding:18px;border-radius:8px;margin-bottom:20px}
.cards{display:grid;grid-template-columns:repeat(5,minmax(120px,1fr));gap:12px;margin:20px 0}.card{background:white;border-left:5px solid #2563eb;padding:14px;border-radius:6px;box-shadow:0 1px 4px #0002}.card span{display:block;color:#6b7280}.card strong{font-size:26px}.critical{border-color:#7f1d1d}.high{border-color:#dc2626}.medium{border-color:#d97706}
table{width:100%;border-collapse:collapse;background:white;margin-bottom:24px;font-size:13px}th{background:#e5e7eb;text-align:left}th,td{padding:9px;border:1px solid #d1d5db;vertical-align:top}footer{padding:18px 36px;color:#6b7280}
@media(max-width:900px){.cards{grid-template-columns:1fr 1fr}.meta{grid-template-columns:1fr}}
'@

$body = @"
<header>
  <h1>Windows Enterprise Troubleshooting Report</h1>
  <p>Plugin-based diagnostic case and normalized finding summary</p>
</header>
<main>
  <section class='meta'>
    <div><strong>Case:</strong> $CaseId</div>
    <div><strong>Ticket:</strong> $TicketNumber</div>
    <div><strong>Customer:</strong> $Customer</div>
    <div><strong>Technician:</strong> $Technician</div>
    <div><strong>Target:</strong> $Target</div>
    <div><strong>Symptom:</strong> $Symptom</div>
  </section>
  $summaryCards
  <h2>Normalized findings</h2>
  $findingsTable
  <h2>Plugin execution</h2>
  $pluginTable
  <h2>Evidence package</h2>
  <p>Machine-readable evidence, findings, plugin results, and metadata are stored in this case folder.</p>
</main>
<footer>Generated $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss K') by Windows Enterprise Troubleshooting Framework v2.0.0</footer>
"@

$reportPath = Join-Path $casePath 'enterprise-case-report.html'
ConvertTo-Html -Title "Enterprise Troubleshooting - $CaseId" -Head "<style>$style</style>" -Body $body |
    Set-Content -Path $reportPath -Encoding UTF8

Write-Host "Assessment complete: $casePath" -ForegroundColor Green
Write-Host "Report: $reportPath" -ForegroundColor Green

if ($OpenReport) {
    Start-Process $reportPath
}

$assessment