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

    # Normalize migrated ledger.json and sourcing_inbox.json against schema.json
    $syncScriptPath = Join-Path $PSScriptRoot "sync_pipeline.ps1"
    if (-not $DryRun -and (Test-Path $syncScriptPath) -and (Test-Path $targetLedger)) {
        try {
            $null = & powershell -NoProfile -ExecutionPolicy Bypass -File $syncScriptPath *>&1
            $global:LASTEXITCODE = 0
        } catch {}
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
$srcSearchConfig = Join-Path $resolvedSource "workflows/ats_search_config.json"
$tgtSearchConfig = Join-Path $targetWorkflowsDir "ats_search_config.json"

if ((Test-Path $srcSearchConfig) -and (Test-Path $tgtSearchConfig)) {
    try {
        $srcConfig = Get-Content $srcSearchConfig -Raw -Encoding UTF8 | ConvertFrom-Json
        $tgtConfig = Get-Content $tgtSearchConfig -Raw -Encoding UTF8 | ConvertFrom-Json

        # 1. Merge modern nested search_criteria schema
        if ($srcConfig.search_criteria) {
            $sc = $srcConfig.search_criteria
            if ($sc.industry) { $tgtConfig.search_criteria.industry = $sc.industry }
            if ($sc.roles) { $tgtConfig.search_criteria.roles = $sc.roles }
            if ($sc.ats_domains) { $tgtConfig.search_criteria.ats_domains = $sc.ats_domains }
            if ($sc.locations) { $tgtConfig.search_criteria.locations = $sc.locations }
            if ($sc.negative_keywords) { $tgtConfig.search_criteria.negative_keywords = $sc.negative_keywords }
            if ($sc.search_scope) { $tgtConfig.search_criteria.search_scope = $sc.search_scope }
            if ($sc.compensation) {
                if ($null -ne $sc.compensation.floor) { $tgtConfig.search_criteria.compensation.floor = $sc.compensation.floor }
                if ($null -ne $sc.compensation.target) { $tgtConfig.search_criteria.compensation.target = $sc.compensation.target }
                if ($null -ne $sc.compensation.relocation_floor) { $tgtConfig.search_criteria.compensation.relocation_floor = $sc.compensation.relocation_floor }
                if ($sc.compensation.currency) { $tgtConfig.search_criteria.compensation.currency = $sc.compensation.currency }
            }
        } else {
            # 2. Fallback: Map legacy flat keys into modern nested search_criteria schema
            if ($srcConfig.target_roles) { $tgtConfig.search_criteria.roles = $srcConfig.target_roles }
            if ($srcConfig.preferred_locations) { $tgtConfig.search_criteria.locations = $srcConfig.preferred_locations }
            if ($srcConfig.negative_keywords) { $tgtConfig.search_criteria.negative_keywords = $srcConfig.negative_keywords }
            if ($null -ne $srcConfig.compensation_floor) { $tgtConfig.search_criteria.compensation.floor = $srcConfig.compensation_floor }
            if ($null -ne $srcConfig.target_compensation) { $tgtConfig.search_criteria.compensation.target = $srcConfig.target_compensation }
            if ($srcConfig.target_company_domains -and (-not $srcConfig.target_companies)) {
                $tgtConfig.target_companies = $srcConfig.target_company_domains
            }
        }

        # 3. Merge top-level lists and custom scoring/batch settings
        if ($srcConfig.target_companies -and @($srcConfig.target_companies).Count -gt 0) {
            $tgtConfig.target_companies = $srcConfig.target_companies
        }
        if ($srcConfig.premier_employers -and @($srcConfig.premier_employers).Count -gt 0) {
            $tgtConfig.premier_employers = $srcConfig.premier_employers
        }
        if ($srcConfig.ats_boards -and @($srcConfig.ats_boards).Count -gt 0) {
            $tgtConfig | Add-Member -NotePropertyName "ats_boards" -NotePropertyValue $srcConfig.ats_boards -Force
        }
        if ($srcConfig.scoring_weights) {
            $tgtConfig.scoring_weights = $srcConfig.scoring_weights
        }
        if ($srcConfig.execution_settings) {
            $tgtConfig.execution_settings = $srcConfig.execution_settings
        }
        if ($srcConfig.search_batches) {
            $tgtConfig | Add-Member -NotePropertyName "search_batches" -NotePropertyValue $srcConfig.search_batches -Force
        }

        if (-not $DryRun) {
            $tgtConfig | ConvertTo-Json -Depth 10 | Set-Content $tgtSearchConfig -Encoding UTF8
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
    $linterScript = Join-Path $targetRoot "scripts/lint_resume_integrity.ps1"
    if (Test-Path $linterScript) {
        & $linterScript -TailoredResumePath $masterResume.FullName
    }
}
exit 0
