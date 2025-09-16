@echo off
REM Bad Apple Player for Windows
REM Enhanced batch file with better error handling

title Bad Apple Player for Windows
echo 🍎 Bad Apple ASCII Animation Player for Windows
echo.

REM Change to script directory
cd /d "%~dp0"

REM Check if we're in the right directory
if not exist "play.sh" (
    echo ❌ Error: play.sh not found in current directory
    echo Please run this batch file from the bad_apple- directory
    pause
    exit /b 1
)

REM Check for bash
echo 🔍 Checking for bash...
where bash >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo ❌ Bash not found!
    echo.
    echo Please install one of the following:
    echo   1. Git for Windows (includes Git Bash)
    echo      Download: https://gitforwindows.org/
    echo   2. Windows Subsystem for Linux (WSL)
    echo      Run: wsl --install
    echo   3. MSYS2 or Cygwin
    echo.
    echo Then run this batch file again.
    echo.
    echo Alternatively, you can run the PowerShell version:
    echo   powershell -ExecutionPolicy Bypass -File play.ps1
    pause
    exit /b 1
)

echo ✅ Bash found! Starting Bad Apple Player...
echo.

REM Run the bash script with error handling
bash "play.sh" --no-compile %*
set EXITCODE=%ERRORLEVEL%

REM Handle exit code
if %EXITCODE% neq 0 (
    echo.
    echo ❌ Script exited with error code %EXITCODE%
    echo.
    echo Common solutions:
    echo   • Install GCC: Run "pacman -S gcc" in MSYS2/MinGW
    echo   • Install Python packages: Run "pip install opencv-python numpy"
    echo   • Check file permissions: Run as administrator if needed
    echo.
    pause
)

exit /b %EXITCODE%