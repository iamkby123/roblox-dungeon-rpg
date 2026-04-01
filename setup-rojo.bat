@echo off
echo ========================================
echo   TheHollow - One-Click Rojo Setup
echo ========================================
echo.

:: Check if Rojo is installed
where rojo >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo Rojo not found. Installing via Aftman...
    where aftman >nul 2>nul
    if %ERRORLEVEL% NEQ 0 (
        echo Aftman not found either. Installing Rojo with npm...
        where npm >nul 2>nul
        if %ERRORLEVEL% NEQ 0 (
            echo.
            echo ERROR: No package manager found.
            echo Install Rojo manually: https://github.com/rojo-rbx/rojo/releases
            echo Or install Node.js first: https://nodejs.org
            pause
            exit /b 1
        )
        npm install -g rojo
    ) else (
        aftman install
    )
)

echo [OK] Rojo is installed:
rojo --version
echo.

:: Install the Rojo plugin into Roblox Studio
echo Installing Rojo plugin into Roblox Studio...
rojo plugin install
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo WARNING: Could not auto-install plugin.
    echo Install it manually from Roblox: https://create.roblox.com/store/asset/13916111004
    echo.
) else (
    echo [OK] Rojo plugin installed in Studio.
    echo.
)

:: Build the place file
echo Building game.rbxlx from src...
rojo build default.project.json -o game.rbxlx
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Build failed!
    pause
    exit /b 1
)
echo [OK] game.rbxlx built successfully.
echo.

echo ========================================
echo   SETUP COMPLETE!
echo ========================================
echo.
echo How to playtest:
echo   1. Double-click playtest.bat
echo   2. Open Roblox Studio
echo   3. Open game.rbxlx in Studio
echo   4. Click "Connect" in the Rojo plugin toolbar
echo   5. Hit Play - your game is running!
echo.
echo   Any edits to src/ will sync instantly.
echo   Press Ctrl+C in playtest.bat when done.
echo ========================================
pause
