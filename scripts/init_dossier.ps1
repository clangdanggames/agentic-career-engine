<#
.SYNOPSIS
    ACE Application Dossier Scaffolder & Clean-Room Resume Forker (Rule 3 & Rule 4 Enforcer)
.DESCRIPTION
    Creates an isolated application dossier directory (applications/YYYY-MM-DD_[company]_[reqid]/),
    performs a strict clean-room fork of the candidate's Master Resume (Rule 4) while stripping
    internal [Level 1/2/3] tags (Rule 3), and pre-populates application_form_guide.md,
    job_description.md, cover_letter.md, and interview_prep.md using the candidate's identity
    and compensation parameters from workflows/ats_search_config.json and applications/ledger.json.
.PARAMETER Company
    Mandatory: Target company name (e.g. "NovaTech Systems").
.PARAMETER Role
    Mandatory: Target role title (e.g. "Senior Platform Engineer").
.PARAMETER RequisitionId
    Optional: Requisition ID or slug (e.g. "4829103").
.PARAMETER Url
    Optional: Direct requisition URL.
.PARAMETER AtsPlatform
    Optional: ATS platform name (auto-detected from Url if omitted).
.PARAMETER PostingCompensation
    Optional: Stated salary range from the job description (e.g. "$165,000 - $195,000").
.PARAMETER RecommendedCompensation
    Optional: Specific numeric target salary to recommend for Field 9 (auto-calibrated if omitted).
.PARAMETER FitScore
    Optional: Calculated 0-100 Personal Fit Score.
.PARAMETER RawJobDescriptionText
    Optional: Raw job description text to embed into job_description.md.
.PARAMETER RawJobDescriptionPath
    Optional: Path to a text/markdown file containing the raw job description.
.PARAMETER MasterResumePath
    Optional: Path to the candidate's Master Resume (auto-detected from resumes/ if omitted).
.PARAMETER RegisterInLedger
    Optional switch: Immediately logs the scaffolded dossier as 'in_progress' in applications/ledger.json
    and graduates any matching lead from applications/sourcing_inbox.json via scripts/sync_pipeline.ps1.
.PARAMETER Force
    Optional switch: Overwrite existing files in the target dossier folder instead of creating a _2 suffix.
#>
param (
    [Parameter(Mandatory = $true)]
    [string]$Company,

    [Parameter(Mandatory = $true)]
    [string]$Role,

    [Parameter(Mandatory = $false)]
    [string]$RequisitionId = "",

    [Parameter(Mandatory = $false)]
    [string]$Url = "",

    [Parameter(Mandatory = $false)]
    [string]$AtsPlatform = "",

    [Parameter(Mandatory = $false)]
    [string]$PostingCompensation = "",

    [Parameter(Mandatory = $false)]
    [int]$RecommendedCompensation = 0,

    [Parameter(Mandatory = $false)]
    [double]$FitScore = -1,

    [Parameter(Mandatory = $false)]
    [string]$RawJobDescriptionText = "",

    [Parameter(Mandatory = $false)]
    [string]$RawJobDescriptionPath = "",

    [Parameter(Mandatory = $false)]
    [string]$MasterResumePath = "",

    [Parameter(Mandatory = $false)]
    [switch]$RegisterInLedger,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$workspaceRoot = (Resolve-Path "$PSScriptRoot/..").Path
$applicationsDir = Join-Path $workspaceRoot "applications"
$templateDir = Join-Path $applicationsDir "dossier_template"
$resumesDir = Join-Path $workspaceRoot "resumes"
$configPath = Join-Path $workspaceRoot "workflows/ats_search_config.json"
$ledgerPath = Join-Path $applicationsDir "ledger.json"

if (-not (Test-Path $templateDir)) {
    Write-Host "[!] ERROR: Dossier template directory not found at: $templateDir" -ForegroundColor Red
    exit 1
}

# 1. Resolve Master Resume Path (Rule 4 Clean-Room Source)
if ([string]::IsNullOrWhiteSpace($MasterResumePath)) {
    $candidates = @(Get-ChildItem -Path $resumesDir -Filter "*_Resume_Master.md" -File -ErrorAction SilentlyContinue)
    if ($candidates.Count -eq 0) {
        $candidates = @(Get-ChildItem -Path $resumesDir -Filter "*Master*.md" -File -ErrorAction SilentlyContinue)
    }
    if ($candidates.Count -eq 0) {
        $candidates = @(Get-ChildItem -Path $resumesDir -Filter "*.md" -File -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -notin @("modular_reserve_bank.md", "resume_template.md", "README.md")
        })
    }
    if ($candidates.Count -gt 0) {
        $MasterResumePath = $candidates[0].FullName
    } else {
        $fallbackTemplate = Join-Path $resumesDir "resume_template.md"
        if (Test-Path $fallbackTemplate) {
            $MasterResumePath = $fallbackTemplate
        } else {
            Write-Host "[!] ERROR: Could not auto-detect Master Resume in $resumesDir." -ForegroundColor Red
            exit 1
        }
    }
} elseif (-not (Test-Path $MasterResumePath)) {
    Write-Host "[!] ERROR: Master Resume not found at: $MasterResumePath" -ForegroundColor Red
    exit 1
}

$masterContent = Get-Content -Path $MasterResumePath -Raw -Encoding UTF8
$masterLines = $masterContent -split "\r?\n"

# 2. Extract Candidate Identity Metadata from Master Resume & Ledger
$candidateName = "Candidate Name"
$candidateLocation = "Remote, USA"
$candidateEmail = "email@example.com"
$candidatePhone = "(555) 000-0000"
$candidateLinkedIn = "https://linkedin.com"

if ($masterLines.Count -ge 1 -and $masterLines[0] -match "^#\s+(.+)$") {
    $extractedName = $matches[1].Trim()
    if ($extractedName -notmatch "^\[") {
        $candidateName = $extractedName
    }
}

if ($masterLines.Count -ge 2) {
    $contactLine = $masterLines[1].Trim()
    $pipeParts = @($contactLine -split "\|" | ForEach-Object { $_.Trim() })
    if ($pipeParts.Count -ge 1 -and $pipeParts[0] -notmatch "^\[") {
        $candidateLocation = $pipeParts[0]
    }
    foreach ($part in $pipeParts) {
        if ($part -match "([a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,})") {
            $emailCandidate = $matches[1]
            if ($emailCandidate -ne "email@domain.com") {
                $candidateEmail = $emailCandidate
            }
        }
        if ($part -match "(\+?1?[\s\-\.]?\(?\d{3}\)?[\s\-\.]?\d{3}[\s\-\.]?\d{4})") {
            $candidatePhone = $matches[1].Trim()
        }
        if ($part -match "linkedin\.com/[^\)\]\s]+") {
            $liMatch = $matches[0]
            if ($liMatch -notmatch "username") {
                $candidateLinkedIn = if ($liMatch -match "^https?://") { $liMatch } else { "https://$liMatch" }
            }
        }
    }
}

# Fallback candidate name & compensation from ledger.json / ats_search_config.json
$targetComp = 150000
$floorComp = 100000
$relocComp = 180000

if (Test-Path $ledgerPath) {
    try {
        $ledgerObj = Get-Content -Path $ledgerPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($candidateName -eq "Candidate Name" -and -not [string]::IsNullOrWhiteSpace([string]$ledgerObj.meta.candidate) -and $ledgerObj.meta.candidate -ne "Candidate Name") {
            $candidateName = [string]$ledgerObj.meta.candidate
        }
        if ($null -ne $ledgerObj.meta.compensation_target) {
            if ($null -ne $ledgerObj.meta.compensation_target.target) { $targetComp = [int]$ledgerObj.meta.compensation_target.target }
            if ($null -ne $ledgerObj.meta.compensation_target.minimum) { $floorComp = [int]$ledgerObj.meta.compensation_target.minimum }
            if ($null -ne $ledgerObj.meta.compensation_target.relocation_minimum) { $relocComp = [int]$ledgerObj.meta.compensation_target.relocation_minimum }
        }
    } catch {}
}

if (Test-Path $configPath) {
    try {
        $cfgObj = Get-Content -Path $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($null -ne $cfgObj.search_criteria -and $null -ne $cfgObj.search_criteria.compensation) {
            if ($null -ne $cfgObj.search_criteria.compensation.target) { $targetComp = [int]$cfgObj.search_criteria.compensation.target }
            if ($null -ne $cfgObj.search_criteria.compensation.floor) { $floorComp = [int]$cfgObj.search_criteria.compensation.floor }
            if ($null -ne $cfgObj.search_criteria.compensation.relocation_floor) { $relocComp = [int]$cfgObj.search_criteria.compensation.relocation_floor }
        }
    } catch {}
}

# 3. Calibrate Role Compensation Recommendation
$calibratedComp = $RecommendedCompensation
if ($calibratedComp -le 0) {
    if (-not [string]::IsNullOrWhiteSpace($PostingCompensation)) {
        $enDash = [string][char]0x2013
        $emDash = [string][char]0x2014
        $normComp = $PostingCompensation.Replace($enDash, "-").Replace($emDash, "-")
        $nums = [System.Collections.Generic.List[double]]::new()
        $numMatches = [regex]::Matches($normComp, '\$?([0-9]{2,3}(?:,[0-9]{3})+|[0-9]{2,3})([kK])?')
        foreach ($m in $numMatches) {
            $val = 0.0
            if ([double]::TryParse(($m.Groups[1].Value -replace ",", ""), [ref]$val)) {
                if ($m.Groups[2].Success -or $val -lt 1000) { $val = $val * 1000 }
                if ($val -ge 30000) { $nums.Add($val) }
            }
        }
        if ($nums.Count -ge 2) {
            $lowBand = ($nums | Measure-Object -Minimum).Minimum
            $highBand = ($nums | Measure-Object -Maximum).Maximum
            # 70th percentile of posted salary band, rounded to nearest 1,000, floored at $floorComp
            $pct70 = $lowBand + (($highBand - $lowBand) * 0.70)
            $calibratedComp = [int]([math]::Round($pct70 / 1000.0) * 1000)
            if ($calibratedComp -lt $floorComp) { $calibratedComp = $floorComp }
        } elseif ($nums.Count -eq 1) {
            $calibratedComp = [int]$nums[0]
        }
    }
    if ($calibratedComp -le 0) {
        $calibratedComp = $targetComp
    }
}

$targetCompStr = "`$$($targetComp.ToString('N0'))"
$floorCompStr = "`$$($floorComp.ToString('N0'))"
$calibratedCompStr = "`$$($calibratedComp.ToString('N0'))"
$targetMaxComp = [int]([math]::Round(($targetComp * 1.15) / 1000.0) * 1000)
$targetMaxCompStr = "`$$($targetMaxComp.ToString('N0'))"

# 4. Resolve ATS Platform, Slugs, and Dossier Directory Path
if ([string]::IsNullOrWhiteSpace($AtsPlatform)) {
    if ($Url -match "greenhouse\.io") { $AtsPlatform = "Greenhouse" }
    elseif ($Url -match "lever\.co") { $AtsPlatform = "Lever" }
    elseif ($Url -match "ashbyhq\.com") { $AtsPlatform = "Ashby" }
    elseif ($Url -match "myworkdayjobs\.com") { $AtsPlatform = "Workday" }
    else { $AtsPlatform = "Direct Portal" }
}

if ([string]::IsNullOrWhiteSpace($RequisitionId) -and -not [string]::IsNullOrWhiteSpace($Url)) {
    if ($Url -match "/jobs/(\d+)") {
        $RequisitionId = $matches[1]
    } elseif ($Url -match "([0-9a-fA-F]{8}-[0-9a-fA-F]{4})") {
        $RequisitionId = $matches[1]
    }
}

$today = (Get-Date).ToString("yyyy-MM-dd")
$companySlug = ($Company.ToLowerInvariant() -replace "[^a-z0-9]+", "_").Trim("_")
$companyPascal = (($Company -replace "[^a-zA-Z0-9\s]+", "") -split "\s+" | Where-Object { $_ -ne "" } | ForEach-Object {
    $_.Substring(0, 1).ToUpperInvariant() + $_.Substring(1)
}) -join "_"

$reqOrRoleSlug = if (-not [string]::IsNullOrWhiteSpace($RequisitionId)) {
    ($RequisitionId -replace "[^a-zA-Z0-9]+", "").Trim()
} else {
    ($Role.ToLowerInvariant() -replace "[^a-z0-9]+", "_").Trim("_")
}

$baseFolderName = "${today}_${companySlug}_${reqOrRoleSlug}"
$dossierFolderName = $baseFolderName
$dossierFullPath = Join-Path $applicationsDir $dossierFolderName

if ((Test-Path $dossierFullPath) -and -not $Force) {
    $suffix = 2
    while (Test-Path (Join-Path $applicationsDir "${baseFolderName}_${suffix}")) {
        $suffix++
    }
    $dossierFolderName = "${baseFolderName}_${suffix}"
    $dossierFullPath = Join-Path $applicationsDir $dossierFolderName
}

New-Item -ItemType Directory -Path $dossierFullPath -Force | Out-Null
$relativeDossierPath = "applications/$dossierFolderName"

# 5. Clean-Room Fork of Master Resume (Rule 4) & Tag Scrubbing (Rule 3 & Rule 9)
$candidateSlug = (($candidateName -replace "[^a-zA-Z0-9\s]+", "") -split "\s+" | Where-Object { $_ -ne "" }) -join "_"
if ([string]::IsNullOrWhiteSpace($candidateSlug) -or $candidateSlug -eq "Candidate_Name") {
    $candidateSlug = "Candidate"
}
$reqFileTag = if (-not [string]::IsNullOrWhiteSpace($RequisitionId)) {
    ($RequisitionId -replace "[^a-zA-Z0-9]+", "")
} else {
    (($Role -replace "[^a-zA-Z0-9\s]+", "") -split "\s+" | Select-Object -First 3) -join "_"
}

$resumeBaseName = "${candidateSlug}_Resume_${companyPascal}_${reqFileTag}"
$tailoredResumeMdName = "$resumeBaseName.md"
$tailoredResumePdfName = "$resumeBaseName.pdf"
$tailoredResumeFullPath = Join-Path $dossierFullPath $tailoredResumeMdName

$cleanForkContent = $masterContent
# Strip any internal [Level 1], [Level 2], [Level 3] or (Level 1/2/3) markers
$cleanForkContent = $cleanForkContent -replace "\s*\[Level\s*[123]\]", ""
$cleanForkContent = $cleanForkContent -replace "\s*\(Level\s*[123]\)", ""
# Scrub any raw em dashes (Rule 9)
$emDash = [string][char]0x2014
$cleanForkContent = $cleanForkContent.Replace(" $emDash ", ", ").Replace($emDash, " - ")

Set-Content -Path $tailoredResumeFullPath -Value $cleanForkContent -Encoding UTF8

# 6. Pre-Populate application_form_guide.md
$formGuideTemplate = Get-Content -Path (Join-Path $templateDir "application_form_guide.md") -Raw -Encoding UTF8
$reqDisplay = if (-not [string]::IsNullOrWhiteSpace($RequisitionId)) { "#$($RequisitionId.TrimStart('#'))" } else { "N/A" }
$urlDisplay = if (-not [string]::IsNullOrWhiteSpace($Url)) { $Url } else { "Pending Direct URL" }
$postingCompDisplay = if (-not [string]::IsNullOrWhiteSpace($PostingCompensation)) {
    $PostingCompensation.Replace($emDash, "-")
} else {
    "Unlisted (Estimated $targetCompStr - $targetMaxCompStr via workflows/compensation_estimator.md)"
}

$formGuideOut = $formGuideTemplate
$formGuideOut = $formGuideOut.Replace("[Company Name]", $Company)
$formGuideOut = $formGuideOut.Replace("[Target Role Title]", $Role)
$formGuideOut = $formGuideOut.Replace("[e.g., #104829]", $reqDisplay)
$formGuideOut = $formGuideOut.Replace("[Greenhouse / Lever / Ashby / Workday / Direct Portal]", $AtsPlatform)
$formGuideOut = $formGuideOut.Replace("[Paste Direct Application URL]", $urlDisplay)
$formGuideOut = $formGuideOut.Replace("[Candidate Name]", $candidateName)
$formGuideOut = $formGuideOut.Replace("[Candidate Email]", $candidateEmail)
$formGuideOut = $formGuideOut.Replace("[Candidate Phone]", $candidatePhone)
$formGuideOut = $formGuideOut.Replace("[Candidate_Name]_Resume_[Company]_[ReqID].pdf", $tailoredResumePdfName)
$formGuideOut = $formGuideOut.Replace("[Candidate LinkedIn URL]", $candidateLinkedIn)
$formGuideOut = $formGuideOut.Replace("[Country]", "United States")
$formGuideOut = $formGuideOut.Replace("[City, State / Metro Region]", $candidateLocation)
$formGuideOut = $formGuideOut.Replace("`$([Target Base from ats_search_config.json])", $targetCompStr)
$formGuideOut = $formGuideOut.Replace("`$[Target Base from ats_search_config.json]", $targetCompStr)
$formGuideOut = $formGuideOut.Replace("`$[Target Base from workflows/ats_search_config.json]", $targetCompStr)
$formGuideOut = $formGuideOut.Replace("`$[Floor]", $floorCompStr)
$formGuideOut = $formGuideOut.Replace("`$[Calibrated Target, e.g. 165000]", $calibratedCompStr)
$formGuideOut = $formGuideOut.Replace("`$[Calculated Target, e.g. 165000]", $calibratedCompStr)
$formGuideOut = $formGuideOut.Replace("[Recommended Number, e.g. 165000]", [string]$calibratedComp)
$formGuideOut = $formGuideOut.Replace("`$[Recommended]", $calibratedCompStr)
$formGuideOut = [regex]::Replace($formGuideOut, '\$\[Stated JD Range[^\]]*\]', $postingCompDisplay)
$formGuideOut = $formGuideOut.Replace("[Company]", $Company)
$formGuideOut = $formGuideOut.Replace($emDash, "-")

Set-Content -Path (Join-Path $dossierFullPath "application_form_guide.md") -Value $formGuideOut -Encoding UTF8

# 7. Pre-Populate job_description.md
$jdTemplate = Get-Content -Path (Join-Path $templateDir "job_description.md") -Raw -Encoding UTF8
$rawJdBody = $RawJobDescriptionText
if ([string]::IsNullOrWhiteSpace($rawJdBody) -and -not [string]::IsNullOrWhiteSpace($RawJobDescriptionPath) -and (Test-Path $RawJobDescriptionPath)) {
    $rawJdBody = Get-Content -Path $RawJobDescriptionPath -Raw -Encoding UTF8
}
if ([string]::IsNullOrWhiteSpace($rawJdBody)) {
    $rawJdBody = "[Paste the raw, unedited job description text here for deterministic reference]"
}
$fitDisplay = if ($FitScore -ge 0) { "$FitScore/100" } else { "Pending Evaluation" }

$jdOut = $jdTemplate
$jdOut = $jdOut.Replace("[Role Title]", $Role)
$jdOut = $jdOut.Replace("[Company Name]", $Company)
$jdOut = $jdOut.Replace("[YYYY-MM-DD]", $today)
$jdOut = $jdOut.Replace("[Direct / Greenhouse / Lever / Ashby / Workday / Referral]", $AtsPlatform)
$jdOut = $jdOut.Replace("[Paste Link]", $urlDisplay)
$jdOut = $jdOut.Replace("[e.g., 88/100]", $fitDisplay)
$jdOut = $jdOut.Replace("[e.g., `$160,000 - `$185,000 + Equity]", $postingCompDisplay)
$jdOut = $jdOut.Replace("[Paste the raw, unedited job description text here for deterministic reference]", $rawJdBody)
$jdOut = $jdOut.Replace($emDash, "-")

Set-Content -Path (Join-Path $dossierFullPath "job_description.md") -Value $jdOut -Encoding UTF8

# 8. Pre-Populate cover_letter.md
$clTemplate = Get-Content -Path (Join-Path $templateDir "cover_letter.md") -Raw -Encoding UTF8
$clOut = $clTemplate
$clOut = $clOut.Replace("[Role Title]", $Role)
$clOut = $clOut.Replace("[Company Name]", $Company)
$clOut = $clOut.Replace("[Candidate Name]", $candidateName)
$clOut = $clOut.Replace("[Candidate Location]", $candidateLocation)
$clOut = $clOut.Replace("[City, State / Remote]", $candidateLocation)
$clOut = $clOut.Replace("[Candidate Email]", $candidateEmail)
$clOut = $clOut.Replace("[Email]", $candidateEmail)
$clOut = $clOut.Replace("[Phone]", $candidatePhone)
$clOut = $clOut.Replace("[Candidate LinkedIn URL]", $candidateLinkedIn)
$clOut = $clOut.Replace("[LinkedIn Profile URL]", $candidateLinkedIn)
$clOut = $clOut.Replace("[ReqID / Link]", $reqDisplay)
$clOut = $clOut.Replace($emDash, "-")

Set-Content -Path (Join-Path $dossierFullPath "cover_letter.md") -Value $clOut -Encoding UTF8

# 9. Pre-Populate interview_prep.md
$prepTemplate = Get-Content -Path (Join-Path $templateDir "interview_prep.md") -Raw -Encoding UTF8
$prepOut = $prepTemplate
$prepOut = $prepOut.Replace("[Company Name]", $Company)
$prepOut = $prepOut.Replace("[Company]", $Company)
$prepOut = $prepOut.Replace("[Role Title]", $Role)
$prepOut = $prepOut.Replace("[Target Title]", $Role)
$prepOut = $prepOut.Replace("[ReqID]", $reqDisplay)
$prepOut = $prepOut.Replace("`$[Target Min]", $targetCompStr)
$prepOut = $prepOut.Replace("`$[Target Max]", $targetMaxCompStr)
$prepOut = $prepOut.Replace("`$[Target Mid]", $calibratedCompStr)
$prepOut = $prepOut.Replace("`$[Hard Floor]", $floorCompStr)
$prepOut = $prepOut.Replace($emDash, "-")

Set-Content -Path (Join-Path $dossierFullPath "interview_prep.md") -Value $prepOut -Encoding UTF8

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "ACE APPLICATION DOSSIER SCAFFOLDED (Rule 3 & Rule 4)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Dossier Folder:       $relativeDossierPath" -ForegroundColor Green
Write-Host "Clean-Room Resume:    $relativeDossierPath/$tailoredResumeMdName" -ForegroundColor Green
Write-Host "Form Guide (Field 9): Configured Target $targetCompStr (Floor $floorCompStr) | Calibrated: $calibratedCompStr"
Write-Host "Scaffolded Assets:    job_description.md, application_form_guide.md, cover_letter.md, interview_prep.md"

if ($RegisterInLedger) {
    $syncScript = Join-Path $PSScriptRoot "sync_pipeline.ps1"
    if (Test-Path $syncScript) {
        $compToLog = if (-not [string]::IsNullOrWhiteSpace($PostingCompensation)) { $PostingCompensation } else { $calibratedCompStr }
        & $syncScript -Company $Company -Role $Role -RequisitionId $RequisitionId -Url $Url -Status "in_progress" -DossierPath $relativeDossierPath -Compensation $compToLog -FitScore $FitScore -GraduateFromInbox -UpdateDashboard
    }
}

$global:LASTEXITCODE = 0
exit 0
