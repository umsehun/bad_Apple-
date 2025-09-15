#!/bin/bash
# build_windows_exe.sh - Windows용 실행 파일 생성 스크립트
# Bad Apple 플레이어를 Windows .exe 파일로 패키징

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$SCRIPT_DIR"
readonly BUILD_DIR="$PROJECT_ROOT/build"
readonly DIST_DIR="$PROJECT_ROOT/dist"
readonly WINDOWS_DIR="$DIST_DIR/windows"

# 로그 함수
log_info() {
    echo "ℹ️  $1"
}

log_success() {
    echo "✅ $1"
}

log_error() {
    echo "❌ $1"
}

log_warning() {
    echo "⚠️  $1"
}

# Windows 빌드 환경 확인
check_build_environment() {
    log_info "Windows 빌드 환경 확인 중..."
    
    # 크로스 컴파일 도구 확인
    local mingw_found=0
    local native_found=0
    
    # MinGW 크로스 컴파일러 확인 (macOS/Linux에서)
    if command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1; then
        log_success "MinGW-w64 크로스 컴파일러 발견"
        export CROSS_COMPILE_CC="x86_64-w64-mingw32-gcc"
        export CROSS_COMPILE_WINDRES="x86_64-w64-mingw32-windres"
        mingw_found=1
    fi
    
    # 32비트 MinGW 확인
    if command -v i686-w64-mingw32-gcc >/dev/null 2>&1; then
        log_success "MinGW-w64 32비트 크로스 컴파일러 발견"
        export CROSS_COMPILE_CC_32="i686-w64-mingw32-gcc"
        export CROSS_COMPILE_WINDRES_32="i686-w64-mingw32-windres"
    fi
    
    # Windows 네이티브 환경 확인
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ -n "${COMSPEC:-}" ]]; then
        log_success "Windows 네이티브 빌드 환경 감지"
        native_found=1
        
        # GCC 확인
        if command -v gcc >/dev/null 2>&1; then
            export NATIVE_CC="gcc"
            log_success "GCC 컴파일러 사용 가능"
        fi
        
        # Clang 확인
        if command -v clang >/dev/null 2>&1; then
            export NATIVE_CLANG="clang"
            log_success "Clang 컴파일러 사용 가능"
        fi
        
        # MSVC 확인
        if command -v cl.exe >/dev/null 2>&1; then
            export NATIVE_MSVC="cl.exe"
            log_success "Microsoft Visual C++ 컴파일러 사용 가능"
        fi
    fi
    
    # 최소 요구사항 확인
    if [[ $mingw_found -eq 0 ]] && [[ $native_found -eq 0 ]]; then
        log_error "Windows 빌드 환경을 찾을 수 없습니다."
        echo ""
        echo "다음 중 하나를 설치해주세요:"
        echo "1. macOS: brew install mingw-w64"
        echo "2. Ubuntu: sudo apt-get install mingw-w64"
        echo "3. Windows: MSYS2, Visual Studio Build Tools"
        echo ""
        exit 1
    fi
    
    # 패키징 도구 확인
    if command -v zip >/dev/null 2>&1; then
        export HAS_ZIP="1"
        log_success "ZIP 압축 도구 사용 가능"
    fi
    
    if command -v tar >/dev/null 2>&1; then
        export HAS_TAR="1"
        log_success "TAR 압축 도구 사용 가능"
    fi
}

# Windows 리소스 파일 생성
create_windows_resources() {
    log_info "Windows 리소스 파일 생성 중..."
    
    local rc_file="$BUILD_DIR/badapple.rc"
    local ico_file="$BUILD_DIR/badapple.ico"
    
    # 디렉토리 생성
    mkdir -p "$BUILD_DIR"
    
    # 리소스 파일 (.rc) 생성
    cat > "$rc_file" << 'EOF'
#include <windows.h>

// 버전 정보
1 VERSIONINFO
FILEVERSION 1,0,0,0
PRODUCTVERSION 1,0,0,0
FILEFLAGSMASK 0x3fL
FILEFLAGS 0x0L
FILEOS 0x40004L
FILETYPE 0x1L
FILESUBTYPE 0x0L
BEGIN
    BLOCK "StringFileInfo"
    BEGIN
        BLOCK "040904b0"
        BEGIN
            VALUE "CompanyName", "Bad Apple Project"
            VALUE "FileDescription", "Bad Apple ASCII Animation Player"
            VALUE "FileVersion", "1.0.0.0"
            VALUE "InternalName", "badapple"
            VALUE "LegalCopyright", "Copyright (C) 2024"
            VALUE "OriginalFilename", "badapple.exe"
            VALUE "ProductName", "Bad Apple Player"
            VALUE "ProductVersion", "1.0.0.0"
        END
    END
    BLOCK "VarFileInfo"
    BEGIN
        VALUE "Translation", 0x409, 1200
    END
END

// 아이콘 (있다면)
//IDI_ICON1 ICON "badapple.ico"

// 매니페스트
1 RT_MANIFEST "badapple.manifest"
EOF
    
    # 매니페스트 파일 생성
    cat > "$BUILD_DIR/badapple.manifest" << 'EOF'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">
  <assemblyIdentity
    version="1.0.0.0"
    processorArchitecture="amd64"
    name="BadApple.Player"
    type="win32"
  />
  <description>Bad Apple ASCII Animation Player</description>
  <trustInfo xmlns="urn:schemas-microsoft-com:asm.v3">
    <security>
      <requestedPrivileges>
        <requestedExecutionLevel level="asInvoker" uiAccess="false"/>
      </requestedPrivileges>
    </security>
  </trustInfo>
  <compatibility xmlns="urn:schemas-microsoft-com:compatibility.v1">
    <application>
      <!-- Windows 10 -->
      <supportedOS Id="{8e0f7a12-bfb3-4fe8-b9a5-48fd50a15a9a}"/>
      <!-- Windows 8.1 -->
      <supportedOS Id="{1f676c76-80e1-4239-95bb-83d0f6d0da78}"/>
      <!-- Windows 8 -->
      <supportedOS Id="{4a2f28e3-53b9-4441-ba9c-d69d4a4a6e38}"/>
      <!-- Windows 7 -->
      <supportedOS Id="{35138b9a-5d96-4fbd-8e2d-a2440225f93a}"/>
    </application>
  </compatibility>
</assembly>
EOF
    
    log_success "Windows 리소스 파일 생성 완료"
}

# C 소스코드 컴파일 (크로스 컴파일)
compile_cross_platform() {
    log_info "크로스 플랫폼 컴파일 시작..."
    
    local source_file="$PROJECT_ROOT/src/platform.c"
    local output_file="$WINDOWS_DIR/platform_detector.exe"
    local rc_file="$BUILD_DIR/badapple.rc"
    local res_file="$BUILD_DIR/badapple.res"
    
    # 디렉토리 생성
    mkdir -p "$WINDOWS_DIR"
    
    # 64비트 빌드
    if [[ -n "${CROSS_COMPILE_CC:-}" ]]; then
        log_info "64비트 Windows 실행 파일 빌드 중..."
        
        # 리소스 컴파일
        if [[ -n "${CROSS_COMPILE_WINDRES:-}" ]] && [[ -f "$rc_file" ]]; then
            log_info "Windows 리소스 컴파일 중..."
            "$CROSS_COMPILE_WINDRES" "$rc_file" -O coff -o "$res_file"
        fi
        
        # 컴파일 플래그
        local compile_flags=(
            "-std=c99"
            "-Wall"
            "-Wextra"
            "-O2"
            "-static"
            "-DWINDOWS_BUILD"
            "-DCROSS_COMPILE"
        )
        
        # 링크 라이브러리
        local link_libs=(
            "-luser32"
            "-lkernel32"
            "-ladvapi32"
            "-lshell32"
        )
        
        # 컴파일 명령 구성
        local compile_cmd=(
            "$CROSS_COMPILE_CC"
            "${compile_flags[@]}"
            "$source_file"
        )
        
        # 리소스 파일 추가 (있다면)
        if [[ -f "$res_file" ]]; then
            compile_cmd+=("$res_file")
        fi
        
        compile_cmd+=(
            "-o" "$output_file"
            "${link_libs[@]}"
        )
        
        log_info "컴파일 명령: ${compile_cmd[*]}"
        
        # 컴파일 실행
        if "${compile_cmd[@]}"; then
            log_success "64비트 Windows 실행 파일 생성 완료: $output_file"
            
            # 파일 크기 확인
            if [[ -f "$output_file" ]]; then
                local file_size
                file_size=$(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file" 2>/dev/null || echo "Unknown")
                log_info "실행 파일 크기: $file_size bytes"
            fi
        else
            log_error "64비트 빌드 실패"
            return 1
        fi
    fi
    
    # 32비트 빌드 (선택적)
    if [[ -n "${CROSS_COMPILE_CC_32:-}" ]]; then
        log_info "32비트 Windows 실행 파일 빌드 중..."
        
        local output_file_32="$WINDOWS_DIR/platform_detector_x86.exe"
        local res_file_32="$BUILD_DIR/badapple_x86.res"
        
        # 32비트 리소스 컴파일
        if [[ -n "${CROSS_COMPILE_WINDRES_32:-}" ]] && [[ -f "$rc_file" ]]; then
            "$CROSS_COMPILE_WINDRES_32" "$rc_file" -O coff -o "$res_file_32"
        fi
        
        # 32비트 컴파일 명령
        local compile_cmd_32=(
            "$CROSS_COMPILE_CC_32"
            "${compile_flags[@]}"
            "$source_file"
        )
        
        if [[ -f "$res_file_32" ]]; then
            compile_cmd_32+=("$res_file_32")
        fi
        
        compile_cmd_32+=(
            "-o" "$output_file_32"
            "${link_libs[@]}"
        )
        
        if "${compile_cmd_32[@]}"; then
            log_success "32비트 Windows 실행 파일 생성 완료: $output_file_32"
        else
            log_warning "32비트 빌드 실패 (무시됨)"
        fi
    fi
}

# 네이티브 Windows 빌드
compile_native_windows() {
    log_info "네이티브 Windows 빌드 시작..."
    
    local source_file="$PROJECT_ROOT/src/platform.c"
    local output_file="$WINDOWS_DIR/platform_detector.exe"
    
    mkdir -p "$WINDOWS_DIR"
    
    # GCC 빌드
    if [[ -n "${NATIVE_CC:-}" ]]; then
        log_info "GCC로 네이티브 빌드 중..."
        
        local compile_flags="-std=c99 -Wall -Wextra -O2 -DWINDOWS_BUILD -DNATIVE_BUILD"
        local link_libs="-luser32 -lkernel32 -ladvapi32"
        
        local cmd="$NATIVE_CC $compile_flags \"$source_file\" -o \"$output_file\" $link_libs"
        log_info "컴파일 명령: $cmd"
        
        if eval "$cmd"; then
            log_success "GCC 네이티브 빌드 완료"
        else
            log_error "GCC 네이티브 빌드 실패"
            return 1
        fi
    fi
    
    # MSVC 빌드
    if [[ -n "${NATIVE_MSVC:-}" ]]; then
        log_info "MSVC로 네이티브 빌드 중..."
        
        local output_file_msvc="$WINDOWS_DIR/platform_detector_msvc.exe"
        local cmd="cl.exe /nologo /O2 /DWINDOWS_BUILD /DNATIVE_BUILD /DMSVC_BUILD \"$source_file\" /Fe:\"$output_file_msvc\" user32.lib kernel32.lib advapi32.lib"
        
        log_info "MSVC 컴파일 명령: $cmd"
        
        if eval "$cmd"; then
            log_success "MSVC 네이티브 빌드 완료"
        else
            log_warning "MSVC 네이티브 빌드 실패 (무시됨)"
        fi
    fi
}

# Windows 패키지 생성
create_windows_package() {
    log_info "Windows 배포 패키지 생성 중..."
    
    # 필요한 파일 복사
    cp "$PROJECT_ROOT/wplay.sh" "$WINDOWS_DIR/"
    cp "$PROJECT_ROOT/platform.sh" "$WINDOWS_DIR/"
    cp "$PROJECT_ROOT/README.md" "$WINDOWS_DIR/"
    
    # Windows용 README 생성
    cat > "$WINDOWS_DIR/README_WINDOWS.md" << 'EOF'
# Bad Apple for Windows

Windows용 Bad Apple ASCII 애니메이션 플레이어입니다.

## 시스템 요구사항

- Windows 7 이상
- Git Bash, WSL, MSYS2, 또는 Cygwin
- 최소 4GB RAM
- 터미널 크기: 80x24 이상 권장

## 설치 및 실행

### 1. 압축 해제
배포 패키지를 적절한 위치에 압축 해제합니다.

### 2. Windows용 플레이어 실행
```bash
# Git Bash, WSL, MSYS2에서:
./wplay.sh

# 또는 기본 플레이어:
./play.sh
```

### 3. PowerShell에서 실행 (네이티브)
```powershell
# PowerShell 7+ 또는 Windows PowerShell 5.1에서:
.\badapple.ps1
```

## 지원 환경

- ✅ WSL (Windows Subsystem for Linux)
- ✅ MSYS2
- ✅ Git Bash
- ✅ Cygwin
- ✅ PowerShell 5.1+
- ✅ PowerShell Core 7+

## 트러블슈팅

### 실행 권한 오류
```bash
chmod +x *.sh
```

### 컴파일러 오류
1. MSYS2 설치: https://www.msys2.org/
2. 빌드 도구 설치:
```bash
pacman -S mingw-w64-x86_64-gcc make
```

### 터미널 크기 문제
Windows Terminal 또는 ConEmu 사용을 권장합니다.

## 추가 정보

- 프로젝트 홈페이지: https://github.com/your-repo/bad-apple
- 이슈 리포트: https://github.com/your-repo/bad-apple/issues

EOF
    
    # Windows 배치 파일 생성
    cat > "$WINDOWS_DIR/badapple.bat" << 'EOF'
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
EOF
    
    # PowerShell 스크립트 생성
    cat > "$WINDOWS_DIR/badapple.ps1" << 'EOF'
# Bad Apple PowerShell Player
param(
    [string]$Mode = "ascii",
    [int]$FPS = 120
)

Write-Host "🍎 Bad Apple PowerShell Player" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Yellow

# 콘솔 설정
$Host.UI.RawUI.WindowTitle = "Bad Apple - PowerShell Edition"

# 프레임 디렉토리 확인
$FramesDir = Join-Path $PSScriptRoot "assets\ascii_frames"
if (-not (Test-Path $FramesDir)) {
    Write-Host "❌ 프레임 디렉토리를 찾을 수 없습니다: $FramesDir" -ForegroundColor Red
    Write-Host "💡 먼저 프레임을 생성해주세요." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# 프레임 파일 로드
$Frames = Get-ChildItem -Path $FramesDir -Filter "*.txt" | Sort-Object Name

Write-Host "📁 프레임 디렉토리: $FramesDir" -ForegroundColor Cyan
Write-Host "🎬 총 프레임 수: $($Frames.Count)" -ForegroundColor Cyan
Write-Host "⚡ FPS: $FPS" -ForegroundColor Cyan
Write-Host ""
Write-Host "⏰ 3초 후 재생 시작... (Ctrl+C로 중지)" -ForegroundColor Green

Start-Sleep -Seconds 3

# 재생 시작
$FrameDelay = [math]::Round(1000 / $FPS)

try {
    foreach ($Frame in $Frames) {
        Clear-Host
        $Content = Get-Content $Frame.FullName -Raw
        Write-Host $Content
        Start-Sleep -Milliseconds $FrameDelay
    }
    
    Clear-Host
    Write-Host "🎭 Bad Apple 재생 완료!" -ForegroundColor Green
} catch {
    Write-Host "⚠️ 재생이 중단되었습니다." -ForegroundColor Yellow
}

Write-Host ""
Read-Host "Press Enter to exit"
EOF
    
    # 압축 패키지 생성
    if [[ "${HAS_ZIP:-0}" == "1" ]]; then
        local zip_file="$DIST_DIR/badapple_windows.zip"
        log_info "ZIP 패키지 생성 중..."
        
        (cd "$DIST_DIR" && zip -r "badapple_windows.zip" "windows/")
        
        if [[ -f "$zip_file" ]]; then
            local zip_size
            zip_size=$(stat -f%z "$zip_file" 2>/dev/null || stat -c%s "$zip_file" 2>/dev/null || echo "Unknown")
            log_success "ZIP 패키지 생성 완료: $zip_file ($zip_size bytes)"
        fi
    fi
    
    if [[ "${HAS_TAR:-0}" == "1" ]]; then
        local tar_file="$DIST_DIR/badapple_windows.tar.gz"
        log_info "TAR.GZ 패키지 생성 중..."
        
        (cd "$DIST_DIR" && tar -czf "badapple_windows.tar.gz" "windows/")
        
        if [[ -f "$tar_file" ]]; then
            local tar_size
            tar_size=$(stat -f%z "$tar_file" 2>/dev/null || stat -c%s "$tar_file" 2>/dev/null || echo "Unknown")
            log_success "TAR.GZ 패키지 생성 완료: $tar_file ($tar_size bytes)"
        fi
    fi
}

# 빌드 정리
cleanup_build() {
    log_info "빌드 파일 정리 중..."
    
    # 임시 파일 삭제
    rm -f "$BUILD_DIR"/*.res
    rm -f "$BUILD_DIR"/*.obj
    rm -f "$BUILD_DIR"/*.tmp
    
    log_success "빌드 정리 완료"
}

# 빌드 테스트
test_windows_build() {
    log_info "Windows 빌드 테스트 시작..."
    
    local exe_file="$WINDOWS_DIR/platform_detector.exe"
    
    if [[ -f "$exe_file" ]]; then
        log_success "실행 파일 존재 확인: $exe_file"
        
        # 파일 정보 출력
        if command -v file >/dev/null 2>&1; then
            local file_info
            file_info=$(file "$exe_file" 2>/dev/null || echo "Unknown")
            log_info "파일 정보: $file_info"
        fi
        
        # Windows 환경에서만 실행 테스트
        if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ -n "${COMSPEC:-}" ]]; then
            log_info "Windows 환경에서 실행 테스트..."
            
            if "$exe_file" --version 2>/dev/null; then
                log_success "실행 파일 테스트 성공"
            else
                log_warning "실행 파일 테스트 실패 (정상일 수 있음)"
            fi
        else
            log_info "크로스 컴파일된 실행 파일 - Windows에서 테스트 필요"
        fi
    else
        log_error "실행 파일을 찾을 수 없습니다: $exe_file"
        return 1
    fi
}

# 메인 함수
main() {
    echo "🏗️  Bad Apple Windows EXE 빌드 시작..."
    echo ""
    
    # 환경 확인
    check_build_environment
    
    # 빌드 디렉토리 준비
    mkdir -p "$BUILD_DIR" "$DIST_DIR" "$WINDOWS_DIR"
    
    # Windows 리소스 생성
    create_windows_resources
    
    # 컴파일
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ -n "${COMSPEC:-}" ]]; then
        # Windows 네이티브 환경
        compile_native_windows
    else
        # 크로스 컴파일 환경
        compile_cross_platform
    fi
    
    # 패키지 생성
    create_windows_package
    
    # 테스트
    test_windows_build
    
    # 정리
    cleanup_build
    
    echo ""
    log_success "Windows EXE 빌드 완료!"
    echo ""
    echo "📦 생성된 파일:"
    echo "   📁 Windows 디렉토리: $WINDOWS_DIR"
    if [[ -f "$WINDOWS_DIR/platform_detector.exe" ]]; then
        echo "   🔧 실행 파일: platform_detector.exe"
    fi
    if [[ -f "$WINDOWS_DIR/platform_detector_x86.exe" ]]; then
        echo "   🔧 32비트 실행 파일: platform_detector_x86.exe"
    fi
    echo "   📜 Windows 플레이어: wplay.sh"
    echo "   📄 배치 파일: badapple.bat"
    echo "   ⚡ PowerShell 스크립트: badapple.ps1"
    
    if [[ -f "$DIST_DIR/badapple_windows.zip" ]]; then
        echo "   📦 ZIP 패키지: badapple_windows.zip"
    fi
    if [[ -f "$DIST_DIR/badapple_windows.tar.gz" ]]; then
        echo "   📦 TAR.GZ 패키지: badapple_windows.tar.gz"
    fi
    
    echo ""
    echo "🚀 사용 방법:"
    echo "   1. Windows에서 배포 패키지 압축 해제"
    echo "   2. badapple.bat 더블클릭 또는"
    echo "   3. Git Bash/WSL에서: ./wplay.sh"
    echo "   4. PowerShell에서: ./badapple.ps1"
}

# 스크립트 실행
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
