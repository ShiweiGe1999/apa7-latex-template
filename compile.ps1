# Compilation script for the APA 7th edition paper on Windows (PowerShell)
# Prepends the local .bin folder to PATH and dynamically downloads biber.exe if missing.

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BinDir = Join-Path $ScriptDir ".bin"
$BcfFile = Join-Path $ScriptDir "main.bcf"
$TexFile = Join-Path $ScriptDir "main.tex"

# Function to map Bcf version to Biber version
function Get-BiberVersion($BcfVer) {
    switch ($BcfVer) {
        "3.8"  { return "2.17" }
        "3.9"  { return "2.18" }
        "3.10" { return "2.19" }
        "3.11" { return "2.21" }
        default { return "2.17" } # Fallback
    }
}

# Function to clear Biber PAR cache and build outputs
function Clean-Cache {
    Write-Host "Cleaning Biber and LaTeX build artifacts..." -ForegroundColor Yellow

    # Locate Biber binary to query cache path
    $BiberCmd = ""
    if (Get-Command biber -ErrorAction SilentlyContinue) {
        $BiberCmd = "biber"
    } elseif (Test-Path (Join-Path $BinDir "biber.exe")) {
        $BiberCmd = Join-Path $BinDir "biber.exe"
    }

    if ($BiberCmd) {
        try {
            $CacheDir = & $BiberCmd --cache 2>$null
            if ($CacheDir -and (Test-Path $CacheDir)) {
                Write-Host "Removing Biber PAR cache: $CacheDir" -ForegroundColor Gray
                Remove-Item -Recurse -Force $CacheDir -ErrorAction SilentlyContinue
            }
        } catch {}
    }

    if (Test-Path $BinDir) {
        Write-Host "Removing local binary cache: $BinDir" -ForegroundColor Gray
        Remove-Item -Recurse -Force $BinDir -ErrorAction SilentlyContinue
    }

    # Remove intermediate files
    $Intermediates = @("*.aux", "*.bbl", "*.bcf", "*.blg", "*.fdb_latexmk", "*.fls", "*.log", "*.run.xml", "*.synctex.gz", "*.out")
    foreach ($pattern in $Intermediates) {
        $files = Get-ChildItem -Path $ScriptDir -Filter $pattern -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            Write-Host "Removing intermediate file: $($file.Name)" -ForegroundColor Gray
            Remove-Item -Force $file.FullName -ErrorAction SilentlyContinue
        }
    }

    Write-Host "Clean completed." -ForegroundColor Green
}

# Function to print help documentation
function Print-Help {
    Write-Host "APA 7th Edition LaTeX Template Compilation Script"
    Write-Host "Usage: .\compile.ps1 [options]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -CleanCache, -c   Clear Biber PAR cache, local .bin, and LaTeX intermediate files"
    Write-Host "  -Help, -h         Show this help message"
}

# Function to download and extract Biber
function Download-Biber($Version) {
    Write-Host "Downloading Biber $Version locally into .bin\..." -ForegroundColor Yellow
    if (!(Test-Path $BinDir)) {
        New-Item -ItemType Directory -Path $BinDir | Out-Null
    }
    
    $BiberPath = Join-Path $BinDir "biber.exe"
    $Url = "https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/$Version/binaries/Windows/biber-MSWIN64.zip/download"
    $ZipFile = Join-Path $ScriptDir "biber-MSWIN64.zip"
    
    # Try downloading with Invoke-WebRequest
    try {
        Write-Host "Downloading Biber from $Url..." -ForegroundColor Gray
        Invoke-WebRequest -Uri $Url -OutFile $ZipFile -UseBasicParsing -TimeoutSec 60
    } catch {
        Write-Error "Failed to download Biber from SourceForge. Please check your internet connection."
        if (Test-Path $ZipFile) { Remove-Item $ZipFile -Force }
        exit 1
    }
    
    # Extract zip file
    try {
        Write-Host "Extracting biber.exe..." -ForegroundColor Gray
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::OpenRead($ZipFile)
        $entry = $zip.Entries | Where-Object { $_.Name -eq "biber.exe" }
        if ($null -eq $entry) {
            throw "biber.exe not found in downloaded zip archive"
        }
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $BiberPath, $true)
        $zip.Dispose()
    } catch {
        Write-Error "Failed to extract Biber binary. The downloaded archive may be corrupt: $_"
        if (Test-Path $ZipFile) { Remove-Item $ZipFile -Force }
        exit 1
    } finally {
        if (Test-Path $ZipFile) { Remove-Item $ZipFile -Force }
    }
    
    # Verify execution and cache generation
    $VerifyOutput = & $BiberPath --version 2>$null
    if ($LASTEXITCODE -ne 0 -or $VerifyOutput -notmatch 'biber version') {
        Write-Warning "Downloaded Biber did not execute successfully. Attempting to clear PAR cache."
        try {
            $CacheDir = & $BiberPath --cache 2>$null
            if ($CacheDir -and (Test-Path $CacheDir)) {
                Remove-Item -Recurse -Force $CacheDir -ErrorAction SilentlyContinue
            }
        } catch {}
        Write-Error "Downloaded Biber executable is not functional."
        exit 1
    }
}

# Pre-flight Check: Verify Tectonic is installed
$TectonicCmd = Get-Command tectonic -ErrorAction SilentlyContinue
if (!$TectonicCmd) {
    Write-Error "Tectonic is not installed or not in system PATH."
    Write-Host "Please install Tectonic before compiling." -ForegroundColor Yellow
    Write-Host "  PowerShell: winget install Tectonic.Tectonic" -ForegroundColor Yellow
    Write-Host "  Chocolatey: choco install tectonic" -ForegroundColor Yellow
    exit 1
}

# Handle command line parameters
if ($args.Count -gt 0) {
    switch -regex ($args[0]) {
        '^(-CleanCache|-c|--clean-cache)$' {
            Clean-Cache
            exit 0
        }
        '^(-Help|-h|--help)$' {
            Print-Help
            exit 0
        }
        default {
            Write-Error "Unknown option: $($args[0])"
            Print-Help
            exit 1
        }
    }
}

# Default Biber version
$BiberVer = "2.17"

# Self-healing check: Read version from Bcf if it exists from previous run
if (Test-Path $BcfFile) {
    $Content = Get-Content $BcfFile -Raw
    if ($Content -match 'controlfile version="([0-9]+\.[0-9]+)"') {
        $BiberVer = Get-BiberVersion $Matches[1]
    }
}

# Check global biber
$UseGlobal = $false
$GlobalBiber = Get-Command biber -ErrorAction SilentlyContinue
if ($GlobalBiber) {
    $VersionOutput = & biber --version 2>$null
    if ($VersionOutput -match 'biber version:\s*([0-9]+\.[0-9]+)') {
        if ($Matches[1] -eq $BiberVer) {
            Write-Host "Compatible global Biber version $($Matches[1]) detected. Skipping local download." -ForegroundColor Green
            $UseGlobal = $true
        }
    }
}

if (-not $UseGlobal) {
    $BiberPath = Join-Path $BinDir "biber.exe"
    $LocalBiberOk = $false
    
    if (Test-Path $BiberPath) {
        $LocalVersion = & $BiberPath --version 2>$null
        if ($LASTEXITCODE -eq 0 -and $LocalVersion -match 'biber version:\s*([0-9]+\.[0-9]+)') {
            if ($Matches[1] -eq $BiberVer) {
                $LocalBiberOk = $true
            }
        }
    }
    
    if (-not $LocalBiberOk) {
        Download-Biber $BiberVer
    }
    
    # Prepend to PATH, avoid duplicates
    $PathList = $env:PATH -split ';'
    if ($PathList -notcontains $BinDir) {
        $env:PATH = "$BinDir;$env:PATH"
    }
}

Write-Host "Compiling document with Tectonic..." -ForegroundColor Cyan
# Run tectonic with full absolute path to the tex file
& tectonic --keep-intermediates $TexFile
$CompileExitCode = $LASTEXITCODE

# If compile fails, check if Bcf version requires a different Biber version
if ($CompileExitCode -ne 0 -and (Test-Path $BcfFile)) {
    $Content = Get-Content $BcfFile -Raw
    if ($Content -match 'controlfile version="([0-9]+\.[0-9]+)"') {
        $RequiredVer = Get-BiberVersion $Matches[1]
        if ($RequiredVer -ne $BiberVer) {
            Write-Host "Version mismatch detected. BibLaTeX control file requires Biber $RequiredVer (used $BiberVer)." -ForegroundColor Red
            Download-Biber $RequiredVer
            
            # Update path and compile again
            $PathList = $env:PATH -split ';'
            if ($PathList -notcontains $BinDir) {
                $env:PATH = "$BinDir;$env:PATH"
            }
            Write-Host "Retrying compilation with Biber $RequiredVer..." -ForegroundColor Cyan
            & tectonic --keep-intermediates $TexFile
            $CompileExitCode = $LASTEXITCODE
        } else {
            # Check for Biber cache corruption
            Write-Host "Compilation failed. Checking if Biber execution fails due to cache corruption..." -ForegroundColor Red
            $BiberCmd = if (Test-Path $BiberPath) { $BiberPath } else { "biber" }
            $TestRun = & $BiberCmd --version 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Host "Biber execution failure detected. Clearing PAR cache for self-healing..." -ForegroundColor Yellow
                try {
                    $CacheDir = & $BiberCmd --cache 2>$null
                    if ($CacheDir -and (Test-Path $CacheDir)) {
                        Remove-Item -Recurse -Force $CacheDir -ErrorAction SilentlyContinue
                        Write-Host "Cleared cache: $CacheDir. Retrying compilation..." -ForegroundColor Cyan
                        & tectonic --keep-intermediates $TexFile
                        $CompileExitCode = $LASTEXITCODE
                    }
                } catch {
                    Write-Host "Failed to automatically clear cache: $_" -ForegroundColor Red
                }
            }
        }
    }
}

if ($CompileExitCode -eq 0) {
    Write-Host "Success! main.pdf has been generated." -ForegroundColor Green
    exit 0
} else {
    Write-Error "Error during compilation. If this issue persists, try running: .\compile.ps1 -CleanCache"
    exit 1
}
