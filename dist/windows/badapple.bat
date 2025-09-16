@echo off
setlocal enabledelayedexpansion

echo 🪟 Bad Apple Windows Launcher
echo.

REM Git Bash 경로 찾기
set "GITBASH_PATHS=C:\Program Files\Git\bin\bash.exe;C:\Git\bin\bash.exe;C:\Program Files (x86)\Git\bin\bash.exe"

for %%i in (%GITBASH_PATHS%) do (
    if exist "%%i" (
        echo ✅ Git Bash 발견: %%i
        "%%i" -c "./wplay.sh"
        goto :end
    )
)

REM WSL 확인
wsl --list >nul 2>&1
if !errorlevel! equ 0 (
    echo ✅ WSL 발견
    wsl bash -c "cd '$(wslpath '%~dp0')' && ./wplay.sh"
    goto :end
)

REM PowerShell 실행
echo ℹ️ Bash 환경을 찾을 수 없습니다. PowerShell로 실행합니다.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0badapple.ps1"

:end
pause
