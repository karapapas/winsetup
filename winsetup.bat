@echo off
setlocal enabledelayedexpansion

:: WinSetup - Unified Windows Setup Script
:: Usage: winsetup.bat [action]

set "ACTION=%~1"

:: If no argument or help requested, show help
if "%ACTION%"=="" goto :show_help
if /i "%ACTION%"=="help" goto :show_help
if /i "%ACTION%"=="--help" goto :show_help
if /i "%ACTION%"=="-h" goto :show_help

:: Route to appropriate action
if /i "%ACTION%"=="install" goto :install
if /i "%ACTION%"=="uninstall" goto :uninstall

:: Invalid action
echo Error: Unknown action '%ACTION%'
echo.
goto :show_help

:install
echo Installing software from software-to-install.txt...
echo.
for /f "tokens=*" %%i in (software-to-install.txt) do (
    echo Installing: %%i
    winget install %%i --silent
)
echo.
echo Installation complete.
goto :end

:uninstall
echo Uninstalling software from software-to-uninstall.txt...
echo.
for /f "tokens=*" %%i in (software-to-uninstall.txt) do (
    echo Uninstalling: %%i
    winget uninstall %%i --silent
)
echo.
echo Uninstallation complete.
goto :end

:show_help
echo WinSetup - Windows Setup Automation Tool
echo.
echo Usage: winsetup.bat [action]
echo.
echo Actions:
echo   install   - Install software from software-to-install.txt
echo   uninstall - Uninstall software from software-to-uninstall.txt
echo   help      - Show this help message
echo.
echo Examples:
echo   winsetup.bat install
echo   winsetup.bat uninstall
goto :end

:end
endlocal
