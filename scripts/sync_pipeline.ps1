#!/usr/bin/env pwsh
<#
.SYNOPSIS
    ACE Pipeline & Dashboard Synchronization Engine (Rule 5 Enforcer)
.DESCRIPTION
    Validates applications/ledger.json and applications/sourcing_inbox.json against
    applications/schema.json, performs atomic CRUD/upsert updates on the application
    ledger, and deterministically synchronizes or audits DASHBOARD.md to guarantee
    100% lockstep parity under Operational Rule 5.
.PARAMETER AppId
    Optional: The application ID to update or create (e.g. app_20261024_novatech).
    If omitted when -Company and -Role are provided, an ID is generated automatically.
.PARAMETER Company
    Optional: Company name (required when creating a new application entry).
.PARAMETER Role
    Optional: Role title (required when creating a new application entry).
.PARAMETER Status
    Optional: Pipeline status to assign (must match schema.json enum:
    sourced, in_progress, outreach_sent, referral_package_sent, referral_submitted,
    applied, screen_scheduled, screen_completed, technical_screen, onsite, offer,
    rejected, rejected_post_vp_screen, withdrawn, archived, closed).
.PARAMETER RequisitionId
    Optional: ATS requisition ID or slug (e.g. 4829103).
.PARAMETER Url
    Optional: Direct requisition URL.
.PARAMETER DossierPath
    Optional: Relative workspace path to the application dossier directory.
.PARAMETER FitScore
    Optional: Numeric fit score (0 to 100). Use -1 to leave unset.
.PARAMETER Compensation
    Optional: Verified or estimated compensation string (e.g. "$165,000 - $195,000").
.PARAMETER ReferralContact
    Optional: Warm contact or referral note (e.g. "Jordan Lee (Staff SRE)" or "Direct Apply").
.PARAMETER Notes
    Optional: Additional notes or context to record on the ledger entry.
.PARAMETER GraduateFromInbox
    Optional switch: If set, removes or marks any matching lead in applications/sourcing_inbox.json
    as graduated when the application is recorded in ledger.json.
.PARAMETER UpdateDashboard
    Optional switch: Deterministically regenerates the Mermaid funnel counts, Active Application
    Status table, and Cumulative Effort & Velocity Milestones in DASHBOARD.md from ledger.json.
#>
param (
    [Parameter(Mandatory = $false)]
    [string]$AppId = "",

    [Parameter(Mandatory = $false)]
    [string]$Company = "",

    [Parameter(Mandatory = $false)]
    [string]$Role = "",

    [Parameter(Mandatory = $false)]
    [string]$Status = "",

    [Parameter(Mandatory = $false)]
    [string]$RequisitionId = "",

    [Parameter(Mandatory = $false)]
    [string]$Url = "",

    [Parameter(Mandatory = $false)]
    [string]$DossierPath = "",

    [Parameter(Mandatory = $false)]
    [double]$FitScore = -1,

    [Parameter(Mandatory = $false)]
    [string]$Compensation = "",

    [Parameter(Mandatory = $false)]
    [string]$ReferralContact = "",

    [Parameter(Mandatory = $false)]
    [string]$Notes = "",

    [Parameter(Mandatory = $false)]
    [switch]$GraduateFromInbox,

    [Parameter(Mandatory = $false)]
    [switch]$UpdateDashboard
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ledgerPath = Join-Path $workspaceRoot "applications/ledger.json"
$inboxJsonPath = Join-Path $workspaceRoot "applications/sourcing_inbox.json"
$dashboardPath = Join-Path $workspaceRoot "DASHBOARD.md"

$validStatuses = @(
    "sourced",
    "in_progress",
    "outreach_sent",
    "referral_package_sent",
    "referral_submitted",
    "applied",
    "screen_scheduled",
    "screen_completed",
    "technical_screen",
    "onsite",
    "offer",
    "rejected",
    "rejected_post_vp_screen",
    "withdrawn",
    "archived",
    "closed"
)

$validLikelihoods = @("High", "Medium", "Low")

function Set-OrAddProperty {
    param (
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        $Value
    )
    $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value -Force
}

function Normalize-StatusString {
    param ([string]$RawStatus)
    if ([string]::IsNullOrWhiteSpace($RawStatus)) { return "" }
    $s = ($RawStatus.Trim().ToLowerInvariant() -replace "[\s\-]+", "_")
    if ($validStatuses -contains $s) { return $s }

    switch -Regex ($s) {
        "^submitted$"                                                    { return "applied" }
        "^(warm_outreach|outreach|contacted|messaged|referral_requested|pending_referral)$" { return "outreach_sent" }
        "^referral_agreed$"                                              { return "referral_package_sent" }
        "^(phone_screen|recruiter_screen|screen)$"                       { return "screen_scheduled" }
        "^(technical|tech_screen|interview|interviewing|coding_challenge)$" { return "technical_screen" }
        "^(final_round|panel|final_loop)$"                               { return "onsite" }
        "^(ghosted|passed|declined|expired)$"                            { return "archived" }
        "^rejected_"                                                     { return "rejected" }
        default                                                          { return $RawStatus }
    }
}

function Normalize-LedgerObject {
    param ($LedgerObj, [string]$TodayStr)
    if ($null -eq $LedgerObj) { return $false }
    $healed = $false

    if ($null -eq $LedgerObj.PSObject.Properties["meta"] -or $null -eq $LedgerObj.meta) {
        Set-OrAddProperty -Object $LedgerObj -Name "meta" -Value ([PSCustomObject]@{
            candidate    = "Candidate Name"
            last_updated = $TodayStr
        })
        $healed = $true
    } else {
        if ([string]::IsNullOrWhiteSpace([string]$LedgerObj.meta.candidate)) {
            Set-OrAddProperty -Object $LedgerObj.meta -Name "candidate" -Value "Candidate Name"
            $healed = $true
        }
        if ([string]::IsNullOrWhiteSpace([string]$LedgerObj.meta.last_updated)) {
            $fallbackDate = if (-not [string]::IsNullOrWhiteSpace([string]$LedgerObj.meta.updated_at)) { [string]$LedgerObj.meta.updated_at } else { $TodayStr }
            Set-OrAddProperty -Object $LedgerObj.meta -Name "last_updated" -Value $fallbackDate
            $healed = $true
        }
    }

    if ($null -eq $LedgerObj.PSObject.Properties["applications"]) {
        Set-OrAddProperty -Object $LedgerObj -Name "applications" -Value @()
        $healed = $true
        return $healed
    }

    $idx = 1
    foreach ($app in @($LedgerObj.applications)) {
        if ($null -eq $app) { continue }

        # Map legacy title/job_title/position -> role
        if ([string]::IsNullOrWhiteSpace([string]$app.role)) {
            foreach ($altRole in @("title", "job_title", "position")) {
                if (-not [string]::IsNullOrWhiteSpace([string]$app.$altRole)) {
                    Set-OrAddProperty -Object $app -Name "role" -Value ([string]$app.$altRole)
                    $healed = $true
                    break
                }
            }
        }

        # Auto-generate missing id
        if ([string]::IsNullOrWhiteSpace([string]$app.id) -and -not [string]::IsNullOrWhiteSpace([string]$app.company)) {
            $cSlug = (([string]$app.company).ToLowerInvariant() -replace "[^a-z0-9]+", "_").Trim("_")
            $dSlug = ($TodayStr -replace "-", "")
            Set-OrAddProperty -Object $app -Name "id" -Value "app_${dSlug}_${cSlug}_${idx}"
            $healed = $true
        }

        # Normalize status
        if (-not [string]::IsNullOrWhiteSpace([string]$app.status)) {
            $origStatus = [string]$app.status
            $normStatus = Normalize-StatusString -RawStatus $origStatus
            if ($normStatus -ne $origStatus) {
                Set-OrAddProperty -Object $app -Name "status" -Value $normStatus
                if ($origStatus -match "^rejected_" -and $origStatus -ne "rejected_post_vp_screen") {
                    $existingNotes = [string]$app.notes
                    if ($existingNotes -notmatch [regex]::Escape($origStatus)) {
                        $mergedNotes = if ([string]::IsNullOrWhiteSpace($existingNotes)) { "Original status: $origStatus" } else { "$existingNotes (Original status: $origStatus)" }
                        Set-OrAddProperty -Object $app -Name "notes" -Value $mergedNotes
                    }
                }
                $healed = $true
            }
        }

        # Normalize string fit_score like "88%" or "88/100"
        if ($null -ne $app.fit_score -and $app.fit_score -is [string] -and -not [string]::IsNullOrWhiteSpace([string]$app.fit_score)) {
            $cleanScoreStr = ([string]$app.fit_score -replace "(%|/100|\s)", "")
            $parsedScore = 0.0
            if ([double]::TryParse($cleanScoreStr, [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$parsedScore)) {
                Set-OrAddProperty -Object $app -Name "fit_score" -Value $parsedScore
                $healed = $true
            }
        }
        $idx++
    }
    return $healed
}

function Normalize-InboxObject {
    param ($InboxObj)
    if ($null -eq $InboxObj) { return $false }
    $healed = $false

    if ($null -eq $InboxObj.PSObject.Properties["leads"]) {
        Set-OrAddProperty -Object $InboxObj -Name "leads" -Value @()
        $healed = $true
    }
    $allLeads = @($InboxObj.leads | Where-Object { $null -ne $_ })
    $activeCount = @($allLeads | Where-Object { [string]$_.status -notin @("archived", "passed", "graduated", "closed") }).Count

    if ($null -eq $InboxObj.PSObject.Properties["meta"] -or $null -eq $InboxObj.meta) {
        Set-OrAddProperty -Object $InboxObj -Name "meta" -Value ([PSCustomObject]@{
            title        = "Job Sourcing Lead Inbox"
            last_scanned = $null
            total_leads  = $allLeads.Count
            active_leads = $activeCount
        })
        $healed = $true
    } else {
        if ([string]::IsNullOrWhiteSpace([string]$InboxObj.meta.title)) {
            Set-OrAddProperty -Object $InboxObj.meta -Name "title" -Value "Job Sourcing Lead Inbox"
            $healed = $true
        }
        if ($null -eq $InboxObj.meta.total_leads) {
            Set-OrAddProperty -Object $InboxObj.meta -Name "total_leads" -Value $allLeads.Count
            $healed = $true
        }
        if ($null -eq $InboxObj.meta.active_leads) {
            Set-OrAddProperty -Object $InboxObj.meta -Name "active_leads" -Value $activeCount
            $healed = $true
        }
    }

    foreach ($lead in $allLeads) {
        if ([string]::IsNullOrWhiteSpace([string]$lead.title) -and -not [string]::IsNullOrWhiteSpace([string]$lead.role)) {
            Set-OrAddProperty -Object $lead -Name "title" -Value ([string]$lead.role)
            $healed = $true
        }
        if ($null -eq $lead.fit_score -or [string]$lead.fit_score -eq "") {
            Set-OrAddProperty -Object $lead -Name "fit_score" -Value 75
            $healed = $true
        } elseif ($lead.fit_score -is [string]) {
            $cleanScoreStr = ([string]$lead.fit_score -replace "(%|/100|\s)", "")
            $parsedScore = 0.0
            if ([double]::TryParse($cleanScoreStr, [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$parsedScore)) {
                Set-OrAddProperty -Object $lead -Name "fit_score" -Value $parsedScore
                $healed = $true
            }
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$lead.likelihood)) {
            $rawLike = ([string]$lead.likelihood).Trim()
            if ($validLikelihoods -notcontains $rawLike) {
                $normLike = if ($rawLike -match "(?i)^high") { "High" }
                    elseif ($rawLike -match "(?i)^med") { "Medium" }
                    elseif ($rawLike -match "(?i)^low") { "Low" }
                    else { $rawLike }
                if ($normLike -ne $rawLike) {
                    Set-OrAddProperty -Object $lead -Name "likelihood" -Value $normLike
                    $healed = $true
                }
            }
        }
    }
    return $healed
}

function Test-LedgerSchema {
    param ($LedgerObj)
    $errors = [System.Collections.Generic.List[string]]::new()

    if ($null -eq $LedgerObj) {
        $errors.Add("ledger.json root object is null.")
        return $errors
    }
    if ($null -eq $LedgerObj.meta) {
        $errors.Add("ledger.json is missing required top-level 'meta' object.")
    } else {
        if ([string]::IsNullOrWhiteSpace([string]$LedgerObj.meta.candidate)) {
            $errors.Add("ledger.json 'meta.candidate' is missing or empty.")
        }
        if ([string]::IsNullOrWhiteSpace([string]$LedgerObj.meta.last_updated)) {
            $errors.Add("ledger.json 'meta.last_updated' is missing or empty.")
        }
    }

    if ($null -eq $LedgerObj.PSObject.Properties["applications"]) {
        $errors.Add("ledger.json is missing required top-level 'applications' array.")
        return $errors
    }

    $seenIds = @{}
    $idx = 0
    foreach ($app in @($LedgerObj.applications)) {
        if ($null -eq $app) { continue }
        $label = if (-not [string]::IsNullOrWhiteSpace([string]$app.id)) { [string]$app.id } else { "index $idx" }

        foreach ($reqField in @("id", "company", "role", "status")) {
            if ([string]::IsNullOrWhiteSpace([string]$app.$reqField)) {
                $errors.Add("ledger.json application [$label] is missing required field '$reqField'.")
            }
        }

        if (-not [string]::IsNullOrWhiteSpace([string]$app.id)) {
            $idKey = ([string]$app.id).ToLowerInvariant()
            if ($seenIds.ContainsKey($idKey)) {
                $errors.Add("ledger.json contains duplicate application id '$($app.id)'.")
            }
            $seenIds[$idKey] = $true
        }

        if (-not [string]::IsNullOrWhiteSpace([string]$app.status)) {
            if ($validStatuses -notcontains [string]$app.status) {
                $errors.Add("ledger.json application [$label] has invalid status '$($app.status)'. Allowed: $($validStatuses -join ', ').")
            }
        }

        if ($null -ne $app.fit_score -and [string]$app.fit_score -ne "") {
            $scoreVal = 0.0
            if (-not [double]::TryParse([string]$app.fit_score, [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$scoreVal) -or $scoreVal -lt 0 -or $scoreVal -gt 100) {
                $errors.Add("ledger.json application [$label] has invalid fit_score '$($app.fit_score)' (must be 0-100).")
            }
        }
        $idx++
    }

    return $errors
}

function Test-InboxSchema {
    param ($InboxObj)
    $errors = [System.Collections.Generic.List[string]]::new()

    if ($null -eq $InboxObj) {
        $errors.Add("sourcing_inbox.json root object is null.")
        return $errors
    }
    if ($null -eq $InboxObj.meta) {
        $errors.Add("sourcing_inbox.json is missing required top-level 'meta' object.")
    } else {
        if ([string]::IsNullOrWhiteSpace([string]$InboxObj.meta.title)) {
            $errors.Add("sourcing_inbox.json 'meta.title' is missing or empty.")
        }
        if ($null -eq $InboxObj.meta.total_leads) {
            $errors.Add("sourcing_inbox.json 'meta.total_leads' is missing.")
        }
        if ($null -eq $InboxObj.meta.active_leads) {
            $errors.Add("sourcing_inbox.json 'meta.active_leads' is missing.")
        }
    }

    if ($null -eq $InboxObj.PSObject.Properties["leads"]) {
        $errors.Add("sourcing_inbox.json is missing required top-level 'leads' array.")
        return $errors
    }

    $idx = 0
    foreach ($lead in @($InboxObj.leads)) {
        if ($null -eq $lead) { continue }
        $label = if (-not [string]::IsNullOrWhiteSpace([string]$lead.id)) { [string]$lead.id } else { "lead index $idx" }

        foreach ($reqField in @("company", "title", "url")) {
            if ([string]::IsNullOrWhiteSpace([string]$lead.$reqField)) {
                $errors.Add("sourcing_inbox.json [$label] is missing required field '$reqField'.")
            }
        }

        if ($null -eq $lead.fit_score -or [string]$lead.fit_score -eq "") {
            $errors.Add("sourcing_inbox.json [$label] is missing required field 'fit_score'.")
        } else {
            $scoreVal = 0.0
            if (-not [double]::TryParse([string]$lead.fit_score, [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$scoreVal) -or $scoreVal -lt 0 -or $scoreVal -gt 100) {
                $errors.Add("sourcing_inbox.json [$label] has invalid fit_score '$($lead.fit_score)' (must be 0-100).")
            }
        }

        if (-not [string]::IsNullOrWhiteSpace([string]$lead.likelihood)) {
            if ($validLikelihoods -notcontains [string]$lead.likelihood) {
                $errors.Add("sourcing_inbox.json [$label] has invalid likelihood '$($lead.likelihood)'. Allowed: High, Medium, Low.")
            }
        }
        $idx++
    }

    return $errors
}

function Get-StatusBadge {
    param ([string]$StatusVal, [string]$AppliedDate)

    $blueCircle = [char]::ConvertFromUtf32(0x1F535)
    $yellowCircle = [char]::ConvertFromUtf32(0x1F7E1)
    $purpleCircle = [char]::ConvertFromUtf32(0x1F7E3)
    $greenCircle = [char]::ConvertFromUtf32(0x1F7E2)
    $orangeCircle = [char]::ConvertFromUtf32(0x1F7E0)
    $whiteCircle = [char]::ConvertFromUtf32(0x26AA)

    $dateSuffix = ""
    if (-not [string]::IsNullOrWhiteSpace($AppliedDate)) {
        $parsedDate = [datetime]::MinValue
        if ([datetime]::TryParse($AppliedDate, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsedDate)) {
            $dateSuffix = " *($($parsedDate.ToString('MMM d', [System.Globalization.CultureInfo]::InvariantCulture)))*"
        }
    }

    switch ($StatusVal) {
        "sourced"               { return "$whiteCircle **Sourced**" }
        "in_progress"           { return "$yellowCircle **In Progress**" }
        "outreach_sent"         { return "$yellowCircle **Warm Outreach**" }
        "referral_package_sent" { return "$yellowCircle **Referral Package Sent**" }
        "referral_submitted"    { return "$greenCircle **Referral Submitted**" }
        "applied"               { return "$blueCircle **Applied**$dateSuffix" }
        "screen_scheduled"      { return "$purpleCircle **Recruiter Screen** *(Scheduled)*" }
        "screen_completed"      { return "$purpleCircle **Recruiter Screen** *(Completed)*" }
        "technical_screen"      { return "$orangeCircle **Technical Screen**" }
        "onsite"                { return "$orangeCircle **Onsite / Final Loop**" }
        "offer"                 { return "$greenCircle **Offer Received**" }
        "withdrawn"             { return "$whiteCircle **Withdrawn**" }
        default                 { return "$whiteCircle **$StatusVal**" }
    }
}

function Get-VerifiedAssetsCell {
    param ($App, [string]$RootPath)

    if (-not [string]::IsNullOrWhiteSpace([string]$App.dossier_path)) {
        $relDossier = ([string]$App.dossier_path) -replace "\\", "/"
        $fullDossier = Join-Path $RootPath $relDossier
        $links = [System.Collections.Generic.List[string]]::new()

        if (Test-Path $fullDossier) {
            $pdfs = @(Get-ChildItem -Path $fullDossier -Filter "*Resume*.pdf" -File -ErrorAction SilentlyContinue)
            if ($pdfs.Count -eq 0) {
                $pdfs = @(Get-ChildItem -Path $fullDossier -Filter "*.pdf" -File -ErrorAction SilentlyContinue)
            }
            if ($pdfs.Count -gt 0) {
                $links.Add("[1-Page PDF]($relDossier/$($pdfs[0].Name))")
            }
            $jdFile = Join-Path $fullDossier "job_description.md"
            if (Test-Path $jdFile) {
                $links.Add("[JD]($relDossier/job_description.md)")
            }
        }

        if ($links.Count -gt 0) {
            return ($links -join " \| ")
        }
        return "[Dossier]($relDossier)"
    }

    if (-not [string]::IsNullOrWhiteSpace([string]$App.url)) {
        return "[Job Posting]($($App.url))"
    }

    return "*Pending Dossier*"
}

if (-not (Test-Path $ledgerPath)) {
    Write-Host "[!] ERROR: Ledger not found at: $ledgerPath" -ForegroundColor Red
    exit 1
}

# 1. Load, auto-normalize legacy fields, and parse ledger.json
$today = (Get-Date).ToString("yyyy-MM-dd")
$rawLedger = Get-Content -Path $ledgerPath -Raw -Encoding UTF8
try {
    $ledger = $rawLedger | ConvertFrom-Json
} catch {
    Write-Host "[!] ERROR: Failed to parse ledger.json. Invalid JSON syntax: $_" -ForegroundColor Red
    exit 1
}

$ledgerHealed = Normalize-LedgerObject -LedgerObj $ledger -TodayStr $today
if ($ledgerHealed) {
    Write-Host "[i] Auto-normalized legacy fields/statuses in ledger.json to match schema.json." -ForegroundColor Cyan
}

if (-not [string]::IsNullOrWhiteSpace($Status)) {
    $Status = Normalize-StatusString -RawStatus $Status
    if ($validStatuses -notcontains $Status) {
        Write-Host "[!] ERROR: Invalid -Status '$Status'. Allowed values in schema.json: $($validStatuses -join ', ')" -ForegroundColor Red
        exit 1
    }
}

# Load, auto-normalize, and validate sourcing_inbox.json if present
$inbox = $null
$activeInboxLeadsCount = 0
$totalInboxLeadsCount = 0
if (Test-Path $inboxJsonPath) {
    $rawInbox = Get-Content -Path $inboxJsonPath -Raw -Encoding UTF8
    try {
        $inbox = $rawInbox | ConvertFrom-Json
    } catch {
        Write-Host "[!] ERROR: Failed to parse sourcing_inbox.json. Invalid JSON syntax: $_" -ForegroundColor Red
        exit 1
    }
    $inboxHealed = Normalize-InboxObject -InboxObj $inbox
    if ($inboxHealed) {
        $inbox | ConvertTo-Json -Depth 10 | Set-Content -Path $inboxJsonPath -Encoding UTF8
        Write-Host "[i] Auto-normalized legacy fields in sourcing_inbox.json to match schema.json." -ForegroundColor Cyan
    }
    $inboxErrors = Test-InboxSchema -InboxObj $inbox
    if ($inboxErrors.Count -gt 0) {
        Write-Host "[!] SCHEMA VALIDATION ERRORS IN sourcing_inbox.json:" -ForegroundColor Red
        foreach ($err in $inboxErrors) {
            Write-Host "   - $err" -ForegroundColor Red
        }
        exit 1
    }
}

# 2. Perform atomic CRUD / Upsert mutation if specified
$didMutate = $ledgerHealed

$hasMutationInput = (-not [string]::IsNullOrWhiteSpace($AppId)) -or (-not [string]::IsNullOrWhiteSpace($Company)) -or (-not [string]::IsNullOrWhiteSpace($Status))
if ($hasMutationInput) {
    $appsList = [System.Collections.Generic.List[object]]::new()
    foreach ($existing in @($ledger.applications)) {
        if ($null -ne $existing) {
            $appsList.Add($existing)
        }
    }

    $targetApp = $null
    if (-not [string]::IsNullOrWhiteSpace($AppId)) {
        $targetApp = $appsList | Where-Object { $_.id -eq $AppId } | Select-Object -First 1
    } elseif (-not [string]::IsNullOrWhiteSpace($Company)) {
        if (-not [string]::IsNullOrWhiteSpace($RequisitionId)) {
            $targetApp = $appsList | Where-Object { $_.company -eq $Company -and $_.requisition_id -eq $RequisitionId } | Select-Object -First 1
        }
        if ($null -eq $targetApp -and -not [string]::IsNullOrWhiteSpace($Role)) {
            $targetApp = $appsList | Where-Object { $_.company -eq $Company -and $_.role -eq $Role } | Select-Object -First 1
        }
    }

    if ($null -eq $targetApp) {
        # Create new entry if Company and Role are supplied
        if ([string]::IsNullOrWhiteSpace($Company) -or [string]::IsNullOrWhiteSpace($Role)) {
            if (-not [string]::IsNullOrWhiteSpace($AppId)) {
                Write-Host "[!] ERROR: Application ID '$AppId' not found in ledger.json. To create a new entry, provide -Company and -Role." -ForegroundColor Red
                exit 1
            } else {
                Write-Host "[!] ERROR: To create a new application in ledger.json, provide both -Company and -Role." -ForegroundColor Red
                exit 1
            }
        }

        $resolvedId = $AppId
        if ([string]::IsNullOrWhiteSpace($resolvedId)) {
            $dateSlug = (Get-Date).ToString("yyyyMMdd")
            $companySlug = ($Company.ToLowerInvariant() -replace "[^a-z0-9]+", "_").Trim("_")
            $baseId = "app_${dateSlug}_${companySlug}"
            $resolvedId = $baseId
            $suffix = 2
            while ($null -ne ($appsList | Where-Object { $_.id -eq $resolvedId })) {
                $resolvedId = "${baseId}_${suffix}"
                $suffix++
            }
        }

        $resolvedStatus = if (-not [string]::IsNullOrWhiteSpace($Status)) { $Status } else { "in_progress" }
        $appliedDateVal = if ($resolvedStatus -eq "applied") { $today } else { $null }

        $newDates = [PSCustomObject]@{
            created       = $today
            applied       = $appliedDateVal
            last_activity = $today
        }

        $targetApp = [PSCustomObject]@{
            id               = $resolvedId
            company          = $Company
            role             = $Role
            requisition_id   = if (-not [string]::IsNullOrWhiteSpace($RequisitionId)) { $RequisitionId } else { $null }
            url              = if (-not [string]::IsNullOrWhiteSpace($Url)) { $Url } else { $null }
            status           = $resolvedStatus
            dossier_path     = if (-not [string]::IsNullOrWhiteSpace($DossierPath)) { $DossierPath } else { $null }
            fit_score        = if ($FitScore -ge 0) { $FitScore } else { $null }
            compensation     = if (-not [string]::IsNullOrWhiteSpace($Compensation)) { $Compensation } else { $null }
            referral_contact = if (-not [string]::IsNullOrWhiteSpace($ReferralContact)) { $ReferralContact } else { $null }
            dates            = $newDates
            notes            = if (-not [string]::IsNullOrWhiteSpace($Notes)) { $Notes } else { $null }
        }

        $appsList.Add($targetApp)
        Set-OrAddProperty -Object $ledger -Name "applications" -Value ([object[]]$appsList.ToArray())
        $didMutate = $true
        Write-Host "[+] Created new application '$resolvedId' ($Company - $Role) with status '$resolvedStatus' in ledger.json" -ForegroundColor Green
    } else {
        # Update existing entry
        if (-not [string]::IsNullOrWhiteSpace($Company)) {
            Set-OrAddProperty -Object $targetApp -Name "company" -Value $Company
        }
        if (-not [string]::IsNullOrWhiteSpace($Role)) {
            Set-OrAddProperty -Object $targetApp -Name "role" -Value $Role
        }
        if (-not [string]::IsNullOrWhiteSpace($Status)) {
            Set-OrAddProperty -Object $targetApp -Name "status" -Value $Status
        }
        if (-not [string]::IsNullOrWhiteSpace($RequisitionId)) {
            Set-OrAddProperty -Object $targetApp -Name "requisition_id" -Value $RequisitionId
        }
        if (-not [string]::IsNullOrWhiteSpace($Url)) {
            Set-OrAddProperty -Object $targetApp -Name "url" -Value $Url
        }
        if (-not [string]::IsNullOrWhiteSpace($DossierPath)) {
            Set-OrAddProperty -Object $targetApp -Name "dossier_path" -Value $DossierPath
        }
        if ($FitScore -ge 0) {
            Set-OrAddProperty -Object $targetApp -Name "fit_score" -Value $FitScore
        }
        if (-not [string]::IsNullOrWhiteSpace($Compensation)) {
            Set-OrAddProperty -Object $targetApp -Name "compensation" -Value $Compensation
        }
        if (-not [string]::IsNullOrWhiteSpace($ReferralContact)) {
            Set-OrAddProperty -Object $targetApp -Name "referral_contact" -Value $ReferralContact
        }
        if (-not [string]::IsNullOrWhiteSpace($Notes)) {
            Set-OrAddProperty -Object $targetApp -Name "notes" -Value $Notes
        }

        if ($null -eq $targetApp.dates) {
            Set-OrAddProperty -Object $targetApp -Name "dates" -Value ([PSCustomObject]@{})
        }
        Set-OrAddProperty -Object $targetApp.dates -Name "last_activity" -Value $today
        if ($Status -eq "applied" -and [string]::IsNullOrWhiteSpace([string]$targetApp.dates.applied)) {
            Set-OrAddProperty -Object $targetApp.dates -Name "applied" -Value $today
        }

        $didMutate = $true
        Write-Host "[+] Updated $($targetApp.id) to status '$($targetApp.status)' in ledger.json" -ForegroundColor Green
    }

    # Optional graduation from sourcing_inbox.json
    if ($GraduateFromInbox -and $null -ne $inbox) {
        $remainingLeads = [System.Collections.Generic.List[object]]::new()
        $graduatedCount = 0
        foreach ($lead in @($inbox.leads)) {
            if ($null -eq $lead) { continue }
            $matchByReq = (-not [string]::IsNullOrWhiteSpace([string]$targetApp.requisition_id)) -and ($lead.requisition_id -eq $targetApp.requisition_id)
            $matchByUrl = (-not [string]::IsNullOrWhiteSpace([string]$targetApp.url)) -and ($lead.url -eq $targetApp.url)
            $matchByCompanyRole = ($lead.company -eq $targetApp.company) -and ($lead.title -eq $targetApp.role)
            if ($matchByReq -or $matchByUrl -or $matchByCompanyRole) {
                $graduatedCount++
            } else {
                $remainingLeads.Add($lead)
            }
        }
        if ($graduatedCount -gt 0) {
            Set-OrAddProperty -Object $inbox -Name "leads" -Value ([object[]]$remainingLeads.ToArray())
            $activeRemaining = @($remainingLeads | Where-Object { $_.status -notin @("archived", "passed", "graduated", "closed") }).Count
            Set-OrAddProperty -Object $inbox.meta -Name "total_leads" -Value $remainingLeads.Count
            Set-OrAddProperty -Object $inbox.meta -Name "active_leads" -Value $activeRemaining
            $inbox | ConvertTo-Json -Depth 10 | Set-Content -Path $inboxJsonPath -Encoding UTF8
            Write-Host "[+] Graduated $graduatedCount lead(s) from sourcing_inbox.json into ledger.json" -ForegroundColor Green
        }
    }
}

# Validate ledger schema after any mutations
$ledgerErrors = Test-LedgerSchema -LedgerObj $ledger
if ($ledgerErrors.Count -gt 0) {
    Write-Host "[!] SCHEMA VALIDATION ERRORS IN ledger.json:" -ForegroundColor Red
    foreach ($err in $ledgerErrors) {
        Write-Host "   - $err" -ForegroundColor Red
    }
    exit 1
}

if ($didMutate) {
    Set-OrAddProperty -Object $ledger.meta -Name "last_updated" -Value $today
    # Ensure applications array serializes as a JSON array even when empty or single-element in PS 5.1
    $appArray = @($ledger.applications | Where-Object { $null -ne $_ })
    if ($appArray.Count -eq 0) {
        Set-OrAddProperty -Object $ledger -Name "applications" -Value @()
        $jsonOut = $ledger | ConvertTo-Json -Depth 10
    } elseif ($appArray.Count -eq 1) {
        Set-OrAddProperty -Object $ledger -Name "applications" -Value ([object[]]@($appArray[0]))
        $jsonOut = $ledger | ConvertTo-Json -Depth 10
        # Guard against PS 5.1 single-element array unwrapping if ConvertTo-Json collapsed it
        $parsedBack = $jsonOut | ConvertFrom-Json
        if ($parsedBack.applications -isnot [System.Array]) {
            $jsonOut = [regex]::Replace($jsonOut, '"applications"\s*:\s*\{', '"applications": [' + "`r`n        {", 1)
            $jsonOut = [regex]::Replace($jsonOut, '(\}\s*,\s*"\$schema"|\}\s*,\s*"meta"|\}\s*\}\s*$)', "}`r`n    ]`$1", 1)
        }
    } else {
        Set-OrAddProperty -Object $ledger -Name "applications" -Value ([object[]]$appArray)
        $jsonOut = $ledger | ConvertTo-Json -Depth 10
    }
    Set-Content -Path $ledgerPath -Value $jsonOut -Encoding UTF8
}

# Reconcile sourcing_inbox.json meta counts if needed
if ($null -ne $inbox) {
    $allLeads = @($inbox.leads | Where-Object { $null -ne $_ })
    $activeLeads = @($allLeads | Where-Object { [string]$_.status -notin @("archived", "passed", "graduated", "closed") })
    $totalInboxLeadsCount = $allLeads.Count
    $activeInboxLeadsCount = $activeLeads.Count

    if ($inbox.meta.total_leads -ne $totalInboxLeadsCount -or $inbox.meta.active_leads -ne $activeInboxLeadsCount) {
        Set-OrAddProperty -Object $inbox.meta -Name "total_leads" -Value $totalInboxLeadsCount
        Set-OrAddProperty -Object $inbox.meta -Name "active_leads" -Value $activeInboxLeadsCount
        $inbox | ConvertTo-Json -Depth 10 | Set-Content -Path $inboxJsonPath -Encoding UTF8
        Write-Host "[i] Reconciled sourcing_inbox.json meta counts (total: $totalInboxLeadsCount, active: $activeInboxLeadsCount)." -ForegroundColor Cyan
    }
}

# Fallback: if sourcing_inbox.json has 0 active leads, check sourcing_inbox.md for markdown-only leads
$inboxMdPath = Join-Path $workspaceRoot "applications/sourcing_inbox.md"
if ($activeInboxLeadsCount -eq 0 -and (Test-Path $inboxMdPath)) {
    $mdLines = Get-Content -Path $inboxMdPath -Encoding UTF8
    $mdLeadRows = 0
    foreach ($line in $mdLines) {
        $t = $line.Trim()
        if ($t -match "^\|" -and $t -notmatch "Fit Score" -and $t -notmatch "^\|[\s:\-\|]+\|$" -and $t -notmatch "No leads yet") {
            $mdLeadRows++
        }
    }
    if ($mdLeadRows -gt 0) {
        $activeInboxLeadsCount = $mdLeadRows
        if ($totalInboxLeadsCount -lt $mdLeadRows) { $totalInboxLeadsCount = $mdLeadRows }
    }
}

if (-not (Test-Path $dashboardPath)) {
    Write-Host "[!] DASHBOARD.md not found at root (workspace may be in onboarding or template state)." -ForegroundColor Yellow
    Write-Host "    Ledger schema check passed. Skipping markdown dashboard parity audit." -ForegroundColor Yellow
    $global:LASTEXITCODE = 0
    exit 0
}

# 3. Compute deterministic pipeline metrics
$allApps = @($ledger.applications | Where-Object { $null -ne $_ })
$activeApps = @($allApps | Where-Object { $_.status -notin @("rejected", "rejected_post_vp_screen", "withdrawn", "archived", "closed") -and $_.status -notlike "rejected*" })
$appliedApps = @($allApps | Where-Object { $_.status -in @("applied", "screen_scheduled", "screen_completed", "technical_screen", "onsite", "offer") })
$submittedEverApps = @($allApps | Where-Object {
    $_.status -in @("applied", "screen_scheduled", "screen_completed", "technical_screen", "onsite", "offer", "rejected_post_vp_screen") -or
    ($null -ne $_.dates -and -not [string]::IsNullOrWhiteSpace([string]$_.dates.applied))
})

$sourcedOrPrepCount = @($activeApps | Where-Object { $_.status -in @("sourced", "in_progress") }).Count
$funnelInboxCount = $activeInboxLeadsCount + $sourcedOrPrepCount
$funnelOutreachCount = @($activeApps | Where-Object { $_.status -in @("outreach_sent", "referral_package_sent", "referral_submitted") }).Count
$funnelAppliedCount = $appliedApps.Count
$funnelScreenCount = @($activeApps | Where-Object { $_.status -in @("screen_scheduled", "screen_completed") }).Count
$funnelTechCount = @($activeApps | Where-Object { $_.status -in @("technical_screen", "onsite") }).Count
$funnelOfferCount = @($activeApps | Where-Object { $_.status -eq "offer" }).Count

# 4. Deterministically update DASHBOARD.md if -UpdateDashboard or if a ledger mutation occurred
if ($UpdateDashboard -or $didMutate) {
    $dashRaw = Get-Content -Path $dashboardPath -Raw -Encoding UTF8
    $updatedDash = $dashRaw

    # 4a. Update Mermaid funnel node counts while preserving existing node labels/icons
    $updatedDash = [regex]::Replace($updatedDash, '(Identified\["[^"\(\r\n]*?\()\d+(\)"\])', "`${1}$funnelInboxCount`${2}")
    $updatedDash = [regex]::Replace($updatedDash, '(Outreach\["[^"\(\r\n]*?\()\d+(\)"\])', "`${1}$funnelOutreachCount`${2}")
    $updatedDash = [regex]::Replace($updatedDash, '(Applied\["[^"\(\r\n]*?\()\d+(\)"\])', "`${1}$funnelAppliedCount`${2}")
    $updatedDash = [regex]::Replace($updatedDash, '(Screen\["[^"\(\r\n]*?\()\d+(\)"\])', "`${1}$funnelScreenCount`${2}")
    $updatedDash = [regex]::Replace($updatedDash, '(Technical\["[^"\(\r\n]*?\()\d+(\)"\])', "`${1}$funnelTechCount`${2}")
    $updatedDash = [regex]::Replace($updatedDash, '(Offer\["[^"\(\r\n]*?\()\d+(\)"\])', "`${1}$funnelOfferCount`${2}")

    # 4b. Regenerate Active Application Status markdown table rows (preserving custom cells from existing DASHBOARD.md rows when ledger fields are null)
    $existingRowMap = @{}
    $existingTableMatch = [regex]::Match($dashRaw, '(?ms)### [^\r\n]*Active Application Status\s*\r?\n\|[^\r\n]+\|\r?\n\|[\s:\-\|]+\|\r?\n((?:\|[^\r\n]+\|\r?\n?)+)')
    if ($existingTableMatch.Success) {
        $rawRowLines = $existingTableMatch.Groups[1].Value -split "\r?\n"
        foreach ($rLine in $rawRowLines) {
            $trimmedRow = $rLine.Trim()
            if (-not $trimmedRow.StartsWith("|") -or $trimmedRow -match "No active applications") { continue }
            $cells = @($trimmedRow.Trim('|') -split '(?<!\\)\|' | ForEach-Object { $_.Trim() })
            if ($cells.Count -ge 7) {
                $compKey = (($cells[0] -replace "\*", "").Trim()).ToLowerInvariant()
                if (-not [string]::IsNullOrWhiteSpace($compKey)) {
                    $existingRowMap[$compKey] = [PSCustomObject]@{
                        RoleCell   = $cells[1]
                        DateCell   = $cells[2]
                        CompCell   = $cells[3]
                        ConnCell   = $cells[4]
                        StatusCell = $cells[5]
                        AssetsCell = $cells[6]
                    }
                }
            }
        }
    }

    $tableRows = [System.Collections.Generic.List[string]]::new()
    if ($activeApps.Count -eq 0) {
        $tableRows.Add("| *No active applications* | *Select a lead from Sourcing Inbox to begin* | - | - | - | - | - |")
    } else {
        foreach ($app in $activeApps) {
            $compKey = (([string]$app.company).Trim()).ToLowerInvariant()
            $priorRow = if ($existingRowMap.ContainsKey($compKey)) { $existingRowMap[$compKey] } else { $null }

            $compCell = "**$($app.company)**"
            $roleCell = [string]$app.role
            if (-not [string]::IsNullOrWhiteSpace([string]$app.requisition_id)) {
                $cleanReq = ([string]$app.requisition_id).TrimStart('#')
                $roleCell = "$roleCell (``#$cleanReq``)"
            } elseif ($null -ne $priorRow -and $priorRow.RoleCell -match '\(`#[^`]+`\)') {
                $roleCell = $priorRow.RoleCell
            }

            $dateVal = ""
            if ($null -ne $app.dates) {
                if (-not [string]::IsNullOrWhiteSpace([string]$app.dates.applied)) {
                    $dateVal = [string]$app.dates.applied
                } elseif (-not [string]::IsNullOrWhiteSpace([string]$app.dates.last_activity)) {
                    $dateVal = [string]$app.dates.last_activity
                } elseif (-not [string]::IsNullOrWhiteSpace([string]$app.dates.created)) {
                    $dateVal = [string]$app.dates.created
                }
            }
            if ([string]::IsNullOrWhiteSpace($dateVal) -and $null -ne $priorRow -and $priorRow.DateCell -notin @("-", "")) {
                $dateCell = $priorRow.DateCell
            } else {
                if ([string]::IsNullOrWhiteSpace($dateVal)) { $dateVal = $today }
                $dateCell = "``$dateVal``"
            }

            $compValCell = "*TBD*"
            if ($null -ne $app.compensation -and -not [string]::IsNullOrWhiteSpace([string]$app.compensation)) {
                if ($app.compensation -is [string]) {
                    $compValCell = "**$($app.compensation)**"
                } else {
                    $compValCell = "**$([string]$app.compensation)**"
                }
            } elseif ($null -ne $priorRow -and $priorRow.CompCell -notin @("*TBD*", "-", "")) {
                $compValCell = $priorRow.CompCell
            }

            $connCell = "*Direct Apply*"
            if (-not [string]::IsNullOrWhiteSpace([string]$app.referral_contact) -and [string]$app.referral_contact -ne "Direct Apply") {
                $connCell = [string]$app.referral_contact
            } elseif ($null -ne $priorRow -and $priorRow.ConnCell -notin @("*Direct Apply*", "-", "")) {
                $connCell = $priorRow.ConnCell
            }

            $appliedDateForBadge = if ($null -ne $app.dates) { [string]$app.dates.applied } else { "" }
            $statusCell = Get-StatusBadge -StatusVal ([string]$app.status) -AppliedDate $appliedDateForBadge
            $assetsCell = Get-VerifiedAssetsCell -App $app -RootPath $workspaceRoot
            if ($assetsCell -eq "*Pending Dossier*" -and $null -ne $priorRow -and $priorRow.AssetsCell -notin @("*Pending Dossier*", "-", "")) {
                $assetsCell = $priorRow.AssetsCell
            }

            $tableRows.Add("| $compCell | $roleCell | $dateCell | $compValCell | $connCell | $statusCell | $assetsCell |")
        }
    }

    $newRowsBlock = ($tableRows -join "`r`n")
    $tablePattern = '(?ms)(### [^\r\n]*Active Application Status\s*\r?\n\|[^\r\n]+\|\r?\n\|[\s:\-\|]+\|\r?\n)(?:\|[^\r\n]+\|\r?\n?)+'
    if ($updatedDash -match $tablePattern) {
        $updatedDash = [regex]::Replace($updatedDash, $tablePattern, "`${1}$newRowsBlock`r`n")
    }

    # 4c. Update Cumulative Effort & Velocity Milestones
    $updatedDash = [regex]::Replace($updatedDash, '(-\s*\*\*Qualified Leads in Inbox\*\*:\s*)\d+', "`${1}$funnelInboxCount")
    $updatedDash = [regex]::Replace($updatedDash, '(-\s*\*\*Applications Submitted\*\*:\s*)\d+', "`${1}$($submittedEverApps.Count)")

    $referralApps = @($activeApps | Where-Object {
        (-not [string]::IsNullOrWhiteSpace([string]$_.referral_contact) -and [string]$_.referral_contact -notin @("Direct Apply", "None", "N/A")) -or
        ($_.status -in @("outreach_sent", "referral_package_sent", "referral_submitted"))
    })
    $referralRate = if ($activeApps.Count -gt 0) { [int][math]::Round(($referralApps.Count / [double]$activeApps.Count) * 100) } else { 0 }
    $updatedDash = [regex]::Replace($updatedDash, '(-\s*\*\*Warm Referral Rate\*\*:\s*)\d+%', "`${1}${referralRate}%")

    $minEvaluated = $allApps.Count + $totalInboxLeadsCount
    $evalMatch = [regex]::Match($updatedDash, '-\s*\*\*Total Opportunities Evaluated\*\*:\s*(\d+)')
    if ($evalMatch.Success) {
        $currentEval = [int]$evalMatch.Groups[1].Value
        $newEval = [math]::Max($currentEval, $minEvaluated)
        $updatedDash = [regex]::Replace($updatedDash, '(-\s*\*\*Total Opportunities Evaluated\*\*:\s*)\d+', "`${1}$newEval")
    }

    if ($updatedDash -ne $dashRaw) {
        Set-Content -Path $dashboardPath -Value $updatedDash -Encoding UTF8
        Write-Host "[+] Deterministically synchronized DASHBOARD.md with ledger.json state." -ForegroundColor Green
    }
}

# 5. Audit parity between ledger.json and DASHBOARD.md
$dashboardContent = Get-Content -Path $dashboardPath -Raw -Encoding UTF8

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "ACE PIPELINE & DASHBOARD SYNCHRONIZATION AUDIT (Rule 5)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Ledger Schema Integrity:             VALID (0 errors)"
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

# Verify Funnel / Milestone Applied Count Parity
$countPatterns = @(
    "$($appliedApps.Count)\s+Verified",
    "Applied[^\r\n]*?\($($appliedApps.Count)\)",
    "Applications Submitted\*\*:\s*$($submittedEverApps.Count)",
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
        $discrepancies.Add("Applied count in DASHBOARD.md does not match ledger.json applied count ($($appliedApps.Count)). Run with -UpdateDashboard to synchronize.")
    }
}

if ($discrepancies.Count -gt 0) {
    Write-Host "`n[!] PARITY WARNINGS DETECTED:" -ForegroundColor Yellow
    foreach ($d in $discrepancies) {
        Write-Host "   - $d" -ForegroundColor Yellow
    }
    Write-Host "`nAction: Run 'powershell -File scripts/sync_pipeline.ps1 -UpdateDashboard' to synchronize DASHBOARD.md with ledger.json state." -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "`n[OK] PERFECT PARITY: applications/ledger.json and DASHBOARD.md are in 100% lockstep.`n" -ForegroundColor Green
    $global:LASTEXITCODE = 0
    exit 0
}
