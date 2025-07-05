#!/bin/zsh
# 🍎 Bad Apple ASCII Player - Simple Single Terminal Launcher
# 🔥 ZERO SPLIT GUARANTEE - Only runs in current terminal

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
PLAYER_BIN="$PROJECT_DIR/build/bin/badapple"

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${CYAN}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; exit 1; }

# 🎯 MAIN: Simple and Direct - NO SPLITS!
main() {
    clear
    echo -e "${BLUE}🍎 Bad Apple ASCII Player - Direct Launch${NC}"
    echo -e "${CYAN}===========================================${NC}"
    echo
    
    # 1. 빌드 확인
    if [ ! -f "$PLAYER_BIN" ]; then
        log_info "Building player..."
        cd "$PROJECT_DIR"
        make > /dev/null 2>&1 || log_error "Build failed"
    fi
    
    # 2. 터미널 크기 감지 및 ASCII 프레임 최적화
    terminal_size=$(stty size)
    term_height=$(echo $terminal_size | cut -d' ' -f1)
    term_width=$(echo $terminal_size | cut -d' ' -f2)
    
    # 🎯 동적 ASCII 크기 계산 (최대 활용 개선)
    ascii_width=120
    ascii_height=30
    
    # 🔥 271x70 환경 특별 처리 (최대 활용)
    if [ "$term_width" -ge 270 ]; then
        ascii_width=$((term_width - 5))  # 최소 여백으로 최대 활용
        ascii_height=$((term_height - 3))  # 최소 여백으로 최대 활용
        log_info "Extra large terminal detected (${term_width}x${term_height}) - using maximum ASCII (${ascii_width}x${ascii_height})"
    elif [ "$term_width" -ge 241 ]; then
        ascii_width=$((term_width - 8))  # 적당한 여백
        ascii_height=$((term_height - 4))
        log_info "Large terminal detected (${term_width}x${term_height}) - using high-res ASCII (${ascii_width}x${ascii_height})"
    elif [ "$term_width" -ge 200 ] && [ "$term_height" -ge 50 ]; then
        ascii_width=$((term_width - 10))  # 10자 여백
        ascii_height=$((term_height - 5))  # 5줄 여백
        log_info "Medium-large terminal detected (${term_width}x${term_height}) - using optimized ASCII (${ascii_width}x${ascii_height})"
    elif [ "$term_width" -ge 150 ] && [ "$term_height" -ge 35 ]; then
        ascii_width=140
        ascii_height=35
        log_info "Medium terminal detected (${term_width}x${term_height}) - using medium-res ASCII (${ascii_width}x${ascii_height})"
    else
        log_info "Standard terminal detected (${term_width}x${term_height}) - using standard ASCII (${ascii_width}x${ascii_height})"
    fi
    
    # 프레임 확인 및 재생성
    frame_count=$(ls -1 "$PROJECT_DIR/assets/ascii_frames"/*.txt 2>/dev/null | wc -l | tr -d ' ')
    first_frame_check=""
    if [ "$frame_count" -gt 0 ]; then
        first_frame_check=$(head -1 "$PROJECT_DIR/assets/ascii_frames/frame_000000.txt" 2>/dev/null | wc -c | tr -d ' ')
    fi
    
    # 프레임이 없거나 크기가 맞지 않으면 재생성
    expected_width=$((ascii_width + 1)) # 개행문자 포함
    if [ "$frame_count" -lt 1000 ] || [ "$first_frame_check" != "$expected_width" ]; then
        log_info "Generating optimized ASCII frames (${ascii_width}x${ascii_height})..."
        cd "$PROJECT_DIR/scripts"
        
        # 가상환경 활성화
        source "../venv/bin/activate" 2>/dev/null || {
            log_info "Creating Python virtual environment..."
            cd "$PROJECT_DIR"
            python3 -m venv venv
            source "venv/bin/activate"
            pip install opencv-python numpy > /dev/null 2>&1
            cd scripts
        }
        
        # 🔥 터미널 크기에 최적화된 고품질 프레임 생성 (청크 문제 해결)
        python extract_ascii_frames.py --input "../assets/bad_apple.mp4" --output "../assets/ascii_frames" --width $ascii_width --height $ascii_height --fps 30 --verbose
        
        # 생성된 프레임 검증
        new_frame_count=$(ls -1 "$PROJECT_DIR/assets/ascii_frames"/*.txt 2>/dev/null | wc -l | tr -d ' ')
        log_success "Generated ${new_frame_count} optimized ASCII frames"
    fi
    
    # 3. 🔥 SIMPLE DIRECT EXECUTION - ZERO SPLITS!
    log_success "Running in current terminal (no new windows)..."
    cd "$PROJECT_DIR"
    
    # 🎯 VERBOSE MODE for debugging frame scaling
    "$PLAYER_BIN" --verbose
}

# 🚀 Execute directly
main "$@"
