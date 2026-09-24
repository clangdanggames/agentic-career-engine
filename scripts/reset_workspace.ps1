# Workspace Reset Utility
# Cleans test application dossiers and re-initializes ledgers to a pristine state.
param (
    [switch]$Force
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$workspaceRoot = (Resolve-Path "$PSScriptRoot\..").Path
$appsDir = Join-Path $workspaceRoot "applications"
$ledgerPath = Join-Path $appsDir "ledger.json"
$inboxJsonPath = Join-Path $appsDir "sourcing_inbox.json"
$inboxMdPath = Join-Path $appsDir "sourcing_inbox.md"

Write-Host "======================================================" -ForegroundColor Yellow
Write-Host "  Agentic Career Engine (ACE) - Workspace Reset Tool  " -ForegroundColor Yellow
Write-Host "======================================================" -ForegroundColor Yellow

if (-not $Force) {
    $confirmation = Read-Host "This will delete all application folders inside 'applications/' and reset your tracking ledgers to an empty state. Proceed? (y/N)"
    if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
        Write-Host "Operation cancelled. No changes made." -ForegroundColor Cyan
        exit 0
    }
}

Write-Host "`n[1/4] Scanning for application subdirectories to remove..." -ForegroundColor Cyan
$subDirs = Get-ChildItem -Path $appsDir -Directory
$removedCount = 0
foreach ($dir in $subDirs) {
    Write-Host "  Removing application dossier: $($dir.Name)" -ForegroundColor DarkGray
    Remove-Item -Path $dir.FullName -Recurse -Force
    $removedCount++
}
Write-Host "  Removed $removedCount application folder(s)." -ForegroundColor Green

Write-Host "`n[2/4] Resetting applications/ledger.json..." -ForegroundColor Cyan
$blankLedger = @{
    "`$schema" = "./schema.json"
    meta = @{
        candidate = "Candidate Name"
        last_updated = (Get-Date -Format "yyyy-MM-dd")
        compensation_target = @{
            target = 160000
            minimum = 120000
            relocation_minimum = 190000
        }
        notes = "Main ledger tracking all active, submitted, and archived career applications."
    }
    applications = @()
}
$blankLedger | ConvertTo-Json -Depth 5 | Set-Content $ledgerPath -Encoding UTF8
Write-Host "  applications/ledger.json reset to empty state." -ForegroundColor Green

Write-Host "`n[3/4] Resetting applications/sourcing_inbox.json..." -ForegroundColor Cyan
$blankInbox = @{
    "`$schema" = "./schema.json"
    meta = @{
        title = "Job Sourcing Lead Inbox"
        last_scanned = $null
        total_leads = 0
        active_leads = 0
    }
    leads = @()
}
$blankInbox | ConvertTo-Json -Depth 5 | Set-Content $inboxJsonPath -Encoding UTF8
Write-Host "  applications/sourcing_inbox.json reset to empty state." -ForegroundColor Green

Write-Host "`n[4/4] Resetting applications/sourcing_inbox.md..." -ForegroundColor Cyan
$blankInboxLines = @(
    "# Job Sourcing Inbox & Opportunity Tracker",
    "",
    "> **Last Scanned**: Never | **Total Qualified Leads**: 0",
    "> **Search Config**: [`workflows/ats_search_config.json`](file:///c:/Code/ACE/workflows/ats_search_config.json) | **Scoring Rubric**: [100-Point Fit Rubric](file:///c:/Code/ACE/.agents/skills/ats-job-scanner/references/scoring_rubric.md)",
    "",
    "---",
    "",
    "## High-Priority Qualified Opportunities (Fit Score >= 75%)",
    "",
    "| Fit Score | Likelihood | Role Title | Company | Location | Compensation | Warm Contact / Referral | Recommended Action / Status |",
    "| :---: | :---: | :--- | :--- | :--- | :--- | :--- | :--- |",
    "| *No leads yet* | - | *Run an ATS scan to populate* | - | - | - | - | - |",
    "",
    "---",
    "",
    "## Detailed Lead Analysis",
    "",
    "*Discovered leads will be analyzed here with scoring breakdowns and warm contact recommendations.*"
)
$blankInboxMd = $blankInboxLines -join "`r`n"
Set-Content -Path $inboxMdPath -Value $blankInboxMd -Encoding UTF8
Write-Host "  applications/sourcing_inbox.md reset to empty state." -ForegroundColor Green

Write-Host "`nSUCCESS: Workspace has been reset cleanly to factory defaults!" -ForegroundColor Green
Write-Host "Your demo files in 'examples/' and configuration in 'workflows/' remain intact." -ForegroundColor Gray
