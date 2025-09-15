#!/bin/bash
# wplay.sh - Windows용 Bad Apple 애니메이션 플레이어
# Windows Git Bash, WSL, Cygwin, MSYS2 환경 지원
# 생성일: 2024년

set -euo pipefail

# 전역 변수
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$SCRIPT_DIR"
readonly BUILD_DIR="$PROJECT_ROOT/build"
readonly BIN_DIR="$BUILD_DIR/bin"
readonly PLATFORM_DETECTOR="$BIN_DIR/platform_detector.exe"  # Windows용 exe
readonly LOG_FILE="$PROJECT_ROOT/badapple.log"

# Windows 환경 확인
check_windows_environment() {
    echo "🪟 Windows 환경 확인 중..."
    
    # Windows 하위 시스템 감지
    if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
        echo "  ✅ WSL (Windows Subsystem for Linux) 감지: $WSL_DISTRO_NAME"
        export BADAPPLE_WINDOWS_ENV="WSL"
    elif [[ "$OSTYPE" == "msys" ]]; then
        echo "  ✅ MSYS2 환경 감지"
        export BADAPPLE_WINDOWS_ENV="MSYS2"
    elif [[ "$OSTYPE" == "cygwin" ]]; then
        echo "  ✅ Cygwin 환경 감지"
        export BADAPPLE_WINDOWS_ENV="Cygwin"
    elif [[ -n "${COMSPEC:-}" ]]; then
        echo "  ✅ Git Bash/MinGW 환경 감지"
        export BADAPPLE_WINDOWS_ENV="GitBash"
    else
        echo "  ❌ Windows 환경을 감지할 수 없습니다."
        echo "     지원 환경: WSL, MSYS2, Cygwin, Git Bash"
        exit 1
    fi
    
    # Windows 버전 확인
    if command -v wmic >/dev/null 2>&1; then
        local win_version
        win_version=$(wmic os get version /value 2>/dev/null | grep "Version=" | cut -d"=" -f2 || echo "Unknown")
        echo "  📊 Windows 버전: $win_version"
        export BADAPPLE_WINDOWS_VERSION="$win_version"
    fi
    
    # PowerShell 지원 확인
    if command -v powershell.exe >/dev/null 2>&1; then
        echo "  ⚡ PowerShell 사용 가능"
        export BADAPPLE_POWERSHELL_AVAILABLE="1"
    elif command -v pwsh.exe >/dev/null 2>&1; then
        echo "  ⚡ PowerShell Core 사용 가능"
        export BADAPPLE_POWERSHELL_AVAILABLE="1"
    else
        echo "  ⚠️  PowerShell 사용 불가"
        export BADAPPLE_POWERSHELL_AVAILABLE="0"
    fi
}

# Windows용 컴파일러 확인
check_windows_compiler() {
    echo "🔧 Windows 컴파일러 확인 중..."
    
    local compiler_found=0
    
    # GCC 확인 (MSYS2, Cygwin, Git Bash)
    if command -v gcc >/dev/null 2>&1; then
        local gcc_version
        gcc_version=$(gcc --version | head -n1 || echo "Unknown")
        echo "  ✅ GCC 컴파일러 발견: $gcc_version"
        export BADAPPLE_COMPILER="gcc"
        export BADAPPLE_CC="gcc"
        export BADAPPLE_EXE_SUFFIX=".exe"
        compiler_found=1
    fi
    
    # Clang 확인
    if command -v clang >/dev/null 2>&1; then
        local clang_version
        clang_version=$(clang --version | head -n1 || echo "Unknown")
        echo "  ✅ Clang 컴파일러 발견: $clang_version"
        if [[ $compiler_found -eq 0 ]]; then
            export BADAPPLE_COMPILER="clang"
            export BADAPPLE_CC="clang"
            export BADAPPLE_EXE_SUFFIX=".exe"
            compiler_found=1
        fi
    fi
    
    # MinGW 확인
    if command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1; then
        echo "  ✅ MinGW-w64 크로스 컴파일러 발견"
        if [[ $compiler_found -eq 0 ]]; then
            export BADAPPLE_COMPILER="mingw"
            export BADAPPLE_CC="x86_64-w64-mingw32-gcc"
            export BADAPPLE_EXE_SUFFIX=".exe"
            compiler_found=1
        fi
    fi
    
    # Visual Studio Build Tools 확인
    if command -v cl.exe >/dev/null 2>&1; then
        echo "  ✅ Microsoft Visual C++ 컴파일러 발견"
        if [[ $compiler_found -eq 0 ]]; then
            export BADAPPLE_COMPILER="msvc"
            export BADAPPLE_CC="cl.exe"
            export BADAPPLE_EXE_SUFFIX=".exe"
            compiler_found=1
        fi
    fi
    
    if [[ $compiler_found -eq 0 ]]; then
        echo "  ❌ 사용 가능한 C 컴파일러를 찾을 수 없습니다."
        echo ""
        echo "  다음 중 하나를 설치해주세요:"
        echo "  1. MSYS2: https://www.msys2.org/"
        echo "  2. Visual Studio Build Tools"
        echo "  3. Git for Windows (MinGW 포함)"
        echo "  4. WSL Ubuntu에서 build-essential 패키지"
        exit 1
    fi
}

# Windows용 플랫폼 감지기 컴파일
compile_windows_platform_detector() {
    echo "🛠️  Windows용 플랫폼 감지기 컴파일 중..."
    
    # 빌드 디렉토리 생성
    mkdir -p "$BIN_DIR"
    
    local source_file="$PROJECT_ROOT/src/platform.c"
    local output_file="$PLATFORM_DETECTOR"
    
    if [[ ! -f "$source_file" ]]; then
        echo "  ❌ 소스 파일을 찾을 수 없습니다: $source_file"
        exit 1
    fi
    
    # Windows 특화 컴파일 플래그
    local compile_flags="-std=c99 -Wall -Wextra -O2"
    local windows_libs=""
    
    # 환경별 컴파일 설정
    case "${BADAPPLE_WINDOWS_ENV:-}" in
        "WSL")
            compile_flags+=" -DWSL_BUILD"
            ;;
        "MSYS2")
            compile_flags+=" -DMSYS2_BUILD"
            windows_libs="-luser32 -lkernel32"
            ;;
        "Cygwin")
            compile_flags+=" -DCYGWIN_BUILD"
            ;;
        "GitBash")
            compile_flags+=" -DGITBASH_BUILD"
            windows_libs="-luser32 -lkernel32"
            ;;
    esac
    
    # 컴파일러별 설정
    case "${BADAPPLE_COMPILER:-}" in
        "gcc"|"clang")
            local cmd="$BADAPPLE_CC $compile_flags \"$source_file\" -o \"$output_file\" $windows_libs"
            echo "  📝 컴파일 명령: $cmd"
            ;;
        "mingw")
            local cmd="$BADAPPLE_CC $compile_flags \"$source_file\" -o \"$output_file\" $windows_libs"
            echo "  📝 MinGW 크로스 컴파일: $cmd"
            ;;
        "msvc")
            local cmd="cl.exe /nologo $source_file /Fe:$output_file"
            echo "  📝 MSVC 컴파일: $cmd"
            ;;
    esac
    
    # 컴파일 실행
    if eval "$cmd"; then
        echo "  ✅ 컴파일 성공: $output_file"
        
        # 파일 크기 확인
        if [[ -f "$output_file" ]]; then
            local file_size
            file_size=$(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file" 2>/dev/null || echo "Unknown")
            echo "  📦 실행 파일 크기: $file_size bytes"
        fi
    else
        echo "  ❌ 컴파일 실패"
        echo "  💡 해결 방법:"
        echo "     1. 컴파일러 설치 확인"
        echo "     2. Windows SDK 설치 (MSVC 사용 시)"
        echo "     3. 관리자 권한으로 실행"
        exit 1
    fi
}

# Windows용 플랫폼 정보 감지 및 환경변수 설정
detect_windows_platform() {
    echo "🔍 Windows 플랫폼 정보 감지 중..."
    
    if [[ ! -x "$PLATFORM_DETECTOR" ]]; then
        echo "  ❌ 플랫폼 감지기를 찾을 수 없습니다: $PLATFORM_DETECTOR"
        echo "  🔄 컴파일을 먼저 진행합니다..."
        compile_windows_platform_detector
    fi
    
    # 플랫폼 정보 수집
    echo "  📊 시스템 정보 수집 중..."
    
    local platform_info
    if platform_info=$("$PLATFORM_DETECTOR" 2>/dev/null); then
        echo "  ✅ 플랫폼 정보 수집 완료"
        
        # JSON 파싱 및 환경변수 설정 (Windows용 최적화)
        export BADAPPLE_OS_NAME=$(echo "$platform_info" | grep -o '"os_name":"[^"]*"' | cut -d'"' -f4 || echo "Windows")
        export BADAPPLE_OS_VERSION=$(echo "$platform_info" | grep -o '"os_version":"[^"]*"' | cut -d'"' -f4 || echo "Unknown")
        export BADAPPLE_TERMINAL=$(echo "$platform_info" | grep -o '"terminal":"[^"]*"' | cut -d'"' -f4 || echo "Unknown")
        export BADAPPLE_SHELL=$(echo "$platform_info" | grep -o '"shell":"[^"]*"' | cut -d'"' -f4 || echo "bash")
        export BADAPPLE_TERMINAL_WIDTH=$(echo "$platform_info" | grep -o '"terminal_width":[0-9]*' | cut -d':' -f2 || echo "120")
        export BADAPPLE_TERMINAL_HEIGHT=$(echo "$platform_info" | grep -o '"terminal_height":[0-9]*' | cut -d':' -f2 || echo "30")
        export BADAPPLE_CPU_CORES=$(echo "$platform_info" | grep -o '"cpu_cores":[0-9]*' | cut -d':' -f2 || echo "4")
        export BADAPPLE_MEMORY_MB=$(echo "$platform_info" | grep -o '"memory_mb":[0-9]*' | cut -d':' -f2 || echo "8192")
        export BADAPPLE_SUPPORTS_ANSI=$(echo "$platform_info" | grep -o '"supports_ansi_colors":[a-z]*' | cut -d':' -f2 || echo "true")
        export BADAPPLE_SUPPORTS_TRUECOLOR=$(echo "$platform_info" | grep -o '"supports_truecolor":[a-z]*' | cut -d':' -f2 || echo "false")
        
        # Windows 특화 설정
        export BADAPPLE_RECOMMENDED_MODE="ASCII"
        export BADAPPLE_RECOMMENDED_FPS="120"
        export BADAPPLE_RECOMMENDED_WIDTH=$((BADAPPLE_TERMINAL_WIDTH - 5))
        export BADAPPLE_RECOMMENDED_HEIGHT=$((BADAPPLE_TERMINAL_HEIGHT - 5))
        
        # 환경별 최적화
        case "${BADAPPLE_WINDOWS_ENV:-}" in
            "WSL")
                export BADAPPLE_RECOMMENDED_FPS="120"
                echo "  🐧 WSL 환경 - Linux 수준 성능 설정"
                ;;
            "MSYS2"|"GitBash")
                export BADAPPLE_RECOMMENDED_FPS="90"
                echo "  🪟 네이티브 Windows 환경 - 최적화된 설정"
                ;;
            "Cygwin")
                export BADAPPLE_RECOMMENDED_FPS="60"
                echo "  🔄 Cygwin 환경 - 안정성 우선 설정"
                ;;
        esac
        
        echo "  📋 감지된 정보:"
        echo "     OS: $BADAPPLE_OS_NAME $BADAPPLE_OS_VERSION"
        echo "     Terminal: $BADAPPLE_TERMINAL (${BADAPPLE_TERMINAL_WIDTH}x${BADAPPLE_TERMINAL_HEIGHT})"
        echo "     CPU: $BADAPPLE_CPU_CORES cores"
        echo "     Memory: $BADAPPLE_MEMORY_MB MB"
        echo "     추천 설정: $BADAPPLE_RECOMMENDED_MODE mode, ${BADAPPLE_RECOMMENDED_FPS}fps"
        echo "     추천 해상도: ${BADAPPLE_RECOMMENDED_WIDTH}x${BADAPPLE_RECOMMENDED_HEIGHT}"
        
    else
        echo "  ⚠️  플랫폼 감지 실패 - 기본값 사용"
        # Windows 기본값 설정
        export BADAPPLE_OS_NAME="Windows"
        export BADAPPLE_OS_VERSION="Unknown"
        export BADAPPLE_TERMINAL="Unknown"
        export BADAPPLE_SHELL="bash"
        export BADAPPLE_TERMINAL_WIDTH="120"
        export BADAPPLE_TERMINAL_HEIGHT="30"
        export BADAPPLE_CPU_CORES="4"
        export BADAPPLE_MEMORY_MB="8192"
        export BADAPPLE_SUPPORTS_ANSI="true"
        export BADAPPLE_SUPPORTS_TRUECOLOR="false"
        export BADAPPLE_RECOMMENDED_MODE="ASCII"
        export BADAPPLE_RECOMMENDED_FPS="60"
        export BADAPPLE_RECOMMENDED_WIDTH="115"
        export BADAPPLE_RECOMMENDED_HEIGHT="25"
    fi
}

# Windows 파일 경로 변환
convert_windows_path() {
    local path="$1"
    
    case "${BADAPPLE_WINDOWS_ENV:-}" in
        "WSL")
            # WSL: Windows 경로를 Linux 스타일로
            echo "$path" | sed 's|\\|/|g'
            ;;
        "MSYS2"|"GitBash")
            # MSYS2/Git Bash: /c/path 형식으로
            echo "$path" | sed 's|C:\\|/c/|g; s|\\|/|g'
            ;;
        "Cygwin")
            # Cygwin: /cygdrive/c/path 형식으로
            echo "$path" | sed 's|C:\\|/cygdrive/c/|g; s|\\|/|g'
            ;;
        *)
            echo "$path"
            ;;
    esac
}

# Windows용 메인 메뉴
show_windows_main_menu() {
    clear
    echo "╔═══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                       🪟 Bad Apple for Windows 🍎                            ║"
    echo "║                     Windows용 ASCII 애니메이션 플레이어                       ║"
    echo "╠═══════════════════════════════════════════════════════════════════════════════╣"
    echo "║                                                                               ║"
    echo "║  🎬 애니메이션 파일 선택:                                                     ║"
    echo "║                                                                               ║"
    echo "║    1️⃣  ASCII 프레임 재생 (assets/ascii_frames/)                             ║"
    echo "║    2️⃣  ANSI 프레임 재생 (assets/ansi_frames/)                               ║"
    echo "║    3️⃣  RGB 프레임 재생 (assets/rgb_frames/)                                 ║"
    echo "║    4️⃣  원본 비디오 재생 (assets/bad_apple.mp4) - Windows Media Player       ║"
    echo "║                                                                               ║"
    echo "║  ⚙️  시스템 도구:                                                             ║"
    echo "║                                                                               ║"
    echo "║    5️⃣  프레임 생성/변환                                                      ║"
    echo "║    6️⃣  시스템 정보 보기                                                      ║"
    echo "║    7️⃣  Windows 환경 테스트                                                   ║"
    echo "║    8️⃣  PowerShell 모드로 실행                                                ║"
    echo "║                                                                               ║"
    echo "║    0️⃣  종료                                                                  ║"
    echo "║                                                                               ║"
    echo "╠═══════════════════════════════════════════════════════════════════════════════╣"
    echo "║ 🪟 Windows 환경: ${BADAPPLE_WINDOWS_ENV:-Unknown}                              "
    echo "║ 📊 터미널: $BADAPPLE_TERMINAL (${BADAPPLE_TERMINAL_WIDTH}x${BADAPPLE_TERMINAL_HEIGHT})"
    echo "║ 🎯 추천 설정: $BADAPPLE_RECOMMENDED_MODE, ${BADAPPLE_RECOMMENDED_FPS}fps      "
    echo "║ 📦 컴파일러: ${BADAPPLE_COMPILER:-Unknown}                                     "
    echo "╚═══════════════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo -n "선택하세요 (0-8): "
}

# PowerShell로 실행 (Windows 네이티브 모드)
run_in_powershell() {
    echo "⚡ PowerShell 모드로 실행 중..."
    
    if [[ "${BADAPPLE_POWERSHELL_AVAILABLE:-0}" == "1" ]]; then
        # PowerShell 스크립트 생성
        local ps_script="$PROJECT_ROOT/badapple.ps1"
        
        cat > "$ps_script" << 'EOF'
# PowerShell 버전 Bad Apple 플레이어
Write-Host "🪟 PowerShell Bad Apple Player 시작..." -ForegroundColor Green

# 콘솔 크기 설정
$console = $host.UI.RawUI
$console.WindowTitle = "Bad Apple - PowerShell Edition"

# ASCII 프레임 재생 함수
function Play-AsciiFrames {
    param([string]$FramesDir)
    
    $frames = Get-ChildItem -Path $FramesDir -Filter "*.txt" | Sort-Object Name
    
    Write-Host "📁 프레임 디렉토리: $FramesDir" -ForegroundColor Yellow
    Write-Host "🎬 총 프레임 수: $($frames.Count)" -ForegroundColor Yellow
    Write-Host "⏰ 재생 시작... (Ctrl+C로 중지)" -ForegroundColor Green
    
    Start-Sleep -Seconds 2
    
    foreach ($frame in $frames) {
        Clear-Host
        Get-Content $frame.FullName
        Start-Sleep -Milliseconds 83  # ~120fps
    }
}

# 메인 실행
$asciiDir = Join-Path $PSScriptRoot "assets\ascii_frames"
if (Test-Path $asciiDir) {
    Play-AsciiFrames -FramesDir $asciiDir
} else {
    Write-Host "❌ ASCII 프레임 디렉토리를 찾을 수 없습니다: $asciiDir" -ForegroundColor Red
    Write-Host "💡 먼저 프레임을 생성해주세요." -ForegroundColor Yellow
}

Write-Host "🎭 PowerShell Bad Apple 재생 완료!" -ForegroundColor Green
Read-Host "Press Enter to continue..."
EOF
        
        # PowerShell 실행
        if command -v powershell.exe >/dev/null 2>&1; then
            powershell.exe -ExecutionPolicy Bypass -File "$(convert_windows_path "$ps_script")"
        elif command -v pwsh.exe >/dev/null 2>&1; then
            pwsh.exe -ExecutionPolicy Bypass -File "$(convert_windows_path "$ps_script")"
        fi
        
        # 임시 파일 정리
        rm -f "$ps_script"
    else
        echo "❌ PowerShell을 사용할 수 없습니다."
        return 1
    fi
}

# Windows 환경 테스트
test_windows_environment() {
    echo "🧪 Windows 환경 테스트 시작..."
    echo ""
    
    # 1. 기본 명령어 테스트
    echo "1️⃣ 기본 명령어 테스트:"
    local commands=("ls" "cat" "echo" "pwd" "which" "grep" "sed" "awk")
    for cmd in "${commands[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            echo "  ✅ $cmd"
        else
            echo "  ❌ $cmd"
        fi
    done
    echo ""
    
    # 2. 컴파일 환경 테스트
    echo "2️⃣ 컴파일 환경 테스트:"
    check_windows_compiler
    echo ""
    
    # 3. 터미널 기능 테스트
    echo "3️⃣ 터미널 기능 테스트:"
    echo "  📏 터미널 크기: ${BADAPPLE_TERMINAL_WIDTH}x${BADAPPLE_TERMINAL_HEIGHT}"
    echo "  🎨 ANSI 색상 지원: ${BADAPPLE_SUPPORTS_ANSI:-Unknown}"
    echo "  🌈 트루컬러 지원: ${BADAPPLE_SUPPORTS_TRUECOLOR:-Unknown}"
    echo ""
    
    # 4. 파일 시스템 테스트
    echo "4️⃣ 파일 시스템 테스트:"
    local test_file="$PROJECT_ROOT/test_windows.tmp"
    if echo "Windows test" > "$test_file" && [[ -f "$test_file" ]]; then
        echo "  ✅ 파일 생성/읽기 가능"
        rm -f "$test_file"
    else
        echo "  ❌ 파일 생성/읽기 실패"
    fi
    echo ""
    
    # 5. 성능 테스트
    echo "5️⃣ 성능 테스트 (간단한 ASCII 애니메이션):"
    echo "  🎬 3초간 테스트 애니메이션 재생..."
    
    for i in {1..30}; do
        clear
        echo "🍎 Bad Apple Test Animation 🍎"
        echo ""
        case $((i % 4)) in
            0) echo "  ⬛⬜⬛⬜⬛⬜⬛⬜" ;;
            1) echo "  ⬜⬛⬜⬛⬜⬛⬜⬛" ;;
            2) echo "  ⬛⬜⬛⬜⬛⬜⬛⬜" ;;
            3) echo "  ⬜⬛⬜⬛⬜⬛⬜⬛" ;;
        esac
        echo ""
        echo "프레임 $i/30"
        sleep 0.1
    done
    
    clear
    echo "✅ Windows 환경 테스트 완료!"
    echo ""
    echo "📊 테스트 결과 요약:"
    echo "  🪟 Windows 환경: ${BADAPPLE_WINDOWS_ENV:-Unknown}"
    echo "  🔧 컴파일러: ${BADAPPLE_COMPILER:-None}"
    echo "  📏 터미널: ${BADAPPLE_TERMINAL_WIDTH}x${BADAPPLE_TERMINAL_HEIGHT}"
    echo "  ⚡ PowerShell: ${BADAPPLE_POWERSHELL_AVAILABLE:-0}"
    echo ""
}

# 메인 함수
main() {
    echo "🪟 Bad Apple Windows 플레이어 시작..."
    echo ""
    
    # Windows 환경 초기화
    check_windows_environment
    check_windows_compiler
    detect_windows_platform
    
    echo ""
    echo "✅ Windows 환경 초기화 완료!"
    echo ""
    
    # 메인 루프
    while true; do
        show_windows_main_menu
        read -r choice
        
        case "$choice" in
            1)
                echo "🎬 ASCII 프레임 재생 시작..."
                # ASCII 재생 로직 (기존 play.sh와 연동)
                ./play.sh ascii
                ;;
            2)
                echo "🎨 ANSI 프레임 재생 시작..."
                ./play.sh ansi
                ;;
            3)
                echo "🌈 RGB 프레임 재생 시작..."
                ./play.sh rgb
                ;;
            4)
                echo "🎥 원본 비디오 재생..."
                local video_path="$(convert_windows_path "$PROJECT_ROOT/assets/bad_apple.mp4")"
                if [[ -f "$PROJECT_ROOT/assets/bad_apple.mp4" ]]; then
                    # Windows에서 비디오 재생
                    if command -v explorer.exe >/dev/null 2>&1; then
                        explorer.exe "$video_path"
                    elif [[ "${BADAPPLE_POWERSHELL_AVAILABLE:-0}" == "1" ]]; then
                        powershell.exe -Command "Start-Process '$video_path'"
                    else
                        echo "❌ 비디오 재생기를 찾을 수 없습니다."
                    fi
                else
                    echo "❌ 비디오 파일을 찾을 수 없습니다: assets/bad_apple.mp4"
                fi
                ;;
            5)
                echo "⚙️ 프레임 생성 시작..."
                ./play.sh generate
                ;;
            6)
                echo "📊 시스템 정보:"
                echo "  OS: $BADAPPLE_OS_NAME $BADAPPLE_OS_VERSION"
                echo "  터미널: $BADAPPLE_TERMINAL"
                echo "  크기: ${BADAPPLE_TERMINAL_WIDTH}x${BADAPPLE_TERMINAL_HEIGHT}"
                echo "  CPU: $BADAPPLE_CPU_CORES cores"
                echo "  메모리: $BADAPPLE_MEMORY_MB MB"
                echo "  Windows 환경: ${BADAPPLE_WINDOWS_ENV:-Unknown}"
                echo "  컴파일러: ${BADAPPLE_COMPILER:-Unknown}"
                ;;
            7)
                test_windows_environment
                ;;
            8)
                run_in_powershell
                ;;
            0)
                echo "👋 Windows Bad Apple 플레이어를 종료합니다."
                exit 0
                ;;
            *)
                echo "❌ 잘못된 선택입니다. 0-8 중에서 선택해주세요."
                ;;
        esac
        
        echo ""
        echo "Press Enter to continue..."
        read -r
    done
}

# 스크립트 실행
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
