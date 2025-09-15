/**
 * @file error_handler.h
 * @brief 고성능 에러 핸들링 유틸리티
 * @author BadApple C Team
 * @date 2025-07-05
 * @version 1.0
 * 
 * C99 표준 준수, 최적화된 에러 처리 매크로와 함수들
 */

 #ifndef ERROR_HANDLER_H
 #define ERROR_HANDLER_H
 
 #include <stdio.h>
 #include <stdlib.h>
 #include <errno.h>
 #include <string.h>
 
 // 컴파일 타임 최적화를 위한 likely/unlikely 힌트
 #ifdef __GNUC__
     #define LIKELY(x)       __builtin_expect(!!(x), 1)
     #define UNLIKELY(x)     __builtin_expect(!!(x), 0)
 #else
     #define LIKELY(x)       (x)
     #define UNLIKELY(x)     (x)
 #endif
 
 // 에러 코드 정의
 typedef enum {
     ERR_SUCCESS = 0,
     ERR_MEMORY_ALLOC = -1,
     ERR_FILE_OPEN = -2,
     ERR_FILE_READ = -3,
     ERR_THREAD_CREATE = -4,
     ERR_INVALID_PARAM = -5,
     ERR_FRAME_LOAD = -6,
     ERR_AUDIO_INIT = -7,
     ERR_DISPLAY_INIT = -8
 } ErrorCode;
 
 // 성능 최적화된 메모리 할당 래퍼
 static inline void* xmalloc(size_t size) {
     void *ptr = malloc(size);
     if (UNLIKELY(!ptr)) {
         fprintf(stderr, "[FATAL] Memory allocation failed: %zu bytes\n", size);
         exit(EXIT_FAILURE);
     }
     return ptr;
 }
 
 // 성능 최적화된 메모리 재할당 래퍼
 static inline void* xrealloc(void *ptr, size_t size) {
     void *new_ptr = realloc(ptr, size);
     if (UNLIKELY(!new_ptr && size > 0)) {
         fprintf(stderr, "[FATAL] Memory reallocation failed: %zu bytes\n", size);
         free(ptr);
         exit(EXIT_FAILURE);
     }
     return new_ptr;
 }
 
 // 안전한 메모리 해제
 static inline void xfree(void **ptr) {
     if (ptr && *ptr) {
         free(*ptr);
         *ptr = NULL;
     }
 }
 
 // 에러 로깅 함수 (최적화된 버퍼링)
 void error_log(ErrorCode code, const char *function, int line, const char *msg);
 
 // 편의 로깅 매크로들
 #define LOG_DEBUG(fmt, ...) do { \
     if (get_log_level() <= 0) { \
         debug_log(__FUNCTION__, __LINE__, fmt, ##__VA_ARGS__); \
     } \
 } while(0)
 
 #define LOG_INFO(fmt, ...) do { \
     info_log(__FUNCTION__, __LINE__, fmt, ##__VA_ARGS__); \
 } while(0)
 
 #define LOG_WARNING(fmt, ...) do { \
     warning_log(__FUNCTION__, __LINE__, fmt, ##__VA_ARGS__); \
 } while(0)
 
 #define LOG_ERROR(fmt, ...) do { \
     error_log(ERR_DISPLAY_INIT, __FUNCTION__, __LINE__, fmt); \
 } while(0)
 
 // 로깅 함수들
 void debug_log(const char *function, int line, const char *format, ...);
 void info_log(const char *function, int line, const char *format, ...);
 void warning_log(const char *function, int line, const char *format, ...);
 void set_log_level(int level);
 int get_log_level(void);
 
 // 시스템 콜 에러 체크 매크로
 #define CHECK_SYSCALL(call, error_msg) do { \
     if (UNLIKELY((call) < 0)) { \
         error_log(ERR_FILE_OPEN, __FUNCTION__, __LINE__, error_msg); \
         return ERR_FILE_OPEN; \
     } \
 } while(0)
 
 // 포인터 유효성 검사 매크로
 #define CHECK_PTR(ptr, error_code) do { \
     if (UNLIKELY(!(ptr))) { \
         error_log(error_code, __FUNCTION__, __LINE__, "Null pointer detected"); \
         return error_code; \
     } \
 } while(0)
 
 // 디버그 빌드에서만 작동하는 어서션
 #ifdef DEBUG
     #define DEBUG_ASSERT(condition, msg) do { \
         if (UNLIKELY(!(condition))) { \
             fprintf(stderr, "[DEBUG] Assertion failed: %s at %s:%d\n", \
                     msg, __FUNCTION__, __LINE__); \
             abort(); \
         } \
     } while(0)
 #else
     #define DEBUG_ASSERT(condition, msg) ((void)0)
 #endif
 
 // 성능 측정을 위한 매크로
 #ifdef PERFORMANCE_MONITORING
     #include <time.h>
     #define PERF_START(name) \
         struct timespec start_##name, end_##name; \
         clock_gettime(CLOCK_MONOTONIC, &start_##name);
     
     #define PERF_END(name) \
         clock_gettime(CLOCK_MONOTONIC, &end_##name); \
         double elapsed_##name = (end_##name.tv_sec - start_##name.tv_sec) * 1000.0 + \
                                (end_##name.tv_nsec - start_##name.tv_nsec) / 1000000.0; \
         printf("[PERF] %s: %.3f ms\n", #name, elapsed_##name);
 #else
     #define PERF_START(name) ((void)0)
     #define PERF_END(name) ((void)0)
 #endif
 
 #endif // ERROR_HANDLER_H
