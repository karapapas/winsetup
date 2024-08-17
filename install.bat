@echo off
for /f "tokens=*" %%i in (software-to-install.txt) do (
	winget install %%i --silent
)