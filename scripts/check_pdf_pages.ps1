param (
    [Parameter(Mandatory = $true)]
    [string]$Path
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $Path)) {
    Write-Error "PDF file not found at: $Path"
    exit 1
}

$resolved = (Resolve-Path $Path).Path
$bytes = [System.IO.File]::ReadAllBytes($resolved)
$text = [System.Text.Encoding]::ASCII.GetString($bytes)
$pageMatches = [regex]::Matches($text, "/Type\s*/Page[^s]")
$pageCount = $pageMatches.Count

$fileName = Split-Path $resolved -Leaf
$color = if ($pageCount -eq 1) { "Green" } else { "Yellow" }
Write-Host "PDF Page Count for $fileName : $pageCount" -ForegroundColor $color

if ($pageCount -eq 1) {
    Write-Host "PASS: Perfect 1-page resume constraint met." -ForegroundColor Green
} elseif ($pageCount -gt 1) {
    Write-Warning "OVERFLOW: PDF is $pageCount pages. Consider trimming 1-2 bullet points or adjusting line-height in render_resume.ps1 to keep it strictly to 1 page."
} else {
    Write-Warning "Could not detect page count via stream marker inspection."
}

return $pageCount
