param (
    [Parameter(Mandatory = $true)]
    [string]$MarkdownPath,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [switch]$VerifyIntegrity
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path $MarkdownPath)) {
    Write-Error "Markdown file not found at: $MarkdownPath"
    exit 1
}

$ResolvedMd = (Resolve-Path $MarkdownPath).Path
$WorkDir = Split-Path -Parent $ResolvedMd

if ($VerifyIntegrity) {
    $linterScript = Join-Path $PSScriptRoot "lint_resume_integrity.ps1"
    if (Test-Path $linterScript) {
        Write-Host "Running Resume Integrity Linter prior to compilation..." -ForegroundColor Cyan
        & powershell -ExecutionPolicy Bypass -File $linterScript -TailoredResumePath $ResolvedMd
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
    $OutputPath = [System.IO.Path]::GetFullPath($OutputPath)
}

$HtmlPath = [System.IO.Path]::ChangeExtension($OutputPath, ".html")

$mdContent = Get-Content -Path $ResolvedMd -Raw -Encoding UTF8

# Extract candidate name from first H1 if present, else fallback
$candidateName = "Candidate Resume"
if ($mdContent -match "(?m)^#\s+([^\r\n]+)") {
    $candidateName = $matches[1].Trim()
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
            $htmlLines += "<h1 class='candidate-name'>$($matches[1])</h1>"
            continue
        }

        if ($trimmed -match "^## (.+)$") {
            $htmlLines += "<h2 class='section-title'>$($matches[1])</h2>"
            continue
        }

        if ($trimmed -match "^### (.+)$") {
            $htmlLines += "<h3 class='job-company'>$($matches[1])</h3>"
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
            $itemContent = $matches[1]
            $itemContent = [regex]::Replace($itemContent, '\*\*(.+?)\*\*', '<strong>$1</strong>')
            $itemContent = [regex]::Replace($itemContent, '\*(.+?)\*', '<em>$1</em>')
            $itemContent = [regex]::Replace($itemContent, '\[(.+?)\]\((.+?)\)', '<a href="$2">$1</a>')
            $itemContent = [regex]::Replace($itemContent, '`(.+?)`', '<code>$1</code>')
            $htmlLines += "<li>$itemContent</li>"
            continue
        }

        $para = $trimmed
        $para = [regex]::Replace($para, '\*\*(.+?)\*\*', '<strong>$1</strong>')
        $para = [regex]::Replace($para, '\*(.+?)\*', '<em>$1</em>')
        $para = [regex]::Replace($para, '\[(.+?)\]\((.+?)\)', '<a href="$2">$1</a>')
        $para = [regex]::Replace($para, '`(.+?)`', '<code>$1</code>')
        
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

$fullHtml = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>$candidateName</title>
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
            font-size: 9pt;
            line-height: 1.28;
            -webkit-print-color-adjust: exact;
        }
        body {
            padding: 0.32in 0.42in;
        }
        .candidate-name {
            font-size: 18pt;
            font-weight: 700;
            color: #0f172a;
            letter-spacing: -0.02em;
            margin-bottom: 2px;
        }
        p {
            margin-bottom: 3px;
        }
        a {
            color: #2563eb;
            text-decoration: none;
        }
        .section-title {
            font-size: 10pt;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            color: #0f172a;
            border-bottom: 1.25px solid #0f172a;
            padding-bottom: 1px;
            margin-top: 6px;
            margin-bottom: 3.5px;
        }
        .job-company {
            font-size: 9.5pt;
            font-weight: 700;
            color: #1e293b;
            margin-top: 4.5px;
            margin-bottom: 1px;
        }
        .job-subheading {
            display: flex;
            justify-content: space-between;
            align-items: baseline;
            font-size: 8.75pt;
            margin-bottom: 2.5px;
        }
        .job-title {
            font-weight: 600;
            color: #334155;
        }
        .job-dates {
            font-weight: 500;
            color: #64748b;
            font-size: 8.5pt;
        }
        .bullet-list {
            margin-left: 15px;
            margin-bottom: 3px;
        }
        .bullet-list li {
            margin-bottom: 2px;
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
    $bodyHtml
</body>
</html>
"@

Set-Content -Path $HtmlPath -Value $fullHtml -Encoding UTF8
Write-Host "Generated HTML at: $HtmlPath"

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
$fileUri = "file:///" + ($HtmlPath -replace '\\', '/')
$processArgs = @(
    "--headless",
    "--disable-gpu",
    "--print-to-pdf-no-header",
    "--print-to-pdf=`"$OutputPath`"",
    "`"$fileUri`""
)

$proc = Start-Process -FilePath $BrowserPath -ArgumentList $processArgs -PassThru -Wait -NoNewWindow
if (Test-Path $OutputPath) {
    Write-Host "SUCCESS: PDF generated cleanly at $OutputPath"
} else {
    Write-Error "Failed to generate PDF at $OutputPath"
}
