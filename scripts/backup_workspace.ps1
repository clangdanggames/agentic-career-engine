# Agentic Career Engine (ACE) - Workspace Backup & Snapshot Utility
# Creates timestamped .zip snapshots of personal candidate state or entire workspace.
# Pure PowerShell: Zero dependencies on Python, Git, or external archive utilities.
param (
    [Parameter(Mandatory = $false, Position = 0)]
    [string]$Destination,

    [switch]$Full,
    [switch]$List,
    [int]$KeepRecent = 0
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$workspaceRoot = (Resolve-Path "$PSScriptRoot\..").Path
$backupRootDir = Join-Path $workspaceRoot ".backups"

# --- LIST BACKUPS MODE ---
if ($List) {
    Write-Host "======================================================" -ForegroundColor Cyan
    Write-Host "  Agentic Career Engine (ACE) - Local Snapshots       " -ForegroundColor Cyan
    Write-Host "======================================================" -ForegroundColor Cyan
    Write-Host "Backup Directory: $backupRootDir`n" -ForegroundColor Gray

    if (-not (Test-Path $backupRootDir)) {
        Write-Host "No local backup directory found at .backups/" -ForegroundColor Yellow
        exit 0
    }

    $backups = Get-ChildItem -Path $backupRootDir -Filter "*.zip" | Sort-Object LastWriteTime -Descending
    if ($backups.Count -eq 0) {
        Write-Host "No .zip backup archives found in .backups/" -ForegroundColor Yellow
        exit 0
    }

    Write-Host "Found $($backups.Count) snapshot archive(s):`n" -ForegroundColor Green
    foreach ($b in $backups) {
        $sizeMB = [math]::Round($b.Length / 1MB, 2)
        $sizeStr = if ($sizeMB -ge 0.01) { "$sizeMB MB" } else { "$([math]::Round($b.Length / 1KB, 1)) KB" }
        Write-Host "  [Archive] $($b.Name)" -ForegroundColor Cyan
        Write-Host "            Created: $($b.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')) | Size: $sizeStr" -ForegroundColor DarkGray
    }
    Write-Host ""
    exit 0
}

# --- SNAPSHOT CREATION ---
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  Agentic Career Engine (ACE) - Workspace Snapshot    " -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

$timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")

# Determine target destination zip path
$targetZip = $null
if ([string]::IsNullOrWhiteSpace($Destination)) {
    if (-not (Test-Path $backupRootDir)) {
        New-Item -ItemType Directory -Path $backupRootDir -Force | Out-Null
    }
    $targetZip = Join-Path $backupRootDir "ace_backup_$timestamp.zip"
} else {
    # If destination is an existing directory or ends with a slash, place file inside it
    if ((Test-Path $Destination -PathType Container) -or $Destination.EndsWith("\") -or $Destination.EndsWith("/")) {
        if (-not (Test-Path $Destination)) {
            New-Item -ItemType Directory -Path $Destination -Force | Out-Null
        }
        $targetZip = Join-Path $Destination "ace_backup_$timestamp.zip"
    } elseif ($Destination.EndsWith(".zip", [System.StringComparison]::OrdinalIgnoreCase)) {
        $parentDir = Split-Path $Destination -Parent
        if (-not [string]::IsNullOrWhiteSpace($parentDir) -and -not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }
        $targetZip = [System.IO.Path]::GetFullPath($Destination)
    } else {
        # Treat as directory path to create
        if (-not (Test-Path $Destination)) {
            New-Item -ItemType Directory -Path $Destination -Force | Out-Null
        }
        $targetZip = Join-Path $Destination "ace_backup_$timestamp.zip"
    }
}

Write-Host "Workspace   : $workspaceRoot" -ForegroundColor Gray
Write-Host "Destination : $targetZip" -ForegroundColor Gray
$scopeDescription = if ($Full) { "Full Workspace (excluding temp & git)" } else { "Candidate Career State (Resumes, Applications, Stories, Network)" }
Write-Host "Scope       : $scopeDescription`n" -ForegroundColor Gray

# Create a temporary staging folder to stage files cleanly
$tempStageDir = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "ace_backup_stage_$([System.Guid]::NewGuid().ToString('N'))")
New-Item -ItemType Directory -Path $tempStageDir -Force | Out-Null

try {
    $archivedItems = 0

    if ($Full) {
        # Full workspace snapshot: Copy all files except .git, .backups, scratch, *.tmp
        $items = Get-ChildItem -Path $workspaceRoot -Force
        foreach ($item in $items) {
            $name = $item.Name
            if ($name -in @(".git", ".backups", "scratch", ".gemini", ".vscode", ".cursor") -or $name.EndsWith(".tmp")) {
                continue
            }
            $targetPath = Join-Path $tempStageDir $name
            Copy-Item -Path $item.FullName -Destination $targetPath -Recurse -Force
            $archivedItems++
        }
    } else {
        # Standard candidate state snapshot
        $stateItems = @(
            "resumes",
            "applications",
            "stories",
            "network",
            "companies",
            "workflows\ats_search_config.json",
            "DASHBOARD.md"
        )

        foreach ($relPath in $stateItems) {
            $fullSource = Join-Path $workspaceRoot $relPath
            if (Test-Path $fullSource) {
                $targetPath = Join-Path $tempStageDir $relPath
                $parentDir = Split-Path $targetPath -Parent
                if (-not (Test-Path $parentDir)) {
                    New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
                }
                Copy-Item -Path $fullSource -Destination $targetPath -Recurse -Force
                $archivedItems++
            }
        }
    }

    if ($archivedItems -eq 0) {
        Write-Warning "No active career state or assets found to back up."
        exit 0
    }

    Write-Host "Archiving $archivedItems core item(s)..." -ForegroundColor Cyan
    if (Test-Path $targetZip) {
        Remove-Item -Path $targetZip -Force
    }

    Compress-Archive -Path "$tempStageDir\*" -DestinationPath $targetZip -CompressionLevel Optimal

    $zipInfo = Get-Item $targetZip
    $sizeMB = [math]::Round($zipInfo.Length / 1MB, 2)
    $sizeStr = if ($sizeMB -ge 0.01) { "$sizeMB MB" } else { "$([math]::Round($zipInfo.Length / 1KB, 1)) KB" }

    Write-Host "`nSUCCESS: Snapshot created successfully!" -ForegroundColor Green
    Write-Host "Archive  : $targetZip" -ForegroundColor Green
    Write-Host "Size     : $sizeStr`n" -ForegroundColor DarkGray

} finally {
    if (Test-Path $tempStageDir) {
        Remove-Item -Path $tempStageDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# --- RETENTION PRUNING ---
if ($KeepRecent -gt 0 -and (Test-Path $backupRootDir)) {
    $existing = Get-ChildItem -Path $backupRootDir -Filter "*.zip" | Sort-Object LastWriteTime -Descending
    if ($existing.Count -gt $KeepRecent) {
        $toDelete = $existing | Select-Object -Skip $KeepRecent
        Write-Host "Pruning old backups (keeping $KeepRecent most recent)..." -ForegroundColor Yellow
        foreach ($old in $toDelete) {
            Write-Host "  Removing old backup: $($old.Name)" -ForegroundColor DarkGray
            Remove-Item -Path $old.FullName -Force
        }
    }
}

return $targetZip
