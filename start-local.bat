@echo off
title Smart Home - Local Launcher

echo ========================================
echo   Smart Home - Local Launcher
echo ========================================
echo.

:: Check Node.js
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Node.js not found. Please install Node.js 18+
    echo Download: https://nodejs.org/
    pause
    exit /b 1
)

:: Start backend server
echo [1/2] Starting backend server (port 8081)...
cd /d "%~dp0server"
if not exist "node_modules" (
    echo Installing server dependencies...
    call npm install
)
start "SmartHome-Backend" cmd /k "cd /d %~dp0server && node index.js"

:: Wait for backend to start
timeout /t 3 /nobreak >nul

:: Start frontend dev server
echo [2/2] Starting frontend dev server (port 5173)...
cd /d "%~dp0"
if not exist "node_modules" (
    echo Installing frontend dependencies...
    call npm install
)
start "SmartHome-Frontend" cmd /k "cd /d %~dp0 && npx vite --host --port 5173"

:: Wait for frontend to start
timeout /t 5 /nobreak >nul

echo.
echo ========================================
echo   Started successfully!
echo ========================================
echo.
echo   Frontend:  http://localhost:5173
echo   Backend:   http://localhost:8081/api/health
echo   Login:     admin / admin123
echo.
echo   Close the windows to stop services.
echo ========================================
echo.

:: Open browser
start http://localhost:5173

pause
