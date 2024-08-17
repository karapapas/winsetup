@echo off
for /f "tokens=*" %%i in (C:\Users\chris\Documents\winsetup\software-to-install.txt) do (
	winget install %%i --silent
)