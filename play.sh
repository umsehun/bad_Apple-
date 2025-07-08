#!/usr/bin/env bash
# 🍎 Bad Apple Player (ASCII / TrueColor) - Interactive Version

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# 디버깅 용: 대체 버퍼/커서 숨김 비활성화하여 출력 유지
printf '\e[?1049h'
tput civis
tput rmam
trap 'tput cnorm; tput smam; printf "\e[?1049l"; exit' EXIT

# 배경을 검은색으로 세팅한 뒤 화면을 지웁니다
printf '\e[48;2;0;0;0m'
printf '\e[2J'
printf '\e[H'
  
PROJECT_DIR="$SCRIPT_DIR"
# 빌드된 실행 파일 경로
PLAYER_BIN="$PROJECT_DIR/build/bin/badapple"

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
    read -rp "번호 선택(Enter=ASCII, 2=RGB): " sel >&2
    case "$sel" in
        2) echo "RGB" ;;  # RGB 선택
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
        make > /dev/null 2>&1 || { echo "❌ Build failed"; exit 1; }
    fi
    
    # 2. 플레이 모드 선택 (ASCII / RGB)
    mode=$(choose_mode)
    printf "\n\e[32m선택된 모드:\e[0m %s\n" "$mode"

    # 3. 비디오 파일 선택
    video_file=$(choose_file ".mp4" "bad_apple.mp4") || { echo "MP4 파일이 필요합니다"; exit 1; }
    printf "\e[33m선택된 비디오:\e[0m %s\n" "$video_file"
    # 절대/상대 경로 판단
    if [[ -f "$video_file" ]]; then
        video_path="$video_file"
    else
        video_path="$PROJECT_DIR/assets/$video_file"
    fi

    # 4. 음악(WAV) 파일 선택 (선택적)
    # Enter 입력 시 무음으로 재생
    printf "\n🎵 \e[1;34m음악(WAV) 파일을 선택하세요 (Enter=무음)\e[0m\n" >&2
    audio_file=$(choose_file ".wav" "") || true
    [[ -n "$audio_file" ]] && printf "\e[33m선택된 오디오:\e[0m %s\n" "$audio_file"
    if [[ -z "$audio_file" ]]; then
        audio_path=""
    elif [[ -f "$audio_file" ]]; then
        audio_path="$audio_file"
    else
        # assets/audio 디렉토리에서 찾은 WAV 파일 경로
        audio_path="$PROJECT_DIR/assets/audio/$audio_file"
    fi

    # 5. 터미널 크기 감지 및 기본 ASCII 프레임 크기 계산
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
        extract_script="scripts/extract_ascii_frames.py"
        target_fps=120
    else
        frames_dir="$PROJECT_DIR/assets/ansi_frames"
        extract_script="scripts/extract_ansi_frames.py"
        target_fps=30
    fi
    
    # 7. 프레임 존재 확인 & 재생성
    frame_count=$(ls -1 "$frames_dir"/*.txt 2>/dev/null | wc -l | tr -d ' ')

    # RGB 모드는 매번 프레임 재생성, ASCII는 캐시 사용
    regenerate=false
    if [[ "$mode" == "RGB" ]]; then
        regenerate=true
    elif [[ $frame_count -eq 0 ]]; then
        regenerate=true
    fi

    if $regenerate; then
        echo "🔄 프레임을 생성합니다 ($mode) …"
        # 동적 해상도 및 FPS 결정
        ts=$(stty size 2>/dev/null || echo "20 80")
        rows=$(echo $ts | cut -d ' ' -f1)
        cols=$(echo $ts | cut -d ' ' -f2)
        # 프레임 크기 및 FPS 설정
        if [[ "$mode" == "RGB" ]]; then
            frame_w=140
            frame_h=50
            fps_val=30
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
        rm -rf "$frames_dir" && mkdir -p "$frames_dir"
        # 리소스 기반 동적 축소 비활성화: 고정 크기(140x50) 유지
        # 품질 개선을 위해 해상도 고정

        # 디버그: 실행 명령 확인
        echo "CMD: python $PROJECT_DIR/$extract_script --input $video_path --output $frames_dir --width $frame_w --height $frame_h --fps $fps_val" >&2
        python "$PROJECT_DIR/$extract_script" \
            --input "$video_path" \
            --output "$frames_dir" \
            --width "$frame_w" --height "$frame_h" --fps "$fps_val" || { echo "❌ 프레임 생성 실패"; exit 1; }
        echo "✅ 프레임 생성 완료"
    fi

    # 8. 플레이어 실행
    echo "🚀 재생 시작 …"

    cd "$PROJECT_DIR"
    run_args=('-f' "$frames_dir" '-r' "$target_fps")
    [[ -n "$audio_path" ]] && run_args+=("-a" "$audio_path")
    "$PLAYER_BIN" "${run_args[@]}"
}

#  Execute
main "$@"