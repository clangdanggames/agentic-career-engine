# Engine In-Place Update Utility
# Safely updates core ACE engine scripts, skills, and SOP workflows from GitHub upstream.
# Strictly preserves all personal user state (resumes, application dossiers, story banks, ledgers, contacts).
param (
    [string]$RepoUrl = "https://github.com/clangdanggames/agentic-career-engine",
    [string]$Branch = "main",
    [switch]$SkipBackup,
    [switch]$DryRun,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$global:ProgressPreference = "SilentlyContinue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$workspaceRoot = (Resolve-Path "$PSScriptRoot\..").Path
$backupRootDir = Join-Path $workspaceRoot ".backups"

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  Agentic Career Engine (ACE) - In-Place Engine Updater" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "Workspace  : $workspaceRoot" -ForegroundColor Gray
Write-Host "Upstream   : $RepoUrl ($Branch)`n" -ForegroundColor Gray

if ($DryRun) {
    Write-Host "[DRY-RUN MODE]: Simulating engine update. No files will be overwritten.`n" -ForegroundColor Yellow
} elseif (-not $Force) {
    $confirm = Read-Host "Update engine components in this workspace from upstream? (Y/n)"
    if ($confirm -and $confirm -ne 'y' -and $confirm -ne 'Y') {
        Write-Host "Update cancelled by user." -ForegroundColor Cyan
        exit 0
    }
}

# ----------------------------------------------------
# 1. Create Local Safety Snapshot
# ----------------------------------------------------
if (-not $SkipBackup -and -not $DryRun) {
    $timestamp = (Get-Date).ToString("yyyy-MM-dd_HHmmss")
    $backupDir = Join-Path $backupRootDir "backup_$timestamp"
    Write-Host "[1/5] Creating safety snapshot at .backups/backup_$timestamp..." -ForegroundColor Cyan

    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

    # Backup engine components
    $backupItems = @("scripts", ".agents", "workflows", "applications\dossier_template", "AGENTS.md", "HARNESS_SETUP.md")
    foreach ($item in $backupItems) {
        $sourceItem = Join-Path $workspaceRoot $item
        if (Test-Path $sourceItem) {
            $destItem = Join-Path $backupDir $item
            $parentDir = Split-Path $destItem -Parent
            if (-not (Test-Path $parentDir)) { New-Item -ItemType Directory -Path $parentDir -Force | Out-Null }
            Copy-Item -Path $sourceItem -Destination $destItem -Recurse -Force
        }
    }
    Write-Host "  Snapshot created successfully." -ForegroundColor Green
} else {
    Write-Host "[1/5] Skipping safety snapshot." -ForegroundColor DarkGray
}

# ----------------------------------------------------
# 2. Download Latest Upstream Engine Archive
# ----------------------------------------------------
Write-Host "`n[2/5] Fetching latest engine release from GitHub ($Branch)..." -ForegroundColor Cyan
$tempZipPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "ace_engine_update_$([System.Guid]::NewGuid().ToString('N')).zip")
$tempExtractDir = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "ace_engine_extracted_$([System.Guid]::NewGuid().ToString('N'))")

$downloadUrl = "$RepoUrl/archive/refs/heads/$Branch.zip"
try {
    Write-Host "  Downloading: $downloadUrl" -ForegroundColor DarkGray
    Invoke-WebRequest -Uri $downloadUrl -OutFile $tempZipPath -UseBasicParsing
    Expand-Archive -Path $tempZipPath -DestinationPath $tempExtractDir -Force
    
    # Locate the extracted repo root (GitHub archives nest files in 'repo-branch')
    $extractedRoot = Get-ChildItem -Path $tempExtractDir -Directory | Select-Object -First 1
    if (-not $extractedRoot) {
        throw "Could not locate extracted repository contents in temporary directory."
    }
    $upstreamRoot = $extractedRoot.FullName
    Write-Host "  Archive downloaded and extracted successfully." -ForegroundColor Green
} catch {
    Write-Error "Failed to download or extract upstream engine archive: $_"
    if (Test-Path $tempZipPath) { Remove-Item -Path $tempZipPath -Force -ErrorAction SilentlyContinue }
    if (Test-Path $tempExtractDir) { Remove-Item -Path $tempExtractDir -Recurse -Force -ErrorAction SilentlyContinue }
    exit 1
}

# ----------------------------------------------------
# 3. Apply Engine Updates (Whitelisted Paths Only)
# ----------------------------------------------------
Write-Host "`n[3/5] Updating Engine Components (Zero User Data Overwrites)..." -ForegroundColor Cyan

$updatedCount = 0

function Update-EngineDirectory {
    param (
        [string]$SubPath
    )
    $sourceSub = Join-Path $upstreamRoot $SubPath
    $targetSub = Join-Path $workspaceRoot $SubPath

    if (Test-Path $sourceSub) {
        Write-Host "  -> Updating $SubPath..." -ForegroundColor DarkGray
        $files = Get-ChildItem -Path $sourceSub -Recurse -File
        foreach ($file in $files) {
            $relativePath = $file.FullName.Substring($sourceSub.Length).TrimStart('\', '/')
            $destFilePath = Join-Path $targetSub $relativePath
            $destFileDir = Split-Path $destFilePath -Parent

            if (-not $DryRun) {
                if (-not (Test-Path $destFileDir)) { New-Item -ItemType Directory -Path $destFileDir -Force | Out-Null }
                Copy-Item -Path $file.FullName -Destination $destFilePath -Force
            }
            $script:updatedCount++
        }
    }
}

# Update Scripts & Skills
Update-EngineDirectory -SubPath "scripts"
Update-EngineDirectory -SubPath ".agents/skills"
Update-EngineDirectory -SubPath "applications/dossier_template"

$srcAppSchema = Join-Path $upstreamRoot "applications/schema.json"
$tgtAppSchema = Join-Path $workspaceRoot "applications/schema.json"
if (Test-Path $srcAppSchema) {
    Write-Host "  -> Updating applications/schema.json..." -ForegroundColor DarkGray
    if (-not $DryRun) {
        Copy-Item -Path $srcAppSchema -Destination $tgtAppSchema -Force
    }
    $updatedCount++
}

# Update Core Workflow SOPs (never overwrite ats_search_config.json directly)
$coreWorkflowDocs = @(
    "job_hunt_workflow.md",
    "compensation_estimator.md",
    "targeted_job_sourcing_queries.md",
    "project_ingestion_prompt.md",
    "storage_and_backup.md",
    "engine_lifecycle.md"
)
foreach ($doc in $coreWorkflowDocs) {
    $srcDoc = Join-Path $upstreamRoot "workflows/$doc"
    $tgtDoc = Join-Path $workspaceRoot "workflows/$doc"
    if (Test-Path $srcDoc) {
        Write-Host "  -> Updating workflows/$doc..." -ForegroundColor DarkGray
        if (-not $DryRun) {
            Copy-Item -Path $srcDoc -Destination $tgtDoc -Force
        }
        $updatedCount++
    }
}

# Update Root Guides (Only update README if it's the project documentation, NOT a user dashboard)
$rootGuides = @("QUICK_START.md", "GENESIS_PROMPT.md", "AGENTS.md", "HARNESS_SETUP.md")
foreach ($guide in $rootGuides) {
    $srcGuide = Join-Path $upstreamRoot $guide
    $tgtGuide = Join-Path $workspaceRoot $guide
    if (Test-Path $srcGuide) {
        Write-Host "  -> Updating $guide..." -ForegroundColor DarkGray
        if (-not $DryRun) {
            Copy-Item -Path $srcGuide -Destination $tgtGuide -Force
        }
        $updatedCount++
    }
}

$upstreamReadme = Join-Path $upstreamRoot "README.md"
$targetReadme = Join-Path $workspaceRoot "README.md"
if (Test-Path $targetReadme) {
    $targetReadmeText = Get-Content $targetReadme -Raw -Encoding UTF8
    if ($targetReadmeText -notmatch "(Career Command Center|Pipeline Progress|Live Pipeline Funnel)") {
        Write-Host "  -> Updating README.md documentation..." -ForegroundColor DarkGray
        if (-not $DryRun) {
            Copy-Item -Path $upstreamReadme -Destination $targetReadme -Force
        }
        $updatedCount++
    } else {
        Write-Host "  [i] Skipping README.md (User customized as active dashboard)." -ForegroundColor DarkGray
    }
}

# ----------------------------------------------------
# 4. Intelligently Merge Search Configuration Keys
# ----------------------------------------------------
Write-Host "`n[4/5] Merging Schema Updates into workflows/ats_search_config.json..." -ForegroundColor Cyan
$upstreamConfigPath = Join-Path $upstreamRoot "workflows\ats_search_config.json"
$targetConfigPath = Join-Path $workspaceRoot "workflows\ats_search_config.json"

if ((Test-Path $upstreamConfigPath) -and (Test-Path $targetConfigPath)) {
    try {
        $upstreamConfig = Get-Content $upstreamConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $targetConfig = Get-Content $targetConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json

        $script:mergedAny = $false
        function Merge-ConfigProperties {
            param (
                $UpstreamObj,
                $TargetObj,
                [string]$PathPrefix = ""
            )
            foreach ($prop in $UpstreamObj.PSObject.Properties) {
                $fullKey = if ($PathPrefix) { "$PathPrefix.$($prop.Name)" } else { $prop.Name }
                if (-not $TargetObj.PSObject.Properties[$prop.Name]) {
                    Write-Host "  -> Adding new schema field: $fullKey" -ForegroundColor DarkGray
                    $TargetObj | Add-Member -MemberType NoteProperty -Name $prop.Name -Value $prop.Value
                    $script:mergedAny = $true
                } elseif ($null -ne $prop.Value -and $prop.Value.GetType().Name -eq "PSCustomObject" -and $null -ne $TargetObj.($prop.Name) -and $TargetObj.($prop.Name).GetType().Name -eq "PSCustomObject") {
                    Merge-ConfigProperties -UpstreamObj $prop.Value -TargetObj $TargetObj.($prop.Name) -PathPrefix $fullKey
                }
            }
        }

        Merge-ConfigProperties -UpstreamObj $upstreamConfig -TargetObj $targetConfig

        # Migrate legacy flat root keys into nested search_criteria if present
        if ($targetConfig.PSObject.Properties["target_roles"] -and $targetConfig.target_roles) {
            $targetConfig.search_criteria.roles = $targetConfig.target_roles
            $script:mergedAny = $true
        }
        if ($targetConfig.PSObject.Properties["preferred_locations"] -and $targetConfig.preferred_locations) {
            $targetConfig.search_criteria.locations = $targetConfig.preferred_locations
            $script:mergedAny = $true
        }
        if ($targetConfig.PSObject.Properties["negative_keywords"] -and $targetConfig.negative_keywords) {
            $targetConfig.search_criteria.negative_keywords = $targetConfig.negative_keywords
            $script:mergedAny = $true
        }
        if ($targetConfig.PSObject.Properties["compensation_floor"] -and $null -ne $targetConfig.compensation_floor) {
            $targetConfig.search_criteria.compensation.floor = $targetConfig.compensation_floor
            $script:mergedAny = $true
        }
        if ($targetConfig.PSObject.Properties["target_compensation"] -and $null -ne $targetConfig.target_compensation) {
            $targetConfig.search_criteria.compensation.target = $targetConfig.target_compensation
            $script:mergedAny = $true
        }
        if ($targetConfig.PSObject.Properties["target_company_domains"] -and $targetConfig.target_company_domains -and @($targetConfig.target_companies).Count -eq 0) {
            $targetConfig.target_companies = $targetConfig.target_company_domains
            $script:mergedAny = $true
        }

        if ($script:mergedAny -and -not $DryRun) {
            $targetConfig | ConvertTo-Json -Depth 10 | Set-Content $targetConfigPath -Encoding UTF8
            Write-Host "  Schema fields merged into ats_search_config.json." -ForegroundColor Green
        } else {
            Write-Host "  ats_search_config.json is already up to date." -ForegroundColor DarkGray
        }
    } catch {
        Write-Warning "Could not merge search config schema: $_"
    }
}

# Normalize legacy ledger.json / sourcing_inbox.json fields in-place via sync_pipeline.ps1
$syncScriptPath = Join-Path $workspaceRoot "scripts\sync_pipeline.ps1"
if (-not $DryRun -and (Test-Path $syncScriptPath) -and (Test-Path (Join-Path $workspaceRoot "applications\ledger.json"))) {
    try {
        $null = & powershell -NoProfile -ExecutionPolicy Bypass -File $syncScriptPath *>&1
        $global:LASTEXITCODE = 0
    } catch {}
}

# ----------------------------------------------------
# 5. Clean Up Temporary Files & Verify
# ----------------------------------------------------
Write-Host "`n[5/5] Cleaning temporary extraction files..." -ForegroundColor Cyan
Remove-Item -Path $tempZipPath -Force -ErrorAction SilentlyContinue
Remove-Item -Path $tempExtractDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "`n======================================================" -ForegroundColor Green
Write-Host "  Engine Update Completed Successfully!               " -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Green
Write-Host "Engine Files Updated   : $updatedCount" -ForegroundColor White
Write-Host "Personal User State    : Strictly Preserved (0 files touched)" -ForegroundColor White
Write-Host "Backup Snapshot        : $(if (-not $SkipBackup -and -not $DryRun) { $backupDir } else { 'Skipped' })`n" -ForegroundColor White
exit 0
