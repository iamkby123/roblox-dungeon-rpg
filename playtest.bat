@echo off
echo ========================================
echo   TheHollow - Rojo Live Sync
echo ========================================
echo.
echo 1. Rojo will start serving...
echo 2. Open Roblox Studio
echo 3. Click the Rojo plugin "Connect" button
echo 4. Hit Play to test!
echo.
echo Changes you make in src/ will sync instantly.
echo Press Ctrl+C to stop.
echo ========================================
echo.
rojo serve default.project.json
pause
