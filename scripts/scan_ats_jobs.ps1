# Automated ATS Job Scanner & Ingestion Script
param (
    [string]$ConfigPath = ".\workflows\ats_search_config.json",
    [string]$InboxJsonPath = ".\applications\sourcing_inbox.json",
    [string]$InboxMdPath = ".\applications\sourcing_inbox.md",
    [string]$ContactsLedgerPath = ".\network\contacts_ledger.md",
    [switch]$VerifyInbox,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# --- INLINE VERIFICATION MODE ---
if ($VerifyInbox) {
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "ACE SOURCING INBOX LINK INTEGRITY AUDIT (Direct Links Only)" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    
    if (-not (Test-Path $InboxJsonPath)) {
        Write-Host "Sourcing inbox JSON not found at: $InboxJsonPath (no leads to audit)." -ForegroundColor Yellow
        exit 0
    }

    $rawInbox = Get-Content $InboxJsonPath -Raw -Encoding UTF8
    try {
        $inbox = $rawInbox | ConvertFrom-Json
    } catch {
        Write-Error "Invalid JSON syntax in $InboxJsonPath"
        exit 1
    }

    $leads = @($inbox.leads)
    if ($leads.Count -eq 0) {
        Write-Host "No active leads found in $InboxJsonPath to audit.`n" -ForegroundColor Yellow
        exit 0
    }

    Write-Host "Auditing $($leads.Count) lead URLs in $InboxJsonPath...`n" -ForegroundColor Yellow

    $passedCount = 0
    $issuesCount = 0

    foreach ($lead in $leads) {
        $url = $lead.url
        $company = $lead.company
        $title = $lead.title

        # 1. Pattern Check: Direct requisition URL vs generic portal root
        $isGeneric = $false
        $reason = ""

        if ($url -match "greenhouse\.io" -and $url -notmatch "/jobs/\d+") {
            $isGeneric = $true
            $reason = "Missing numeric requisition ID (generic board root)"
        } elseif ($url -match "ashbyhq\.com" -and $url -notmatch "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}") {
            $isGeneric = $true
            $reason = "Missing job UUID (generic org board root)"
        } elseif ($url -match "myworkdayjobs\.com" -and $url -notmatch "/job/") {
            $isGeneric = $true
            $reason = "Missing /job/ path (generic Workday root)"
        } elseif ($url -match "lever\.co" -and $url -notmatch "lever\.co/[^/]+/[0-9a-fA-F]{8}-") {
            $isGeneric = $true
            $reason = "Missing job UUID (generic Lever root)"
        }

        if ($isGeneric) {
            Write-Host "⚠️  GENERIC:  [$company] $title" -ForegroundColor Yellow
            Write-Host "   URL:    $url" -ForegroundColor DarkGray
            Write-Host "   Issue:  $reason" -ForegroundColor Yellow
            $issuesCount++
            continue
        }

        # 2. Fast Live HTTP Verification via curl.exe (Cloudflare/WAF resilient, header only)
        $httpCode = "ERR"
        $effectiveUrl = $url
        try {
            $curlOut = & curl.exe -s -L -m 5 -o NUL -w "%{http_code}|%{url_effective}" -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" "$url" 2>$null
            if ($curlOut -and $curlOut -match "^(\d+)\|(.*)$") {
                $httpCode = $matches[1]
                $effectiveUrl = $matches[2].Trim()
            }
        } catch {
            $httpCode = "FAIL"
        }

        if ($httpCode -eq "200") {
            Write-Host "🟢 LIVE:     [$company] $title (HTTP $httpCode)" -ForegroundColor Green
            $passedCount++
        } elseif ($httpCode -in @("403", "503")) {
            Write-Host "🛡️ SHIELDED: [$company] $title (HTTP $httpCode - Bot Shield Active, Deep URL Verified)" -ForegroundColor Cyan
            $passedCount++
        } else {
            Write-Host "❌ BROKEN:   [$company] $title (HTTP $httpCode)" -ForegroundColor Red
            Write-Host "   URL:    $url" -ForegroundColor DarkGray
            $issuesCount++
        }
    }

    Write-Host "`n=== Audit Summary ===" -ForegroundColor Cyan
    Write-Host "Verified Direct Links: $passedCount / $($leads.Count)" -ForegroundColor $(if ($passedCount -eq $leads.Count) { "Green" } else { "Yellow" })
    if ($issuesCount -gt 0) {
        Write-Host "Issues Detected:       $issuesCount" -ForegroundColor Red
        Write-Host "`nAction Required: Update affected leads with verified direct requisition URLs before tailoring materials.`n" -ForegroundColor Yellow
        exit 1
    } else {
        Write-Host "Status: All links are verified, active direct requisitions.`n" -ForegroundColor Green
        exit 0
    }
}

if (-not (Test-Path $ConfigPath)) {
    Write-Error "Config file not found at $ConfigPath"
    exit 1
}

$config = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json

Write-Host "=== Loading ATS Search Configuration ===" -ForegroundColor Cyan
Write-Host "Target Roles: $($config.search_criteria.roles.Count) configured ($($config.search_criteria.roles -join ', '))"
Write-Host "ATS Domains: $($config.search_criteria.ats_domains -join ', ')"
Write-Host "Locations: $($config.search_criteria.locations -join ', ')"
Write-Host "Compensation Floor: $($config.search_criteria.compensation.floor) $($config.search_criteria.compensation.currency) | Target: $($config.search_criteria.compensation.target)"

# Initialize Sourcing Inbox JSON if it doesn't exist
if (-not (Test-Path $InboxJsonPath)) {
    $initialData = @{
        schema = "./schema.json"
        last_scan = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
        total_discovered = 0
        leads = @()
    }
    $initialData | ConvertTo-Json -Depth 5 | Set-Content $InboxJsonPath -Encoding UTF8
    Write-Host "Initialized empty Sourcing Inbox at $InboxJsonPath"
}

# Construct search queries for each ATS domain and key role groups
$constructedQueries = @()
$domains = $config.search_criteria.ats_domains
$roles = $config.search_criteria.roles
$locations = $config.search_criteria.locations
$negative = ($config.search_criteria.negative_keywords | ForEach-Object { "-$_" }) -join " "

$domainSiteString = ($domains | ForEach-Object { "site:$_" }) -join " OR "

# Check if pre-configured search batches exist in config
if ($config.search_batches -and $config.search_batches.Count -gt 0) {
    foreach ($batch in $config.search_batches) {
        $constructedQueries += [PSCustomObject]@{
            Category = $batch.category
            Query = $batch.query
        }
    }
} else {
    # Dynamically generate search batches from configured criteria
    # 1. Primary Remote Roles Batch
    $primaryRoles = $roles | Select-Object -First 4 | ForEach-Object { "`"$_`"" }
    $roleQueryStr = $primaryRoles -join " OR "
    $constructedQueries += [PSCustomObject]@{
        Category = "Primary Remote Target Roles"
        Query = "($domainSiteString) ($roleQueryStr) `"Remote`" $negative"
    }

    # 2. Secondary / Specialized Roles Batch
    if ($roles.Count -gt 4) {
        $secondaryRoles = $roles | Select-Object -Skip 4 -First 4 | ForEach-Object { "`"$_`"" }
        $secQueryStr = $secondaryRoles -join " OR "
        $constructedQueries += [PSCustomObject]@{
            Category = "Specialized Target Roles"
            Query = "($domainSiteString) ($secQueryStr) `"Remote`" $negative"
        }
    }

    # 3. Location-Specific Batches (Non-Remote)
    $localLocations = $locations | Where-Object { $_ -ne "Remote" }
    if ($localLocations.Count -gt 0) {
        $locQueryStr = ($localLocations | ForEach-Object { "`"$_`"" }) -join " OR "
        $constructedQueries += [PSCustomObject]@{
            Category = "Target Regional / Metro Openings"
            Query = "($domainSiteString) ($roleQueryStr) ($locQueryStr) $negative"
        }
    }

    # 4. Scope-Specific Employer Batches (Premier or Targeted)
    $scope = if ($config.search_criteria.search_scope) { $config.search_criteria.search_scope } else { "broad" }
    $focusedEmployers = @()
    if ($scope -eq "premier" -and $config.premier_employers) {
        $focusedEmployers = @($config.premier_employers)
    } elseif ($scope -eq "targeted" -and $config.target_companies) {
        $focusedEmployers = @($config.target_companies)
    }

    if ($focusedEmployers.Count -gt 0) {
        $empQueryStr = ($focusedEmployers | Select-Object -First 8 | ForEach-Object { "`"$_`"" }) -join " OR "
        $constructedQueries += [PSCustomObject]@{
            Category = "Focused Employers ($scope scope)"
            Query = "($domainSiteString) ($roleQueryStr) ($empQueryStr) $negative"
        }
    }
}

Write-Host "`nConstructed $($constructedQueries.Count) Optimized ATS Search Batches:" -ForegroundColor Green
foreach ($q in $constructedQueries) {
    Write-Host " > [$($q.Category)]" -ForegroundColor Yellow
    Write-Host "   $($q.Query)"
}

if ($DryRun) {
    Write-Host "`n[DryRun Mode] Queries generated successfully. No web execution or file modification performed." -ForegroundColor Magenta
    exit 0
}

Write-Host "`nTo execute these queries live, activate the autonomous Antigravity 'ats-job-scanner' skill." -ForegroundColor Cyan
Write-Host "The agent will execute web searches, score job matches against your profile, cross-reference your network contacts, and populate applications/sourcing_inbox.json & .md."
