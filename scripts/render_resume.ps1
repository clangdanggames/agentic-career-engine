#!/usr/bin/env pwsh
param (
    [Parameter(Mandatory = $true)]
    [string]$MarkdownPath,

    [Parameter(Mandatory = $false)]
    [Alias("OutputPdfPath")]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [switch]$VerifyIntegrity,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Tight", "Compact", "Standard", "Comfortable", "Spacious")]
    [string]$Density = "Standard",

    [Parameter(Mandatory = $false)]
    [ValidateSet("Resume", "CoverLetter")]
    [string]$DocumentType = "Resume",

    [Parameter(Mandatory = $false)]
    [int]$TargetPages = 0,

    [Parameter(Mandatory = $false)]
    [switch]$AutoFit,

    [Parameter(Mandatory = $false)]
    [switch]$CleanHtml
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path $MarkdownPath)) {
    Write-Error "Markdown file not found at: $MarkdownPath"
    exit 1
}

$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$minFillRatio = 0.78
if ($TargetPages -le 0) {
    $TargetPages = 1
    $configPath = Join-Path $workspaceRoot "workflows/ats_search_config.json"
    if (Test-Path $configPath) {
        try {
            $cfg = Get-Content -Path $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($null -ne $cfg.resume_settings) {
                if ($null -ne $cfg.resume_settings.target_pages -and [int]$cfg.resume_settings.target_pages -gt 0) {
                    $TargetPages = [int]$cfg.resume_settings.target_pages
                }
                if ($null -ne $cfg.resume_settings.min_fill_ratio -and [double]$cfg.resume_settings.min_fill_ratio -gt 0) {
                    $minFillRatio = [double]$cfg.resume_settings.min_fill_ratio
                }
            }
        } catch {}
    }
}

$ResolvedMd = (Resolve-Path $MarkdownPath).Path
$WorkDir = Split-Path -Parent $ResolvedMd

# Auto-detect CoverLetter document type if filename matches cover_letter*.md
if (-not $PSBoundParameters.ContainsKey("DocumentType") -and (Split-Path $ResolvedMd -Leaf) -match "(?i)cover[_-]?letter") {
    $DocumentType = "CoverLetter"
}

if ($VerifyIntegrity -and $DocumentType -eq "Resume") {
    $linterScript = Join-Path $PSScriptRoot "lint_resume_integrity.ps1"
    if (Test-Path $linterScript) {
        Write-Host "Running Resume Integrity Linter prior to compilation..." -ForegroundColor Cyan
        & $linterScript -TailoredResumePath $ResolvedMd
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Integrity check failed. Compilation aborted."
            exit 1
        }
    }
}

if (-not $OutputPath) {
    $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($ResolvedMd)
    $OutputPath = Join-Path $WorkDir "$BaseName.pdf"
} else {
    $OutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
}

$HtmlPath = [System.IO.Path]::ChangeExtension($OutputPath, ".html")

$mdContent = Get-Content -Path $ResolvedMd -Raw -Encoding UTF8

function Escape-HtmlEntities {
    param ([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return $Text }
    $escaped = $Text -replace '&', '&amp;'
    $escaped = $escaped -replace '<', '&lt;'
    $escaped = $escaped -replace '>', '&gt;'
    return $escaped
}

function Format-InlineMarkdown {
    param ([string]$Text)
    $safe = Escape-HtmlEntities -Text $Text
    $safe = [regex]::Replace($safe, '\*\*(.+?)\*\*', '<strong>$1</strong>')
    $safe = [regex]::Replace($safe, '\*(.+?)\*', '<em>$1</em>')
    $safe = [regex]::Replace($safe, '\[(.+?)\]\((.+?)\)', '<a href="$2">$1</a>')
    $safe = [regex]::Replace($safe, '`(.+?)`', '<code>$1</code>')
    return $safe
}

# Extract candidate name from first H1 if present, else fallback
$candidateName = "Candidate Resume"
if ($mdContent -match "(?m)^#\s+([^\r\n]+)") {
    $candidateName = Escape-HtmlEntities -Text $matches[1].Trim()
}

function Convert-MarkdownToHtmlBody {
    param ([string]$md)

    $lines = $md -split "\r?\n"
    $htmlLines = @()
    $inList = $false

    foreach ($line in $lines) {
        $trimmed = $line.Trim()

        if ($inList -and (-not $trimmed.StartsWith("- ") -and -not $trimmed.StartsWith("* "))) {
            $htmlLines += "</ul>"
            $inList = $false
        }

        if ($trimmed -eq "") {
            continue
        }

        if ($trimmed -match "^# (.+)$") {
            $h1Text = Escape-HtmlEntities -Text $matches[1]
            $htmlLines += "<h1 class='candidate-name'>$h1Text</h1>"
            continue
        }

        if ($trimmed -match "^## (.+)$") {
            $h2Text = Escape-HtmlEntities -Text $matches[1]
            $htmlLines += "<h2 class='section-title'>$h2Text</h2>"
            continue
        }

        if ($trimmed -match "^### (.+)$") {
            $h3Text = Format-InlineMarkdown -Text $matches[1]
            $htmlLines += "<h3 class='job-company'>$h3Text</h3>"
            continue
        }

        if ($trimmed -match "^---$") {
            continue
        }

        if ($trimmed -match "^[-*] (.+)$") {
            if (-not $inList) {
                $htmlLines += "<ul class='bullet-list'>"
                $inList = $true
            }
            $itemContent = Format-InlineMarkdown -Text $matches[1]
            $htmlLines += "<li>$itemContent</li>"
            continue
        }

        $para = Format-InlineMarkdown -Text $trimmed
        
        if ($para -match "^<strong>(.+?)</strong>\s*\|\s*(.+)$") {
            $htmlLines += "<div class='job-subheading'><span class='job-title'>$($matches[1])</span><span class='job-dates'>$($matches[2])</span></div>"
        } else {
            $htmlLines += "<p>$para</p>"
        }
    }

    if ($inList) {
        $htmlLines += "</ul>"
    }

    return $htmlLines -join "`n"
}

$bodyHtml = Convert-MarkdownToHtmlBody -md $mdContent

function Build-DocumentHtml {
    param (
        [string]$BodyContent,
        [string]$TitleText,
        [string]$DocType = "Resume",
        [string]$DensityPreset = "Standard"
    )

    if ($DocType -eq "CoverLetter") {
        $fontSize = "10.25pt"
        $lineHeight = "1.45"
        $bodyPadding = "0.60in 0.70in"
        $h1Size = "16pt"
        $h2Size = "10.5pt"
        $h3Size = "10pt"
        $pMargin = "8px"
        $secTop = "12px"
        $secBottom = "6px"
        $liMargin = "4px"
    } else {
        switch ($DensityPreset) {
            "Compact" {
                $fontSize = "8.35pt"
                $lineHeight = "1.19"
                $bodyPadding = "0.23in 0.34in"
                $h1Size = "16pt"
                $h2Size = "9.1pt"
                $h3Size = "8.9pt"
                $pMargin = "2px"
                $secTop = "4px"
                $secBottom = "2px"
                $liMargin = "1px"
            }
            "Tight" {
                $fontSize = "8.05pt"
                $lineHeight = "1.14"
                $bodyPadding = "0.19in 0.30in"
                $h1Size = "15pt"
                $h2Size = "8.8pt"
                $h3Size = "8.6pt"
                $pMargin = "1.5px"
                $secTop = "3px"
                $secBottom = "1.5px"
                $liMargin = "0.75px"
            }
            "Comfortable" {
                $fontSize = "9.15pt"
                $lineHeight = "1.34"
                $bodyPadding = "0.35in 0.44in"
                $h1Size = "18pt"
                $h2Size = "10.0pt"
                $h3Size = "9.6pt"
                $pMargin = "3.5px"
                $secTop = "7px"
                $secBottom = "3.5px"
                $liMargin = "2.5px"
            }
            "Spacious" {
                $fontSize = "9.60pt"
                $lineHeight = "1.42"
                $bodyPadding = "0.42in 0.50in"
                $h1Size = "19pt"
                $h2Size = "10.5pt"
                $h3Size = "10.0pt"
                $pMargin = "4.5px"
                $secTop = "9px"
                $secBottom = "4.5px"
                $liMargin = "3.5px"
            }
            default {
                $fontSize = "8.65pt"
                $lineHeight = "1.25"
                $bodyPadding = "0.28in 0.38in"
                $h1Size = "17pt"
                $h2Size = "9.5pt"
                $h3Size = "9.25pt"
                $pMargin = "2.5px"
                $secTop = "5px"
                $secBottom = "2.5px"
                $liMargin = "1.5px"
            }
        }
    }

    return @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>$TitleText</title>
    <style>
        @page {
            size: letter;
            margin: 0;
        }
        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }
        html, body {
            background-color: #ffffff;
            color: #1e293b;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            font-size: $fontSize;
            line-height: $lineHeight;
            -webkit-print-color-adjust: exact;
        }
        body {
            padding: $bodyPadding;
        }
        .candidate-name {
            font-size: $h1Size;
            font-weight: 700;
            color: #0f172a;
            letter-spacing: -0.02em;
            margin-bottom: 2px;
        }
        p {
            margin-bottom: $pMargin;
        }
        a {
            color: #2563eb;
            text-decoration: none;
        }
        .section-title {
            font-size: $h2Size;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            color: #0f172a;
            border-bottom: 1.25px solid #0f172a;
            padding-bottom: 1px;
            margin-top: $secTop;
            margin-bottom: $secBottom;
        }
        .job-company {
            font-size: $h3Size;
            font-weight: 700;
            color: #1e293b;
            margin-top: 3.5px;
            margin-bottom: 1px;
        }
        .job-subheading {
            display: flex;
            justify-content: space-between;
            align-items: baseline;
            font-size: 8.5pt;
            margin-bottom: 2px;
        }
        .job-title {
            font-weight: 600;
            color: #334155;
        }
        .job-dates {
            font-weight: 500;
            color: #64748b;
            font-size: 8.25pt;
        }
        .bullet-list {
            margin-left: 14px;
            margin-bottom: $pMargin;
        }
        .bullet-list li {
            margin-bottom: $liMargin;
            padding-left: 1px;
        }
        code {
            font-family: "Consolas", "Courier New", monospace;
            background: #f1f5f9;
            padding: 0.5px 2.5px;
            border-radius: 2px;
            font-size: 8.5pt;
        }
        em {
            color: #475569;
            font-size: 8.5pt;
        }
    </style>
</head>
<body>
    $BodyContent
</body>
</html>
"@
}

function Get-PdfPageCount {
    param ([string]$PdfFile)
    if (-not (Test-Path $PdfFile)) { return 0 }
    $bytes = [System.IO.File]::ReadAllBytes((Resolve-Path $PdfFile).Path)
    $text = [System.Text.Encoding]::ASCII.GetString($bytes)
    return ([regex]::Matches($text, "/Type\s*/Page[^s]")).Count
}

function Get-EstimatedVisualFillRatio {
    param ([string]$MarkdownText, [int]$TargetPageCount = 1)
    if ([string]::IsNullOrWhiteSpace($MarkdownText) -or $TargetPageCount -le 0) { return 0.0 }
    $lines = $MarkdownText -split "\r?\n"
    $visualLines = 0.0
    foreach ($l in $lines) {
        $t = $l.Trim()
        if ([string]::IsNullOrWhiteSpace($t) -or $t -eq "---") { continue }
        if ($t -match "^# ") { $visualLines += 2.0 }
        elseif ($t -match "^## ") { $visualLines += 1.7 }
        elseif ($t -match "^### ") { $visualLines += 1.3 }
        elseif ($t -match "^\*\*[^*]+\*\*\s*\|") { $visualLines += 1.15 }
        else {
            $cleanLen = ($t -replace "\*\*|\*|\[([^\]]+)\]\([^\)]+\)", '$1').Length
            $wrappedLines = [math]::Max(1.0, [math]::Ceiling($cleanLen / 132.0))
            $visualLines += ($wrappedLines * 1.08)
        }
    }
    # Standard 1-page capacity at 8.65pt / 1.25 line-height on US Letter is ~66.5 visual lines
    $capacity = 66.5 * $TargetPageCount
    return [math]::Round(($visualLines / $capacity), 2)
}

$htmlParent = Split-Path -Parent $HtmlPath
if (-not [string]::IsNullOrWhiteSpace($htmlParent) -and -not (Test-Path $htmlParent)) {
    New-Item -ItemType Directory -Path $htmlParent -Force | Out-Null
}

$fullHtml = Build-DocumentHtml -BodyContent $bodyHtml -TitleText $candidateName -DocType $DocumentType -DensityPreset $Density
Set-Content -Path $HtmlPath -Value $fullHtml -Encoding UTF8
Write-Host "Generated HTML ($DocumentType, Density: $Density) at: $HtmlPath"

# Locate Chromium-based headless browsers (Edge or Chrome)
$AvailableBrowsers = [System.Collections.Generic.List[string]]::new()
$CandidatePaths = @(
    # Windows paths
    "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    "C:\Program Files\Microsoft\Edge\Application\msedge.exe",
    "C:\Program Files\Google\Chrome\Application\chrome.exe",
    "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    # macOS paths
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
    "/Applications/Chromium.app/Contents/MacOS/Chromium",
    # Linux paths
    "/usr/bin/google-chrome",
    "/usr/bin/google-chrome-stable",
    "/usr/bin/chromium",
    "/usr/bin/chromium-browser"
)

foreach ($path in $CandidatePaths) {
    if ((Test-Path $path) -and -not $AvailableBrowsers.Contains($path)) {
        $AvailableBrowsers.Add($path)
    }
}

$pathBins = @("msedge", "chrome", "google-chrome", "google-chrome-stable", "chromium", "chromium-browser")
foreach ($bin in $pathBins) {
    $cmd = Get-Command $bin -ErrorAction SilentlyContinue
    if ($cmd -and -not $AvailableBrowsers.Contains($cmd.Source)) {
        $AvailableBrowsers.Add($cmd.Source)
    }
}

if ($AvailableBrowsers.Count -eq 0) {
    Write-Warning "Neither Microsoft Edge nor Google Chrome was found at standard locations. HTML generated, but PDF compile skipped."
    exit 0
}

$BrowserPath = $AvailableBrowsers[0]
Write-Host "Compiling clean PDF via Headless Browser: $BrowserPath"
$fileUri = [System.Uri]::new($HtmlPath).AbsoluteUri

function Invoke-HeadlessPdfCompile {
    param (
        [string]$BrowserBin,
        [string]$SourceUri,
        [string]$PdfOutPath
    )
    $tempProfileDir = Join-Path ([System.IO.Path]::GetTempPath()) ("ace_pdf_profile_" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tempProfileDir -Force | Out-Null
    $compileStart = (Get-Date).ToUniversalTime().AddSeconds(-1)

    $candidatesToTry = @($BrowserBin) + @($AvailableBrowsers | Where-Object { $_ -ne $BrowserBin })
    try {
        foreach ($candidate in $candidatesToTry) {
            if ($env:OS -eq "Windows_NT") {
                $browserArgs = @(
                    "--headless",
                    "--disable-gpu",
                    "--no-first-run",
                    "--no-default-browser-check",
                    "--user-data-dir=`"$tempProfileDir`"",
                    "--print-to-pdf-no-header",
                    "--print-to-pdf=`"$PdfOutPath`"",
                    "`"$SourceUri`""
                )
            } else {
                $browserArgs = @(
                    "--headless",
                    "--disable-gpu",
                    "--no-sandbox",
                    "--no-first-run",
                    "--no-default-browser-check",
                    "--user-data-dir=$tempProfileDir",
                    "--print-to-pdf-no-header",
                    "--print-to-pdf=$PdfOutPath",
                    "$SourceUri"
                )
            }
            $null = Start-Process -FilePath $candidate -ArgumentList $browserArgs -PassThru -Wait -NoNewWindow
            if ((Test-Path $PdfOutPath) -and ((Get-Item $PdfOutPath).LastWriteTimeUtc -ge $compileStart)) {
                $script:BrowserPath = $candidate
                break
            }
        }
    } finally {
        if (Test-Path $tempProfileDir) {
            Remove-Item -Path $tempProfileDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Invoke-HeadlessPdfCompile -BrowserBin $BrowserPath -SourceUri $fileUri -PdfOutPath $OutputPath

if (-not (Test-Path $OutputPath)) {
    Write-Error "Failed to generate PDF at $OutputPath"
    exit 1
}

$pageCount = Get-PdfPageCount -PdfFile $OutputPath
$activeDensity = $Density
$estimatedFillRatio = Get-EstimatedVisualFillRatio -MarkdownText $mdContent -TargetPageCount $TargetPages

# Bi-Directional Auto-Fit (Rule 6): Shrink minor overflow OR expand sparse layouts to neatly fill TargetPages
if (($AutoFit -or -not $PSBoundParameters.ContainsKey("Density")) -and $DocumentType -eq "Resume") {
    if ($pageCount -eq ($TargetPages + 1)) {
        # 1. Shrinking Path: Document spilled 1 page over TargetPages
        $shrinkPresets = @("Compact", "Tight") | Where-Object { $_ -ne $Density }
        foreach ($preset in $shrinkPresets) {
            Write-Host "Page count is $pageCount (> Target $TargetPages). Auto-shrinking with '$preset' density preset..." -ForegroundColor Yellow
            $activeDensity = $preset
            $fullHtml = Build-DocumentHtml -BodyContent $bodyHtml -TitleText $candidateName -DocType $DocumentType -DensityPreset $preset
            Set-Content -Path $HtmlPath -Value $fullHtml -Encoding UTF8
            Invoke-HeadlessPdfCompile -BrowserBin $BrowserPath -SourceUri $fileUri -PdfOutPath $OutputPath
            $pageCount = Get-PdfPageCount -PdfFile $OutputPath
            if ($pageCount -le $TargetPages) {
                break
            }
        }
        # If document still exceeds TargetPages even at Tight density (e.g. a genuine multi-page Master CV rendered with TargetPages=1), restore original Density
        if ($pageCount -gt $TargetPages -and $activeDensity -ne $Density) {
            $activeDensity = $Density
            $fullHtml = Build-DocumentHtml -BodyContent $bodyHtml -TitleText $candidateName -DocType $DocumentType -DensityPreset $Density
            Set-Content -Path $HtmlPath -Value $fullHtml -Encoding UTF8
            Invoke-HeadlessPdfCompile -BrowserBin $BrowserPath -SourceUri $fileUri -PdfOutPath $OutputPath
            $pageCount = Get-PdfPageCount -PdfFile $OutputPath
        }
    } elseif ($pageCount -lt $TargetPages -or ($pageCount -eq $TargetPages -and $estimatedFillRatio -lt $minFillRatio)) {
        # 2. Expanding Path: Document is under TargetPages or has sparse vertical fill (< minFillRatio)
        $expandPresets = if ($pageCount -lt $TargetPages -or $estimatedFillRatio -lt 0.75) {
            @("Comfortable", "Spacious")
        } else {
            @("Comfortable")
        }
        foreach ($preset in $expandPresets) {
            if ($preset -eq $activeDensity) { continue }
            $prevDensity = $activeDensity
            Write-Host "Sparse layout detected (Fill ratio ~$($estimatedFillRatio * 100)% for $TargetPages page(s)). Auto-expanding with '$preset' density preset..." -ForegroundColor Cyan
            $fullHtml = Build-DocumentHtml -BodyContent $bodyHtml -TitleText $candidateName -DocType $DocumentType -DensityPreset $preset
            Set-Content -Path $HtmlPath -Value $fullHtml -Encoding UTF8
            Invoke-HeadlessPdfCompile -BrowserBin $BrowserPath -SourceUri $fileUri -PdfOutPath $OutputPath
            $newPageCount = Get-PdfPageCount -PdfFile $OutputPath

            if ($newPageCount -gt $TargetPages) {
                # Roll back if expanding pushed the document over TargetPages
                $activeDensity = $prevDensity
                $fullHtml = Build-DocumentHtml -BodyContent $bodyHtml -TitleText $candidateName -DocType $DocumentType -DensityPreset $prevDensity
                Set-Content -Path $HtmlPath -Value $fullHtml -Encoding UTF8
                Invoke-HeadlessPdfCompile -BrowserBin $BrowserPath -SourceUri $fileUri -PdfOutPath $OutputPath
                $pageCount = Get-PdfPageCount -PdfFile $OutputPath
                break
            } else {
                $activeDensity = $preset
                $pageCount = $newPageCount
            }
        }
    }
}

if ($CleanHtml -and (Test-Path $HtmlPath)) {
    Remove-Item -Path $HtmlPath -Force -ErrorAction SilentlyContinue
}

Write-Host "SUCCESS: PDF generated cleanly at $OutputPath" -ForegroundColor Green
if ($pageCount -eq $TargetPages) {
    Write-Host "PASS: Target $TargetPages-page constraint verified ($pageCount page(s) | Mode: $DocumentType | Density: $activeDensity)." -ForegroundColor Green
    if ($DocumentType -eq "Resume" -and $estimatedFillRatio -lt 0.55) {
        Write-Warning "SPARSE CONTENT: Resume content fills ~$([int][math]::Round($estimatedFillRatio * 100))% of $TargetPages page(s) even at '$activeDensity' density. Pull additional verified bullets or skills from resumes/modular_reserve_bank.md and resumes/career_profile_bank.md to substantively fill the page."
    }
} elseif ($pageCount -gt $TargetPages) {
    Write-Warning "OVERFLOW: Compiled PDF is $pageCount pages (Target: $TargetPages) at '$activeDensity' density. Demote 1-2 less relevant bullets to resumes/modular_reserve_bank.md or adjust -TargetPages."
} elseif ($pageCount -gt 0 -and $pageCount -lt $TargetPages) {
    Write-Warning "UNDERFLOW / SPARSE: Compiled PDF is $pageCount page(s), below target of $TargetPages page(s). Pull additional verified bullets or skills from resumes/modular_reserve_bank.md and resumes/career_profile_bank.md to fill $TargetPages page(s)."
}
exit 0
