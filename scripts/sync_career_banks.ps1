#!/usr/bin/env pwsh
<#
.SYNOPSIS
    ACE Career Bank Synchronizer & Master-to-Bank Backfill Utility
.DESCRIPTION
    Enforces the Bank-First Architecture by ensuring resumes/career_profile_bank.md and
    resumes/modular_reserve_bank.md exist and inspecting the candidate's Master Resume
    (resumes/[Name]_Resume_Master.md) to non-destructively backfill any skills, employers,
    experience bullets, or education/credential entries that are not yet stored in the banks.
.PARAMETER MasterResumePath
    Optional: Path to the candidate's Master Resume (auto-detected from resumes/ if omitted).
.PARAMETER ProfileBankPath
    Optional: Path to resumes/career_profile_bank.md.
.PARAMETER ReserveBankPath
    Optional: Path to resumes/modular_reserve_bank.md.
.PARAMETER Quiet
    Switch: Suppresses informational output when no changes are needed.
.PARAMETER DryRun
    Switch: Reports items that would be backfilled without modifying files.
#>
param (
    [Parameter(Mandatory = $false)]
    [string]$MasterResumePath = "",

    [Parameter(Mandatory = $false)]
    [Alias("CareerProfileBankPath")]
    [string]$ProfileBankPath = "",

    [Parameter(Mandatory = $false)]
    [string]$ReserveBankPath = "",

    [Parameter(Mandatory = $false)]
    [switch]$Quiet,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$resumesDir = Join-Path $workspaceRoot "resumes"

if ([string]::IsNullOrWhiteSpace($ProfileBankPath)) {
    $ProfileBankPath = Join-Path $resumesDir "career_profile_bank.md"
} elseif (-not [System.IO.Path]::IsPathRooted($ProfileBankPath)) {
    $ProfileBankPath = Join-Path $workspaceRoot $ProfileBankPath
}

if ([string]::IsNullOrWhiteSpace($ReserveBankPath)) {
    $ReserveBankPath = Join-Path $resumesDir "modular_reserve_bank.md"
} elseif (-not [System.IO.Path]::IsPathRooted($ReserveBankPath)) {
    $ReserveBankPath = Join-Path $workspaceRoot $ReserveBankPath
}

# 1. Initialize default bank files if missing in an upgraded/migrated workspace
if (-not (Test-Path $ProfileBankPath) -and -not $DryRun) {
    $parentDir = Split-Path $ProfileBankPath -Parent
    if (-not (Test-Path $parentDir)) { New-Item -ItemType Directory -Path $parentDir -Force | Out-Null }
    $defaultProfileLines = @(
        "# Comprehensive Career Profile Bank (Skills, Education, Credentials & References)",
        "",
        "> **Purpose**: Paired with `resumes/modular_reserve_bank.md` and `stories/star_story_bank.md`, this file is the exhaustive single source of truth for your career profile.",
        "",
        "---",
        "",
        "## Section 1: Candidate Identity & Contact Metadata",
        "",
        "- **Full Name**: [First Name] [Last Name]",
        "- **Primary Location**: [City, State / Metro Region]",
        "- **Email**: [email@domain.com]",
        "- **Phone**: [(555) 000-0000]",
        "- **LinkedIn URL**: [https://linkedin.com/in/username]",
        "",
        "---",
        "",
        "## Section 2: Categorized Skills & Competency Matrix",
        "",
        "---",
        "",
        "## Section 3: Education & Academic Credentials",
        "",
        "---",
        "",
        "## Section 4: Certifications, Licenses, Publications & Awards",
        "",
        "---",
        "",
        "## Section 5: Professional References & Endorsements",
        "",
        "| Reference Name | Title & Organization | Relationship / Context | Contact Info (Email / Phone / LinkedIn) | Best Vouching Areas / Notes |",
        "| :--- | :--- | :--- | :--- | :--- |"
    )
    Set-Content -Path $ProfileBankPath -Value ($defaultProfileLines -join "`n") -Encoding UTF8
}

if (-not (Test-Path $ReserveBankPath) -and -not $DryRun) {
    $parentDir = Split-Path $ReserveBankPath -Parent
    if (-not (Test-Path $parentDir)) { New-Item -ItemType Directory -Path $parentDir -Force | Out-Null }
    $defaultReserveLines = @(
        "# Comprehensive Experience & Modular Bullet Bank",
        "",
        "> **Purpose**: Paired with `resumes/career_profile_bank.md`, this file is the exhaustive factual repository of your chronological employment history, core accomplishments, and specialized reserve bullets.",
        "",
        "---",
        "",
        "## Part 1: Chronological Work History & Role Bullets",
        "",
        "---",
        "",
        "## Part 2: Thematic & Cross-Cutting Project Bullets"
    )
    Set-Content -Path $ReserveBankPath -Value ($defaultReserveLines -join "`n") -Encoding UTF8
}

# 2. Auto-detect Master Resume if not explicitly passed
if ([string]::IsNullOrWhiteSpace($MasterResumePath)) {
    if (Test-Path $resumesDir) {
        $candidates = @(Get-ChildItem -Path $resumesDir -Filter "*_Resume_Master.md" -File -ErrorAction SilentlyContinue)
        if ($candidates.Count -eq 0) {
            $candidates = @(Get-ChildItem -Path $resumesDir -Filter "*Master*.md" -File -ErrorAction SilentlyContinue)
        }
        if ($candidates.Count -eq 0) {
            $candidates = @(Get-ChildItem -Path $resumesDir -Filter "*.md" -File -ErrorAction SilentlyContinue | Where-Object {
                $_.Name -notin @("career_profile_bank.md", "modular_reserve_bank.md", "resume_template.md", "README.md")
            })
        }
        if ($candidates.Count -gt 0) {
            $MasterResumePath = $candidates[0].FullName
        }
    }
} elseif (-not (Test-Path $MasterResumePath)) {
    $resolvedMaster = Join-Path $workspaceRoot $MasterResumePath
    if (Test-Path $resolvedMaster) {
        $MasterResumePath = $resolvedMaster
    }
}

if ([string]::IsNullOrWhiteSpace($MasterResumePath) -or -not (Test-Path $MasterResumePath)) {
    if (-not $Quiet) {
        Write-Host "[i] No candidate Master Resume found to backfill into banks." -ForegroundColor DarkGray
    }
    $global:LASTEXITCODE = 0
    exit 0
}

$masterRaw = Get-Content -Path $MasterResumePath -Raw -Encoding UTF8
if ([string]::IsNullOrWhiteSpace($masterRaw)) {
    $global:LASTEXITCODE = 0
    exit 0
}

$profileRaw = if (Test-Path $ProfileBankPath) { Get-Content -Path $ProfileBankPath -Raw -Encoding UTF8 } else { "" }
$reserveRaw = if (Test-Path $ReserveBankPath) { Get-Content -Path $ReserveBankPath -Raw -Encoding UTF8 } else { "" }

$masterLines = $masterRaw -split "\r?\n"

# 3. Parse Master Resume sections
$candidateName = ""
$contactLine = ""
if ($masterLines.Count -ge 1 -and $masterLines[0] -match "^#\s+(.+)$") {
    $extractedName = $matches[1].Trim()
    if ($extractedName -notmatch "^\[") {
        $candidateName = $extractedName
    }
}
if ($masterLines.Count -ge 2 -and $masterLines[1] -notmatch "^#" -and $masterLines[1] -notmatch "^\[City") {
    $contactLine = $masterLines[1].Trim()
}

$summaryLinesToSync = [System.Collections.Generic.List[string]]::new()
$skillsLinesToSync = [System.Collections.Generic.List[string]]::new()
$eduLinesToSync = [System.Collections.Generic.List[string]]::new()
$experienceRoles = [System.Collections.Generic.List[PSCustomObject]]::new()

$currentSection = ""
$currentRoleObj = $null

for ($i = 0; $i -lt $masterLines.Count; $i++) {
    $line = $masterLines[$i]
    $trimmed = $line.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed -eq "---") { continue }

    if ($trimmed -match "^##\s+(.+)$") {
        $secTitle = $matches[1].Trim()
        if ($secTitle -match "(?i)(Professional Summary|Executive Summary|Summary|Profile)") {
            $currentSection = "summary"
        } elseif ($secTitle -match "(?i)(Core Competencies|Technical Skills|Skills|Areas of Expertise)") {
            $currentSection = "skills"
        } elseif ($secTitle -match "(?i)(Professional Experience|Work Experience|Experience|Employment)") {
            $currentSection = "experience"
        } elseif ($secTitle -match "(?i)(Education|Credentials|Certifications)") {
            $currentSection = "education"
        } else {
            $currentSection = "other"
        }
        continue
    }

    switch ($currentSection) {
        "summary" {
            if ($trimmed -notmatch "^\[2-3 sentence" -and $trimmed -notmatch "^\[e\.g\.") {
                $summaryLinesToSync.Add($trimmed)
            }
        }
        "skills" {
            if ($trimmed -match "^[-*]\s+" -and $trimmed -notmatch "\[e\.g\.") {
                $skillsLinesToSync.Add($trimmed)
            }
        }
        "experience" {
            if ($trimmed -match "^###\s+(.+)$") {
                $compName = $matches[1].Trim()
                if ($compName -notmatch "^\[") {
                    $currentRoleObj = [PSCustomObject]@{
                        Company   = $compName
                        Subheader = ""
                        Bullets   = [System.Collections.Generic.List[string]]::new()
                    }
                    $experienceRoles.Add($currentRoleObj)
                } else {
                    $currentRoleObj = $null
                }
            } elseif ($null -ne $currentRoleObj) {
                if ($trimmed -match "^\*\*[^*]+\*\*" -and [string]::IsNullOrWhiteSpace($currentRoleObj.Subheader)) {
                    $currentRoleObj.Subheader = $trimmed
                } elseif ($trimmed -match "^[-*]\s+(.+)$") {
                    $bText = $matches[1].Trim()
                    if ($bText -notmatch "^\[Action verb\]") {
                        $currentRoleObj.Bullets.Add($bText)
                    }
                }
            }
        }
        "education" {
            if ($trimmed -notmatch "^\[University" -and $trimmed -notmatch "\[Field of Study\]" -and $trimmed -notmatch "\[e\.g\.") {
                $eduLinesToSync.Add($trimmed)
            }
        }
    }
}

# 4. Backfill missing Identity, Skills, and Education into career_profile_bank.md
$profileModified = $false
$updatedProfile = $profileRaw
$skillsAddedCount = 0
$eduAddedCount = 0

if (-not [string]::IsNullOrWhiteSpace($candidateName) -and $updatedProfile -match "\[First Name\] \[Last Name\]") {
    $updatedProfile = $updatedProfile.Replace("[First Name] [Last Name]", $candidateName)
    $profileModified = $true
}

if (-not [string]::IsNullOrWhiteSpace($contactLine)) {
    $parts = @($contactLine -split "\|" | ForEach-Object { $_.Trim() })
    if ($parts.Count -ge 1 -and $parts[0] -notmatch "^\[" -and $updatedProfile -match "\[City, State / Metro Region\]") {
        $updatedProfile = $updatedProfile.Replace("[City, State / Metro Region]", $parts[0])
        $profileModified = $true
    }
    foreach ($p in $parts) {
        if ($p -match "([a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,})") {
            $emailVal = $matches[1]
            if ($emailVal -ne "email@domain.com" -and $updatedProfile -match "\[email@domain\.com\]") {
                $updatedProfile = $updatedProfile.Replace("[email@domain.com]", $emailVal)
                $profileModified = $true
            }
        }
        if ($p -match "(\+?1?[\s\-\.]?\(?\d{3}\)?[\s\-\.]?\d{3}[\s\-\.]?\d{4})") {
            $phoneVal = $matches[1].Trim()
            if ($updatedProfile -match "\[\(555\) 000-0000\]") {
                $updatedProfile = $updatedProfile.Replace("[(555) 000-0000]", $phoneVal)
                $profileModified = $true
            }
        }
        if ($p -match "linkedin\.com/[^\)\]\s]+") {
            $liVal = $matches[0]
            if ($liVal -notmatch "username" -and $updatedProfile -match "\[https://linkedin\.com/in/username\]") {
                $fullLi = if ($liVal -match "^https?://") { $liVal } else { "https://$liVal" }
                $updatedProfile = $updatedProfile.Replace("[https://linkedin.com/in/username]", $fullLi)
                $profileModified = $true
            }
        }
    }
}

$profileWithoutPlaceholders = ($updatedProfile -replace "(?i)\[e\.g\.[^\]]*\]", "" -replace "(?i)\([^)]*e\.g\.[^)]*\)", "")

$missingSkillLines = [System.Collections.Generic.List[string]]::new()
foreach ($sLine in $skillsLinesToSync) {
    # Check if this exact skill line or its core content is already in career_profile_bank.md
    $cleanCheck = ($sLine -replace "^[-*]\s+", "").Trim()
    $isAlreadyPresent = ($profileWithoutPlaceholders.IndexOf($cleanCheck, [System.StringComparison]::OrdinalIgnoreCase) -ge 0)
    if (-not $isAlreadyPresent -and $cleanCheck -match "^\*\*([^*]+)\*\*:\s*(.+)$") {
        $catName = $matches[1].Trim()
        $content = $matches[2].Trim()
        # Check if the category header or core skill tokens are already represented in career_profile_bank.md
        if ($profileWithoutPlaceholders.IndexOf($catName, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            $isAlreadyPresent = $true
        } else {
            $tokens = @($content -split "[,;/]" | ForEach-Object { ($_ -replace "[().*]", "").Trim() } | Where-Object { $_.Length -ge 3 })
            $matchedTokens = 0
            foreach ($t in $tokens) {
                if ($profileWithoutPlaceholders.IndexOf($t, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                    $matchedTokens++
                }
            }
            if ($tokens.Count -gt 0 -and ($matchedTokens / $tokens.Count) -ge 0.6) {
                $isAlreadyPresent = $true
            }
        }
    }
    if (-not $isAlreadyPresent) {
        $levelPrefix = "`[Level 1: Core Direct]` "
        if ($cleanCheck -match "(?i)Level\s*2") { $levelPrefix = "`[Level 2: AI-Assisted / Architecture]` " }
        elseif ($cleanCheck -match "(?i)Level\s*3") { $levelPrefix = "`[Level 3: Working Exposure / Evaluated]` " }
        elseif ($cleanCheck -match "`\[Level\s*[123]") { $levelPrefix = "" }
        $missingSkillLines.Add("- ${levelPrefix}${cleanCheck}")
        $skillsAddedCount++
    }
}

if ($missingSkillLines.Count -gt 0) {
    $skillBlock = "`n### Synchronized Master Resume Competencies`n" + ($missingSkillLines -join "`n") + "`n"
    if ($updatedProfile -match "(?m)^##\s+.*Section 3:") {
        $updatedProfile = [regex]::Replace($updatedProfile, '(?m)(^---\s*\r?\n+##\s+.*Section 3:)', "$skillBlock`n`$1", 1)
    } else {
        $updatedProfile = $updatedProfile.TrimEnd() + "`n" + $skillBlock
    }
    $profileModified = $true
}

$missingEduLines = [System.Collections.Generic.List[string]]::new()
foreach ($eLine in $eduLinesToSync) {
    $cleanEdu = ($eLine -replace "^###\s+", "" -replace "^[-*]\s+", "").Trim()
    $eduPresent = ($profileWithoutPlaceholders.IndexOf($cleanEdu, [System.StringComparison]::OrdinalIgnoreCase) -ge 0)
    if (-not $eduPresent) {
        $eduParts = @($cleanEdu -split "\|" | ForEach-Object { ($_ -replace "\*\*", "").Trim() } | Where-Object { $_.Length -ge 3 })
        if ($eduParts.Count -gt 0) {
            $matchedEduParts = 0
            foreach ($ep in $eduParts) {
                if ($profileWithoutPlaceholders.IndexOf($ep, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                    $matchedEduParts++
                }
            }
            if ($matchedEduParts -eq $eduParts.Count) {
                $eduPresent = $true
            }
        }
    }
    if ($cleanEdu.Length -gt 2 -and -not $eduPresent) {
        $missingEduLines.Add($eLine)
        $eduAddedCount++
    }
}

if ($missingEduLines.Count -gt 0) {
    $eduBlock = "`n" + ($missingEduLines -join "`n") + "`n"
    if ($updatedProfile -match "(?m)^##\s+.*Section 4:") {
        $updatedProfile = [regex]::Replace($updatedProfile, '(?m)(^---\s*\r?\n+##\s+.*Section 4:)', "$eduBlock`n`$1", 1)
    } else {
        $updatedProfile = $updatedProfile.TrimEnd() + "`n`n## Synchronized Education & Credentials" + $eduBlock
    }
    $profileModified = $true
}

if ($profileModified -and -not $DryRun) {
    Set-Content -Path $ProfileBankPath -Value ($updatedProfile -replace "`r`n", "`n") -Encoding UTF8
}

# 5. Backfill missing Employers & Bullets into modular_reserve_bank.md
$reserveModified = $false
$updatedReserve = $reserveRaw
$rolesAddedCount = 0
$bulletsAddedCount = 0

foreach ($roleObj in $experienceRoles) {
    $compHeader = "### $($roleObj.Company)"
    $missingBulletsForRole = [System.Collections.Generic.List[string]]::new()

    foreach ($b in $roleObj.Bullets) {
        # Strip any leading [Level X] tag when checking substring existence
        $coreBulletText = ($b -replace "^`?\[Level\s*[123][^\]]*\]`?\s*", "").Trim()
        if ($coreBulletText.Length -gt 10 -and $updatedReserve.IndexOf($coreBulletText, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
            $formattedBullet = if ($b -match "^`?\[Level\s*[123]") {
                "- $b"
            } else {
                "- ``[Level 1: Core Direct]`` $b"
            }
            $missingBulletsForRole.Add($formattedBullet)
            $bulletsAddedCount++
        }
    }

    $hasCompanyInReserve = ($updatedReserve.IndexOf($roleObj.Company, [System.StringComparison]::OrdinalIgnoreCase) -ge 0)

    if (-not $hasCompanyInReserve -or $missingBulletsForRole.Count -gt 0) {
        if (-not $hasCompanyInReserve) {
            $rolesAddedCount++
            $roleLines = [System.Collections.Generic.List[string]]::new()
            $roleLines.Add("")
            $roleLines.Add($compHeader)
            if (-not [string]::IsNullOrWhiteSpace($roleObj.Subheader)) {
                $roleLines.Add($roleObj.Subheader)
            }
            foreach ($mb in $missingBulletsForRole) {
                $roleLines.Add($mb)
            }
            $roleBlock = ($roleLines -join "`n") + "`n"

            if ($updatedReserve -match "(?m)^##\s+.*Part 2:") {
                $updatedReserve = [regex]::Replace($updatedReserve, '(?m)(^---\s*\r?\n+##\s+.*Part 2:)', "$roleBlock`n`$1", 1)
            } else {
                $updatedReserve = $updatedReserve.TrimEnd() + "`n" + $roleBlock
            }
            $reserveModified = $true
        } elseif ($missingBulletsForRole.Count -gt 0) {
            # Company header already exists in modular_reserve_bank.md; append missing bullets under it
            $escapedComp = [regex]::Escape($roleObj.Company)
            $compPattern = "(?m)(^###\s+[^\r\n]*$escapedComp[^\r\n]*\r?\n(?:\*\*[^\r\n]+\r?\n)?)"
            $addedBlock = ($missingBulletsForRole -join "`n") + "`n"
            if ($updatedReserve -match $compPattern) {
                $updatedReserve = [regex]::Replace($updatedReserve, $compPattern, "`${1}$addedBlock", 1)
            } else {
                $updatedReserve = $updatedReserve.TrimEnd() + "`n`n### $($roleObj.Company) (Additional Master Bullets)`n" + $addedBlock
            }
            $reserveModified = $true
        }
    }
}

if ($reserveModified -and -not $DryRun) {
    Set-Content -Path $ReserveBankPath -Value ($updatedReserve -replace "`r`n", "`n") -Encoding UTF8
}

if (-not $Quiet -or $profileModified -or $reserveModified) {
    if ($profileModified -or $reserveModified) {
        Write-Host "[+] Synchronized Master Resume data into Career Banks (Skills: +$skillsAddedCount, Education: +$eduAddedCount, Employers: +$rolesAddedCount, Bullets: +$bulletsAddedCount)." -ForegroundColor Green
    } elseif (-not $Quiet) {
        Write-Host "[OK] Career Banks (career_profile_bank.md & modular_reserve_bank.md) are already synchronized (100% of Master Resume data present)." -ForegroundColor Green
    }
}

$global:LASTEXITCODE = 0
exit 0
