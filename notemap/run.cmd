@echo off
cd /d "%~dp0"
if not exist "build\notemap.exe" (
  echo build\notemap.exe not found. Run build.ps1 first.
  pause
  exit /b 1
)
start "" http://127.0.0.1:8777
build\notemap.exe
pause
