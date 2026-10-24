<#
.SYNOPSIS
    ACE Automated ATS Job Scanner, Public API Fetcher & Sourcing Inbox Engine
.DESCRIPTION
    Constructs targeted ATS search batches, fetches structured job postings directly
    from Greenhouse, Lever, and Ashby public JSON APIs, extracts Schema.org JobPosting
    JSON-LD blocks from direct job URLs, scores opportunities using the deterministic
    100-Point Fit Rubric, cross-references 1st-degree contacts in network/contacts_ledger.md,
    and maintains applications/sourcing_inbox.json and applications/sourcing_inbox.md.
.PARAMETER ConfigPath
    Path to workflows/ats_search_config.json.
.PARAMETER InboxJsonPath
    Path to applications/sourcing_inbox.json.
.PARAMETER InboxMdPath
    Path to applications/sourcing_inbox.md.
.PARAMETER ContactsLedgerPath
    Path to network/contacts_ledger.md.
.PARAMETER Boards
    Optional array of ATS board identifiers (e.g. "greenhouse:stripe", "lever:plaid",
    "ashby:linear", or full board URLs) to query via public JSON APIs.
.PARAMETER FetchBoards
    Switch: Queries public JSON APIs for all boards in -Boards and config.ats_boards.
.PARAMETER ExtractUrl
    Optional: Extracts, scores, and evaluates a single job posting URL via public ATS API
    or HTML Schema.org JSON-LD (<script type="application/ld+json">).
.PARAMETER MockSourcePath
    Optional: Local file or directory containing JSON API payloads or HTML pages with
    application/ld+json for offline/sandbox ingestion and testing.
.PARAMETER Ingest
    Switch: Automatically ingests qualified scored leads into applications/sourcing_inbox.json
    and regenerates applications/sourcing_inbox.md.
.PARAMETER RenderInboxMd
    Switch: Deterministically regenerates applications/sourcing_inbox.md from sourcing_inbox.json.
.PARAMETER VerifyInbox
    Switch: Audits all lead URLs in sourcing_inbox.json for Rule 8 Direct Requisition compliance.
.PARAMETER DryRun
    Switch: Generates search queries or previews scored leads without modifying inbox files.
#>
param (
    [string]$ConfigPath = "./workflows/ats_search_config.json",
    [string]$InboxJsonPath = "./applications/sourcing_inbox.json",
    [string]$InboxMdPath = "./applications/sourcing_inbox.md",
    [string]$ContactsLedgerPath = "./network/contacts_ledger.md",
    [string[]]$Boards = @(),
    [switch]$FetchBoards,
    [string]$ExtractUrl = "",
    [string]$MockSourcePath = "",
    [switch]$Ingest,
    [switch]$RenderInboxMd,
    [switch]$VerifyInbox,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Set-OrAddProp {
    param ($Obj, [string]$Name, $Val)
    $Obj | Add-Member -NotePropertyName $Name -NotePropertyValue $Val -Force
}

function Test-DirectRequisitionUrl {
    param ([string]$Url)
    if ([string]::IsNullOrWhiteSpace($Url)) {
        return [PSCustomObject]@{ IsDirect = $false; Reason = "Empty URL" }
    }
    if ($Url -match "greenhouse\.io" -and $Url -notmatch "/jobs/\d+") {
        return [PSCustomObject]@{ IsDirect = $false; Reason = "Missing numeric requisition ID (generic board root)" }
    }
    if ($Url -match "ashbyhq\.com" -and $Url -notmatch "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}") {
        return [PSCustomObject]@{ IsDirect = $false; Reason = "Missing job UUID (generic org board root)" }
    }
    if ($Url -match "myworkdayjobs\.com" -and $Url -notmatch "/job/") {
        return [PSCustomObject]@{ IsDirect = $false; Reason = "Missing /job/ path (generic Workday root)" }
    }
    if ($Url -match "lever\.co" -and $Url -notmatch "lever\.co/[^/]+/[0-9a-fA-F]{8}-") {
        return [PSCustomObject]@{ IsDirect = $false; Reason = "Missing job UUID (generic Lever root)" }
    }
    return [PSCustomObject]@{ IsDirect = $true; Reason = "" }
}

function ConvertFrom-HtmlToPlainText {
    param ([string]$Html)
    if ([string]::IsNullOrWhiteSpace($Html)) { return "" }
    $decoded = [System.Net.WebUtility]::HtmlDecode($Html)
    $decoded = [System.Net.WebUtility]::HtmlDecode($decoded)
    $plain = $decoded -replace "<[^>]+>", " "
    $plain = $plain -replace "\s+", " "
    return $plain.Trim()
}

function Extract-CompensationFromText {
    param ([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
    # Match e.g. $150,000 - $190,000 or $150k - $190k
    $rangeRegex = '\$([0-9]{2,3}(?:,[0-9]{3})+|[0-9]{2,3}[kK])\s*(?:-|to|and)\s*\$?([0-9]{2,3}(?:,[0-9]{3})+|[0-9]{2,3}[kK])'
    $enDash = [string][char]0x2013
    $emDash = [string][char]0x2014
    $normalizedText = $Text.Replace($enDash, "-").Replace($emDash, "-")
    $m = [regex]::Match($normalizedText, $rangeRegex, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($m.Success) {
        $lowRaw = $m.Groups[1].Value
        $highRaw = $m.Groups[2].Value
        return "`$$lowRaw - `$$($highRaw.TrimStart('$'))"
    }
    return $null
}

function Get-MaxSalaryNumeric {
    param ([string]$CompStr)
    if ([string]::IsNullOrWhiteSpace($CompStr)) { return 0 }
    $matchesList = [regex]::Matches($CompStr, '\$?([0-9]{2,3}(?:,[0-9]{3})+|[0-9]{2,3})([kK])?')
    $maxVal = 0
    foreach ($m in $matchesList) {
        $numStr = $m.Groups[1].Value -replace ",", ""
        $val = 0
        if ([double]::TryParse($numStr, [ref]$val)) {
            if ($m.Groups[2].Success -or $val -lt 1000) {
                $val = $val * 1000
            }
            if ($val -gt $maxVal) { $maxVal = $val }
        }
    }
    return $maxVal
}

function Get-NetworkContactsMap {
    param ([string]$LedgerFilePath)
    $contacts = [System.Collections.Generic.List[PSCustomObject]]::new()
    if (-not (Test-Path $LedgerFilePath)) { return $contacts }

    $lines = Get-Content -Path $LedgerFilePath -Encoding UTF8
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        # Match markdown table rows: | Org | Contact Name | Title | ...
        if ($trimmed -match "^\|([^|]+)\|([^|]+)\|([^|]+)\|") {
            $org = ($matches[1] -replace "\*", "").Trim()
            $name = ($matches[2] -replace "\*", "").Trim()
            $role = ($matches[3] -replace "\*", "").Trim()
            if ($org -in @("Organization", ":---", "---", "Acme Corp", "") -or $org -match "^\[") {
                continue
            }
            if ($name -in @("Contact Name", ":---", "---", "Jane Doe", "") -or $name -match "^\[") {
                continue
            }
            $contacts.Add([PSCustomObject]@{
                Company = $org
                Name    = $name
                Title   = $role
            })
        } elseif ($trimmed -match "^-\s*\*\*([^*]+)\*\*\s*\|\s*\*?([^@*|]+)@\s*([^|*\r\n]+)\*?") {
            $name = $matches[1].Trim()
            $role = $matches[2].Trim()
            $org = $matches[3].Trim()
            if ($name -notmatch "^\[" -and $org -notmatch "^\[") {
                $contacts.Add([PSCustomObject]@{
                    Company = $org
                    Name    = $name
                    Title   = $role
                })
            }
        }
    }
    return $contacts
}

function Invoke-HttpTextFetch {
    param ([string]$Uri)
    $curlBin = if (Get-Command "curl.exe" -ErrorAction SilentlyContinue) { "curl.exe" } elseif (Get-Command "curl" -ErrorAction SilentlyContinue) { "curl" } else { $null }
    if ($curlBin) {
        $out = & $curlBin -s -L -m 15 -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) ACE-Scanner/1.0" "$Uri" 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace(($out -join "`n"))) {
            return ($out -join "`n")
        }
    }
    $resp = Invoke-WebRequest -Uri $Uri -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
    return [string]$resp.Content
}

function ConvertFrom-AtsPayload {
    param (
        [string]$RawContent,
        [string]$SourceHint = "",
        [string]$CompanyOverride = "",
        [string]$BoardSlug = ""
    )
    $extractedJobs = [System.Collections.Generic.List[PSCustomObject]]::new()
    if ([string]::IsNullOrWhiteSpace($RawContent)) { return $extractedJobs }

    $trimmed = $RawContent.Trim()

    # Case 1: HTML page containing <script type="application/ld+json">
    if ($trimmed -match "^<!DOCTYPE|^<html|<script[^>]*application/ld\+json") {
        $ldMatches = [regex]::Matches($trimmed, '(?is)<script[^>]*type=["'']application/ld\+json["''][^>]*>(.*?)</script>')
        foreach ($m in $ldMatches) {
            $jsonBlock = $m.Groups[1].Value.Trim()
            try {
                $parsedLd = $jsonBlock | ConvertFrom-Json
                $candidates = @()
                if ($parsedLd -is [System.Array]) {
                    $candidates = $parsedLd
                } elseif ($null -ne $parsedLd.'@graph') {
                    $candidates = @($parsedLd.'@graph')
                } else {
                    $candidates = @($parsedLd)
                }

                foreach ($item in $candidates) {
                    if ($null -eq $item) { continue }
                    $typeVal = [string]$item.'@type'
                    if ($typeVal -notmatch "JobPosting") { continue }

                    $title = [string]$item.title
                    $compName = if (-not [string]::IsNullOrWhiteSpace($CompanyOverride)) {
                        $CompanyOverride
                    } elseif ($null -ne $item.hiringOrganization -and -not [string]::IsNullOrWhiteSpace([string]$item.hiringOrganization.name)) {
                        [string]$item.hiringOrganization.name
                    } else {
                        "Unknown Company"
                    }

                    $reqId = $null
                    if ($null -ne $item.identifier) {
                        if ($item.identifier -is [string]) {
                            $reqId = [string]$item.identifier
                        } elseif (-not [string]::IsNullOrWhiteSpace([string]$item.identifier.value)) {
                            $reqId = [string]$item.identifier.value
                        }
                    }

                    $jobUrl = if (-not [string]::IsNullOrWhiteSpace([string]$item.url)) {
                        [string]$item.url
                    } elseif (-not [string]::IsNullOrWhiteSpace($SourceHint) -and $SourceHint -match "^https?://") {
                        $SourceHint
                    } else {
                        ""
                    }

                    if ([string]::IsNullOrWhiteSpace($reqId) -and $jobUrl -match "/jobs/(\d+)") {
                        $reqId = $matches[1]
                    } elseif ([string]::IsNullOrWhiteSpace($reqId) -and $jobUrl -match "([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})") {
                        $reqId = $matches[1]
                    }

                    $locParts = [System.Collections.Generic.List[string]]::new()
                    if ([string]$item.jobLocationType -match "TELECOMMUTE") {
                        $locParts.Add("Remote")
                    }
                    if ($null -ne $item.jobLocation) {
                        $locObjs = if ($item.jobLocation -is [System.Array]) { $item.jobLocation } else { @($item.jobLocation) }
                        foreach ($lo in $locObjs) {
                            if ($null -ne $lo.address) {
                                $city = [string]$lo.address.addressLocality
                                $region = [string]$lo.address.addressRegion
                                $country = [string]$lo.address.addressCountry
                                $locStr = (@($city, $region, $country) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ", "
                                if (-not [string]::IsNullOrWhiteSpace($locStr) -and -not $locParts.Contains($locStr)) {
                                    $locParts.Add($locStr)
                                }
                            }
                        }
                    }
                    $locationStr = if ($locParts.Count -gt 0) { $locParts -join " / " } else { "Unspecified" }

                    $compBand = $null
                    if ($null -ne $item.baseSalary -and $null -ne $item.baseSalary.value) {
                        $minV = $item.baseSalary.value.minValue
                        $maxV = $item.baseSalary.value.maxValue
                        if ($null -ne $minV -and $null -ne $maxV) {
                            $minFormatted = ([double]$minV).ToString("N0")
                            $maxFormatted = ([double]$maxV).ToString("N0")
                            $compBand = "`$$minFormatted - `$$maxFormatted"
                        } elseif ($null -ne $item.baseSalary.value.value) {
                            $valFormatted = ([double]$item.baseSalary.value.value).ToString("N0")
                            $compBand = "`$$valFormatted"
                        }
                    }

                    $descPlain = ConvertFrom-HtmlToPlainText -Html ([string]$item.description)
                    if ([string]::IsNullOrWhiteSpace($compBand)) {
                        $compBand = Extract-CompensationFromText -Text $descPlain
                    }

                    $platform = if ($jobUrl -match "greenhouse\.io") { "Greenhouse" }
                        elseif ($jobUrl -match "lever\.co") { "Lever" }
                        elseif ($jobUrl -match "ashbyhq\.com") { "Ashby" }
                        elseif ($jobUrl -match "myworkdayjobs\.com") { "Workday" }
                        else { "Schema.org JSON-LD" }

                    $extractedJobs.Add([PSCustomObject]@{
                        company        = $compName
                        title          = $title
                        requisition_id = $reqId
                        url            = $jobUrl
                        ats_platform   = $platform
                        location       = $locationStr
                        compensation   = $compBand
                        description    = $descPlain
                    })
                }
            } catch {}
        }
        return $extractedJobs
    }

    # Case 2: JSON API Payload (Greenhouse, Lever, or Ashby)
    try {
        $jsonObj = $trimmed | ConvertFrom-Json
    } catch {
        return $extractedJobs
    }

    # 2a. Greenhouse Board or Single Job Payload
    if ($null -ne $jsonObj.PSObject.Properties["jobs"] -and ($SourceHint -match "greenhouse" -or ($jsonObj.jobs.Count -gt 0 -and $null -ne $jsonObj.jobs[0].PSObject.Properties["absolute_url"]))) {
        foreach ($j in @($jsonObj.jobs)) {
            if ($null -eq $j) { continue }
            $urlVal = [string]$j.absolute_url
            $compName = if (-not [string]::IsNullOrWhiteSpace($CompanyOverride)) {
                $CompanyOverride
            } elseif (-not [string]::IsNullOrWhiteSpace([string]$j.company_name)) {
                [string]$j.company_name
            } elseif ($urlVal -match "greenhouse\.io/([^/]+)/jobs/") {
                (Get-Culture).TextInfo.ToTitleCase(($matches[1] -replace "[-_]", " "))
            } elseif (-not [string]::IsNullOrWhiteSpace($BoardSlug)) {
                (Get-Culture).TextInfo.ToTitleCase(($BoardSlug -replace "[-_]", " "))
            } else {
                "Greenhouse Employer"
            }

            $locVal = if ($null -ne $j.location -and -not [string]::IsNullOrWhiteSpace([string]$j.location.name)) { [string]$j.location.name } else { "Unspecified" }
            $descVal = ConvertFrom-HtmlToPlainText -Html ([string]$j.content)
            $compBand = Extract-CompensationFromText -Text $descVal

            $extractedJobs.Add([PSCustomObject]@{
                company        = $compName
                title          = [string]$j.title
                requisition_id = [string]$j.id
                url            = $urlVal
                ats_platform   = "Greenhouse"
                location       = $locVal
                compensation   = $compBand
                description    = $descVal
            })
        }
        return $extractedJobs
    }

    # Single Greenhouse job object
    if ($null -ne $jsonObj.PSObject.Properties["absolute_url"] -and $null -ne $jsonObj.PSObject.Properties["id"]) {
        $urlVal = [string]$jsonObj.absolute_url
        $compName = if (-not [string]::IsNullOrWhiteSpace($CompanyOverride)) {
            $CompanyOverride
        } elseif ($urlVal -match "greenhouse\.io/([^/]+)/jobs/") {
            (Get-Culture).TextInfo.ToTitleCase(($matches[1] -replace "[-_]", " "))
        } else {
            "Greenhouse Employer"
        }
        $locVal = if ($null -ne $jsonObj.location) { [string]$jsonObj.location.name } else { "Unspecified" }
        $descVal = ConvertFrom-HtmlToPlainText -Html ([string]$jsonObj.content)
        $compBand = Extract-CompensationFromText -Text $descVal

        $extractedJobs.Add([PSCustomObject]@{
            company        = $compName
            title          = [string]$jsonObj.title
            requisition_id = [string]$jsonObj.id
            url            = $urlVal
            ats_platform   = "Greenhouse"
            location       = $locVal
            compensation   = $compBand
            description    = $descVal
        })
        return $extractedJobs
    }

    # 2b. Ashby Job Board Payload
    if ($null -ne $jsonObj.PSObject.Properties["jobs"] -and ($SourceHint -match "ashby" -or ($jsonObj.jobs.Count -gt 0 -and ($null -ne $jsonObj.jobs[0].PSObject.Properties["jobUrl"] -or $null -ne $jsonObj.jobs[0].PSObject.Properties["isRemote"])))) {
        foreach ($j in @($jsonObj.jobs)) {
            if ($null -eq $j) { continue }
            $urlVal = if (-not [string]::IsNullOrWhiteSpace([string]$j.jobUrl)) {
                [string]$j.jobUrl
            } elseif (-not [string]::IsNullOrWhiteSpace($BoardSlug)) {
                "https://jobs.ashbyhq.com/$BoardSlug/$($j.id)"
            } else {
                ""
            }
            $compName = if (-not [string]::IsNullOrWhiteSpace($CompanyOverride)) {
                $CompanyOverride
            } elseif ($urlVal -match "ashbyhq\.com/([^/]+)/") {
                (Get-Culture).TextInfo.ToTitleCase(($matches[1] -replace "[-_]", " "))
            } elseif (-not [string]::IsNullOrWhiteSpace($BoardSlug)) {
                (Get-Culture).TextInfo.ToTitleCase(($BoardSlug -replace "[-_]", " "))
            } else {
                "Ashby Employer"
            }

            $locVal = if (-not [string]::IsNullOrWhiteSpace([string]$j.location)) { [string]$j.location } else { "Unspecified" }
            if ($j.isRemote -eq $true -and $locVal -notmatch "Remote") {
                $locVal = "$locVal (Remote)"
            }

            $descVal = if (-not [string]::IsNullOrWhiteSpace([string]$j.descriptionPlain)) {
                [string]$j.descriptionPlain
            } else {
                ConvertFrom-HtmlToPlainText -Html ([string]$j.descriptionHtml)
            }

            $compBand = $null
            if ($null -ne $j.compensation) {
                if (-not [string]::IsNullOrWhiteSpace([string]$j.compensation.compensationTierSummary)) {
                    $compBand = [string]$j.compensation.compensationTierSummary
                } elseif (-not [string]::IsNullOrWhiteSpace([string]$j.compensation.scrapeableCompensationSalarySummary)) {
                    $compBand = [string]$j.compensation.scrapeableCompensationSalarySummary
                }
            }
            if ([string]::IsNullOrWhiteSpace($compBand)) {
                $compBand = Extract-CompensationFromText -Text $descVal
            }

            $extractedJobs.Add([PSCustomObject]@{
                company        = $compName
                title          = [string]$j.title
                requisition_id = [string]$j.id
                url            = $urlVal
                ats_platform   = "Ashby"
                location       = $locVal
                compensation   = $compBand
                description    = $descVal
            })
        }
        return $extractedJobs
    }

    # 2c. Lever Postings Payload (array or single posting with hostedUrl)
    $leverItems = @()
    if ($jsonObj -is [System.Array]) {
        $leverItems = $jsonObj
    } elseif ($null -ne $jsonObj.PSObject.Properties["hostedUrl"]) {
        $leverItems = @($jsonObj)
    }

    if ($leverItems.Count -gt 0 -and $null -ne $leverItems[0].PSObject.Properties["hostedUrl"]) {
        foreach ($j in $leverItems) {
            if ($null -eq $j) { continue }
            $urlVal = [string]$j.hostedUrl
            $compName = if (-not [string]::IsNullOrWhiteSpace($CompanyOverride)) {
                $CompanyOverride
            } elseif ($urlVal -match "lever\.co/([^/]+)/") {
                (Get-Culture).TextInfo.ToTitleCase(($matches[1] -replace "[-_]", " "))
            } elseif (-not [string]::IsNullOrWhiteSpace($BoardSlug)) {
                (Get-Culture).TextInfo.ToTitleCase(($BoardSlug -replace "[-_]", " "))
            } else {
                "Lever Employer"
            }

            $locVal = if ($null -ne $j.categories -and -not [string]::IsNullOrWhiteSpace([string]$j.categories.location)) {
                [string]$j.categories.location
            } else {
                "Unspecified"
            }
            if ([string]$j.workplaceType -match "remote" -and $locVal -notmatch "Remote") {
                $locVal = "$locVal (Remote)"
            }

            $descVal = (@([string]$j.descriptionPlain, [string]$j.additionalPlain) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join " "
            if ([string]::IsNullOrWhiteSpace($descVal)) {
                $descVal = ConvertFrom-HtmlToPlainText -Html ([string]$j.description)
            }

            $compBand = $null
            if ($null -ne $j.salaryRange -and $null -ne $j.salaryRange.min -and $null -ne $j.salaryRange.max) {
                $minFormatted = ([double]$j.salaryRange.min).ToString("N0")
                $maxFormatted = ([double]$j.salaryRange.max).ToString("N0")
                $compBand = "`$$minFormatted - `$$maxFormatted"
            }
            if ([string]::IsNullOrWhiteSpace($compBand)) {
                $compBand = Extract-CompensationFromText -Text $descVal
            }

            $extractedJobs.Add([PSCustomObject]@{
                company        = $compName
                title          = [string]$j.text
                requisition_id = [string]$j.id
                url            = $urlVal
                ats_platform   = "Lever"
                location       = $locVal
                compensation   = $compBand
                description    = $descVal
            })
        }
        return $extractedJobs
    }

    return $extractedJobs
}

function Get-JobFitEvaluation {
    param (
        $Job,
        $ConfigObj,
        $ContactsList
    )

    $title = [string]$Job.title
    $desc = [string]$Job.description
    $combinedText = "$title $desc"
    $location = [string]$Job.location
    $company = [string]$Job.company

    # 1. Negative Keyword Filter on Title
    $negKeywords = @()
    if ($null -ne $ConfigObj.search_criteria -and $null -ne $ConfigObj.search_criteria.negative_keywords) {
        $negKeywords = @($ConfigObj.search_criteria.negative_keywords)
    }
    foreach ($neg in $negKeywords) {
        if ([string]::IsNullOrWhiteSpace($neg)) { continue }
        if ($title -match "\b$([regex]::Escape($neg))\b") {
            return [PSCustomObject]@{
                FitScore    = 0
                Likelihood  = "Low"
                WarmContact = $null
                Notes       = "Filtered out by negative title keyword '$neg'."
                FilteredOut = $true
            }
        }
    }

    # 2. Core Competencies (up to 40 pts: 20 pts role alignment + 20 pts core keywords)
    $roleScore = 0
    $targetRoles = @($ConfigObj.search_criteria.roles)
    foreach ($tr in $targetRoles) {
        if ([string]::IsNullOrWhiteSpace($tr)) { continue }
        if ($title -match [regex]::Escape($tr)) {
            $roleScore = 20
            break
        }
        $roleTokens = @($tr -split "\s+" | Where-Object { $_.Length -gt 3 -and $_ -notin @("Senior", "Staff", "Lead", "Principal", "Director", "Manager") })
        $matchedTokens = 0
        foreach ($rt in $roleTokens) {
            if ($title -match [regex]::Escape($rt)) { $matchedTokens++ }
        }
        if ($roleTokens.Count -gt 0) {
            $candidateScore = [int][math]::Round(($matchedTokens / [double]$roleTokens.Count) * 18)
            if ($candidateScore -gt $roleScore) { $roleScore = $candidateScore }
        }
    }

    $coreKwScore = 0
    $coreKeywords = @()
    if ($null -ne $ConfigObj.scoring_weights -and $null -ne $ConfigObj.scoring_weights.core_competencies) {
        $coreKeywords = @($ConfigObj.scoring_weights.core_competencies.keywords)
    }
    $matchedCore = [System.Collections.Generic.List[string]]::new()
    foreach ($kw in $coreKeywords) {
        if (-not [string]::IsNullOrWhiteSpace($kw) -and $combinedText -match [regex]::Escape($kw)) {
            $matchedCore.Add($kw)
        }
    }
    if ($coreKeywords.Count -gt 0) {
        $targetHits = [math]::Min(4, $coreKeywords.Count)
        $coreKwScore = [int][math]::Min(20, [math]::Round(($matchedCore.Count / [double]$targetHits) * 20))
    } else {
        $coreKwScore = 15
    }
    $totalCore = [math]::Min(40, $roleScore + $coreKwScore)

    # 3. Scope & Impact (up to 30 pts)
    $scopeScore = 0
    $scopeKeywords = @()
    if ($null -ne $ConfigObj.scoring_weights -and $null -ne $ConfigObj.scoring_weights.scope_and_impact) {
        $scopeKeywords = @($ConfigObj.scoring_weights.scope_and_impact.keywords)
    }
    $matchedScope = 0
    foreach ($kw in $scopeKeywords) {
        if (-not [string]::IsNullOrWhiteSpace($kw) -and $combinedText -match [regex]::Escape($kw)) {
            $matchedScope++
        }
    }
    if ($scopeKeywords.Count -gt 0) {
        $targetScopeHits = [math]::Min(3, $scopeKeywords.Count)
        $scopeScore = [int][math]::Min(30, [math]::Round(($matchedScope / [double]$targetScopeHits) * 30))
    } else {
        $scopeScore = 20
    }

    # 4. Seniority & Leadership (up to 20 pts)
    $seniorityScore = 0
    $senKeywords = @()
    if ($null -ne $ConfigObj.scoring_weights -and $null -ne $ConfigObj.scoring_weights.seniority_and_leadership) {
        $senKeywords = @($ConfigObj.scoring_weights.seniority_and_leadership.keywords)
    }
    $matchedSen = 0
    foreach ($kw in $senKeywords) {
        if (-not [string]::IsNullOrWhiteSpace($kw) -and $combinedText -match [regex]::Escape($kw)) {
            $matchedSen++
        }
    }
    if ($senKeywords.Count -gt 0) {
        $targetSenHits = [math]::Min(2, $senKeywords.Count)
        $seniorityScore = [int][math]::Min(20, [math]::Round(($matchedSen / [double]$targetSenHits) * 20))
    } else {
        $seniorityScore = 15
    }

    # 5. Domain & Industry (up to 10 pts)
    $domainScore = 0
    $domKeywords = @()
    if ($null -ne $ConfigObj.scoring_weights -and $null -ne $ConfigObj.scoring_weights.domain_and_industry) {
        $domKeywords = @($ConfigObj.scoring_weights.domain_and_industry.keywords)
    }
    $matchedDom = 0
    foreach ($kw in $domKeywords) {
        if (-not [string]::IsNullOrWhiteSpace($kw) -and "$company $combinedText" -match [regex]::Escape($kw)) {
            $matchedDom++
        }
    }
    if ($domKeywords.Count -gt 0) {
        $domainScore = if ($matchedDom -gt 0) { 10 } else { 5 }
    } else {
        $domainScore = 8
    }

    $rawScore = $totalCore + $scopeScore + $seniorityScore + $domainScore
    $notesParts = [System.Collections.Generic.List[string]]::new()
    if ($matchedCore.Count -gt 0) {
        $notesParts.Add("Matched core competencies: $(($matchedCore | Select-Object -First 4) -join ', ').")
    }

    # 6. Compensation Floor Check
    $compFloor = 0
    if ($null -ne $ConfigObj.search_criteria -and $null -ne $ConfigObj.search_criteria.compensation -and $null -ne $ConfigObj.search_criteria.compensation.floor) {
        $compFloor = [double]$ConfigObj.search_criteria.compensation.floor
    }
    $maxListedSalary = Get-MaxSalaryNumeric -CompStr ([string]$Job.compensation)
    $belowFloor = $false
    if ($maxListedSalary -gt 0 -and $compFloor -gt 0 -and $maxListedSalary -lt $compFloor) {
        $deduction = if ($null -ne $ConfigObj.scoring_weights.gap_advisory_deduction) { [int]$ConfigObj.scoring_weights.gap_advisory_deduction } else { 15 }
        $rawScore = [math]::Max(0, $rawScore - $deduction)
        $belowFloor = $true
        $notesParts.Add("Advisory: Listed max salary ($($Job.compensation)) is below configured floor (`$$($compFloor.ToString('N0'))).")
    }

    # 7. Network Contact Cross-Reference
    $warmContactStr = $null
    foreach ($c in $ContactsList) {
        if ([string]::IsNullOrWhiteSpace($c.Company) -or [string]::IsNullOrWhiteSpace($company)) { continue }
        if ($company -match "^$([regex]::Escape($c.Company))$" -or $c.Company -match "^$([regex]::Escape($company))$") {
            $warmContactStr = "$($c.Name) ($($c.Title))"
            break
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($warmContactStr)) {
        $boost = if ($null -ne $ConfigObj.scoring_weights -and $null -ne $ConfigObj.scoring_weights.referral_boost_points) {
            [int]$ConfigObj.scoring_weights.referral_boost_points
        } else {
            30
        }
        $rawScore = [math]::Min(100, $rawScore + $boost)
        $notesParts.Add("1st-degree referral available: $warmContactStr.")
    }

    $finalScore = [int][math]::Max(0, [math]::Min(100, $rawScore))

    # 8. Location Match & Likelihood Determination
    $targetLocs = @($ConfigObj.search_criteria.locations)
    $locMatched = ($targetLocs.Count -eq 0)
    foreach ($tl in $targetLocs) {
        if ($location -match [regex]::Escape($tl)) {
            $locMatched = $true
            break
        }
    }

    $likelihood = "Medium"
    if ($belowFloor) {
        $likelihood = "Low"
    } elseif (-not [string]::IsNullOrWhiteSpace($warmContactStr) -or ($finalScore -ge 80 -and $locMatched)) {
        $likelihood = "High"
    } elseif ($finalScore -lt 65 -or (-not $locMatched -and $location -ne "Unspecified")) {
        $likelihood = "Low"
    }

    return [PSCustomObject]@{
        FitScore    = $finalScore
        Likelihood  = $likelihood
        WarmContact = $warmContactStr
        Notes       = ($notesParts -join " ")
        FilteredOut = $false
    }
}

function Update-SourcingInboxMarkdown {
    param (
        [string]$JsonFilePath,
        [string]$MdFilePath
    )

    if (-not (Test-Path $JsonFilePath)) { return }
    $inboxObj = Get-Content -Path $JsonFilePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $allLeads = @($inboxObj.leads | Where-Object { $null -ne $_ })
    $activeLeads = @($allLeads | Where-Object { [string]$_.status -notin @("archived", "passed", "graduated", "closed") } | Sort-Object -Property @{Expression = { [double]$_.fit_score }; Descending = $true })
    $archivedLeads = @($allLeads | Where-Object { [string]$_.status -in @("archived", "passed") })

    $inboxEmoji = [char]::ConvertFromUtf32(0x1F4E5)
    $starEmoji = [char]::ConvertFromUtf32(0x1F31F)
    $searchEmoji = [char]::ConvertFromUtf32(0x1F50D)
    $boxEmoji = [char]::ConvertFromUtf32(0x1F4E6)
    $warnEmoji = [char]::ConvertFromUtf32(0x26A0) + [char]0xFE0F

    $lastScannedStr = if (-not [string]::IsNullOrWhiteSpace([string]$inboxObj.meta.last_scanned)) {
        [string]$inboxObj.meta.last_scanned
    } else {
        "Never"
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("# $inboxEmoji Job Sourcing Inbox & Opportunity Tracker")
    $lines.Add("")
    $lines.Add("> **Last Scanned**: $lastScannedStr | **Total Qualified Leads**: $($activeLeads.Count)  ")
    $lines.Add("> **Search Config**: [``workflows/ats_search_config.json``](../workflows/ats_search_config.json) | **Scoring Rubric**: [100-Point Fit Rubric](../.agents/skills/ats-job-scanner/references/scoring_rubric.md)  ")
    $lines.Add("> **Graduation Policy**: The Sourcing Inbox is a triage queue operating on **Inbox Zero**. Once an opportunity is activated (application dossier scaffolded or referral outreach initiated), it graduates out of this inbox into [``applications/ledger.json``](ledger.json) and is tracked on [``DASHBOARD.md``](../DASHBOARD.md).")
    $lines.Add("")
    $lines.Add("---")
    $lines.Add("")
    $lines.Add("## $starEmoji High-Priority Qualified Opportunities (Fit Score >= 75%)")
    $lines.Add("")
    $lines.Add("| Fit Score | Likelihood | Role Title | Company | Location | Compensation | Warm Contact / Referral | Recommended Action / Status |")
    $lines.Add("| :---: | :---: | :--- | :--- | :--- | :--- | :--- | :--- |")

    if ($activeLeads.Count -eq 0) {
        $lines.Add("| *No leads yet* | - | *Run an ATS scan to populate* | - | - | - | - | - |")
    } else {
        foreach ($lead in $activeLeads) {
            $urlCheck = Test-DirectRequisitionUrl -Url ([string]$lead.url)
            $titleText = [string]$lead.title
            if (-not $urlCheck.IsDirect) {
                $titleText = "$titleText ($warnEmoji Confirm Requisition Link)"
            }
            $roleLink = "[$titleText]($($lead.url))"
            if (-not [string]::IsNullOrWhiteSpace([string]$lead.requisition_id) -and ([string]$lead.requisition_id).Length -le 12) {
                $roleLink = "$roleLink (``#$($lead.requisition_id)``)"
            }

            $locText = if (-not [string]::IsNullOrWhiteSpace([string]$lead.location)) { [string]$lead.location } else { "Unspecified" }
            $compText = if (-not [string]::IsNullOrWhiteSpace([string]$lead.compensation)) { "**$($lead.compensation)**" } else { "*Unlisted (Est. Pending)*" }
            $warmText = if (-not [string]::IsNullOrWhiteSpace([string]$lead.warm_contact)) { "**$($lead.warm_contact)**" } else { "*None identified*" }
            $actionText = if (-not [string]::IsNullOrWhiteSpace([string]$lead.warm_contact)) {
                "Warm referral outreach"
            } elseif ([double]$lead.fit_score -ge 80) {
                "Scaffold dossier & tailor 1-page PDF"
            } else {
                "Review JD & gap negotiability"
            }

            $lines.Add("| **$($lead.fit_score)%** | **$($lead.likelihood)** | $roleLink | **$($lead.company)** | $locText | $compText | $warmText | $actionText |")
        }
    }

    $lines.Add("")
    $lines.Add("---")
    $lines.Add("")
    $lines.Add("## $searchEmoji Detailed Lead Analysis")
    $lines.Add("")

    if ($activeLeads.Count -eq 0) {
        $lines.Add("*Discovered leads will be analyzed here with scoring breakdowns and warm contact recommendations.*")
    } else {
        foreach ($lead in $activeLeads) {
            $reqLabel = if (-not [string]::IsNullOrWhiteSpace([string]$lead.requisition_id)) { " (Req ``#$($lead.requisition_id)``)" } else { "" }
            $lines.Add("### $($lead.company) - $($lead.title)$reqLabel")
            $lines.Add("- **Direct Requisition Link**: [$($lead.url)]($($lead.url))")
            $lines.Add("- **Fit Score**: **$($lead.fit_score)%** | **Success Likelihood**: **$($lead.likelihood)** | **ATS Platform**: $(if ($lead.ats_platform) { $lead.ats_platform } else { 'Direct ATS' })")
            $lines.Add("- **Location**: $(if ($lead.location) { $lead.location } else { 'Unspecified' }) | **Compensation**: $(if ($lead.compensation) { $lead.compensation } else { 'Unlisted' })")
            if (-not [string]::IsNullOrWhiteSpace([string]$lead.warm_contact)) {
                $lines.Add("- **Warm Referral Path**: $($lead.warm_contact)")
            }
            if (-not [string]::IsNullOrWhiteSpace([string]$lead.notes)) {
                $lines.Add("- **Evaluation Notes**: $($lead.notes)")
            }
            $lines.Add("")
        }
    }

    $lines.Add("---")
    $lines.Add("")
    $lines.Add("## $boxEmoji Archived & Passed Leads")
    $lines.Add("")
    if ($archivedLeads.Count -eq 0) {
        $lines.Add("*Opportunities reviewed and passed on (below compensation floor, location mismatch, or non-negotiable gaps) are archived here to maintain Inbox Zero.*")
    } else {
        foreach ($arch in $archivedLeads) {
            $lines.Add("- **$($arch.company)** - [$($arch.title)]($($arch.url)) *(Fit: $($arch.fit_score)% | Status: $($arch.status))*")
        }
    }

    Set-Content -Path $MdFilePath -Value ($lines -join "`r`n") -Encoding UTF8
    Write-Host "[+] Updated ranked Sourcing Inbox markdown at $MdFilePath ($($activeLeads.Count) active leads)." -ForegroundColor Green
}

# --- 1. INLINE VERIFICATION MODE (-VerifyInbox) ---
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
        Write-Host "[!] ERROR: Invalid JSON syntax in $InboxJsonPath" -ForegroundColor Red
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

        $urlCheck = Test-DirectRequisitionUrl -Url $url
        if (-not $urlCheck.IsDirect) {
            Write-Host "[!] GENERIC:  [$company] $title" -ForegroundColor Yellow
            Write-Host "    URL:      $url" -ForegroundColor DarkGray
            Write-Host "    Issue:    $($urlCheck.Reason)" -ForegroundColor Yellow
            $issuesCount++
            continue
        }

        # 2. Fast Live HTTP Verification via curl (Cloudflare/WAF resilient, cross-platform)
        $httpCode = "ERR"
        try {
            $curlBin = if (Get-Command "curl.exe" -ErrorAction SilentlyContinue) { "curl.exe" } elseif (Get-Command "curl" -ErrorAction SilentlyContinue) { "curl" } else { $null }
            $nullDev = if ($env:OS -eq "Windows_NT") { "NUL" } else { "/dev/null" }
            if ($curlBin) {
                $curlOut = & $curlBin -s -L -m 5 -o $nullDev -w "%{http_code}|%{url_effective}" -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" "$url" 2>$null
                if ($curlOut -and $curlOut -match "^(\d+)\|(.*)$") {
                    $httpCode = $matches[1]
                }
            } else {
                $resp = Invoke-WebRequest -Uri $url -Method Head -MaximumRedirection 5 -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
                $httpCode = [string]$resp.StatusCode
            }
        } catch {
            if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
                $httpCode = [string][int]$_.Exception.Response.StatusCode
            } else {
                $httpCode = "FAIL"
            }
        }

        if ($httpCode -eq "200") {
            Write-Host "[+] LIVE:     [$company] $title (HTTP $httpCode)" -ForegroundColor Green
            $passedCount++
        } elseif ($httpCode -in @("403", "503")) {
            Write-Host "[~] SHIELDED: [$company] $title (HTTP $httpCode - Bot Shield Active, Deep URL Verified)" -ForegroundColor Cyan
            $passedCount++
        } else {
            Write-Host "[-] BROKEN:   [$company] $title (HTTP $httpCode)" -ForegroundColor Red
            Write-Host "    URL:      $url" -ForegroundColor DarkGray
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

# --- 2. STANDALONE MARKDOWN RENDER MODE (-RenderInboxMd) ---
if ($RenderInboxMd -and -not $FetchBoards -and [string]::IsNullOrWhiteSpace($ExtractUrl) -and [string]::IsNullOrWhiteSpace($MockSourcePath) -and $Boards.Count -eq 0) {
    Update-SourcingInboxMarkdown -JsonFilePath $InboxJsonPath -MdFilePath $InboxMdPath
    exit 0
}

if (-not (Test-Path $ConfigPath)) {
    Write-Host "[!] ERROR: Config file not found at $ConfigPath" -ForegroundColor Red
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
    $initialData = [ordered]@{
        "`$schema" = "./schema.json"
        meta = [ordered]@{
            title = "Job Sourcing Lead Inbox"
            last_scanned = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
            total_leads = 0
            active_leads = 0
        }
        leads = @()
    }
    $initialData | ConvertTo-Json -Depth 5 | Set-Content $InboxJsonPath -Encoding UTF8
    Write-Host "Initialized empty Sourcing Inbox at $InboxJsonPath"
}

# --- 3. DIRECT ATS PUBLIC API / JSON-LD / MOCK EXTRACTION & SCORING MODE ---
$boardList = [System.Collections.Generic.List[object]]::new()
foreach ($b in $Boards) {
    if (-not [string]::IsNullOrWhiteSpace($b)) { $boardList.Add($b) }
}
if ($FetchBoards -and $null -ne $config.ats_boards) {
    foreach ($cb in @($config.ats_boards)) {
        if ($null -ne $cb -and -not [string]::IsNullOrWhiteSpace([string]$cb)) {
            $boardList.Add($cb)
        }
    }
}

$runDirectExtraction = ($boardList.Count -gt 0) -or (-not [string]::IsNullOrWhiteSpace($ExtractUrl)) -or (-not [string]::IsNullOrWhiteSpace($MockSourcePath))

if ($runDirectExtraction) {
    $contactsList = Get-NetworkContactsMap -LedgerFilePath $ContactsLedgerPath
    $rawExtractedJobs = [System.Collections.Generic.List[PSCustomObject]]::new()

    # 3a. Process local mock fixtures if supplied (-MockSourcePath)
    if (-not [string]::IsNullOrWhiteSpace($MockSourcePath)) {
        if (-not (Test-Path $MockSourcePath)) {
            Write-Host "[!] ERROR: MockSourcePath not found: $MockSourcePath" -ForegroundColor Red
            exit 1
        }
        $mockFiles = if ((Get-Item $MockSourcePath).PSIsContainer) {
            Get-ChildItem -Path $MockSourcePath -File | Where-Object { $_.Extension -in @(".json", ".html", ".htm") }
        } else {
            @(Get-Item $MockSourcePath)
        }
        foreach ($mf in $mockFiles) {
            $rawText = Get-Content -Path $mf.FullName -Raw -Encoding UTF8
            $parsedJobs = ConvertFrom-AtsPayload -RawContent $rawText -SourceHint $mf.Name
            foreach ($pj in $parsedJobs) { $rawExtractedJobs.Add($pj) }
        }
    }

    # 3b. Process single job URL extraction (-ExtractUrl)
    if (-not [string]::IsNullOrWhiteSpace($ExtractUrl)) {
        Write-Host "`n[*] Extracting structured job posting from: $ExtractUrl" -ForegroundColor Cyan
        $apiEndpoint = $ExtractUrl
        $boardSlug = ""
        if ($ExtractUrl -match "greenhouse\.io/([^/]+)/jobs/(\d+)") {
            $boardSlug = $matches[1]
            $jobId = $matches[2]
            $apiEndpoint = "https://boards-api.greenhouse.io/v1/boards/$boardSlug/jobs/$jobId"
        } elseif ($ExtractUrl -match "jobs\.lever\.co/([^/]+)/([0-9a-fA-F]{8}-[0-9a-fA-F0-9\-]+)") {
            $boardSlug = $matches[1]
            $jobId = $matches[2]
            $apiEndpoint = "https://api.lever.co/v0/postings/$boardSlug/$jobId?mode=json"
        }

        try {
            $fetchedContent = Invoke-HttpTextFetch -Uri $apiEndpoint
            $parsedJobs = ConvertFrom-AtsPayload -RawContent $fetchedContent -SourceHint $ExtractUrl -BoardSlug $boardSlug
            if ($parsedJobs.Count -eq 0 -and $apiEndpoint -ne $ExtractUrl) {
                $htmlContent = Invoke-HttpTextFetch -Uri $ExtractUrl
                $parsedJobs = ConvertFrom-AtsPayload -RawContent $htmlContent -SourceHint $ExtractUrl -BoardSlug $boardSlug
            }
            foreach ($pj in $parsedJobs) { $rawExtractedJobs.Add($pj) }
        } catch {
            Write-Host "[!] Warning: Failed to fetch $ExtractUrl : $_" -ForegroundColor Yellow
        }
    }

    # 3c. Process ATS Public Board APIs (-Boards / -FetchBoards)
    foreach ($boardEntry in $boardList) {
        $platform = ""
        $slug = ""
        $compLabel = ""

        if ($boardEntry -is [string]) {
            $bStr = ([string]$boardEntry).Trim()
            if ($bStr -match "^(greenhouse|lever|ashby):(.+)$") {
                $platform = $matches[1].ToLowerInvariant()
                $slug = $matches[2].Trim()
            } elseif ($bStr -match "greenhouse\.io/([^/\?]+)") {
                $platform = "greenhouse"
                $slug = $matches[1]
            } elseif ($bStr -match "lever\.co/([^/\?]+)") {
                $platform = "lever"
                $slug = $matches[1]
            } elseif ($bStr -match "ashbyhq\.com/([^/\?]+)") {
                $platform = "ashby"
                $slug = $matches[1]
            }
        } else {
            $platform = ([string]$boardEntry.platform).ToLowerInvariant()
            $slug = [string]$boardEntry.board
            $compLabel = [string]$boardEntry.company
        }

        if ([string]::IsNullOrWhiteSpace($platform) -or [string]::IsNullOrWhiteSpace($slug)) {
            Write-Host "[!] Skipping unrecognized board specifier: $boardEntry" -ForegroundColor Yellow
            continue
        }

        $apiUrl = switch ($platform) {
            "greenhouse" { "https://boards-api.greenhouse.io/v1/boards/$slug/jobs?content=true" }
            "lever"      { "https://api.lever.co/v0/postings/$slug?mode=json" }
            "ashby"      { "https://api.ashbyhq.com/posting-api/job-board/$slug?includeCompensation=true" }
        }

        Write-Host "[*] Fetching $platform board '$slug' via Public JSON API..." -ForegroundColor Cyan
        try {
            $payload = Invoke-HttpTextFetch -Uri $apiUrl
            $parsed = ConvertFrom-AtsPayload -RawContent $payload -SourceHint $platform -CompanyOverride $compLabel -BoardSlug $slug
            Write-Host "    Retrieved $($parsed.Count) raw postings from $slug." -ForegroundColor Gray
            foreach ($pj in $parsed) { $rawExtractedJobs.Add($pj) }
        } catch {
            Write-Host "[!] Warning: Public API fetch failed for $platform`:$slug : $_" -ForegroundColor Yellow
        }
    }

    # 3d. Score & Evaluate All Extracted Postings
    $minScore = if ($null -ne $config.execution_settings -and $null -ne $config.execution_settings.min_fit_score_to_inbox) {
        [int]$config.execution_settings.min_fit_score_to_inbox
    } else {
        65
    }
    $todayStr = (Get-Date).ToString("yyyy-MM-dd")
    $qualifiedLeads = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($job in $rawExtractedJobs) {
        $eval = Get-JobFitEvaluation -Job $job -ConfigObj $config -ContactsList $contactsList
        if ($eval.FilteredOut) { continue }

        if ($eval.FitScore -ge $minScore -or -not [string]::IsNullOrWhiteSpace($eval.WarmContact)) {
            $slugComp = ($job.company.ToLowerInvariant() -replace "[^a-z0-9]+", "_").Trim("_")
            $reqPart = if (-not [string]::IsNullOrWhiteSpace($job.requisition_id)) {
                ($job.requisition_id -replace "[^a-zA-Z0-9]+", "").Substring(0, [math]::Min(8, ($job.requisition_id -replace "[^a-zA-Z0-9]+", "").Length))
            } else {
                [guid]::NewGuid().ToString("N").Substring(0, 6)
            }
            $leadId = "lead_${slugComp}_${reqPart}"

            $qualifiedLeads.Add([PSCustomObject]@{
                id              = $leadId
                company         = $job.company
                title           = $job.title
                requisition_id  = $job.requisition_id
                url             = $job.url
                ats_platform    = $job.ats_platform
                location        = $job.location
                compensation    = $job.compensation
                fit_score       = $eval.FitScore
                likelihood      = $eval.Likelihood
                warm_contact    = $eval.WarmContact
                discovered_date = $todayStr
                status          = "active"
                notes           = $eval.Notes
            })
        }
    }

    $sortedQualified = @($qualifiedLeads | Sort-Object -Property @{Expression = { $_.fit_score }; Descending = $true })
    Write-Host "`n=== Direct ATS Extraction & Scoring Summary ===" -ForegroundColor Cyan
    Write-Host "Raw Postings Evaluated: $($rawExtractedJobs.Count)"
    Write-Host "Qualified Leads (>=${minScore}%): $($sortedQualified.Count)" -ForegroundColor Green

    foreach ($ql in $sortedQualified) {
        $refTag = if (-not [string]::IsNullOrWhiteSpace($ql.warm_contact)) { " [Referral: $($ql.warm_contact)]" } else { "" }
        Write-Host "  [+] [$($ql.fit_score)% | $($ql.likelihood)] $($ql.company) - $($ql.title) ($($ql.location))$refTag" -ForegroundColor Green
    }

    if ($Ingest -and -not $DryRun) {
        $inboxObj = Get-Content -Path $InboxJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $existingLeads = [System.Collections.Generic.List[object]]::new()
        foreach ($el in @($inboxObj.leads)) {
            if ($null -ne $el) { $existingLeads.Add($el) }
        }

        # Check ledger.json as well to prevent re-ingesting already applied/active applications
        $ledgerPath = Join-Path (Split-Path $InboxJsonPath -Parent) "ledger.json"
        $ledgerUrls = @{}
        if (Test-Path $ledgerPath) {
            try {
                $ledgerObj = Get-Content -Path $ledgerPath -Raw -Encoding UTF8 | ConvertFrom-Json
                foreach ($app in @($ledgerObj.applications)) {
                    if ($null -ne $app -and -not [string]::IsNullOrWhiteSpace([string]$app.url)) {
                        $ledgerUrls[([string]$app.url).ToLowerInvariant()] = $true
                    }
                }
            } catch {}
        }

        $addedCount = 0
        foreach ($newLead in $sortedQualified) {
            $urlKey = ([string]$newLead.url).ToLowerInvariant()
            if ($ledgerUrls.ContainsKey($urlKey)) { continue }

            $dup = $existingLeads | Where-Object {
                ([string]$_.url -eq [string]$newLead.url) -or
                ((-not [string]::IsNullOrWhiteSpace([string]$newLead.requisition_id)) -and ($_.company -eq $newLead.company) -and ($_.requisition_id -eq $newLead.requisition_id))
            } | Select-Object -First 1

            if ($null -eq $dup) {
                $existingLeads.Add($newLead)
                $addedCount++
            } else {
                # Update score/notes on existing lead
                Set-OrAddProp -Obj $dup -Name "fit_score" -Val $newLead.fit_score
                Set-OrAddProp -Obj $dup -Name "likelihood" -Val $newLead.likelihood
                if (-not [string]::IsNullOrWhiteSpace($newLead.warm_contact)) {
                    Set-OrAddProp -Obj $dup -Name "warm_contact" -Val $newLead.warm_contact
                }
                if (-not [string]::IsNullOrWhiteSpace($newLead.compensation)) {
                    Set-OrAddProp -Obj $dup -Name "compensation" -Val $newLead.compensation
                }
            }
        }

        $finalSorted = @($existingLeads | Sort-Object -Property @{Expression = { [double]$_.fit_score }; Descending = $true })
        $activeCount = @($finalSorted | Where-Object { [string]$_.status -notin @("archived", "passed", "graduated", "closed") }).Count

        Set-OrAddProp -Obj $inboxObj -Name "leads" -Val ([object[]]$finalSorted)
        Set-OrAddProp -Obj $inboxObj.meta -Name "last_scanned" -Val (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
        Set-OrAddProp -Obj $inboxObj.meta -Name "total_leads" -Val $finalSorted.Count
        Set-OrAddProp -Obj $inboxObj.meta -Name "active_leads" -Val $activeCount

        # Guard single-element array serialization in PS 5.1
        $jsonOut = $inboxObj | ConvertTo-Json -Depth 10
        if ($finalSorted.Count -eq 1) {
            $parsedBack = $jsonOut | ConvertFrom-Json
            if ($parsedBack.leads -isnot [System.Array]) {
                $jsonOut = [regex]::Replace($jsonOut, '"leads"\s*:\s*\{', '"leads": [' + "`r`n        {", 1)
                $jsonOut = [regex]::Replace($jsonOut, '(\}\s*,\s*"\$schema"|\}\s*,\s*"meta"|\}\s*\}\s*$)', "}`r`n    ]`$1", 1)
            }
        }
        Set-Content -Path $InboxJsonPath -Value $jsonOut -Encoding UTF8
        Write-Host "[+] Ingested $addedCount new qualified lead(s) into $InboxJsonPath (Active: $activeCount)." -ForegroundColor Green

        Update-SourcingInboxMarkdown -JsonFilePath $InboxJsonPath -MdFilePath $InboxMdPath
    }

    $global:LASTEXITCODE = 0
    exit 0
}

# --- 4. SEARCH BATCH CONSTRUCTION MODE (Default / -DryRun) ---
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

Write-Host "`nTo execute these queries live, activate the autonomous 'ats-job-scanner' skill or run with -FetchBoards / -Boards / -ExtractUrl -Ingest." -ForegroundColor Cyan
Write-Host "The scanner will extract structured postings, score job matches against your profile, cross-reference your network contacts, and populate applications/sourcing_inbox.json & .md."
$global:LASTEXITCODE = 0
exit 0
