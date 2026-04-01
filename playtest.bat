@echo off
echo ========================================
echo   TheHollow - Rojo Live Sync
echo ========================================
echo.

echo [1/2] Building .rbxlx from src...
rojo build default.project.json -o game.rbxlx
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Rojo build failed!
    pause
    exit /b 1
)
echo Build complete: game.rbxlx updated.
echo.

echo [2/2] Starting Rojo live server...
echo Open Roblox Studio, connect the Rojo plugin, and hit Play!
echo Press Ctrl+C when you're done playtesting.
echo ========================================
echo.
rojo serve default.project.json

echo.
echo ========================================
echo   Saving changes...
echo ========================================
echo.
echo Rebuilding .rbxlx with latest changes...
rojo build default.project.json -o game.rbxlx

echo Pushing to GitHub...
git add -A
git commit -m "Update game from playtest session"
git push
echo.
echo Done! Changes saved and pushed to GitHub.
pause
