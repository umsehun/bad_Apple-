#!/usr/bin/env bash
if [[ -z "${BADAPPLE_NO_PROFILE:-}" ]]; then
  export BADAPPLE_NO_PROFILE=1
  exec bash --noprofile --norc "$0" "$@"
fi
# 🍎 Bad Apple Player (ASCII / TrueColor) - Interactive Version

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
set -euo pipefail
# ERR 트랩 상속
set -o errtrace

# 색상 정의 (플랫폼 추천 표시용)
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color
# 디버그 로깅을 위해 대체 화면 버퍼 전환과 EXIT 트랩을 일시 비활성화합니다
# printf '\e[?1049h'
# tput civis
# tput rmam
# trap 'tput cnorm; tput smam; printf "\e[?1049l"; exit' EXIT
# 이전 EXIT 트랩 비활성화
# trap 'tput cnorm; tput smam; printf "\e[?1049l"; exit' EXIT
# 스크립트 종료 시 대기하여 로그 확인 가능하도록 EXIT 트랩 설정
finish() {
    echo -e "\n🔴 스크립트가 종료되었습니다. 로그를 확인 후 Enter 키를 눌러 종료하세요." >&2
    read -r -p "" dummy
}
trap finish EXIT
trap 'echo -e "\n❌ 에러 발생: 명령 \"$BASH_COMMAND\" (라인 $LINENO)" >&2; read -rp "디버그 로그 확인 후 Enter 키를 눌러 종료" >&2; exit 1' ERR

# 배경을 검은색으로 세팅한 뒤 화면을 지웁니다
printf '\e[48;2;0;0;0m'
printf '\e[2J'
printf '\e[H'
  
PROJECT_DIR="$SCRIPT_DIR"
# 빌드된 실행 파일 경로
PLAYER_BIN="$PROJECT_DIR/build/bin/badapple"

# 🔧 플랫폼 감지 및 최적화 설정
echo "🔍 플랫폼 환경 감지 중..." >&2

# 명령행 인수에서 --no-compile 옵션 추출
PLATFORM_ARGS=()
for arg in "$@"; do
    case $arg in
        --no-compile)
            PLATFORM_ARGS+=("--no-compile")
            ;;
    esac
done

source "$PROJECT_DIR/platform.sh"
detect_and_export_platform "${PLATFORM_ARGS[@]}"
if [[ -z "${BADAPPLE_OS_NAME:-}" ]]; then
    echo "❌ 플랫폼 감지 실패: 환경변수 미설정. 반드시 source로 실행되어야 합니다." >&2
    exit 1
fi
echo "✅ 플랫폼 감지: $BADAPPLE_OS_NAME / $BADAPPLE_TERMINAL / $BADAPPLE_RECOMMENDED_MODE"

# sanitize PATH to remove Yarn v2 global errors and entries with spaces
IFS=":" read -ra _p <<< "$PATH"
clean_path=
for p in "${_p[@]}"; do
    if [[ "$p" =~ [[:space:]] ]] || [[ "$p" == *"Usage Error"* ]]; then
        continue
    fi
    [[ -z "$p" ]] && continue
    clean_path+="$p:"
done
export PATH="${clean_path%:}"

# 목록에서 파일 선택 함수
choose_file() {
    local pattern="$1" default="$2"
    # 패턴에 따라 검색 디렉토리 결정 (.wav 파일은 assets/audio에서 검색)
    local search_dir
    if [[ "$pattern" == ".wav" ]]; then
        search_dir="$PROJECT_DIR/assets/audio"
    else
        search_dir="$PROJECT_DIR/assets"
    fi
    local files=()
    while IFS= read -r -d $'\0' f; do
        files+=("$(basename "$f")")
    done < <(find "$search_dir" -maxdepth 1 -type f -name "*$pattern" -print0)

    # 매칭 파일이 없더라도 사용자에게 직접 입력/건너뛰기 옵션 제공
    if [[ ${#files[@]} -eq 0 ]]; then
        printf "\n\e[1;34m▶ %s 파일이 존재하지 않습니다. 직접 경로 입력(0) 또는 Enter로 건너뛰기\e[0m\n" "$pattern" >&2
        read -rp "번호 선택(Enter=건너뛰기, 0=직접 입력): " sel >&2
        if [[ -z "$sel" ]]; then
            echo ""; return 0  # 건너뛰기
        elif [[ "$sel" == "0" ]]; then
            read -rp "직접 경로 입력: " custom >&2
            echo "$custom"; return 0
        else
            echo ""; return 0
        fi
    fi

    printf "\n\e[1;34m▶ 파일을 선택하세요 (%s)\e[0m\n" "$pattern" >&2
    local i=1
    for f in "${files[@]}"; do
        printf " %2d) %s\n" "$i" "$f" >&2
        ((i++))
    done
    read -rp "번호 선택(Enter=$default, 0=직접 입력, 이름 입력): " sel >&2

    if [[ -z "$sel" && -n "$default" ]]; then
        echo "$default"; return 0
    elif [[ "$sel" == "0" ]]; then
        read -rp "직접 경로 입력: " custom >&2
        echo "$custom"; return 0
    elif [[ -f "$PROJECT_DIR/assets/$sel" || -f "$sel" ]]; then
        # 사용자가 파일명을 직접 입력
        echo "$sel"; return 0
    elif [[ "$sel" =~ ^[0-9]+$ && "$sel" -ge 1 && "$sel" -le ${#files[@]} ]]; then
        echo "${files[$((sel-1))]}"; return 0
    else
        echo ""; return 1
    fi
}

# 옵션 선택 유틸 (ASCII/RGB/GRAPHICS) - 플랫폼 추천 반영
choose_mode() {
    local recommended="${BADAPPLE_RECOMMENDED_MODE:-ASCII}"
    
    echo -e "\n🔹 재생 모드를 선택하세요:" >&2
    echo "  1) ASCII (기본)" >&2
    echo "  2) RGB (24비트 트루컬러)" >&2
    echo "  3) GRAPHICS (이미지 직접 출력)" >&2
    
    # 플랫폼 추천 표시
    case "$recommended" in
        "GRAPHICS") echo -e "  ${GREEN}💡 추천: GRAPHICS 모드 (Kitty 그래픽 지원 감지)${NC}" >&2 ;;
        "RGB") echo -e "  ${GREEN}💡 추천: RGB 모드 (24비트 트루컬러 지원 감지)${NC}" >&2 ;;
        "ASCII") echo -e "  ${GREEN}💡 추천: ASCII 모드 (안정성 우선)${NC}" >&2 ;;
    esac
    
    read -rp "번호 선택(Enter=추천모드, 1=ASCII, 2=RGB, 3=GRAPHICS): " sel >&2
    case "$sel" in
        3) echo "GRAPHICS" ;;
        2) echo "RGB" ;;
        1) echo "ASCII" ;;
        "") echo "$recommended" ;;  # 추천 모드 사용
        *) echo "$recommended" ;;   # 기타 입력시 추천 모드
    esac
}

# 🎯 MAIN: Clean and Direct
main() {
    clear
    echo " Bad Apple Player (ASCII / RGB)"
    echo "=================================="
    echo
    
    # 1. 빌드 확인 - 플랫폼별 병렬 빌드 최적화
    if [ ! -f "$PLAYER_BIN" ]; then
        echo "Building player..." >&2
        cd "$PROJECT_DIR"
        
        # 플랫폼 감지된 병렬 빌드 설정 사용
        local build_flags="${BADAPPLE_BUILD_PARALLEL:--j$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 1)}"
        echo "🔨 Building with flags: make $build_flags" >&2
        
        make $build_flags > /dev/null 2>&1 || { 
            echo "❌ Build failed" >&2
            exit 1
        }
        echo "✅ Build completed successfully" >&2
    fi
    
    # 2. 플레이 모드 선택 (ASCII / RGB)
    mode=$(choose_mode)
    echo "DEBUG: STEP 2 - Mode selected: $mode" >&2

    # 3. 비디오 파일 선택
    while true; do
        # ERR/errexit 방지
        set +e
        video_file=$(choose_file ".mp4" "bad_apple.mp4")
        rc=$?
        set -e
        if [ "$rc" -eq 0 ]; then
            break
        else
            echo "⚠️ 잘못된 입력입니다. 유효한 MP4 파일을 선택해주세요." >&2
        fi
    done
    echo "DEBUG: STEP 3 - Video file: $video_file" >&2
    # 절대/상대 경로 판단
    if [[ -f "$video_file" ]]; then
        video_path="$video_file"
    else
        video_path="$PROJECT_DIR/assets/$video_file"
    fi

    # 4. 음악(WAV) 파일 선택 (선택적)
    while true; do
        set +e
        audio_file=$(choose_file ".wav" "")
        rc=$?
        set -e
        if [ "$rc" -eq 0 ]; then
            break
        else
            echo "⚠️ WAV 선택 중 오류 발생, 무음 모드로 계속합니다." >&2
            audio_file=""
            break
        fi
    done
    echo "DEBUG: STEP 4 - Audio file: ${audio_file:-(none)}" >&2
    if [[ -z "$audio_file" ]]; then
        audio_path=""
    elif [[ -f "$audio_file" ]]; then
        audio_path="$audio_file"
    else
        # assets/audio 디렉토리에서 찾은 WAV 파일 경로
        audio_path="$PROJECT_DIR/assets/audio/$audio_file"
    fi

    # 5. 터미널 크기 감지 및 ASCII 프레임 크기 계산 - 플랫폼 최적화 반영
    echo "DEBUG: STEP 5 - Platform-optimized terminal size detection" >&2
    
    # 플랫폼 감지된 정보 우선 사용
    if [[ -n "${BADAPPLE_TERMINAL_WIDTH:-}" ]] && [[ -n "${BADAPPLE_TERMINAL_HEIGHT:-}" ]]; then
        cols="$BADAPPLE_TERMINAL_WIDTH"
        rows="$BADAPPLE_TERMINAL_HEIGHT"
        echo "🔧 플랫폼 감지: ${cols}x${rows} (${BADAPPLE_TERMINAL})" >&2
    else
        # 폴백: stty 사용
        ts=$(stty size 2>/dev/null || echo "24 80")
        rows=$(echo $ts | cut -d ' ' -f1)
        cols=$(echo $ts | cut -d ' ' -f2)
        echo "📏 폴백 감지: ${cols}x${rows}" >&2
    fi
    
    # 플랫폼 추천 크기 우선 사용, 없으면 계산
    if [[ -n "${BADAPPLE_RECOMMENDED_WIDTH:-}" ]] && [[ -n "${BADAPPLE_RECOMMENDED_HEIGHT:-}" ]]; then
        ascii_width="$BADAPPLE_RECOMMENDED_WIDTH"
        ascii_height="$BADAPPLE_RECOMMENDED_HEIGHT"
        echo "💡 추천 크기 사용: ${ascii_width}x${ascii_height}" >&2
    else
        # 폴백 계산
        ascii_width=$((cols - 3))
        ascii_height=$((rows - 3))
        [ "$ascii_width" -lt 40 ] && ascii_width=40
        [ "$ascii_height" -lt 20 ] && ascii_height=20
        [ "$ascii_width" -gt 300 ] && ascii_width=300
        [ "$ascii_height" -gt 100 ] && ascii_height=100
        echo "🔢 계산된 크기: ${ascii_width}x${ascii_height}" >&2
    fi

    # Note: 터미널 크기 기반 해상도 조정은 ANSI 모드에서 프레임 생성 직전에 수행합니다

    # 6. 프레임 디렉터리 / 추출 스크립트 설정 - 플랫폼별 FPS 최적화
    local recommended_fps="60"  # 60 FPS로 통일
    
    if [[ "$mode" == "ASCII" ]]; then
        frames_dir="$PROJECT_DIR/assets/ascii_frames"
        extract_script="scripts/extract_ascii_frames_fast.py"
        target_fps="$recommended_fps"
    elif [[ "$mode" == "RGB" ]]; then
        frames_dir="$PROJECT_DIR/assets/ansi_frames"
        extract_script="scripts/extract_ansi_frames.py"
        target_fps="$recommended_fps"
    else
        # GRAPHICS 모드: PNG 프레임 사용
        frames_dir="$PROJECT_DIR/assets/png_frames"
        extract_script="scripts/extract_png_frames.py"
        target_fps="$recommended_fps"
    fi
    
    echo "🎯 선택된 모드: $mode, FPS: $target_fps (추천: $recommended_fps)" >&2
    # 기존 프레임 디렉터리 완전 초기화 후 카운트(삭제 시간 대기)
    if [[ -d "$frames_dir" ]]; then
        rm -rf "$frames_dir"
        sync; sleep 0.1
    fi
    mkdir -p "$frames_dir"
    
    # 7. 프레임 존재 확인 & 자동 생성 (모든 모드 지원)
    shopt -s nullglob
    if [[ "$mode" == "GRAPHICS" ]]; then
        frames=("$frames_dir"/*.png)
    else
        frames=("$frames_dir"/*.txt)
    fi
    frame_count=${#frames[@]}
    echo "DEBUG: STEP 7 - frames_dir=$frames_dir, existing frames=$frame_count" >&2

    # 프레임이 없으면 자동 생성 - 모든 모드 지원
    if [[ "$frame_count" -eq 0 ]]; then
        echo "🔄 프레임이 없으므로 자동으로 생성합니다 ($mode) …" >&2
        
        # 플랫폼 추천 크기 사용 (이미 위에서 설정됨)
        frame_w="$ascii_width"
        frame_h="$ascii_height"
        fps_val="$target_fps"
        
        echo "📏 터미널 ${cols}x${rows}, 프레임: ${frame_w}x${frame_h}, FPS: ${fps_val}" >&2
        echo "🔧 플랫폼: ${BADAPPLE_OS_NAME:-Unknown} ${BADAPPLE_TERMINAL:-Unknown}" >&2
        
        # 모드별 추출 스크립트 실행
        if [[ "$mode" == "ASCII" ]]; then
            # ASCII 모드는 항상 120 FPS 고정
            fps_val=120
            cmd=(python3 "$PROJECT_DIR/scripts/extract_ascii_frames_fast.py" --input "$video_path" --output "$frames_dir" --width "$frame_w" --height "$frame_h" --fps "$fps_val")
        elif [[ "$mode" == "RGB" ]]; then
            # RGB 모드는 60 FPS
            fps_val=60
            cmd=(python3 "$PROJECT_DIR/scripts/extract_ansi_frames.py" --input "$video_path" --output "$frames_dir" --width "$frame_w" --height "$frame_h" --fps "$fps_val")
        else  # GRAPHICS
            # GRAPHICS 모드는 60 FPS
            fps_val=60
            cmd=(python3 "$PROJECT_DIR/scripts/extract_png_frames.py" --input "$video_path" --output "$frames_dir" --width "$frame_w" --height "$frame_h" --fps "$fps_val")
        fi
        
        echo "CMD_PYTHON: ${cmd[*]}" >&2
        set +e
        set +o pipefail
        set -x
        if "${cmd[@]}" 2>&1 | tee /tmp/badapple_extract.log; then
            ec=0
        else
            ec=$?
        fi
        set +x
        set -o pipefail
        set -e
        if [ $ec -ne 0 ]; then
            echo "❌ 프레임 생성 실패 (Exit code $ec)" >&2
            echo "📝 추출 로그 상위 20줄:" >&2
            head -n 20 /tmp/badapple_extract.log >&2
            echo "... 전체 로그는 /tmp/badapple_extract.log 에 있습니다." >&2
            exit $ec
        fi
        echo "✅ 프레임 생성 완료"
        # 프레임 재확인
        if [[ "$mode" == "GRAPHICS" ]]; then
            frames=("$frames_dir"/*.png)
        else
            frames=("$frames_dir"/*.txt)
        fi
        frame_count=${#frames[@]}
    fi
    if [[ "$frame_count" -eq 0 ]]; then
        echo "❌ 프레임이 존재하지 않아 재생을 중단합니다." >&2
        exit 1
    fi
    
    # 8. 플레이어 실행
    echo "DEBUG: STEP 8 - Starting player" >&2
    echo "🚀 재생 시작 …"

    cd "$PROJECT_DIR"
    if [[ "$mode" == "GRAPHICS" ]]; then
        echo "🔍 GRAPHICS 모드 의존성 확인..."
        # kitty 자동 설치 (Homebrew)
        if ! command -v kitty >/dev/null 2>&1; then
            if command -v brew >/dev/null 2>&1; then
                echo "🍺 Homebrew로 kitty 설치 중..."
                brew install --cask kitty || echo "❌ kitty 설치 실패" >&2
            else
                echo "❌ Homebrew가 없어 kitty 설치를 자동으로 진행할 수 없습니다." >&2
            fi
        fi
        # ImageMagick 설치 (PNG 디코딩용)
        if command -v brew >/dev/null 2>&1; then
            echo "🍺 Homebrew로 ImageMagick 설치 중..."
            brew install imagemagick || brew upgrade imagemagick
        else
            echo "❌ Homebrew가 없어 ImageMagick 설치를 자동으로 진행할 수 없습니다." >&2
        fi
        # iTerm2 imgcat 자동 설치
        if ! command -v imgcat >/dev/null 2>&1 && [[ "$TERM_PROGRAM" == "iTerm.app" ]]; then
            echo "📥 iTerm2 Shell Integration 설치 중..."
            curl -L https://iterm2.com/misc/install_shell_integration.sh | bash || echo "❌ imgcat 설치 실패" >&2
            source ~/.iterm2_shell_integration.bash >/dev/null 2>&1
        fi
        # 설치 확인
        if ! command -v kitty >/dev/null 2>&1 && ! command -v imgcat >/dev/null 2>&1; then
            echo "❌ GRAPHICS 모드를 사용하려면 kitty 또는 imgcat이 필요합니다." >&2
            exit 1
        fi
        # GRAPHICS 모드: 터미널 그래픽 프로토콜 (kitty 또는 imgcat 필요)
        sleep_time=$(awk "BEGIN {printf \"%.6f\", 1/$target_fps}")
        find "$frames_dir" -maxdepth 1 -type f -name '*.png' | sort | \
        while IFS= read -r img; do
            if command -v kitty > /dev/null 2>&1; then
                # Kitty: 개행 방지를 위해 --clear 제거하고 커서 위치 고정
                kitty +kitten icat --silent --transfer-mode=memory --stdin < "$img"
                # 커서 위치를 화면 시작으로 고정 (개행 방지)
                printf '\033[H'
            elif command -v imgcat > /dev/null 2>&1; then
                imgcat "$img"
                # imgcat 후에도 커서 위치 고정
                printf '\033[H'
            else
                echo "❌ GRAPHICS 모드를 사용하려면 kitty 또는 iTerm2의 imgcat이 필요합니다." >&2
                exit 1
            fi
            sleep "$sleep_time"
        done
        exit 0
    fi
    run_args=('-f' "$frames_dir" '-r' "$target_fps")
    [[ -n "$audio_path" ]] && run_args+=("-a" "$audio_path")
    # 디버그: 플레이어 실행 명령
    echo "CMD_PLAYER: $PLAYER_BIN ${run_args[*]}" >&2
    "$PLAYER_BIN" "${run_args[@]}" || { echo "❌ 플레이어 실행 실패 (code=$?)" >&2; tput cnorm; tput smam; printf "\e[?1049l"; exit 1; }
}

#  Execute
main "$@"