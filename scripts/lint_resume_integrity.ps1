<#
.SYNOPSIS
    Integrity Linter for Tailored Resumes against Master Resume and Reserve Bank.
.DESCRIPTION
    Enforces Operational Rule 3 (The Closed-Set Whitelist Rule):
    Verifies that no unverified technical tools, certifications, platforms, or buzzwords
    appear in a tailored resume unless they are explicitly present in the candidate's
    Master Resume or Modular Reserve Bank.
.PARAMETER TailoredResumePath
    Path to the tailored markdown resume to verify.
.PARAMETER MasterResumePath
    Path to the master resume repository (defaults to auto-detecting resumes/*_Resume_Master.md).
.PARAMETER ReserveBankPath
    Path to the modular reserve bank (defaults to resumes/modular_reserve_bank.md if present).
#>
param (
    [Parameter(Mandatory = $true)]
    [string]$TailoredResumePath,

    [Parameter(Mandatory = $false)]
    [string]$MasterResumePath = "",

    [Parameter(Mandatory = $false)]
    [string]$ReserveBankPath = "resumes/modular_reserve_bank.md"
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$workspaceRoot = (Resolve-Path "$PSScriptRoot\..").Path

# Resolve tailored resume path
if (-not (Test-Path $TailoredResumePath)) {
    $resolvedTailored = Join-Path $workspaceRoot $TailoredResumePath
    if (Test-Path $resolvedTailored) {
        $TailoredResumePath = $resolvedTailored
    } else {
        Write-Error "Tailored resume file not found: $TailoredResumePath"
        exit 1
    }
}

# Auto-detect master resume if not explicitly passed
if ([string]::IsNullOrWhiteSpace($MasterResumePath)) {
    $resumesDir = Join-Path $workspaceRoot "resumes"
    $masters = Get-ChildItem -Path $resumesDir -Filter "*_Resume_Master.md" -File -ErrorAction SilentlyContinue
    if ($masters.Count -gt 0) {
        $MasterResumePath = $masters[0].FullName
    } else {
        # Fall back to demo or template
        $demoMaster = Join-Path $workspaceRoot "examples\demo_showcase\Alex_Morgan_Resume.md"
        if (Test-Path $demoMaster) {
            $MasterResumePath = $demoMaster
        } else {
            Write-Error "No Master Resume found. Please provide a path to resumes/[Your_Name]_Resume_Master.md"
            exit 1
        }
    }
} elseif (-not (Test-Path $MasterResumePath)) {
    $resolvedMaster = Join-Path $workspaceRoot $MasterResumePath
    if (Test-Path $resolvedMaster) {
        $MasterResumePath = $resolvedMaster
    } else {
        Write-Error "Master resume file not found: $MasterResumePath"
        exit 1
    }
}

$tailoredText = Get-Content -Path $TailoredResumePath -Raw -Encoding UTF8
$masterText = Get-Content -Path $MasterResumePath -Raw -Encoding UTF8

# Combine with reserve bank if present
$resolvedReserve = if (Test-Path $ReserveBankPath) { $ReserveBankPath } else { Join-Path $workspaceRoot $ReserveBankPath }
if (Test-Path $resolvedReserve) {
    $reserveText = Get-Content -Path $resolvedReserve -Raw -Encoding UTF8
    $whitelistCorpus = "$masterText`n$reserveText"
    $hasReserve = $true
} else {
    $whitelistCorpus = $masterText
    $hasReserve = $false
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "🛡️  ACE RESUME INTEGRITY LINTER (Rule 3 Whitelist Check)" -ForegroundColor Cyan
Write-Host "Target:   $(Split-Path $TailoredResumePath -Leaf)" -ForegroundColor Cyan
Write-Host "Master:   $(Split-Path $MasterResumePath -Leaf)" -ForegroundColor Cyan
if ($hasReserve) {
    Write-Host "Reserve:  $(Split-Path $resolvedReserve -Leaf)" -ForegroundColor Cyan
}
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. High-Risk / Commonly Hallucinated Keyword Sentry
# Checks for common buzzwords that models sycophantically backfill from JDs
$highRiskKeywords = @(
    "Kubernetes", "K8s", "Terraform", "AWS", "Amazon Web Services", "Azure",
    "GCP", "Google Cloud", "Linux Administration", "Linux Admin", "Golang",
    "Ansible", "Chef", "Puppet", "Prometheus", "OpenTelemetry", "Spacelift",
    "Swift", "Kotlin", "React Native", "Salesforce", "Epic EHR", "SAP",
    "Workday", "Six Sigma Black Belt", "PMP", "CPA", "FINRA Series 7"
)

$hallucinatedFound = [System.Collections.Generic.List[string]]::new()
foreach ($buzz in $highRiskKeywords) {
    $buzzPattern = [regex]::Escape($buzz)
    if ($tailoredText -match "(?i)\b$buzzPattern\b") {
        if ($whitelistCorpus -notmatch "(?i)\b$buzzPattern\b") {
            $hallucinatedFound.Add($buzz)
        }
    }
}

# 2. Extract Skill Tokens from Core Competencies & Skills sections
function Extract-CompetencyTokens {
    param ([string]$content)
    
    $tokensList = [System.Collections.Generic.List[string]]::new()
    $lines = $content -split "\r?\n"
    $inSkills = $false

    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed -match "^##\s+(?:Core Competencies|Technical Skills|Skills|Areas of Expertise)") {
            $inSkills = $true
            continue
        }
        if ($inSkills -and $trimmed -match "^##\s+") {
            $inSkills = $false
            break
        }
        if ($inSkills -and $trimmed -match "^-\s*\*\*([^*]+)\*\*:\s*(.+)$") {
            $categoryVal = $matches[2]
            $rawItems = $categoryVal -split "[,;]"
            foreach ($item in $rawItems) {
                $clean = $item.Trim().TrimEnd('.').Trim()
                # Strip parenthetical annotations like (3.10+), (P4), (.NET)
                $cleanNoParen = ($clean -replace "\(.*?\)", "").Trim()
                if ($cleanNoParen.Length -gt 1) {
                    $tokensList.Add($cleanNoParen)
                }
            }
        }
    }
    return $tokensList
}

$skills = Extract-CompetencyTokens -content $tailoredText
$unverifiedSkills = [System.Collections.Generic.List[string]]::new()

Write-Host "`nVerifying $($skills.Count) competency tokens against Master Resume whitelist..." -ForegroundColor Yellow

foreach ($skill in $skills) {
    $parts = $skill -split "/"
    $matched = $false

    foreach ($p in $parts) {
        $cleanPart = $p.Trim()
        if ($cleanPart.Length -le 1) { continue }

        $escaped = [regex]::Escape($cleanPart)
        if ($whitelistCorpus -match "(?i)\b$escaped\b" -or $whitelistCorpus.IndexOf($cleanPart, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            $matched = $true
            break
        }
    }

    if (-not $matched) {
        $unverifiedSkills.Add($skill)
    }
}

# 3. Check for "(Familiar)" or "(Proficient)" Qualifier Injection
$familiarMatches = [regex]::Matches($tailoredText, "([A-Za-z0-9+#\.\s]{2,25})\s*\(\s*(?:Familiar|Proficient|Working Knowledge)\s*\)", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
$suspiciousFamiliar = [System.Collections.Generic.List[string]]::new()
foreach ($m in $familiarMatches) {
    $phrase = $m.Groups[1].Value.Trim()
    $escapedPhrase = [regex]::Escape($phrase)
    if ($whitelistCorpus -notmatch "(?i)\b$escapedPhrase\b") {
        $suspiciousFamiliar.Add($m.Value)
    }
}

# 4. Report Findings & Determine Status
$hasFailure = $false

if ($hallucinatedFound.Count -gt 0) {
    $hasFailure = $true
    Write-Host "`n❌ CRITICAL: Unverified JD-backfilled buzzwords detected:" -ForegroundColor Red
    foreach ($h in ($hallucinatedFound | Select-Object -Unique)) {
        Write-Host "   - $h" -ForegroundColor Red
    }
}

if ($suspiciousFamiliar.Count -gt 0) {
    $hasFailure = $true
    Write-Host "`n❌ VIOLATION: Unverified skills tagged with '(Familiar)' or '(Proficient)':" -ForegroundColor Red
    foreach ($f in ($suspiciousFamiliar | Select-Object -Unique)) {
        Write-Host "   - $f" -ForegroundColor Red
    }
}

if ($unverifiedSkills.Count -gt 0) {
    $hasFailure = $true
    Write-Host "`n❌ VIOLATION: The following competencies/skills do NOT exist in the Master Resume whitelist:" -ForegroundColor Red
    foreach ($u in ($unverifiedSkills | Select-Object -Unique)) {
        Write-Host "   - $u" -ForegroundColor Red
    }
}

if ($hasFailure) {
    Write-Host "`n🚫 INTEGRITY LINT FAILED: Rule 3 (Closed-Set Whitelist) violated." -ForegroundColor Red
    Write-Host "Action Required: Remove or replace these unverified items with authentic Master Resume capabilities before proceeding to PDF compilation or submission.`n" -ForegroundColor Red
    exit 1
} else {
    Write-Host "`n✅ INTEGRITY LINT PASSED: All competency tokens strictly verified in Master Resume whitelist.`n" -ForegroundColor Green
    exit 0
}
