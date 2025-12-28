@echo off
:: Run Tests - Automatic elevation and execution policy bypass wrapper

:: Check for admin privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator privileges...
    echo.
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: Run PowerShell script with execution policy bypass
echo Running WinSetup Test Suite...
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0run-tests.ps1"

:: Pause to see results
echo.
pause
