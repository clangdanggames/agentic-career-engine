# Script to parse LinkedIn Connections.csv and analyze network against target companies
param (
    [string]$CsvPath = ".\network\Connections.csv",
    [string]$ConfigFile = ".\workflows\ats_search_config.json",
    [string[]]$TargetCompanies = @(),
    [int]$TopCompaniesCount = 30
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path $CsvPath)) {
    Write-Warning "Connections.csv not found at: $CsvPath"
    Write-Host "Export your LinkedIn connections via: LinkedIn Settings & Privacy -> Data Privacy -> Get a copy of your data -> Connections."
    Write-Host "Place the exported 'Connections.csv' into the 'network/' directory and rerun this script."
    exit 0
}

# Determine target companies/keywords to match against
$keywords = @()

if ($TargetCompanies.Count -gt 0) {
    $keywords = $TargetCompanies
} elseif (Test-Path $ConfigFile) {
    try {
        $cfg = Get-Content $ConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($cfg.target_companies) {
            $keywords = @($cfg.target_companies)
        }
    } catch {
        Write-Warning "Could not parse target_companies from $ConfigFile"
    }
}

# Fallback default target company keywords across major sectors if none specified
    $keywords = @(
        # Big Tech, Platforms & Cloud
        "Google", "Microsoft", "Amazon", "AWS", "Apple", "Meta", "Netflix", "NVIDIA", "Oracle", "Salesforce", "Adobe", "Cisco", "IBM", "SAP", "ServiceNow", "Workday",
        # High-Growth Platforms & Tech
        "Stripe", "Datadog", "Snowflake", "Palantir", "Uber", "Airbnb", "DoorDash", "Pinterest", "Spotify", "GitHub", "Cloudflare",
        # Healthcare, Biotech & Pharma
        "UnitedHealth", "Pfizer", "Johnson & Johnson", "Eli Lilly", "AbbVie", "Merck", "Thermo Fisher", "Moderna", "CVS Health", "Genentech", "Amgen",
        # Financial Services & Fintech
        "JPMorgan", "Chase", "Goldman Sachs", "Morgan Stanley", "Visa", "Mastercard", "American Express", "Fidelity", "Capital One", "Coinbase",
        # Strategy, Consulting & Professional Services
        "McKinsey", "Boston Consulting Group", "BCG", "Bain", "Deloitte", "PwC", "EY", "Ernst & Young", "KPMG", "Accenture",
        # Consumer, Retail & Media
        "Nike", "Target", "Walmart", "Disney", "Warner Bros", "Starbucks", "Procter & Gamble", "P&G", "PepsiCo", "Costco",
        # Gaming & Interactive
        "Epic Games", "Riot Games", "Roblox", "Unity", "Electronic Arts", "EA", "Sony", "PlayStation", "2K", "Valve"
    )
}

# Read lines and skip initial header notes until the CSV header
$allLines = Get-Content -Path $CsvPath -Encoding UTF8
$headerIndex = -1
for ($i = 0; $i -lt $allLines.Count; $i++) {
    if ($allLines[$i].StartsWith("First Name,Last Name")) {
        $headerIndex = $i
        break
    }
}

if ($headerIndex -eq -1) {
    Write-Error "Valid LinkedIn CSV header ('First Name,Last Name...') was not found in $CsvPath"
    exit 1
}

$csvContent = $allLines[$headerIndex..($allLines.Count - 1)] -join "`r`n"
$connections = @(ConvertFrom-Csv -InputObject $csvContent)

Write-Host "=== LinkedIn Network Analysis ===" -ForegroundColor Cyan
Write-Host "Total Connections Found: $($connections.Count)"

# Group by Company
$topCompanies = $connections | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Company) } | 
    Group-Object Company | Sort-Object Count -Descending | Select-Object -First $TopCompaniesCount

Write-Host "`n=== Top $TopCompaniesCount Companies in Network ===" -ForegroundColor Yellow
$topCompanies | ForEach-Object {
    Write-Host ("{0,-35} : {1,3} connections" -f $_.Name, $_.Count)
}

# Find connections at target companies
$matchedConnections = @()

foreach ($conn in $connections) {
    $comp = $conn.Company
    if ([string]::IsNullOrWhiteSpace($comp)) { continue }
    
    foreach ($kw in $keywords) {
        if ($comp -like "*$kw*") {
            $matchedConnections += [PSCustomObject]@{
                Name = "$($conn.'First Name') $($conn.'Last Name')".Trim()
                Company = $conn.Company
                Position = $conn.Position
                URL = $conn.URL
                ConnectedOn = $conn.'Connected On'
            }
            break
        }
    }
}

Write-Host "`n=== Matched Connections in Target Companies ($($matchedConnections.Count)) ===" -ForegroundColor Green
$matchedConnections | Sort-Object Company, Position | ForEach-Object {
    Write-Host "$($_.Company) | $($_.Name) | $($_.Position) | $($_.URL)"
}

Write-Host "`nAnalysis complete. You can log relevant 1st-degree contacts into network/contacts_ledger.md for warm referral routing." -ForegroundColor Gray
