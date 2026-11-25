@echo off
cd /d "%~dp0"
where py >nul 2>&1
if %errorlevel% equ 0 (
    py -3 serve.py %*
    pause
    exit /b
)
where python >nul 2>&1
if %errorlevel% equ 0 (
    python serve.py %*
    pause
    exit /b
)
echo Python 3 is required. Install it from https://www.python.org/downloads/windows/
echo Enable the Python launcher or add Python to PATH, then run this file again.
pause
