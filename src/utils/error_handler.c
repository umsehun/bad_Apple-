/**
 * @file error_handler.c
 * @brief 고성능 에러 핸들링 유틸리티 구현부
 * @author BadApple C Team
 * @date 2025-07-05
 */

 #include "error_handler.h"
 #include <stdio.h>
 #include <stdlib.h>
 #include <stdarg.h>
 #include <time.h>
 #include <string.h>
 #include <errno.h>
 #include <unistd.h>
 
 // 로그 레벨 정의
 typedef enum {
     LOG_LEVEL_DEBUG = 0,
     LOG_LEVEL_INFO,
     LOG_LEVEL_WARNING,
     LOG_LEVEL_ERROR,
     LOG_LEVEL_FATAL
 } LogLevel;
 
 // 로그 색상 정의 (ANSI 이스케이프 시퀀스)
 static const char* LOG_COLORS[] = {
     "\033[0;36m",  // DEBUG - Cyan
     "\033[0;32m",  // INFO - Green
     "\033[1;33m",  // WARNING - Yellow
     "\033[0;31m",  // ERROR - Red
     "\033[1;31m"   // FATAL - Bright Red
 };
 
 static const char* LOG_PREFIXES[] = {
     "DEBUG",
     "INFO",
     "WARNING",
     "ERROR",
     "FATAL"
 };
 
 // 색상 리셋
 static const char* COLOR_RESET = "\033[0m";
 
 // 현재 로그 레벨 (릴리즈에서는 INFO 이상만)
 #ifdef DEBUG
 static LogLevel g_current_log_level = LOG_LEVEL_DEBUG;
 #else
 static LogLevel g_current_log_level = LOG_LEVEL_INFO;
 #endif
 
 // 에러 메시지 매핑 함수 (성능 최적화)
 static const char* get_error_message(ErrorCode code) {
     switch (code) {
         case ERR_SUCCESS: return "Success";
         case ERR_MEMORY_ALLOC: return "Memory allocation failed";
         case ERR_FILE_OPEN: return "File open failed";
         case ERR_FILE_READ: return "File read failed";
         case ERR_THREAD_CREATE: return "Thread creation failed";
         case ERR_INVALID_PARAM: return "Invalid parameter";
         case ERR_FRAME_LOAD: return "Frame loading failed";
         case ERR_AUDIO_INIT: return "Audio initialization failed";
         case ERR_DISPLAY_INIT: return "Display initialization failed";
         default: return "Unknown error";
     }
 }
 
 /**
  * @brief 현재 시간을 문자열로 포맷
  */
 static void format_timestamp(char* buffer, size_t size) {
     time_t now;
     struct tm* tm_info;
     
     time(&now);
     tm_info = localtime(&now);
     
     strftime(buffer, size, "%H:%M:%S", tm_info);
 }
 
 /**
  * @brief 로그 메시지 출력 (내부 함수)
  */
 static void log_message(LogLevel level, const char* function, int line, const char* format, va_list args) {
     if (level < g_current_log_level) {
         return;
     }
     
     char timestamp[32];
     format_timestamp(timestamp, sizeof(timestamp));
     
     // 스레드 안전한 출력을 위해 stderr 사용
     FILE* output = (level >= LOG_LEVEL_ERROR) ? stderr : stdout;
     
     // 색상과 타임스탬프 출력
     fprintf(output, "%s[%s %s]%s ", 
             LOG_COLORS[level], 
             timestamp, 
             LOG_PREFIXES[level], 
             COLOR_RESET);
     
     // 함수명과 라인 출력 (에러/디버그 레벨에서만)
     if (level >= LOG_LEVEL_ERROR || level == LOG_LEVEL_DEBUG) {
         fprintf(output, "(%s:%d) ", function, line);
     }
     
     // 실제 메시지 출력
     vfprintf(output, format, args);
     fprintf(output, "\n");
     
     // 버퍼 플러시 (실시간 출력 보장)
     fflush(output);
 }
 
 void error_log(ErrorCode code, const char *function, int line, const char *msg) {
     LogLevel level;
     
     // 에러 코드에 따른 로그 레벨 결정
     switch (code) {
         case ERR_SUCCESS:
             level = LOG_LEVEL_INFO;
             break;
         case ERR_INVALID_PARAM:
             level = LOG_LEVEL_WARNING;
             break;
         case ERR_MEMORY_ALLOC:
         case ERR_THREAD_CREATE:
             level = LOG_LEVEL_FATAL;
             break;
         default:
             level = LOG_LEVEL_ERROR;
             break;
     }
     
     // 에러 메시지 포맷
     char error_msg[512];
     snprintf(error_msg, sizeof(error_msg), "Error %d: %s (errno: %s)", 
              code, msg, strerror(errno));
     
     va_list empty_args;
     log_message(level, function, line, error_msg, empty_args);
 }
 
 /**
  * @brief 디버그 로그 출력
  */
 void debug_log(const char *function, int line, const char *format, ...) {
     va_list args;
     va_start(args, format);
     log_message(LOG_LEVEL_DEBUG, function, line, format, args);
     va_end(args);
 }
 
 /**
  * @brief 정보 로그 출력
  */
 void info_log(const char *function, int line, const char *format, ...) {
     va_list args;
     va_start(args, format);
     log_message(LOG_LEVEL_INFO, function, line, format, args);
     va_end(args);
 }
 
 /**
  * @brief 경고 로그 출력
  */
 void warning_log(const char *function, int line, const char *format, ...) {
     va_list args;
     va_start(args, format);
     log_message(LOG_LEVEL_WARNING, function, line, format, args);
     va_end(args);
 }
 
 /**
  * @brief 로그 레벨 설정
  */
 void set_log_level(int level) {
     if (level >= LOG_LEVEL_DEBUG && level <= LOG_LEVEL_FATAL) {
         g_current_log_level = (LogLevel)level;
     }
 }
 
 /**
  * @brief 현재 로그 레벨 가져오기
  */
 int get_log_level(void) {
     return (int)g_current_log_level;
 }