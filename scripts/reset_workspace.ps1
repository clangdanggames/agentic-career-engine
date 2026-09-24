# Workspace Reset Utility
# Cleans test application dossiers and re-initializes ledgers to a pristine state.
# SAFETY GUARD: Requires explicit human confirmation to prevent accidental data loss.
param (
    [string]$ConfirmPhrase
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$workspaceRoot = (Resolve-Path "$PSScriptRoot\..").Path
$appsDir = Join-Path $workspaceRoot "applications"
$ledgerPath = Join-Path $appsDir "ledger.json"
$inboxJsonPath = Join-Path $appsDir "sourcing_inbox.json"
$inboxMdPath = Join-Path $appsDir "sourcing_inbox.md"

Write-Host "======================================================" -ForegroundColor Red
Write-Host "  [!] AGENTIC CAREER ENGINE - WORKSPACE RESET TOOL    " -ForegroundColor Red
Write-Host "======================================================" -ForegroundColor Red
Write-Host "WARNING: This utility is for maintenance and fresh installations." -ForegroundColor Yellow
Write-Host "Executing this will permanently delete all application folders and reset your ledgers." -ForegroundColor Yellow

$confirmed = $false

if ($ConfirmPhrase -eq "RESET-ALL-DATA") {
    $confirmed = $true
} else {
    Write-Host "`nTo prevent accidental loss of job applications, human confirmation is required." -ForegroundColor Yellow
    $userInput = Read-Host "Type 'RESET' (all caps) to permanently wipe application dossiers and reset ledgers"
    if ($userInput -eq "RESET") {
        $confirmed = $true
    }
}

if (-not $confirmed) {
    Write-Warning "Reset aborted. Confirmation phrase was not matched. No files were modified."
    exit 0
}

# Create safe backup of current ledgers before wiping
$archiveDir = Join-Path $appsDir ".archive"
if (-not (Test-Path $archiveDir)) {
    New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null
}
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

if (Test-Path $ledgerPath) {
    Copy-Item -Path $ledgerPath -Destination (Join-Path $archiveDir "ledger_$timestamp.bak.json") -Force
}
if (Test-Path $inboxJsonPath) {
    Copy-Item -Path $inboxJsonPath -Destination (Join-Path $archiveDir "sourcing_inbox_$timestamp.bak.json") -Force
}
Write-Host "`n[Safety] Pre-reset snapshot saved to applications/.archive/" -ForegroundColor DarkGray

Write-Host "`n[1/4] Scanning for application subdirectories to remove..." -ForegroundColor Cyan
$subDirs = Get-ChildItem -Path $appsDir -Directory | Where-Object { $_.Name -ne ".archive" }
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
            target = 150000
            minimum = 100000
            relocation_minimum = 180000
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
Write-Host "Demo showcase files in 'examples/' and configuration in 'workflows/' were preserved." -ForegroundColor Gray
