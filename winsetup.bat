@echo off
:: WinSetup Launcher - Runs the PowerShell script with execution policy bypass
:: This bypasses PowerShell's script execution policy for this session only

powershell.exe -ExecutionPolicy Bypass -File "%~dp0winsetup.ps1" %*
