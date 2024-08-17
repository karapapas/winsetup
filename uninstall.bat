@echo off
for /f "tokens=*" %%i in (software-to-uninstall.txt) do (
	winget uninstall %%i --silent
)