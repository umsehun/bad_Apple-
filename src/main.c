/**
 * @file main.c
 * @brief Bad Apple ASCII 애니메이션 메인 프로그램
 * @author BadApple C Team
 * @date 2025-07-05
 * @version 1.0
 * 
 * 고성능 C 구현 - 싱글톤 패턴, mmap, pthread 기반
 */

#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <string.h>
#include <unistd.h>
#include <getopt.h>

#include "core/frame_manager.h"
#include "core/audio_manager.h"
#include "core/display_manager.h"
#include "utils/error_handler.h"

// 애플리케이션 설정
typedef struct {
    char frames_dir[512];       // 프레임 디렉토리
    char audio_file[512];       // 오디오 파일
    double fps;                 // 목표 FPS
    DisplayMode display_mode;   // 디스플레이 모드
    AudioBackend audio_backend; // 오디오 백엔드
    bool show_stats;            // 통계 표시
    bool verbose;               // 상세 로그
} AppConfig;

// 전역 상태
static volatile bool g_running = true;
static AppConfig g_config = {
    .frames_dir = "assets/ascii_frames",
    .audio_file = "assets/audio/bad_apple.wav",  // 실제 파일명으로 수정
    .fps = 29.9863,             // 🎵 초정밀 오디오 동기화 (6572 frames ÷ 219.149932s = 29.9863)
    .display_mode = DISPLAY_MODE_OPTIMIZED,
    .audio_backend = AUDIO_BACKEND_FFPLAY,
    .show_stats = false,
    .verbose = false
};

// 시그널 핸들러 (우아한 종료)
static void signal_handler(int sig) {
    (void)sig;
    g_running = false;
    printf("\n[INFO] Graceful shutdown initiated...\n");
}

// 도움말 출력
static void print_usage(const char *program_name) {
    printf("Usage: %s [OPTIONS]\n", program_name);
    printf("\nBad Apple ASCII Animation Player - High Performance C Implementation\n");
    printf("\nOptions:\n");
    printf("  -f, --frames-dir <dir>    ASCII frames directory (default: %s)\n", g_config.frames_dir);
    printf("  -a, --audio-file <file>   Audio file path (default: %s)\n", g_config.audio_file);
    printf("  -r, --fps <fps>           Target FPS (default: %.1f)\n", g_config.fps);
    printf("  -m, --display-mode <mode> Display mode: normal|buffered|optimized (default: optimized)\n");
    printf("  -b, --audio-backend <be>  Audio backend: ffplay|system (default: ffplay)\n");
    printf("  -s, --show-stats          Show performance statistics\n");
    printf("  -v, --verbose             Verbose logging\n");
    printf("  -h, --help                Show this help message\n");
    printf("\nExamples:\n");
    printf("  %s                                    # Default settings\n", program_name);
    printf("  %s -f ./frames -a ./audio.mp3 -r 30  # Custom settings\n", program_name);
    printf("  %s -m buffered -s                     # Buffered mode with stats\n", program_name);
}

// 명령행 인수 파싱
static ErrorCode parse_arguments(int argc, char *argv[]) {
    static struct option long_options[] = {
        {"frames-dir",    required_argument, 0, 'f'},
        {"audio-file",    required_argument, 0, 'a'},
        {"fps",           required_argument, 0, 'r'},
        {"display-mode",  required_argument, 0, 'm'},
        {"audio-backend", required_argument, 0, 'b'},
        {"show-stats",    no_argument,       0, 's'},
        {"verbose",       no_argument,       0, 'v'},
        {"help",          no_argument,       0, 'h'},
        {0, 0, 0, 0}
    };
    
    int opt;
    int option_index = 0;
    
    while ((opt = getopt_long(argc, argv, "f:a:r:m:b:svh", long_options, &option_index)) != -1) {
        switch (opt) {
            case 'f':
                strncpy(g_config.frames_dir, optarg, sizeof(g_config.frames_dir) - 1);
                break;
            case 'a':
                strncpy(g_config.audio_file, optarg, sizeof(g_config.audio_file) - 1);
                break;
            case 'r':
                g_config.fps = atof(optarg);
                if (g_config.fps <= 0 || g_config.fps > 120) {
                    fprintf(stderr, "Error: FPS must be between 0 and 120\n");
                    return ERR_INVALID_PARAM;
                }
                break;
            case 'm':
                if (strcmp(optarg, "normal") == 0) {
                    g_config.display_mode = DISPLAY_MODE_NORMAL;
                } else if (strcmp(optarg, "buffered") == 0) {
                    g_config.display_mode = DISPLAY_MODE_BUFFERED;
                } else if (strcmp(optarg, "optimized") == 0) {
                    g_config.display_mode = DISPLAY_MODE_OPTIMIZED;
                } else {
                    fprintf(stderr, "Error: Invalid display mode '%s'\n", optarg);
                    return ERR_INVALID_PARAM;
                }
                break;
            case 'b':
                if (strcmp(optarg, "ffplay") == 0) {
                    g_config.audio_backend = AUDIO_BACKEND_FFPLAY;
                } else if (strcmp(optarg, "system") == 0) {
                    g_config.audio_backend = AUDIO_BACKEND_SYSTEM;
                } else {
                    fprintf(stderr, "Error: Invalid audio backend '%s'\n", optarg);
                    return ERR_INVALID_PARAM;
                }
                break;
            case 's':
                g_config.show_stats = true;
                break;
            case 'v':
                g_config.verbose = true;
                break;
            case 'h':
                print_usage(argv[0]);
                exit(EXIT_SUCCESS);
            case '?':
                return ERR_INVALID_PARAM;
            default:
                fprintf(stderr, "Error: Unknown option\n");
                return ERR_INVALID_PARAM;
        }
    }
    
    return ERR_SUCCESS;
}

// 애플리케이션 초기화
static ErrorCode initialize_application(void) {
    ErrorCode result;
    
    if (g_config.verbose) {
        printf("[INFO] Initializing Bad Apple ASCII Animation...\n");
    }
    
    // 프레임 매니저 초기화
    result = frame_manager_init(g_config.frames_dir);
    if (result != ERR_SUCCESS) {
        error_log(ERR_FRAME_LOAD, __FUNCTION__, __LINE__, "Frame manager initialization failed");
        return result;
    }
    
    // 디스플레이 매니저 초기화
    result = display_manager_init(g_config.display_mode, g_config.fps);
    if (result != ERR_SUCCESS) {
        error_log(ERR_DISPLAY_INIT, __FUNCTION__, __LINE__, "Display manager initialization failed");
        return result;
    }
    
    // 오디오 매니저 초기화
    result = audio_manager_init();
    if (result != ERR_SUCCESS) {
        error_log(ERR_AUDIO_INIT, __FUNCTION__, __LINE__, "Audio manager initialization failed");
        return result;
    }
    
    if (g_config.verbose) {
        printf("[INFO] All managers initialized successfully\n");
        printf("[INFO] Frames: %zu, FPS: %.1f, Mode: %d\n", 
               frame_manager_get_total_frames(), g_config.fps, g_config.display_mode);
    }
    
    return ERR_SUCCESS;
}

// 통계 출력
static void print_statistics(void) {
    if (!g_config.show_stats) return;
    
    FrameStats frame_stats = frame_manager_get_stats();
    AudioStats audio_stats = audio_manager_get_stats();
    RenderStats render_stats = display_manager_get_stats();
    
    printf("\n==================== PERFORMANCE STATISTICS ====================\n");
    printf("Frame Manager:\n");
    printf("  Total Memory Used: %zu bytes (%.2f MB)\n", 
           frame_stats.total_memory_used, frame_stats.total_memory_used / 1024.0 / 1024.0);
    printf("  Average Frame Size: %.1f bytes\n", frame_stats.avg_frame_size);
    printf("  Cache Hits: %zu, Misses: %zu\n", frame_stats.cache_hits, frame_stats.cache_misses);
    printf("  Load Time: %.2f ms\n", frame_stats.total_load_time_ms);
    
    printf("\nDisplay Manager:\n");
    printf("  Frames Rendered: %llu\n", (unsigned long long)render_stats.frames_rendered);
    printf("  Average Render Time: %.3f ms\n", render_stats.avg_render_time_ms);
    printf("  Buffer Switches: %llu\n", (unsigned long long)render_stats.buffer_switches);
    printf("  Optimizations Applied: %llu\n", (unsigned long long)render_stats.optimizations_applied);
    
    printf("\nAudio Manager:\n");
    printf("  Playback Duration: %.2f ms\n", audio_stats.playback_duration_ms);
    printf("  Restart Count: %d\n", audio_stats.restart_count);
    printf("  Sync Enabled: %s\n", audio_stats.sync_enabled ? "Yes" : "No");
    
    printf("================================================================\n");
}

/**
 * @brief 프레임 실제 너비 감지
 */
static size_t detect_frame_width(const char* frame_data) {
    if (!frame_data) return 0;
    
    const char* line_end = strchr(frame_data, '\n');
    if (line_end) {
        return line_end - frame_data;
    }
    
    // 개행이 없으면 전체 길이
    return strlen(frame_data);
}

/**
 * @brief 터미널 크기에 맞게 ASCII 프레임 스케일링 (개선된 버전)
 */
static char* scale_frame_to_terminal(const char* frame_data, size_t frame_size, 
                                   uint16_t terminal_width, uint16_t terminal_height,
                                   size_t* scaled_size) {
    if (!frame_data || frame_size == 0) return NULL;
    
    // 실제 프레임 너비 감지
    size_t actual_frame_width = detect_frame_width(frame_data);
    size_t estimated_lines = 0;
    
    // 프레임 라인 수 정확히 계산
    const char* ptr = frame_data;
    while (*ptr) {
        if (*ptr == '\n') estimated_lines++;
        ptr++;
    }
    
    if (g_config.verbose) {
        printf("[DEBUG] Frame info: width=%zu, lines=%zu, terminal=%dx%d\n", 
               actual_frame_width, estimated_lines, terminal_width, terminal_height);
    }
    
    // 🔥 프레임이 터미널 크기에 적합하면 그대로 사용 (개선된 조건)
    if (actual_frame_width <= terminal_width && estimated_lines <= terminal_height - 2) {
        *scaled_size = frame_size;
        char* result = malloc(frame_size + 1);
        if (result) {
            memcpy(result, frame_data, frame_size);
            result[frame_size] = '\0';
        }
        return result;
    }
    
    // 🔥 스마트 스케일링: 터미널 크기에 맞게 조정 
    size_t scaled_buffer_size = terminal_width * terminal_height + terminal_height; 
    char* scaled_frame = malloc(scaled_buffer_size);
    if (!scaled_frame) return NULL;
    
    const char* src_ptr = frame_data;
    char* dst_ptr = scaled_frame;
    size_t dst_used = 0;
    
    // 🎯 라인별 처리로 정확한 스케일링
    size_t lines_processed = 0;
    size_t target_lines = terminal_height - 2; // 여유 공간 확보
    
    while (*src_ptr && lines_processed < target_lines && dst_used < scaled_buffer_size - 1) {
        size_t line_chars = 0;
        const char* line_start = src_ptr;
        
        // 현재 줄의 끝까지 이동 (정확한 너비 계산)
        while (*src_ptr && *src_ptr != '\n') {
            src_ptr++;
            line_chars++;
        }
        
        // 🔥 터미널 너비에 맞게 라인 조정
        size_t target_width = terminal_width - 1; // 여유 공간
        size_t copy_chars = (line_chars < target_width) ? line_chars : target_width;
        
        if (dst_used + copy_chars + 1 < scaled_buffer_size) {
            // 라인 복사
            memcpy(dst_ptr, line_start, copy_chars);
            dst_ptr += copy_chars;
            dst_used += copy_chars;
            
            // 라인이 터미널보다 좁으면 패딩 추가하지 않음 (자연스러운 모양 유지)
            *dst_ptr++ = '\n';
            dst_used++;
        }
        
        // 다음 줄로 이동
        if (*src_ptr == '\n') src_ptr++;
        lines_processed++;
    }
    
    *dst_ptr = '\0';
    *scaled_size = dst_used;
    
    return scaled_frame;
}

// 메인 애니메이션 루프
static ErrorCode run_animation_loop(void) {
    ErrorCode result;
    
    // 터미널 크기 가져오기
    uint16_t terminal_width, terminal_height;
    display_manager_get_terminal_size(&terminal_width, &terminal_height);
    
    if (g_config.verbose) {
        printf("[INFO] Terminal size: %dx%d\n", terminal_width, terminal_height);
    }
    
    // 오디오 재생 시작
    result = audio_manager_start_playback(g_config.audio_file);
    if (result != ERR_SUCCESS) {
        printf("[WARNING] Audio playback failed, continuing with video only\n");
    }
    
    size_t total_frames = frame_manager_get_total_frames();
    size_t current_frame = 0;
    
    if (g_config.verbose) {
        printf("[INFO] Starting animation loop with %zu frames\n", total_frames);
    }
    
    // 메인 애니메이션 루프
    while (g_running && current_frame < total_frames) {
        // 프레임 가져오기
        size_t frame_size;
        const char *frame_data = frame_manager_get_next_frame(&frame_size);
        
        if (!frame_data) {
            error_log(ERR_FRAME_LOAD, __FUNCTION__, __LINE__, "Failed to get frame");
            break;
        }
        
        // 🔥 터미널 크기에 맞게 프레임 스케일링
        size_t scaled_size;
        char* scaled_frame = scale_frame_to_terminal(frame_data, frame_size, 
                                                   terminal_width, terminal_height, 
                                                   &scaled_size);
        
        if (scaled_frame) {
            // 스케일링된 프레임 렌더링
            result = display_manager_render_frame(scaled_frame, scaled_size);
            free(scaled_frame); // 메모리 해제
        } else {
            // 스케일링 실패 시 원본 프레임 사용
            result = display_manager_render_frame(frame_data, frame_size);
        }
        
        if (result != ERR_SUCCESS) {
            error_log(ERR_DISPLAY_INIT, __FUNCTION__, __LINE__, "Frame rendering failed");
            break;
        }
        
        // FPS 동기화
        display_manager_frame_sync();
        
        current_frame++;
        
        // 진행 상황 출력 (verbose 모드)
        if (g_config.verbose && current_frame % 100 == 0) {
            printf("[DEBUG] Rendered frame %zu/%zu (%.1f%%)\n", 
                   current_frame, total_frames, 
                   (double)current_frame / total_frames * 100.0);
        }
    }
    
    if (g_config.verbose) {
        printf("[INFO] Animation loop completed\n");
    }
    
    return ERR_SUCCESS;
}

// 애플리케이션 정리
static void cleanup_application(void) {
    if (g_config.verbose) {
        printf("[INFO] Cleaning up resources...\n");
    }
    
    // 통계 출력
    print_statistics();
    
    // 모든 매니저 정리
    audio_manager_cleanup();
    display_manager_cleanup();
    frame_manager_cleanup();
    
    if (g_config.verbose) {
        printf("[INFO] Cleanup completed\n");
    }
}

// 메인 함수
int main(int argc, char *argv[]) {
    ErrorCode result;
    
    // 시그널 핸들러 등록
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);
    
    printf("🍎 Bad Apple ASCII Animation Player v1.0\n");
    printf("High Performance C Implementation with Singleton Pattern\n\n");
    
    // 명령행 인수 파싱
    result = parse_arguments(argc, argv);
    if (result != ERR_SUCCESS) {
        print_usage(argv[0]);
        return EXIT_FAILURE;
    }
    
    // 애플리케이션 초기화
    result = initialize_application();
    if (result != ERR_SUCCESS) {
        fprintf(stderr, "Failed to initialize application\n");
        cleanup_application();
        return EXIT_FAILURE;
    }
    
    // 메인 애니메이션 실행
    result = run_animation_loop();
    if (result != ERR_SUCCESS) {
        fprintf(stderr, "Animation loop failed\n");
    }
    
    // 정리 및 종료
    cleanup_application();
    
    printf("\n🎬 Animation completed! Thanks for watching Bad Apple!\n");
    
    return (result == ERR_SUCCESS) ? EXIT_SUCCESS : EXIT_FAILURE;
}
