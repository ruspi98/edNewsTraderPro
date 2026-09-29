@echo off
setlocal EnableDelayedExpansion
title edNewsTraderPro Setup ^& Dependency Doctor

cd /d "%~dp0"

echo ====================================================================
echo        edNewsTraderPro - Automated Setup ^& Dependency Doctor
echo ====================================================================
echo.

where powershell >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] PowerShell tidak ditemukan di sistem Windows ini!
    echo Setup memerlukan PowerShell untuk memproses dependensi dan instalasi otomatis.
    echo.
    pause
    exit /b 1
)

:: Jalankan setup.ps1 dengan ExecutionPolicy Bypass
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1" %*
set SCRIPT_EXIT_CODE=%ERRORLEVEL%

if %SCRIPT_EXIT_CODE% NEQ 0 (
    echo.
    echo [PERINGATAN] Setup selesai dengan kode keluar: %SCRIPT_EXIT_CODE%
)

echo %* | findstr /i /c:"-NonInteractive" >nul
if %ERRORLEVEL% NEQ 0 (
    echo.
    pause
)
exit /b %SCRIPT_EXIT_CODE%
