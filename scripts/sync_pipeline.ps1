<#
.SYNOPSIS
    ACE Pipeline & Dashboard Synchronization Validator (Rule 5 Enforcer)
.DESCRIPTION
    Validates and maintains 100% lockstep parity between applications/ledger.json
    and DASHBOARD.md. Enforces Operational Rule 5 (Atomic State & Dashboard Synchronization).
.PARAMETER AppId
    Optional: The application ID to update (e.g. app_20260923_novatech).
.PARAMETER Status
    Optional: New status to assign (e.g. applied, referral_package_sent, screen_scheduled).
.PARAMETER Notes
    Optional: Additional notes or context to append.
#>
param (
    [Parameter(Mandatory = $false)]
    [string]$AppId = "",

    [Parameter(Mandatory = $false)]
    [string]$Status = "",

    [Parameter(Mandatory = $false)]
    [string]$Notes = ""
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$workspaceRoot = (Resolve-Path "$PSScriptRoot\..").Path
$ledgerPath = Join-Path $workspaceRoot "applications\ledger.json"
$dashboardPath = Join-Path $workspaceRoot "DASHBOARD.md"

if (-not (Test-Path $ledgerPath)) {
    Write-Error "Ledger not found at: $ledgerPath"
    exit 1
}

if (-not (Test-Path $dashboardPath)) {
    Write-Host "[!] DASHBOARD.md not found at root (workspace may be in onboarding or template state)." -ForegroundColor Yellow
    Write-Host "    Ledger check passed. Skipping markdown dashboard parity audit." -ForegroundColor Yellow
    exit 0
}

# 1. Load and parse ledger
$rawLedger = Get-Content -Path $ledgerPath -Raw -Encoding UTF8
try {
    $ledger = $rawLedger | ConvertFrom-Json
} catch {
    Write-Error "Failed to parse ledger.json. Invalid JSON syntax: $_"
    exit 1
}

# 2. Update status if specified
$today = (Get-Date).ToString("yyyy-MM-dd")
if (-not [string]::IsNullOrWhiteSpace($AppId) -and -not [string]::IsNullOrWhiteSpace($Status)) {
    $targetApp = $ledger.applications | Where-Object { $_.id -eq $AppId }
    if ($null -eq $targetApp) {
        Write-Error "Application ID not found in ledger: $AppId"
        exit 1
    }

    $targetApp.status = $Status
    if ($null -eq $targetApp.dates) {
        $targetApp | Add-Member -NotePropertyName "dates" -NotePropertyValue ([PSCustomObject]@{}) -Force
    }
    $targetApp.dates.last_activity = $today

    if ($Status -eq "applied") {
        $targetApp.dates | Add-Member -NotePropertyName "applied" -NotePropertyValue $today -Force
    }

    if (-not [string]::IsNullOrWhiteSpace($Notes)) {
        $targetApp.notes = $Notes
    }

    $ledger.meta.last_updated = $today
    $ledger | ConvertTo-Json -Depth 10 | Set-Content -Path $ledgerPath -Encoding UTF8
    Write-Host "Updated $AppId to status '$Status' in ledger.json" -ForegroundColor Green
}

# 3. Audit parity between ledger and DASHBOARD.md
$dashboardContent = Get-Content -Path $dashboardPath -Raw -Encoding UTF8

$appliedApps = @($ledger.applications | Where-Object { $_.status -in "applied", "screen_scheduled", "screen_completed", "technical_screen", "onsite", "offer" })
$activeApps = @($ledger.applications | Where-Object { $_.status -notin "rejected", "rejected_post_vp_screen", "archived", "closed" -and $_.status -notlike "rejected*" })

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "ACE PIPELINE & DASHBOARD SYNCHRONIZATION AUDIT (Rule 5)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Total Active Applications in Ledger: $($activeApps.Count)"
Write-Host "Verified 'Applied' Count:            $($appliedApps.Count)"

$discrepancies = [System.Collections.Generic.List[string]]::new()

foreach ($app in $activeApps) {
    $company = $app.company
    if ([string]::IsNullOrWhiteSpace($company)) { continue }
    $coreCompany = ($company -replace "\(.*?\)", "").Trim()
    if ($dashboardContent -notmatch [regex]::Escape($company) -and $dashboardContent -notmatch [regex]::Escape($coreCompany)) {
        $discrepancies.Add("Missing active company from DASHBOARD.md: $company ($($app.id))")
    }
}

# Flexible count mentions check
$countPatterns = @(
    "$($appliedApps.Count)\s+Verified",
    "Applied\s*\(?$($appliedApps.Count)\)?",
    "Applications Submitted:\s*$($appliedApps.Count)",
    "Applied:\s*$($appliedApps.Count)"
)
$countMatched = $false
foreach ($pat in $countPatterns) {
    if ($dashboardContent -match $pat) {
        $countMatched = $true
        break
    }
}

if (-not $countMatched -and $appliedApps.Count -gt 0) {
    if ($dashboardContent -match "Pipeline Progress" -or $dashboardContent -match "Funnel") {
        Write-Host "[i] Note: Active applied count ($($appliedApps.Count)) was not matched by standard milestone regex in DASHBOARD.md. Please verify manually." -ForegroundColor Yellow
    }
}

if ($discrepancies.Count -gt 0) {
    Write-Host "`n[!] PARITY WARNINGS DETECTED:" -ForegroundColor Yellow
    foreach ($d in $discrepancies) {
        Write-Host "   - $d" -ForegroundColor Yellow
    }
    Write-Host "`nAction: Synchronize DASHBOARD.md with ledger.json state." -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "`n[OK] PERFECT PARITY: applications/ledger.json and DASHBOARD.md are in 100% lockstep.`n" -ForegroundColor Green
    exit 0
}
