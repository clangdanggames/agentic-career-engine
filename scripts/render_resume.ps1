#!/usr/bin/env pwsh
param (
    [Parameter(Mandatory = $true)]
    [string]$MarkdownPath,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [switch]$VerifyIntegrity,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Standard", "Compact", "Tight")]
    [string]$Density = "Standard",

    [Parameter(Mandatory = $false)]
    [ValidateSet("Resume", "CoverLetter")]
    [string]$DocumentType = "Resume",

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

$htmlParent = Split-Path -Parent $HtmlPath
if (-not [string]::IsNullOrWhiteSpace($htmlParent) -and -not (Test-Path $htmlParent)) {
    New-Item -ItemType Directory -Path $htmlParent -Force | Out-Null
}

$fullHtml = Build-DocumentHtml -BodyContent $bodyHtml -TitleText $candidateName -DocType $DocumentType -DensityPreset $Density
Set-Content -Path $HtmlPath -Value $fullHtml -Encoding UTF8
Write-Host "Generated HTML ($DocumentType, Density: $Density) at: $HtmlPath"

# Locate Chromium-based headless browser (Edge or Chrome)
$BrowserPath = $null
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
    if (Test-Path $path) {
        $BrowserPath = $path
        break
    }
}

# Check if browser binary is available on PATH
if ($null -eq $BrowserPath) {
    $pathBins = @("msedge", "chrome", "google-chrome", "google-chrome-stable", "chromium", "chromium-browser")
    foreach ($bin in $pathBins) {
        $cmd = Get-Command $bin -ErrorAction SilentlyContinue
        if ($cmd) {
            $BrowserPath = $cmd.Source
            break
        }
    }
}

if ($null -eq $BrowserPath) {
    Write-Warning "Neither Microsoft Edge nor Google Chrome was found at standard locations. HTML generated, but PDF compile skipped."
    exit 0
}

Write-Host "Compiling clean PDF via Headless Browser: $BrowserPath"
$fileUri = [System.Uri]::new($HtmlPath).AbsoluteUri

function Invoke-HeadlessPdfCompile {
    param (
        [string]$BrowserBin,
        [string]$SourceUri,
        [string]$PdfOutPath
    )
    if ($env:OS -eq "Windows_NT") {
        $browserArgs = @(
            "--headless",
            "--disable-gpu",
            "--print-to-pdf-no-header",
            "--print-to-pdf=`"$PdfOutPath`"",
            "`"$SourceUri`""
        )
    } else {
        $browserArgs = @(
            "--headless",
            "--disable-gpu",
            "--no-sandbox",
            "--print-to-pdf-no-header",
            "--print-to-pdf=$PdfOutPath",
            "$SourceUri"
        )
    }
    $null = Start-Process -FilePath $BrowserBin -ArgumentList $browserArgs -PassThru -Wait -NoNewWindow
}

Invoke-HeadlessPdfCompile -BrowserBin $BrowserPath -SourceUri $fileUri -PdfOutPath $OutputPath

if (-not (Test-Path $OutputPath)) {
    Write-Error "Failed to generate PDF at $OutputPath"
    exit 1
}

$pageCount = Get-PdfPageCount -PdfFile $OutputPath
$activeDensity = $Density

# Automatic 1-page density stepping when minor 2-page overflow occurs and AutoFit is enabled (or default Density was used)
if ($pageCount -eq 2 -and ($AutoFit -or -not $PSBoundParameters.ContainsKey("Density")) -and $DocumentType -eq "Resume") {
    $fallbackPresets = @("Compact", "Tight") | Where-Object { $_ -ne $Density }
    foreach ($preset in $fallbackPresets) {
        Write-Host "Page count is $pageCount (> 1). Auto-fitting with '$preset' density preset..." -ForegroundColor Yellow
        $activeDensity = $preset
        $fullHtml = Build-DocumentHtml -BodyContent $bodyHtml -TitleText $candidateName -DocType $DocumentType -DensityPreset $preset
        Set-Content -Path $HtmlPath -Value $fullHtml -Encoding UTF8
        Invoke-HeadlessPdfCompile -BrowserBin $BrowserPath -SourceUri $fileUri -PdfOutPath $OutputPath
        $pageCount = Get-PdfPageCount -PdfFile $OutputPath
        if ($pageCount -eq 1) {
            break
        }
    }
    # If document is still > 1 page even at Tight density (e.g. a genuine 2-page Master CV), restore original Density so typography is not needlessly squished
    if ($pageCount -gt 1 -and $activeDensity -ne $Density) {
        $activeDensity = $Density
        $fullHtml = Build-DocumentHtml -BodyContent $bodyHtml -TitleText $candidateName -DocType $DocumentType -DensityPreset $Density
        Set-Content -Path $HtmlPath -Value $fullHtml -Encoding UTF8
        Invoke-HeadlessPdfCompile -BrowserBin $BrowserPath -SourceUri $fileUri -PdfOutPath $OutputPath
        $pageCount = Get-PdfPageCount -PdfFile $OutputPath
    }
}

if ($CleanHtml -and (Test-Path $HtmlPath)) {
    Remove-Item -Path $HtmlPath -Force -ErrorAction SilentlyContinue
}

Write-Host "SUCCESS: PDF generated cleanly at $OutputPath" -ForegroundColor Green
if ($pageCount -eq 1) {
    Write-Host "PASS: Strict 1-page constraint verified (1 page | Mode: $DocumentType | Density: $activeDensity)." -ForegroundColor Green
} elseif ($pageCount -gt 1) {
    Write-Warning "OVERFLOW: Compiled PDF is $pageCount pages even at '$activeDensity' density. Trim 1-2 bullets to fit strictly on 1 page."
}
exit 0
