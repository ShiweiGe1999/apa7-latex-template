@echo off
rem Helper redirect script to PowerShell compilation for Windows users, forwarding all arguments
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0compile.ps1" %*
