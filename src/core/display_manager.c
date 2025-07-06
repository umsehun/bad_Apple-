/**
 * @file display_manager.c
 * @brief 고성능 터미널 디스플레이 관리 싱글톤 구현부
 * @author BadApple C Team
 * @date 2025-07-05
 * @version 1.0
 * 
 * ANSI 이스케이프 시퀀스와 저수준 I/O 기반 최적화된 출력
 */

 #include "display_manager.h"
 #include <string.h>
 #include <time.h>
 #include <unistd.h>
 #include <signal.h>
 #include <sys/time.h>
 #include <sys/ioctl.h>
 #include <termios.h>
 #include <stdlib.h>
 #include <pthread.h>
 
 // 싱글톤 인스턴스
 static DisplayManager g_display_manager = {0};
 static pthread_once_t g_once_control = PTHREAD_ONCE_INIT;
 
 // 성능 최적화를 위한 상수
 #define BUFFER_SIZE_FACTOR 2    // 버퍼 크기 배수
 #define NANOSEC_PER_SEC 1000000000L
 #define MICROSEC_PER_SEC 1000000L
 
 // ANSI 이스케이프 시퀀스
 #define CURSOR_HIDE "\033[?25l"
 #define CURSOR_SHOW "\033[?25h"
 #define ALT_SCREEN_ON "\033[?1049h"
 #define ALT_SCREEN_OFF "\033[?1049l"
 #define FAST_CLEAR_AND_HOME "\033[2J\033[H"
 
 /**
  * @brief 현재 시간 가져오기 (나노초 정밀도)
  */
 static void get_current_time(struct timespec *ts) {
     clock_gettime(CLOCK_MONOTONIC, ts);
 }
 
 /**
  * @brief 두 timespec 간의 차이 계산 (밀리초 단위)
  */
 static double timespec_diff_ms(const struct timespec *start, const struct timespec *end) {
     double sec_diff = end->tv_sec - start->tv_sec;
     double nsec_diff = end->tv_nsec - start->tv_nsec;
     return (sec_diff * 1000.0) + (nsec_diff / 1000000.0);
 }
 
 /**
  * @brief 터미널 크기 감지 (개선된 버전)
  */
 static void detect_terminal_size(TerminalSize *size) {
     struct winsize w;
     if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &w) == 0 && w.ws_col > 0 && w.ws_row > 0) {
         size->width = w.ws_col;
         size->height = w.ws_row;
     }
 }
 
 /**
  * @brief 색상 지원 감지
  */
 static ColorSupport detect_color_support(void) {
     const char *term = getenv("TERM");
     const char *colorterm = getenv("COLORTERM");
     
     // 24비트 트루컬러 지원 확인
     if (colorterm && (strstr(colorterm, "truecolor") || strstr(colorterm, "24bit"))) {
         return COLOR_SUPPORT_24_BIT;
     }
     
     // 8비트 색상 지원 확인
     if (term && (strstr(term, "256color") || strstr(term, "xterm"))) {
         return COLOR_SUPPORT_8_BIT;
     }
     
     return COLOR_SUPPORT_NONE;
 }
 
 /**
  * @brief 원본 터미널 설정 저장 및 최소한의 설정
  */
 static ErrorCode setup_terminal_raw_mode(DisplayManager *dm) {
     // 원본 터미널 설정 저장만 하고 Raw 모드는 설정하지 않음
     if (tcgetattr(STDIN_FILENO, &dm->original_termios) < 0) {
         return ERR_DISPLAY_INIT;
     }
     
     // 🔥 터미널 분할 방지: Raw 모드 설정 비활성화
     // Raw 모드가 터미널 분할을 일으킬 수 있으므로 최소한의 설정만 적용
     
     return ERR_SUCCESS;
 }
 
 /**
  * @brief 터미널 설정 복원 (분할 방지)
  */
 static void restore_terminal_settings(DisplayManager *dm) {
     // 🔥 분할 방지: 최소한의 복원만 수행
     // tcsetattr(STDIN_FILENO, TCSAFLUSH, &dm->original_termios);
     (void)dm; // 경고 억제
 }
 
 /**
  * @brief 더블 버퍼 초기화
  */
 static ErrorCode init_double_buffer(DisplayManager *dm) {
     // 터미널 크기 기반으로 버퍼 크기 계산
     size_t estimated_frame_size = dm->terminal_size.width * dm->terminal_size.height;
     dm->buffer_size = estimated_frame_size * BUFFER_SIZE_FACTOR;
     
     // 전면 버퍼 할당
     dm->front_buffer = xmalloc(dm->buffer_size);
     if (!dm->front_buffer) {
         return ERR_MEMORY_ALLOC;
     }
     
     // 후면 버퍼 할당 (더블 버퍼링 모드에서만)
     if (dm->mode == DISPLAY_MODE_BUFFERED) {
         dm->back_buffer = xmalloc(dm->buffer_size);
         if (!dm->back_buffer) {
             xfree((void**)&dm->front_buffer);
             return ERR_MEMORY_ALLOC;
         }
     }
     
     // 버퍼 초기화
     memset(dm->front_buffer, 0, dm->buffer_size);
     if (dm->back_buffer) {
         memset(dm->back_buffer, 0, dm->buffer_size);
     }
     
     return ERR_SUCCESS;
 }
 
 /**
  * @brief 싱글톤 초기화 (한 번만 실행)
  */
 static void init_display_manager_once(void) {
     memset(&g_display_manager, 0, sizeof(DisplayManager));
     
     // 뮤텍스 초기화
     pthread_mutex_init(&g_display_manager.mutex, NULL);
     
     g_display_manager.is_initialized = false;
     g_display_manager.mode = DISPLAY_MODE_NORMAL;
     g_display_manager.target_fps = 15.0;
 }
 
 DisplayManager* display_manager_get_instance(void) {
     pthread_once(&g_once_control, init_display_manager_once);
     return &g_display_manager;
 }
 
 ErrorCode display_manager_init(DisplayMode mode, double target_fps) {
     PERF_START(display_init);
     
     DisplayManager *dm = display_manager_get_instance();
     pthread_mutex_lock(&dm->mutex);
     
     // 이미 초기화된 경우 정리 후 재초기화
     if (dm->is_initialized) {
         // 기존 리소스 해제
         restore_terminal_settings(dm);
         xfree((void**)&dm->front_buffer);
         xfree((void**)&dm->back_buffer);
         memset(&dm->stats, 0, sizeof(RenderStats));
     }
     
     // 설정 저장
     dm->mode = mode;
     dm->target_fps = (target_fps > 0) ? target_fps : 15.0;
     
     // 터미널 정보 감지
     detect_terminal_size(&dm->terminal_size);
     dm->color_support = detect_color_support();
     
     // 터미널 Raw 모드 설정
     ErrorCode result = setup_terminal_raw_mode(dm);
     if (result != ERR_SUCCESS) {
         pthread_mutex_unlock(&dm->mutex);
         error_log(ERR_DISPLAY_INIT, __FUNCTION__, __LINE__, "Failed to setup terminal raw mode");
         return ERR_DISPLAY_INIT;
     }
     
     // 버퍼 초기화
     result = init_double_buffer(dm);
     if (result != ERR_SUCCESS) {
         restore_terminal_settings(dm);
         pthread_mutex_unlock(&dm->mutex);
         error_log(ERR_MEMORY_ALLOC, __FUNCTION__, __LINE__, "Failed to initialize display buffers");
         return ERR_MEMORY_ALLOC;
     }
     
     // 대체 화면 버퍼 활성화 비활성화 (터미널 분할 방지)
     // write(STDOUT_FILENO, ALT_SCREEN_ON, strlen(ALT_SCREEN_ON));
     
     // 커서 숨기기
     display_manager_hide_cursor(true);
     
     // 화면 초기화
     display_manager_clear_screen();
     
     // 마지막 프레임 시간 초기화
     get_current_time(&dm->last_frame_time);
     
     // 통계 초기화
     memset(&dm->stats, 0, sizeof(RenderStats));
     
     dm->is_initialized = true;
     pthread_mutex_unlock(&dm->mutex);
     
     PERF_END(display_init);
     
     return ERR_SUCCESS;
 }
 
 void display_manager_clear_screen(void) {
     // 최적화된 화면 지우기: 커서 이동 + 화면 지우기
     write(STDOUT_FILENO, FAST_CLEAR_AND_HOME, strlen(FAST_CLEAR_AND_HOME));
 }
 
 void display_manager_hide_cursor(bool hide) {
     if (hide) {
         write(STDOUT_FILENO, CURSOR_HIDE, strlen(CURSOR_HIDE));
     } else {
         write(STDOUT_FILENO, CURSOR_SHOW, strlen(CURSOR_SHOW));
     }
 }
 
 ErrorCode display_manager_render_frame(const char* frame_data, size_t frame_size) {
     CHECK_PTR(frame_data, ERR_INVALID_PARAM);
     
     DisplayManager *dm = display_manager_get_instance();
     if (!dm->is_initialized) {
         return ERR_DISPLAY_INIT;
     }
     
     // 빈 프레임 체크
     if (frame_size == 0) {
         return ERR_SUCCESS;
     }
     
     pthread_mutex_lock(&dm->mutex);
     
     struct timespec render_start;
     get_current_time(&render_start);
     
     // 커서를 홈 위치로 이동
     write(STDOUT_FILENO, "\033[H", 3);
     
     // 프레임 데이터 직접 출력
     write(STDOUT_FILENO, frame_data, frame_size);
     
     // 통계 업데이트
     struct timespec render_end;
     get_current_time(&render_end);
     
     double render_time = timespec_diff_ms(&render_start, &render_end);
     dm->stats.frames_rendered++;
     dm->stats.bytes_written += frame_size;
     
     // 이동 평균으로 렌더링 시간 계산
     if (dm->stats.frames_rendered == 1) {
         dm->stats.avg_render_time_ms = render_time;
     } else {
         dm->stats.avg_render_time_ms = (dm->stats.avg_render_time_ms * 0.9) + (render_time * 0.1);
     }
     
     pthread_mutex_unlock(&dm->mutex);
     
     return ERR_SUCCESS;
 }
 
 void display_manager_frame_sync(void) {
     DisplayManager *dm = display_manager_get_instance();
     if (!dm->is_initialized || dm->target_fps <= 0) {
         return;
     }
     
     pthread_mutex_lock(&dm->mutex);
     
     struct timespec current_time;
     get_current_time(&current_time);
     
     // 🔥 절대 시간 기반 오디오 동기화 (누적 오차 방지)
     static struct timespec animation_start_time = {0, 0};
     static bool first_frame = true;
     
     // 첫 프레임에서 애니메이션 시작 시간 기록
     if (first_frame) {
         animation_start_time = current_time;
         first_frame = false;
         dm->last_frame_time = current_time;
         pthread_mutex_unlock(&dm->mutex);
         return;
     }
     
     // 현재 프레임 번호 계산 (통계에서 가져옴)
     uint64_t current_frame = dm->stats.frames_rendered;
     
     // 목표 시간 계산 (절대 시간 기준)
     double target_time_sec = (double)current_frame / dm->target_fps;
     long target_time_ns = (long)(target_time_sec * NANOSEC_PER_SEC);
     
     // 실제 경과 시간 계산
     long elapsed_ns = (current_time.tv_sec - animation_start_time.tv_sec) * NANOSEC_PER_SEC +
                       (current_time.tv_nsec - animation_start_time.tv_nsec);
     
     // 동기화 대기 시간 계산
     long sleep_ns = target_time_ns - elapsed_ns;
     
     if (sleep_ns > 0) {
         struct timespec sleep_time = {
             .tv_sec = sleep_ns / NANOSEC_PER_SEC,
             .tv_nsec = sleep_ns % NANOSEC_PER_SEC
         };
         
         // 정밀한 대기 (오디오 동기화)
         nanosleep(&sleep_time, NULL);
     }
     
     // 현재 FPS 계산 (이전 프레임과의 간격 기준)
     long frame_interval_ns = (current_time.tv_sec - dm->last_frame_time.tv_sec) * NANOSEC_PER_SEC +
                             (current_time.tv_nsec - dm->last_frame_time.tv_nsec);
     
     if (frame_interval_ns > 0) {
         dm->stats.current_fps = NANOSEC_PER_SEC / (double)frame_interval_ns;
     }
     
     // 마지막 프레임 시간 업데이트
     get_current_time(&dm->last_frame_time);
     
     pthread_mutex_unlock(&dm->mutex);
 }
 
 double display_manager_get_current_fps(void) {
     DisplayManager *dm = display_manager_get_instance();
     pthread_mutex_lock(&dm->mutex);
     double fps = dm->stats.current_fps;
     pthread_mutex_unlock(&dm->mutex);
     return fps;
 }
 
 RenderStats display_manager_get_stats(void) {
     DisplayManager *dm = display_manager_get_instance();
     pthread_mutex_lock(&dm->mutex);
     RenderStats stats = dm->stats;
     pthread_mutex_unlock(&dm->mutex);
     return stats;
 }
 
 void display_manager_cleanup(void) {
     DisplayManager *dm = display_manager_get_instance();
     pthread_mutex_lock(&dm->mutex);
     
     if (dm->is_initialized) {
         // 커서 보이기
         display_manager_hide_cursor(false);
         
         // 화면 지우기
         display_manager_clear_screen();
         
         // 대체 화면 버퍼 비활성화 (이미 비활성화됨)
         // write(STDOUT_FILENO, ALT_SCREEN_OFF, strlen(ALT_SCREEN_OFF));
         
         // 터미널 설정 복원
         restore_terminal_settings(dm);
         
         // 버퍼 해제
         xfree((void**)&dm->front_buffer);
         xfree((void**)&dm->back_buffer);
         
         dm->is_initialized = false;
         dm->buffer_size = 0;
         memset(&dm->stats, 0, sizeof(RenderStats));
     }
     
     pthread_mutex_unlock(&dm->mutex);
 }