@echo off
setlocal

pushd "%~dp0"

where pwsh.exe >nul 2>nul
if %errorlevel%==0 (
    pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0fill.ps1" %*
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0fill.ps1" %*
)

set "exit_code=%errorlevel%"
popd
exit /b %exit_code%
