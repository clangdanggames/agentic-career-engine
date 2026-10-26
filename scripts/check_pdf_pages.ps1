#!/usr/bin/env pwsh
param (
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $false)]
    [int]$TargetPages = 0
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path $Path)) {
    Write-Error "PDF file not found at: $Path"
    exit 1
}

$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if ($TargetPages -le 0) {
    $TargetPages = 1
    $configPath = Join-Path $workspaceRoot "workflows/ats_search_config.json"
    if (Test-Path $configPath) {
        try {
            $cfg = Get-Content -Path $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($null -ne $cfg.resume_settings -and $null -ne $cfg.resume_settings.target_pages -and [int]$cfg.resume_settings.target_pages -gt 0) {
                $TargetPages = [int]$cfg.resume_settings.target_pages
            }
        } catch {}
    }
}

$resolved = (Resolve-Path $Path).Path
$bytes = [System.IO.File]::ReadAllBytes($resolved)
$text = [System.Text.Encoding]::ASCII.GetString($bytes)
$pageMatches = [regex]::Matches($text, "/Type\s*/Page[^s]")
$pageCount = $pageMatches.Count

$fileName = Split-Path $resolved -Leaf
$color = if ($pageCount -eq $TargetPages) { "Green" } else { "Yellow" }
Write-Host "PDF Page Count for $fileName : $pageCount (Target: $TargetPages)" -ForegroundColor $color

if ($pageCount -eq $TargetPages) {
    Write-Host "PASS: Target $TargetPages-page constraint met." -ForegroundColor Green
} elseif ($pageCount -gt $TargetPages) {
    Write-Warning "OVERFLOW: PDF is $pageCount pages (Target: $TargetPages). Consider using Compact/Tight density in render_resume.ps1 or demoting 1-2 less relevant bullets back to resumes/modular_reserve_bank.md."
} elseif ($pageCount -gt 0 -and $pageCount -lt $TargetPages) {
    Write-Warning "UNDERFLOW / SPARSE: PDF is $pageCount page(s), below target of $TargetPages page(s). Expand the resume by pulling additional verified bullets/skills from resumes/modular_reserve_bank.md and resumes/career_profile_bank.md or using Comfortable/Spacious density."
} else {
    Write-Warning "Could not detect page count via stream marker inspection."
}

$global:LASTEXITCODE = 0
return $pageCount
