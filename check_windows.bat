@echo off
REM Windows Compatibility Check Script
REM This script checks if all required components are installed

title Bad Apple - Windows Compatibility Check
echo 🍎 Bad Apple Windows Compatibility Check
echo.

set "MISSING_COMPONENTS="
set "HAS_BASH=0"
set "HAS_PYTHON=0"
set "HAS_FFMPEG=0"

echo 🔍 Checking components...
echo.

REM Check for bash
where bash >nul 2>nul
if %ERRORLEVEL% equ 0 (
    echo ✅ Git Bash / MSYS2 / WSL found
    set "HAS_BASH=1"
) else (
    echo ❌ Bash not found
    set "MISSING_COMPONENTS=%MISSING_COMPONENTS% bash"
)

REM Check for Python
where python >nul 2>nul
if %ERRORLEVEL% equ 0 (
    echo ✅ Python found
    set "HAS_PYTHON=1"
) else (
    where python3 >nul 2>nul
    if %ERRORLEVEL% equ 0 (
        echo ✅ Python3 found
        set "HAS_PYTHON=1"
    ) else (
        echo ❌ Python not found
        set "MISSING_COMPONENTS=%MISSING_COMPONENTS% python"
    )
)

REM Check for FFmpeg
where ffmpeg >nul 2>nul
if %ERRORLEVEL% equ 0 (
    echo ✅ FFmpeg found
    set "HAS_FFMPEG=1"
) else (
    echo ❌ FFmpeg not found
    set "MISSING_COMPONENTS=%MISSING_COMPONENTS% ffmpeg"
)

echo.
if "%MISSING_COMPONENTS%"=="" (
    echo 🎉 All components found! You can run Bad Apple Player.
    echo.
    echo Run: play.bat
    echo.
) else (
    echo ⚠️  Some components are missing. Please install:
    echo.
    if not "!HAS_BASH!"=="1" (
        echo   🐚 Bash Environment:
        echo     • Git for Windows: https://gitforwindows.org/
        echo     • MSYS2: https://www.msys2.org/
        echo     • WSL: Enable in Windows Features
        echo.
    )
    if not "!HAS_PYTHON!"=="1" (
        echo   🐍 Python:
        echo     • Download: https://python.org/downloads/
        echo     • Install with pip
        echo.
    )
    if not "!HAS_FFMPEG!"=="1" (
        echo   🎬 FFmpeg:
        echo     • Chocolatey: choco install ffmpeg
        echo     • Scoop: scoop install ffmpeg
        echo     • Download: https://ffmpeg.org/download.html
        echo.
    )
    echo After installing missing components, run: play.bat
    echo.
)

echo Press any key to continue...
pause >nul