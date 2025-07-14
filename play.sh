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

# 옵션 선택 유틸 (ASCII/RGB)
choose_mode() {
    echo -e "\n🔹 재생 모드를 선택하세요:" >&2
    echo "  1) ASCII" >&2
    echo "  2) RGB" >&2
    echo "  3) GRAPHICS" >&2
    read -rp "번호 선택(Enter=ASCII, 2=RGB, 3=GRAPHICS): " sel >&2
    case "$sel" in
        3) echo "GRAPHICS" ;;  # 이미지 모드
        2) echo "RGB" ;;  # RGB 모드
        ""|1) echo "ASCII" ;;  # 기본값 ASCII
        *) echo "ASCII" ;;  # 기타 입력 시 기본값
    esac
}

# 🎯 MAIN: Clean and Direct
main() {
    clear
    echo " Bad Apple Player (ASCII / RGB)"
    echo "=================================="
    echo
    
    # 1. 빌드 확인
    if [ ! -f "$PLAYER_BIN" ]; then
        echo "Building player..."
        cd "$PROJECT_DIR"
        # 병렬 빌드로 속도 개선
        make -j$(sysctl -n hw.ncpu) > /dev/null 2>&1 || { echo "❌ Build failed"; exit 1; }
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

    # 5. 터미널 크기 감지 및 기본 ASCII 프레임 크기 계산
    echo "DEBUG: STEP 5 - Detecting terminal size and calculating ASCII dimensions" >&2
    ts=$(stty size 2>/dev/null || echo "20 80")
    rows=$(echo $ts | cut -d ' ' -f1)
    cols=$(echo $ts | cut -d ' ' -f2)
    ascii_width=$((cols - 3))
    ascii_height=$((rows - 3))
    [ "$ascii_width" -lt 40 ] && ascii_width=40
    [ "$ascii_height" -lt 20 ] && ascii_height=20
    [ "$ascii_width" -gt 300 ] && ascii_width=300
    [ "$ascii_height" -gt 100 ] && ascii_height=100

    # Note: 터미널 크기 기반 해상도 조정은 ANSI 모드에서 프레임 생성 직전에 수행합니다

    # 6. 프레임 디렉터리 / 추출 스크립트 설정
    if [[ "$mode" == "ASCII" ]]; then
        frames_dir="$PROJECT_DIR/assets/ascii_frames"
        extract_script="scripts/extract_ascii_frames_fast.py"
        target_fps=120
    elif [[ "$mode" == "RGB" ]]; then
        frames_dir="$PROJECT_DIR/assets/ansi_frames"
        extract_script="scripts/extract_ansi_frames.py"
        target_fps=120
    else
        # GRAPHICS 모드: PNG 프레임 사용
        frames_dir="$PROJECT_DIR/assets/png_frames"
        extract_script="scripts/extract_png_frames.py"
        target_fps=120
    fi
    # 기존 프레임 디렉터리 완전 초기화 후 카운트(삭제 시간 대기)
    if [[ -d "$frames_dir" ]]; then
        rm -rf "$frames_dir"
        sync; sleep 0.1
    fi
    mkdir -p "$frames_dir"
    
    # 7. 프레임 존재 확인 & 재생성
    # nullglob 사용하여 패턴 미매치 시 빈 배열로 처리
    shopt -s nullglob
    frames=("$frames_dir"/*.txt)
    frame_count=${#frames[@]}
    echo "DEBUG: STEP 7 - frames_dir=$frames_dir, existing frames=$frame_count" >&2

    # Always regenerate for ASCII/RGB modes to allow resume 지원
    regenerate=false
    if [[ "$mode" == "ASCII" || "$mode" == "RGB" ]]; then
        regenerate=true
    fi
    echo "DEBUG: STEP 7 - Regenerate frames? $regenerate" >&2

    if $regenerate; then
        echo "🔄 프레임을 생성합니다 ($mode) …"
        echo "DEBUG: STEP 7a - Begin frame extraction" >&2
        # 동적 해상도 및 FPS 결정
        ts=$(stty size 2>/dev/null || echo "20 80")
        rows=$(echo $ts | cut -d ' ' -f1)
        cols=$(echo $ts | cut -d ' ' -f2)
        # 프레임 크기 및 FPS 설정
        if [[ "$mode" == "RGB" ]]; then
            frame_w=140
            frame_h=50
            fps_val=120
        else
            # 프레임 크기: 좌우/상하 여백 확보
            frame_w=$((cols - 3))
            frame_h=$((rows - 3))
            [ "$frame_w" -lt 40 ] && frame_w=40
            [ "$frame_h" -lt 20 ] && frame_h=20
            # FPS 설정: ASCII=120
            fps_val=120
        fi
        echo "📏 터미널 ${cols}x${rows}, Frames: ${frame_w}x${frame_h}, FPS: ${fps_val}" >&2
        # 프레임 디렉터리 초기화
        # rm -rf "$frames_dir" && mkdir -p "$frames_dir" # This line is now redundant due to the new_code
        # 리소스 기반 동적 축소 비활성화: 고정 크기(140x50) 유지
        # 품질 개선을 위해 해상도 고정

        # 디버그: Python 환경 확인
        echo "DEBUG: Python version: $(python --version 2>&1)" >&2
        echo "DEBUG: Python executable: $(command -v python)" >&2
        echo "DEBUG: Extract script exists:" >&2
        ls -l "$PROJECT_DIR/$extract_script" >&2
        echo "DEBUG: PATH=$PATH" >&2
        # 프레임 추출 커맨드
        cmd=(python "$PROJECT_DIR/$extract_script" --input "$video_path" --output "$frames_dir" --width "$frame_w" --height "$frame_h" --fps "$fps_val")
        echo "CMD_PYTHON: ${cmd[*]}" >&2
        # Python 프레임 추출 실행 (pipefail 방지 및 exit code 수집)
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
    else
        echo "🔘 캐시된 프레임 사용 (생성 스킵)" >&2
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
                # Kitty: stream-till-eof 모드로 stdin 직접 스트리밍 (확장자/identify 우회)
                kitty +kitten icat --clear --silent --transfer-mode=memory --stdin < "$img"
            elif command -v imgcat > /dev/null 2>&1; then
                imgcat "$img"
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