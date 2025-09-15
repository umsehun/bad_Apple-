@echo off
REM Bad Apple Player for Windows
REM This batch file runs the bash script on Windows

echo 🔍 Bad Apple Player for Windows
echo.

REM Check if bash is available
where bash >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo ❌ Bash not found!
    echo.
    echo Please install one of the following:
    echo   1. Git for Windows (includes Git Bash)
    echo   2. Windows Subsystem for Linux (WSL)
    echo   3. MSYS2 or Cygwin
    echo.
    echo Then run this batch file again.
    pause
    exit /b 1
)

echo ✅ Bash found! Starting Bad Apple Player...
echo.

REM Run the bash script
bash "%~dp0play.sh" %*

REM Keep window open if there was an error
if %ERRORLEVEL% neq 0 (
    echo.
    echo ❌ Script exited with error code %ERRORLEVEL%
    pause
)