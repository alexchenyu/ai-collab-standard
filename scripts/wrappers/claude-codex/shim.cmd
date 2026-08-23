@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dpn0.ps1" %*
exit /b %ERRORLEVEL%
