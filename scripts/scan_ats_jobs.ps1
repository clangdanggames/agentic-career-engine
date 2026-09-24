# Automated ATS Job Scanner & Ingestion Script
param (
    [string]$ConfigPath = ".\workflows\ats_search_config.json",
    [string]$InboxJsonPath = ".\applications\sourcing_inbox.json",
    [string]$InboxMdPath = ".\applications\sourcing_inbox.md",
    [string]$ContactsLedgerPath = ".\network\contacts_ledger.md",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

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
