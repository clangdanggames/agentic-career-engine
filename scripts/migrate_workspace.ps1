# Workspace Migration Utility
# Migrates career assets, application dossiers, and ledgers from a previous ACE workspace or legacy project (e.g. 'Job Hunt').
# Ensures zero data loss and clean separation of user state from engine files.
param (
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$SourcePath,

    [switch]$DryRun,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$targetRoot = (Resolve-Path "$PSScriptRoot\..").Path
$targetAppsDir = Join-Path $targetRoot "applications"
$targetResumesDir = Join-Path $targetRoot "resumes"
$targetStoriesDir = Join-Path $targetRoot "stories"
$targetNetworkDir = Join-Path $targetRoot "network"
$targetCompaniesDir = Join-Path $targetRoot "companies"
$targetWorkflowsDir = Join-Path $targetRoot "workflows"

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  Agentic Career Engine (ACE) - Workspace Migrator    " -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

# 1. Validate Source Path
if (-not (Test-Path $SourcePath)) {
    Write-Error "Source path does not exist: '$SourcePath'"
    exit 1
}

$resolvedSource = (Resolve-Path $SourcePath).Path
if ($resolvedSource -eq $targetRoot) {
    Write-Error "Source path cannot be identical to the target workspace ('$targetRoot')."
    exit 1
}

Write-Host "Source Workspace: $resolvedSource" -ForegroundColor Gray
Write-Host "Target Workspace: $targetRoot`n" -ForegroundColor Gray

if ($DryRun) {
    Write-Host "[DRY-RUN MODE]: Simulating migration. No files will be modified.`n" -ForegroundColor Yellow
} elseif (-not $Force) {
    $confirm = Read-Host "Migrate career data from '$resolvedSource' into this workspace? (Y/n)"
    if ($confirm -and $confirm -ne 'y' -and $confirm -ne 'Y') {
        Write-Host "Migration cancelled by user." -ForegroundColor Cyan
        exit 0
    }
}

$summary = [ordered]@{
    ResumesMigrated      = 0
    StoriesMigrated      = 0
    NetworkFilesMigrated = 0
    CompaniesMigrated    = 0
    DossiersMigrated     = 0
    LedgerUpdated        = $false
    DashboardMigrated    = $false
    ConfigMerged         = $false
}

# ----------------------------------------------------
# Helper: Copy or Dry-Run Copy File
# ----------------------------------------------------
function Copy-MigratedFile {
    param (
        [string]$SourceFile,
        [string]$DestinationDir,
        [string]$CustomTargetName = $null
    )

    if (-not (Test-Path $DestinationDir)) {
        if (-not $DryRun) {
            New-Item -ItemType Directory -Path $DestinationDir -Force | Out-Null
        }
    }

    $fileName = if ($CustomTargetName) { $CustomTargetName } else { (Split-Path $SourceFile -Leaf) }
    $destFile = Join-Path $DestinationDir $fileName

    Write-Host "  -> $fileName" -ForegroundColor DarkGray
    if (-not $DryRun) {
        Copy-Item -Path $SourceFile -Destination $destFile -Force
    }
}

# ----------------------------------------------------
# 1. Migrate Resumes
# ----------------------------------------------------
Write-Host "[1/7] Migrating Resumes & Bullet Reserve Bank..." -ForegroundColor Cyan
$sourceResumesDir = Join-Path $resolvedSource "resumes"
if (Test-Path $sourceResumesDir) {
    $resumeFiles = Get-ChildItem -Path $sourceResumesDir -File | Where-Object {
        $_.Name -notmatch "\[Candidate_Name\]"
    }

    foreach ($file in $resumeFiles) {
        Copy-MigratedFile -SourceFile $file.FullName -DestinationDir $targetResumesDir
        $summary.ResumesMigrated++
    }

    # Variants folder if present
    $sourceVariantsDir = Join-Path $sourceResumesDir "variants"
    if (Test-Path $sourceVariantsDir) {
        $variantFiles = Get-ChildItem -Path $sourceVariantsDir -File | Where-Object { $_.Name -ne "README.md" }
        $targetVariantsDir = Join-Path $targetResumesDir "variants"
        foreach ($vf in $variantFiles) {
            Copy-MigratedFile -SourceFile $vf.FullName -DestinationDir $targetVariantsDir
            $summary.ResumesMigrated++
        }
    }
} else {
    Write-Host "  No resumes/ folder found in source." -ForegroundColor DarkGray
}

# ----------------------------------------------------
# 2. Migrate STAR Interview Stories
# ----------------------------------------------------
Write-Host "`n[2/7] Migrating STAR Story Bank & Cheat Sheets..." -ForegroundColor Cyan
$sourceStoriesDir = Join-Path $resolvedSource "stories"
if (Test-Path $sourceStoriesDir) {
    $storyFiles = Get-ChildItem -Path $sourceStoriesDir -File -Filter "*.md"
    foreach ($file in $storyFiles) {
        Copy-MigratedFile -SourceFile $file.FullName -DestinationDir $targetStoriesDir
        $summary.StoriesMigrated++
    }
} else {
    Write-Host "  No stories/ folder found in source." -ForegroundColor DarkGray
}

# ----------------------------------------------------
# 3. Migrate Network & Contacts Ledger
# ----------------------------------------------------
Write-Host "`n[3/7] Migrating Network Contacts & LinkedIn Exports..." -ForegroundColor Cyan
$sourceNetworkDir = Join-Path $resolvedSource "network"
if (Test-Path $sourceNetworkDir) {
    $networkFiles = Get-ChildItem -Path $sourceNetworkDir -File | Where-Object {
        $_.Extension -in @(".md", ".csv", ".json")
    }
    foreach ($file in $networkFiles) {
        Copy-MigratedFile -SourceFile $file.FullName -DestinationDir $targetNetworkDir
        $summary.NetworkFilesMigrated++
    }
} else {
    Write-Host "  No network/ folder found in source." -ForegroundColor DarkGray
}

# ----------------------------------------------------
# 4. Migrate Target Companies
# ----------------------------------------------------
Write-Host "`n[4/7] Migrating Target Company Tier Lists..." -ForegroundColor Cyan
$sourceCompaniesDir = Join-Path $resolvedSource "companies"
if (Test-Path $sourceCompaniesDir) {
    $companyFiles = Get-ChildItem -Path $sourceCompaniesDir -File -Filter "*.md"
    foreach ($file in $companyFiles) {
        Copy-MigratedFile -SourceFile $file.FullName -DestinationDir $targetCompaniesDir
        $summary.CompaniesMigrated++
    }
} else {
    Write-Host "  No companies/ folder found in source." -ForegroundColor DarkGray
}

# ----------------------------------------------------
# 5. Migrate Application Dossiers & Ledgers
# ----------------------------------------------------
Write-Host "`n[5/7] Migrating Application Dossiers & Ledger..." -ForegroundColor Cyan
$sourceAppsDir = Join-Path $resolvedSource "applications"
if (Test-Path $sourceAppsDir) {
    # Copy dossier folders (anything not dossier_template)
    $dossierDirs = Get-ChildItem -Path $sourceAppsDir -Directory | Where-Object {
        $_.Name -ne "dossier_template"
    }

    foreach ($dir in $dossierDirs) {
        $destDossier = Join-Path $targetAppsDir $dir.Name
        Write-Host "  -> Dossier: $($dir.Name)" -ForegroundColor DarkGray
        if (-not $DryRun) {
            Copy-Item -Path $dir.FullName -Destination $destDossier -Recurse -Force
        }
        $summary.DossiersMigrated++
    }

    # Migrate ledger.json
    $sourceLedger = Join-Path $sourceAppsDir "ledger.json"
    $targetLedger = Join-Path $targetAppsDir "ledger.json"
    if (Test-Path $sourceLedger) {
        try {
            $srcLedgerContent = Get-Content $sourceLedger -Raw -Encoding UTF8 | ConvertFrom-Json
            $tgtLedgerContent = if (Test-Path $targetLedger) {
                Get-Content $targetLedger -Raw -Encoding UTF8 | ConvertFrom-Json
            } else {
                [ordered]@{
                    "`$schema" = "./schema.json"
                    meta = @{}
                    applications = @()
                }
            }

            # Merge metadata
            if ($srcLedgerContent.meta) {
                $tgtLedgerContent.meta.candidate = $srcLedgerContent.meta.candidate
                $tgtLedgerContent.meta.last_updated = (Get-Date -Format "yyyy-MM-dd")
                if ($srcLedgerContent.meta.compensation_target) {
                    $tgtLedgerContent.meta.compensation_target = $srcLedgerContent.meta.compensation_target
                }
                if ($srcLedgerContent.meta.notes) {
                    $tgtLedgerContent.meta.notes = $srcLedgerContent.meta.notes
                }
            }

            # Merge applications
            if ($srcLedgerContent.applications) {
                $tgtLedgerContent.applications = $srcLedgerContent.applications
            }

            if (-not $DryRun) {
                $tgtLedgerContent | ConvertTo-Json -Depth 6 | Set-Content $targetLedger -Encoding UTF8
            }
            Write-Host "  -> Merged applications/ledger.json ($($tgtLedgerContent.applications.Count) applications)" -ForegroundColor DarkGray
            $summary.LedgerUpdated = $true
        } catch {
            Write-Warning "Could not parse source ledger.json: $_"
        }
    }

    # Migrate sourcing inbox if present
    $sourceInboxJson = Join-Path $sourceAppsDir "sourcing_inbox.json"
    if (Test-Path $sourceInboxJson) {
        Copy-MigratedFile -SourceFile $sourceInboxJson -DestinationDir $targetAppsDir
    }
    $sourceInboxMd = Join-Path $sourceAppsDir "sourcing_inbox.md"
    if (Test-Path $sourceInboxMd) {
        Copy-MigratedFile -SourceFile $sourceInboxMd -DestinationDir $targetAppsDir
    }
} else {
    Write-Host "  No applications/ folder found in source." -ForegroundColor DarkGray
}

# ----------------------------------------------------
# 6. Migrate Dashboard (DASHBOARD.md)
# ----------------------------------------------------
Write-Host "`n[6/7] Migrating Live Career Dashboard..." -ForegroundColor Cyan
$dashboardFound = $false

# 1st Priority: Source has DASHBOARD.md
$sourceDashboard = Join-Path $resolvedSource "DASHBOARD.md"
if (Test-Path $sourceDashboard) {
    Copy-MigratedFile -SourceFile $sourceDashboard -DestinationDir $targetRoot -CustomTargetName "DASHBOARD.md"
    $dashboardFound = $true
}

# 2nd Priority: Source has career_dashboard.md
if (-not $dashboardFound) {
    $legacyDashboard = Join-Path $resolvedSource "career_dashboard.md"
    if (Test-Path $legacyDashboard) {
        Copy-MigratedFile -SourceFile $legacyDashboard -DestinationDir $targetRoot -CustomTargetName "DASHBOARD.md"
        $dashboardFound = $true
    }
}

# 3rd Priority: Source README.md is a personalized dashboard (legacy Job Hunt convention)
if (-not $dashboardFound) {
    $sourceReadme = Join-Path $resolvedSource "README.md"
    if (Test-Path $sourceReadme) {
        $readmeText = Get-Content $sourceReadme -Raw -Encoding UTF8
        if ($readmeText -match "(Career Command Center|Pipeline Progress|Live Pipeline Funnel|Active Application Status)") {
            Write-Host "  Detected personalized dashboard in source README.md; migrating to DASHBOARD.md" -ForegroundColor DarkGray
            Copy-MigratedFile -SourceFile $sourceReadme -DestinationDir $targetRoot -CustomTargetName "DASHBOARD.md"
            $dashboardFound = $true
        }
    }
}

$summary.DashboardMigrated = $dashboardFound

# ----------------------------------------------------
# 7. Merge Search Configuration
# ----------------------------------------------------
Write-Host "`n[7/7] Merging ATS Search Configuration..." -ForegroundColor Cyan
$srcSearchConfig = Join-Path $resolvedSource "workflows\ats_search_config.json"
$tgtSearchConfig = Join-Path $targetWorkflowsDir "ats_search_config.json"

if ((Test-Path $srcSearchConfig) -and (Test-Path $tgtSearchConfig)) {
    try {
        $srcConfig = Get-Content $srcSearchConfig -Raw -Encoding UTF8 | ConvertFrom-Json
        $tgtConfig = Get-Content $tgtSearchConfig -Raw -Encoding UTF8 | ConvertFrom-Json

        if ($srcConfig.target_roles) { $tgtConfig.target_roles = $srcConfig.target_roles }
        if ($srcConfig.compensation_floor) { $tgtConfig.compensation_floor = $srcConfig.compensation_floor }
        if ($srcConfig.target_compensation) { $tgtConfig.target_compensation = $srcConfig.target_compensation }
        if ($srcConfig.preferred_locations) { $tgtConfig.preferred_locations = $srcConfig.preferred_locations }
        if ($srcConfig.target_company_domains) { $tgtConfig.target_company_domains = $srcConfig.target_company_domains }
        if ($srcConfig.negative_keywords) { $tgtConfig.negative_keywords = $srcConfig.negative_keywords }

        if (-not $DryRun) {
            $tgtConfig | ConvertTo-Json -Depth 5 | Set-Content $tgtSearchConfig -Encoding UTF8
        }
        Write-Host "  -> Merged personal search filters into workflows/ats_search_config.json" -ForegroundColor DarkGray
        $summary.ConfigMerged = $true
    } catch {
        Write-Warning "Could not merge search configurations: $_"
    }
}

# ----------------------------------------------------
# Post-Migration Verification
# ----------------------------------------------------
Write-Host "`n======================================================" -ForegroundColor Green
Write-Host "  Migration Completed Successfully!                   " -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Green
Write-Host "Resumes Migrated       : $($summary.ResumesMigrated)" -ForegroundColor White
Write-Host "Application Dossiers   : $($summary.DossiersMigrated)" -ForegroundColor White
Write-Host "Interview Stories      : $($summary.StoriesMigrated)" -ForegroundColor White
Write-Host "Network & Contact Files: $($summary.NetworkFilesMigrated)" -ForegroundColor White
Write-Host "Target Companies       : $($summary.CompaniesMigrated)" -ForegroundColor White
Write-Host "Applications Ledger    : $(if ($summary.LedgerUpdated) {'Updated'} else {'Unchanged'})" -ForegroundColor White
Write-Host "Career Dashboard       : $(if ($summary.DashboardMigrated) {'Migrated to DASHBOARD.md'} else {'Not found in source'})" -ForegroundColor White
Write-Host "ATS Search Config      : $(if ($summary.ConfigMerged) {'Merged'} else {'Unchanged'})`n" -ForegroundColor White

# Run Resume Integrity Linter if master resume is present
$masterResume = Get-ChildItem -Path $targetResumesDir -Filter "*_Resume_Master.md" -File | Select-Object -First 1
if ($masterResume -and -not $DryRun) {
    Write-Host "Running integrity check on migrated master resume: $($masterResume.Name)..." -ForegroundColor Yellow
    $linterScript = Join-Path $targetRoot "scripts\lint_resume_integrity.ps1"
    if (Test-Path $linterScript) {
        powershell -ExecutionPolicy Bypass -File $linterScript -TailoredResumePath $masterResume.FullName
    }
}
