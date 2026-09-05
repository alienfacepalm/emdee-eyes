@echo off
rem Shim so `emdee-eyes` resolves from cmd.exe and PowerShell alike (PowerShell
rem does not run .ps1 files by bare name via PATH for security reasons, but it
rem does resolve .cmd files, same as cmd.exe). Forwards to the real
rem implementation next to this file and passes the exit code back through.
setlocal
set "EMDEE_EYES_DIR=%~dp0"
where pwsh >nul 2>nul
if %ERRORLEVEL%==0 (
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%EMDEE_EYES_DIR%emdee-eyes.ps1" %*
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%EMDEE_EYES_DIR%emdee-eyes.ps1" %*
)
exit /b %ERRORLEVEL%
