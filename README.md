# 🍎 Bad Apple ASCII Animation Player

High-performance C99 implementation of the famous Bad Apple animation in ASCII format, synchronized with audio playback in the terminal.

## ✨ Features

- **One-Click Launch**: Single `play.sh` script handles everything automatically
- **Smart Setup**: Auto-detects dependencies, extracts frames, builds project
- **MacBook Optimized**: Single window launch with perfect aspect ratio
- **High Performance**: Optimized C99 code with multithreading
- **ASCII Art**: Frame-by-frame ASCII conversion with quality enhancement
- **Audio Sync**: Synchronized audio playback with video frames (extracted from video if needed)
- **Terminal Optimized**: Automatic screen resolution detection and optimization
- **Zero Configuration**: Just place video file and run - everything else is automatic
- **Cross-Platform**: Works on macOS, Linux, and other Unix-like systems

## 🚀 Quick Start

### The Easy Way (Recommended) 🎯
```bash
git clone <repository>
cd badApple

# Place your files:
# - bad_apple.mp4 in assets/
# - bad_apple.wav in assets/ (optional - can be extracted from video)

# One command does everything:
./play.sh
```

### Using Make
```bash
# Build and launch (handles setup automatically)
make play

# Force fresh extraction
make play-fresh

# Clean build and launch
make play-clean
```

### Manual Build
```bash
make          # Build only
make run      # Run in current terminal
```

### Advanced Options
```bash
# Force re-extract frames
./play.sh --force-extract

# Force rebuild
./play.sh --force-build

# Show help
./play.sh --help
```

## 📋 Prerequisites

### Required
- **C Compiler**: gcc with C99 support
- **System**: macOS, Linux, or Unix-like OS
- **Terminal**: ANSI color support
- **Libraries**: pthread, math library (libm)

### For Frame Extraction
- **Python 3**: With pip package manager
- **FFmpeg**: For video processing
- **Python packages**: opencv-python, numpy

### Install Dependencies (macOS)
```bash
# Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install FFmpeg
brew install ffmpeg

# Install Python packages
pip3 install opencv-python numpy
```

## 🎮 Usage

### Basic Commands
```bash
make help              # Show all available commands
make play-fullhd       # Launch Full HD in fullscreen (best quality)
make play              # Launch in new terminal (standard quality)
make run               # Run in current terminal
make play-fullscreen   # Standard fullscreen mode
```

### Quality Modes
```bash
# High-Quality Mode (160x50 frames)
make setup-fullscreen  # One-time setup for best quality
make play-fullhd       # Play in Full HD fullscreen

# Standard Mode (80x24 frames)
make setup-all         # Standard setup
make play              # Standard quality playback

# Frame Extraction Options
make extract-fullscreen # Extract high-quality 160x50 frames
make extract-frames     # Extract standard 80x24 frames
make regenerate-fullhd  # Regenerate Full HD frames
```

### Advanced Launch Options
```bash
# Custom terminal dimensions
scripts/run_player.sh -w 120 -h 40

# Adjust aspect ratio
scripts/run_player.sh -r 1.5    # Wider
scripts/run_player.sh -r 0.8    # Narrower

# Force specific terminal app
scripts/run_player.sh --help    # See all options
```

### Project Structure
```
badApple/
├── src/                    # C source code
│   ├── main.c             # Main application
│   ├── core/              # Core modules
│   │   ├── audio_manager.* # Audio playback
│   │   ├── display_manager.* # Terminal rendering
│   │   └── frame_manager.* # Frame loading/caching
│   └── utils/             # Utility modules
├── assets/                # Media files
│   ├── audio/            # Audio files
│   └── ascii_frames/     # Generated ASCII frames
├── scripts/              # Build and utility scripts
└── build/               # Build output
```

## 🔧 Build System

### Build Targets
```bash
make all            # Build release version (default)
make debug          # Build with debug symbols
make clean          # Clean build artifacts
make test           # Run functionality tests
make benchmark      # Performance benchmarks
make install        # Install to system (sudo required)
```

### Playback Targets
```bash
make run               # Run in current terminal
make play              # Launch in new terminal window
make play-fullscreen   # Standard fullscreen mode
make play-fullhd       # Full HD fullscreen (best quality)
```

### Frame Extraction
```bash
make extract-frames      # Extract standard 80x24 ASCII frames
make extract-fullscreen  # Extract high-quality 160x50 frames
make regenerate-fullhd   # Regenerate Full HD frames
```

### Setup Targets
```bash
make setup-all       # Complete standard setup (frames + build)
make setup-fullscreen # Complete Full HD setup (extract + build)
```

## 🎨 How It Works

### Frame Extraction
1. **Video Processing**: Python scripts use OpenCV to extract frames from `bad_apple.mp4`
2. **Quality Enhancement**: Advanced processing with CLAHE, gamma correction, and bilateral filtering
3. **ASCII Conversion**: Each frame converted to ASCII art using optimized brightness mapping
4. **Multiple Resolutions**: 
   - Standard: 80x24 frames for compatibility
   - Full HD: 160x50 frames for maximum quality
5. **Terminal Optimization**: Frames optimized for terminal display with proper aspect ratio
6. **Storage**: ASCII frames saved as individual text files

### Playback Engine
1. **Frame Manager**: Loads and caches ASCII frames with memory optimization
2. **Audio Manager**: Handles audio playback synchronization using system audio
3. **Display Manager**: Optimized terminal rendering with ANSI escape sequences
4. **Synchronization**: Frame timing synchronized with audio for smooth playback
5. **Fullscreen Support**: AppleScript integration for single-window fullscreen on macOS

### Terminal Optimization
- **Aspect Ratio Correction**: Compensates for terminal character dimensions (typically 2:1 ratio)
- **Size Calculation**: Automatically calculates optimal terminal dimensions
- **Multiple Modes**: Support for various viewing preferences and quality levels
- **Single Window**: Prevents terminal splitting for fullscreen modes

## 🎯 Performance Features

- **Memory Management**: Efficient frame caching and memory pooling
- **Multithreading**: Separate threads for audio, video, and display
- **Compiler Optimization**: LTO, loop unrolling, and architecture-specific optimizations
- **Platform Native**: Compiled for your specific CPU architecture

## 🐛 Troubleshooting

### Common Issues

**No frames displayed / blank output:**
```bash
# Check if frames were extracted properly
ls -la assets/ascii_frames/
# Should show 3000+ .txt files

# Re-extract frames if needed
make extract-frames
```

**Audio not playing:**
```bash
# Check if audio file exists
ls -la assets/audio/bad_apple.wav

# Test audio separately
afplay assets/audio/bad_apple.wav  # macOS
# or
aplay assets/audio/bad_apple.wav   # Linux
```

**Build errors:**
```bash
# Check dependencies
make deps

# Clean and rebuild
make clean
make debug    # Build with debug info
```

**Wrong aspect ratio:**
```bash
# Adjust aspect ratio
scripts/run_player.sh -r 1.5    # Try different ratios
scripts/run_player.sh -w 100 -h 30  # Manual dimensions
```

### Debug Mode
```bash
make debug        # Build with debug symbols
gdb build/bin/badapple  # Debug with GDB
make memcheck     # Memory leak detection (requires valgrind)
```

## 📊 Performance Monitoring

The player includes built-in performance monitoring:
- Frame rate statistics
- Memory usage tracking
- Audio synchronization metrics
- Render time measurements

Run with debug build to see detailed performance information.

## 🛠️ Development

### Code Structure
- **Modular Design**: Separate managers for different concerns
- **Thread Safety**: Proper synchronization primitives
- **Error Handling**: Comprehensive error checking and recovery
- **Memory Safety**: Careful memory management and leak prevention

### Build Configuration
- **Release**: `-O3 -flto -march=native` for maximum performance
- **Debug**: `-g -O0 -DDEBUG` for development and debugging
- **Standards**: Strict C99 compliance with warning flags

### Contributing
1. Follow the existing code style
2. Run `make test` before submitting
3. Use `make format` to format code (requires clang-format)
4. Run `make static-analysis` for code quality checks

## 📄 License

This project is for educational and entertainment purposes. Original Bad Apple video by Team Shanghai Alice.

## 🙏 Credits

- **Original Video**: Bad Apple!! by Team Shanghai Alice
- **Inspiration**: ASCII art animation community
- **Implementation**: High-performance C99 terminal animation

---

**Enjoy the show! 🍎✨**

For the best experience, use `make setup-fullscreen` followed by `make play-fullhd` to enjoy the animation in Full HD quality with optimized fullscreen viewing.

## 🍎 MacBook Optimized Launch (NEW!)

**Perfect for MacBook users experiencing terminal window splitting issues**

### Quick MacBook Setup
```bash
# One-time setup
make setup-fullscreen

# Launch with MacBook optimization (창분할 방지)
make play-final-macbook
```

### MacBook Launch Options
- `make play-final-macbook` - **RECOMMENDED**: 1710x1107 픽셀, 창분할 완전 차단
- `make play-ultimate-macbook` - 고급 격리 모드 (터미널 완전 분리)
- `make play-macbook` - 기본 MacBook 최적화 설정

### MacBook Features
- ✅ **창 분할 방지**: 6분할, 3분할 등 터미널 창 분할 완전 차단
- ✅ **정확한 크기**: 1710x1107 픽셀로 MacBook 화면에 최적화
- ✅ **독립 터미널**: 새로운 Terminal.app 인스턴스로 완전 격리
- ✅ **자동 최적화**: 터미널 설정 자동 조정 (폰트, 색상, 크기)
- ✅ **오류 복구**: 실행 실패 시 자동 폴백 모드
# badApple-
# badApple-
# bad_Apple-
