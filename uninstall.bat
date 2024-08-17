@echo off
for /f "tokens=*" %%i in (C:\Users\chris\Documents\winsetup\software-to-uninstall.txt) do (
	winget uninstall %%i --silent
)