# Compilation script for the APA 7th edition paper on Windows (PowerShell)
# Prepends the project folder to the PATH to prioritize the compatible local biber.exe.

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$env:PATH = "$ScriptDir;$env:PATH"

Write-Host "Compiling document with Tectonic..." -ForegroundColor Cyan
tectonic main.tex

if ($LASTEXITCODE -eq 0) {
    Write-Host "Success! main.pdf has been generated." -ForegroundColor Green
} else {
    Write-Error "Error during compilation."
    exit 1
}
