@echo off
title TheHollow - Rojo Live Sync
cd /d "%~dp0"

set ROJO="%USERPROFILE%\.local\bin\rojo.exe"

echo ========================================
echo   TheHollow - Rojo Live Sync
echo ========================================
echo.

:: Check Rojo is installed
if not exist %ROJO% (
    echo ERROR: Rojo not found at %ROJO%
    echo Install it from https://github.com/rojo-rbx/rojo/releases
    pause
    exit /b 1
)

:: Pull latest from GitHub (non-fatal)
echo [1/4] Pulling latest from GitHub...
git pull origin master 2>nul
if errorlevel 1 (
    echo    WARNING: Git pull failed. Continuing with local files...
)
echo.

:: Build the place file
echo [2/4] Building place file with Rojo...
%ROJO% build -o game.rbxlx
if errorlevel 1 (
    echo ERROR: Rojo build failed!
    pause
    exit /b 1
)
echo    Built game.rbxlx successfully.
echo.

:: Find Roblox Studio (auto-detect latest version)
echo [3/4] Opening Roblox Studio...
set "STUDIO_EXE="
for /f "delims=" %%d in ('dir /b /o-d "%LOCALAPPDATA%\Roblox\Versions\version-*" 2^>nul') do (
    if exist "%LOCALAPPDATA%\Roblox\Versions\%%d\RobloxStudioBeta.exe" (
        set "STUDIO_EXE=%LOCALAPPDATA%\Roblox\Versions\%%d\RobloxStudioBeta.exe"
        goto :found_studio
    )
)

:found_studio
if not defined STUDIO_EXE (
    echo ERROR: Could not find Roblox Studio!
    echo    Make sure Roblox Studio is installed.
    pause
    exit /b 1
)

start "" "%STUDIO_EXE%" "%~dp0game.rbxlx"
echo    Launched Studio: %STUDIO_EXE%
echo.

:: Wait a moment for Studio to start loading
timeout /t 3 /nobreak >nul

:: Start Rojo serve
echo [4/4] Starting Rojo live-sync server...
echo.
echo ========================================
echo   Rojo server running on localhost:34872
echo   It will auto-connect via the plugin.
echo   Press Ctrl+C to stop.
echo ========================================
echo.

%ROJO% serve
