@echo off
title TheHollow - Rojo Live Sync
echo ========================================
echo   TheHollow - Rojo Live Sync
echo ========================================
echo.
echo Starting Rojo server...
echo Connect from Studio, then hit Play.
echo Ctrl+C to stop.
echo.
"%APPDATA%\npm\rojo.cmd" serve default.project.json
pause
