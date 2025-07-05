# Makefile for Bad Apple ASCII Animation
# High Performance C Implementation
# Author: BadApple C Team
# Date: 2025-07-05

# 컴파일러 및 플래그
CC = gcc
CFLAGS = -std=c99 -Wall -Wextra -pedantic -flto
CFLAGS += -O3 -march=native -mtune=native
CFLAGS += -ffast-math -funroll-loops -finline-functions
CFLAGS += -DPERFORMANCE_MONITORING

# 디버그 빌드 플래그
DEBUG_CFLAGS = -std=c99 -Wall -Wextra -pedantic -g -O0 -DDEBUG

# 링크 플래그
LDFLAGS = -pthread -lm

# 디렉토리 구조
SRCDIR = src
BUILDDIR = build
OBJDIR = $(BUILDDIR)/obj
BINDIR = $(BUILDDIR)/bin

# 소스 파일들
SOURCES = $(SRCDIR)/main.c \
          $(SRCDIR)/core/frame_manager.c \
          $(SRCDIR)/core/audio_manager.c \
          $(SRCDIR)/core/display_manager.c \
          $(SRCDIR)/utils/error_handler.c \
          $(SRCDIR)/utils/file_utils.c

# 오브젝트 파일들
OBJECTS = $(SOURCES:$(SRCDIR)/%.c=$(OBJDIR)/%.o)

# 실행 파일
TARGET = $(BINDIR)/badapple

# 기본 타겟
.PHONY: all clean debug install test benchmark setup play run extract-frames extract-fullscreen play-fullhd play-fullscreen regenerate-fullhd

all: setup $(TARGET)

# 디렉토리 생성
setup:
	@mkdir -p $(OBJDIR)/core $(OBJDIR)/utils $(BINDIR)
	@mkdir -p assets/ascii_frames
	@echo "🚀 Setting up build directories..."

# 릴리즈 빌드
$(TARGET): $(OBJECTS)
	@echo "🔗 Linking $(TARGET)..."
	@$(CC) $(OBJECTS) -o $@ $(LDFLAGS)
	@echo "✅ Build completed successfully!"
	@echo "📊 Binary size: $$(du -h $(TARGET) | cut -f1)"

# 오브젝트 파일 컴파일
$(OBJDIR)/%.o: $(SRCDIR)/%.c
	@echo "🔨 Compiling $<..."
	@$(CC) $(CFLAGS) -c $< -o $@

# 디버그 빌드
debug: CFLAGS = $(DEBUG_CFLAGS)
debug: setup $(TARGET)
	@echo "🐛 Debug build completed!"

# 클린업
clean:
	@echo "🧹 Cleaning build artifacts..."
	@rm -rf $(BUILDDIR)
	@echo "✅ Clean completed!"

# 설치 (시스템 PATH에 복사)
install: $(TARGET)
	@echo "📦 Installing badapple to /usr/local/bin..."
	@sudo cp $(TARGET) /usr/local/bin/badapple
	@sudo chmod +x /usr/local/bin/badapple
	@echo "✅ Installation completed!"

# 테스트 실행
test: $(TARGET)
	@echo "🧪 Running basic functionality tests..."
	@$(TARGET) --help > /dev/null && echo "✅ Help command works"
	@test -d assets/ascii_frames || (echo "⚠️  Warning: assets/ascii_frames not found" && mkdir -p assets/ascii_frames)
	@test -d assets/audio || (echo "⚠️  Warning: assets/audio not found" && mkdir -p assets/audio)
	@echo "✅ Basic tests passed!"

# 성능 벤치마크
benchmark: $(TARGET)
	@echo "📈 Running performance benchmark..."
	@time $(TARGET) --show-stats --verbose || echo "📊 Benchmark completed (check output above)"

# 메모리 검사 (valgrind 필요)
memcheck: debug
	@echo "🔍 Running memory leak detection..."
	@valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes $(TARGET) --help

# 정적 분석 (cppcheck 필요)
static-analysis:
	@echo "🔍 Running static code analysis..."
	@cppcheck --enable=all --std=c99 --suppress=missingIncludeSystem $(SRCDIR)/

# 코드 포맷팅 (clang-format 필요)
format:
	@echo "🎨 Formatting source code..."
	@find $(SRCDIR) -name "*.c" -o -name "*.h" | xargs clang-format -i -style="{BasedOnStyle: Google, IndentWidth: 4, ColumnLimit: 100}"
	@echo "✅ Code formatting completed!"

# 의존성 정보 출력
deps:
	@echo "📋 Build Dependencies:"
	@echo "  Required: gcc, make, pthread"
	@echo "  Optional: ffplay (for audio), valgrind (for memcheck), cppcheck (for analysis)"
	@echo "  Runtime: Terminal with ANSI support"

# 빌드 정보 출력
info:
	@echo "ℹ️  Build Configuration:"
	@echo "  Compiler: $(CC)"
	@echo "  CFLAGS: $(CFLAGS)"
	@echo "  LDFLAGS: $(LDFLAGS)"
	@echo "  Target: $(TARGET)"
	@echo "  Optimization: O3 + LTO + native arch"

# 도움말
help:
	@echo "🍎 Bad Apple ASCII Animation Build System"
	@echo ""
	@echo "🔨 Build Targets:"
	@echo "  all         - Build release version (default)"
	@echo "  debug       - Build debug version with symbols"
	@echo "  clean       - Remove all build artifacts"
	@echo "  install     - Install to /usr/local/bin (requires sudo)"
	@echo ""
	@echo "🎬 Playback Targets:"
	@echo "  play        - Launch Bad Apple Player (RECOMMENDED)"
	@echo "  play-fresh  - Launch with fresh frame extraction"
	@echo "  play-rebuild- Launch with forced rebuild"
	@echo "  play-clean  - Clean build and launch"
	@echo "  run         - Run player in current terminal"
	@echo ""
	@echo "🎞️  Frame Extraction:"
	@echo "  extract-frames - Extract ASCII frames manually"
	@echo ""
	@echo "⚙️  Setup Targets:"
	@echo "  setup-all   - Complete setup (build only, play handles extraction)"
	@echo ""
	@echo "🧪 Development Tools:"
	@echo "  test            - Run basic functionality tests"
	@echo "  benchmark       - Run performance benchmark"
	@echo "  memcheck        - Run memory leak detection (requires valgrind)"
	@echo "  static-analysis - Run static code analysis (requires cppcheck)"
	@echo "  format          - Format source code (requires clang-format)"
	@echo "  deps            - Show build dependencies"
	@echo "  info            - Show build configuration"
	@echo "  help            - Show this help message"
	@echo ""
	@echo "📚 Usage Examples:"
	@echo "  make           # Build release version"
	@echo "  make play      # Launch Bad Apple Player (RECOMMENDED)"
	@echo "  make play-fresh# Launch with fresh extraction"
	@echo "  make debug     # Build debug version"
	@echo ""
	@echo "💡 Quick Start:"
	@echo "  1. make        # Build the player"
	@echo "  2. make play   # Launch and enjoy! (handles all setup automatically)"
	@echo ""
	@echo "🍎 The new unified launcher (play.sh) handles everything automatically:"
	@echo "  - Dependency checking and installation"
	@echo "  - ASCII frame extraction from video"
	@echo "  - Audio extraction and setup"
	@echo "  - Building if needed"
	@echo "  - MacBook-optimized single window launch"

# 플레이어 실행 - 모든 실행은 통합된 play.sh 사용
play: $(TARGET)
	@echo "🎬 Launching Bad Apple Player..."
	@./play.sh

# 플레이어 실행 (현재 터미널에서만)
run: $(TARGET)
	@echo "🎬 Running Bad Apple Player in current terminal..."
	@./play.sh

# 플레이어 실행 (프레임 강제 재추출)
play-fresh: $(TARGET)
	@echo "🎬 Launching with fresh frame extraction..."
	@./play.sh --force-extract

# 플레이어 실행 (강제 재빌드)
play-rebuild: 
	@echo "🎬 Launching with forced rebuild..."
	@./play.sh --force-build

# 완전 초기화 후 실행
play-clean: clean
	@echo "🎬 Clean build and launch..."
	@./play.sh --force-build

# ASCII 프레임 추출 - 통합된 play.sh에서 자동 처리
extract-frames: setup
	@echo "🎞️  Extracting ASCII frames..."
	@cd scripts && python3 extract_ascii_frames.py
	@echo "✅ Frame extraction completed!"

# 전체 설정 (통합된 play.sh 사용)
setup-all: all
	@echo "🎉 Build completed! Use 'make play' to launch with automatic setup."

# 종속성 규칙 (자동 생성)
-include $(OBJECTS:.o=.d)

$(OBJDIR)/%.d: $(SRCDIR)/%.c
	@mkdir -p $(dir $@)
	@$(CC) -MM -MT $(@:.d=.o) $< > $@
