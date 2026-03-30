@echo off
title TheHollow - Playtest
cd /d "%~dp0"

echo ========================================
echo   TheHollow - One-Click Playtest
echo ========================================
echo.

:: Pull latest from GitHub
echo [1/3] Pulling latest from GitHub...
git pull origin master
if errorlevel 1 (
    echo WARNING: Git pull failed. Continuing with local files...
)
echo.

:: Build the place file from source
echo [2/3] Building place file with Rojo...
"%USERPROFILE%\.local\bin\rojo.exe" build -o game.rbxlx
if errorlevel 1 (
    echo ERROR: Rojo build failed!
    pause
    exit /b 1
)
echo    Built game.rbxlx successfully.
echo.

:: Open in Roblox Studio
echo [3/3] Opening in Roblox Studio...
start "" "%LOCALAPPDATA%\Roblox\Versions\version-116cc3d51f634937\RobloxStudioBeta.exe" "%~dp0game.rbxlx"

echo.
echo ========================================
echo   Starting Rojo live-sync server...
echo   Connect in Studio: Plugins ^> Rojo ^> Connect
echo   Press Ctrl+C to stop the server.
echo ========================================
echo.

:: Start Rojo serve for live sync while playtesting
"%USERPROFILE%\.local\bin\rojo.exe" serve
