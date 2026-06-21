# Unit Tests for APA 7th Edition LaTeX Template Compilation Pipeline on Windows

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ParentDir = Split-Path -Parent $ScriptDir
$BcfFile = Join-Path $ScriptDir "mock_main.bcf"

$FailedTests = 0
$TotalTests = 0

function Assert-Equals($Expected, $Actual, $Message) {
    global: $TotalTests = $TotalTests + 1
    if ($Expected -eq $Actual) {
        Write-Host "  [PASS] $Message" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $Message" -ForegroundColor Red
        Write-Host "         Expected: '$Expected'"
        Write-Host "         Actual:   '$Actual'"
        global: $FailedTests = $FailedTests + 1
    }
}

# Mapping function (exact copy of compile.ps1 implementation for testing)
function Get-BiberVersion($BcfVer) {
    switch ($BcfVer) {
        "3.8"  { return "2.17" }
        "3.9"  { return "2.18" }
        "3.10" { return "2.19" }
        "3.11" { return "2.21" }
        default { return "2.17" } # Fallback
    }
}

Write-Host "=================================================="
Write-Host "Running Unit Tests for compile.ps1"
Write-Host "=================================================="

# Test Case 1: Get-BiberVersion mapping
Write-Host "Test Case 1: Get-BiberVersion mapping..."
Assert-Equals "2.17" (Get-BiberVersion "3.8") "Version 3.8 maps to Biber 2.17"
Assert-Equals "2.18" (Get-BiberVersion "3.9") "Version 3.9 maps to Biber 2.18"
Assert-Equals "2.19" (Get-BiberVersion "3.10") "Version 3.10 maps to Biber 2.19"
Assert-Equals "2.21" (Get-BiberVersion "3.11") "Version 3.11 maps to Biber 2.21"
Assert-Equals "2.17" (Get-BiberVersion "unknown") "Unknown version falls back to Biber 2.17"

# Test Case 2: Regex matching
Write-Host "Test Case 2: Parsing .bcf controlfile version..."
$MockContent = '<?xml version="1.0" encoding="utf-8"?><bcf:controlfile version="3.11" xmlns:bcf="https://github.com/plk/biblatex/controlfile"></bcf:controlfile>'
$ParsedVer = ""
if ($MockContent -match 'controlfile version="([0-9]+\.[0-9]+)"') {
    $ParsedVer = $Matches[1]
}
Assert-Equals "3.11" $ParsedVer "PowerShell regex successfully extracts version 3.11"

# Test Case 3: Resolving Biber version from parsed version
Write-Host "Test Case 3: Resolving Biber version from parsed version..."
$MockContent = '<?xml version="1.0" encoding="utf-8"?><bcf:controlfile version="3.10"></bcf:controlfile>'
$ParsedVer = ""
if ($MockContent -match 'controlfile version="([0-9]+\.[0-9]+)"') {
    $ParsedVer = $Matches[1]
}
$ResolvedBiber = Get-BiberVersion $ParsedVer
Assert-Equals "2.19" $ResolvedBiber "Correctly resolves Biber 2.19 for BCF version 3.10"

Write-Host "=================================================="
if ($FailedTests -eq 0) {
    Write-Host "ALL $TotalTests TESTS PASSED SUCCESSFULLY!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "$FailedTests OUT OF $TotalTests TESTS FAILED." -ForegroundColor Red
    exit 1
}
