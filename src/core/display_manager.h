/**
 * @file display_manager.h
 * @brief 고성능 터미널 디스플레이 관리 싱글톤
 * @author BadApple C Team
 * @date 2025-07-05
 * @version 1.0
 * 
 * ANSI 이스케이프 시퀀스와 저수준 I/O 기반 최적화된 출력
 */

 #ifndef DISPLAY_MANAGER_H
 #define DISPLAY_MANAGER_H
 
 #include <stddef.h>
 #include <stdbool.h>
 #include <stdint.h>
 #include <time.h>
 #include <termios.h>
 #include <sys/ioctl.h>
 #include "../utils/error_handler.h"
 
 // ANSI 이스케이프 시퀀스 상수
 #define FAST_CLEAR_AND_HOME "\033[2J\033[H"
 #define CURSOR_HIDE "\033[?25l"
 #define CURSOR_SHOW "\033[?25h"
 #define ALT_SCREEN_ON "\033[?1049h"
 #define ALT_SCREEN_OFF "\033[?1049l"
 
 // 디스플레이 모드
 typedef enum {
     DISPLAY_MODE_NORMAL = 0,     // 일반 모드 (빠른 출력)
     DISPLAY_MODE_BUFFERED,       // 더블 버퍼링 모드
     DISPLAY_MODE_OPTIMIZED       // 최적화 모드
 } DisplayMode;
 
 // 색상 지원 수준
 typedef enum {
     COLOR_SUPPORT_NONE = 0,      // 흑백
     COLOR_SUPPORT_8_BIT,         // 8비트 색상
     COLOR_SUPPORT_24_BIT         // 24비트 트루컬러
 } ColorSupport;
 
 // 터미널 크기
 typedef struct {
     uint16_t width;
     uint16_t height;
 } TerminalSize;
 
 // 렌더링 통계
 typedef struct {
     uint64_t frames_rendered;    // 렌더링된 프레임 수
     uint64_t bytes_written;      // 출력된 바이트 수
     double avg_render_time_ms;   // 평균 렌더링 시간
     double current_fps;          // 현재 FPS
     uint64_t buffer_switches;    // 버퍼 교체 횟수
     uint64_t optimizations_applied; // 적용된 최적화 수
 } RenderStats;
 
 // 싱글톤 디스플레이 매니저
 typedef struct {
     pthread_mutex_t mutex;       // 스레드 안전성
     bool is_initialized;         // 초기화 상태
     DisplayMode mode;            // 디스플레이 모드
     ColorSupport color_support;  // 색상 지원 수준
     
     // 터미널 정보
     TerminalSize terminal_size;  // 터미널 크기
     struct termios original_termios; // 원본 터미널 설정
     
     // 성능 최적화 버퍼링
     char *front_buffer;          // 전면 버퍼
     char *back_buffer;           // 후면 버퍼  
     size_t buffer_size;          // 버퍼 크기
     
     // FPS 제어
     double target_fps;           // 목표 FPS
     struct timespec last_frame_time; // 마지막 프레임 시간
     
     // 통계 정보
     RenderStats stats;
 } DisplayManager;
 
 /**
  * @brief 싱글톤 인스턴스 접근
  * @return DisplayManager 싱글톤 인스턴스
  */
 DisplayManager* display_manager_get_instance(void);
 
 /**
  * @brief 디스플레이 매니저 초기화
  * @param mode 디스플레이 모드
  * @param target_fps 목표 FPS (기본값: 15)
  * @return 성공 시 ERR_SUCCESS, 실패 시 에러 코드
  */
 ErrorCode display_manager_init(DisplayMode mode, double target_fps);
 
 /**
  * @brief 화면 지우기 (최적화된 ANSI 시퀀스 사용)
  */
 void display_manager_clear_screen(void);
 
 /**
  * @brief 커서 숨기기/보이기
  * @param hide true면 숨기기, false면 보이기
  */
 void display_manager_hide_cursor(bool hide);
 
 /**
  * @brief 프레임 렌더링 (저수준 write 사용)
  * @param frame_data 프레임 데이터
  * @param frame_size 프레임 크기
  * @return 성공 시 ERR_SUCCESS, 실패 시 에러 코드
  */
 ErrorCode display_manager_render_frame(const char* frame_data, size_t frame_size);
 
 /**
  * @brief FPS 제한 대기 (정확한 타이밍 제어)
  */
 void display_manager_frame_sync(void);
 
 /**
  * @brief 현재 FPS 가져오기
  * @return 현재 FPS
  */
 double display_manager_get_current_fps(void);
 
 /**
  * @brief 렌더링 통계 가져오기
  * @return RenderStats 구조체 복사본
  */
 RenderStats display_manager_get_stats(void);
 
 /**
  * @brief 디스플레이 매니저 정리 및 해제
  */
 void display_manager_cleanup(void);
 
 /**
  * @brief 디스플레이 준비 상태 확인
  * @return 초기화되고 사용 가능하면 true
  */
 static inline bool display_manager_is_ready(void) {
     DisplayManager *dm = display_manager_get_instance();
     return dm && dm->is_initialized;
 }
 
 /**
  * @brief 터미널 크기 가져오기
  * @param width 출력: 터미널 너비
  * @param height 출력: 터미널 높이
  */
 static inline void display_manager_get_terminal_size(uint16_t* width, uint16_t* height) {
     DisplayManager *dm = display_manager_get_instance();
     if (dm && width && height) {
         *width = dm->terminal_size.width;
         *height = dm->terminal_size.height;
     }
 }
 
 #endif // DISPLAY_MANAGER_H