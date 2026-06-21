@echo off
rem Compilation script for the APA 7th edition paper on Windows (CMD)
rem Prepends the project folder to the PATH to prioritize the compatible local biber.exe.

set SCRIPT_DIR=%~dp0
set PATH=%SCRIPT_DIR%;%PATH%

echo Compiling document with Tectonic...
tectonic main.tex

if %ERRORLEVEL% EQU 0 (
    echo Success! main.pdf has been generated.
) else (
    echo Error during compilation.
    exit /b 1
)
