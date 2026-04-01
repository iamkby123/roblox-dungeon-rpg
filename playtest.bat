@echo off
title TheHollow - Rojo Live Sync
echo ========================================
echo   TheHollow - Rojo Live Sync
echo ========================================
echo.

:: Add npm global bin to PATH so rojo is found
set PATH=%APPDATA%\npm;%USERPROFILE%\.local\bin;%PATH%

where rojo >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Rojo not found. Run setup-rojo.bat first.
    pause
    exit /b 1
)

echo Starting Rojo server...
echo Connect from Studio, then hit Play.
echo Ctrl+C to stop.
echo.
rojo serve default.project.json
pause
