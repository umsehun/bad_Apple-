#!/bin/zsh
# 🍎 Bad Apple ASCII Player - Clean Version

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
PLAYER_BIN="$PROJECT_DIR/build/bin/badapple"

# 🎯 MAIN: Clean and Direct
main() {
    clear
    echo "🍎 Bad Apple ASCII Player"
    echo "========================="
    echo
    
    # 1. 빌드 확인
    if [ ! -f "$PLAYER_BIN" ]; then
        echo "Building player..."
        cd "$PROJECT_DIR"
        make > /dev/null 2>&1 || { echo "❌ Build failed"; exit 1; }
    fi
    
    # 2. 터미널 크기 감지 및 ASCII 프레임 최적화
    terminal_size=$(stty size 2>/dev/null || echo "20 80")
    term_height=$(echo $terminal_size | cut -d' ' -f1)
    term_width=$(echo $terminal_size | cut -d' ' -f2)
    
    # 🎯 터미널 크기에 맞는 ASCII 크기 계산
    ascii_width=$((term_width - 3))
    ascii_height=$((term_height - 3))
    
    # 최소/최대 크기 제한
    [ "$ascii_width" -lt 80 ] && ascii_width=80
    [ "$ascii_height" -lt 20 ] && ascii_height=20
    [ "$ascii_width" -gt 300 ] && ascii_width=300
    [ "$ascii_height" -gt 100 ] && ascii_height=100
    
    echo "Terminal: ${term_width}x${term_height}, ASCII: ${ascii_width}x${ascii_height}"
    
    # 프레임 확인 및 재생성
    frame_count=$(ls -1 "$PROJECT_DIR/assets/ascii_frames"/*.txt 2>/dev/null | wc -l | tr -d ' ')
    first_frame_check=""
    if [ "$frame_count" -gt 0 ]; then
        first_frame_check=$(head -1 "$PROJECT_DIR/assets/ascii_frames/frame_000000.txt" 2>/dev/null | wc -c | tr -d ' ')
    fi
    
    # 프레임이 없거나 크기가 맞지 않으면 재생성
    expected_width=$((ascii_width + 1)) # 개행문자 포함
    if [ "$frame_count" -lt 1000 ] || [ "$first_frame_check" != "$expected_width" ]; then
        echo "Generating ASCII frames..."
        cd "$PROJECT_DIR"
        
        # 🔥 기존 ASCII 프레임 완전 삭제 (인덴트 문제 해결)
        rm -rf "assets/ascii_frames"
        mkdir -p "assets/ascii_frames"
        
        # 가상환경 활성화
        source "venv/bin/activate" 2>/dev/null || {
            echo "Setting up Python environment..."
            python3 -m venv venv
            source "venv/bin/activate"
            pip install opencv-python numpy > /dev/null 2>&1
        }
        
        # ASCII 프레임 생성
        python scripts/extract_ascii_frames.py --input "assets/bad_apple.mp4" --output "assets/ascii_frames" --width $ascii_width --height $ascii_height --fps 30
        
        echo "✅ ASCII frames generated"
    fi
    
    # 3. 플레이어 실행
    echo "Starting playback..."
    cd "$PROJECT_DIR"
    "$PLAYER_BIN"
}

#  Execute
main "$@"
