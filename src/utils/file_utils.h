/**
 * @file file_utils.h
 * @brief 고성능 파일 I/O 유틸리티
 * @author BadApple C Team
 * @date 2025-07-05
 */

 #ifndef FILE_UTILS_H
 #define FILE_UTILS_H
 
 #include <sys/types.h>
 #include <sys/stat.h>
 #include <fcntl.h>
 #include <unistd.h>
 #include <sys/mman.h>
 #include <dirent.h>
 #include <stddef.h>
 #include <stdbool.h>
 #include "error_handler.h"
 
 // 파일 정보 구조체
 typedef struct {
     char *data;          // mmap된 데이터 포인터
     size_t size;         // 파일 크기
     int fd;              // 파일 디스크립터
     bool is_mapped;      // mmap 여부
 } FileBuffer;
 
 // 디렉토리 스캔 결과
 typedef struct {
     char **filenames;    // 파일명 배열
     size_t count;        // 파일 개수
     size_t capacity;     // 배열 용량
 } FileList;
 
 /**
  * @brief mmap을 사용한 고성능 파일 로딩
  * @param filepath 파일 경로
  * @param buffer 출력 버퍼
  * @return 성공 시 ERR_SUCCESS, 실패 시 에러 코드
  */
 ErrorCode file_load_mmap(const char *filepath, FileBuffer *buffer);
 
 /**
  * @brief 파일 버퍼 해제
  * @param buffer 해제할 버퍼
  */
 void file_buffer_free(FileBuffer *buffer);
 
 /**
  * @brief 디렉토리에서 특정 확장자 파일 스캔
  * @param dir_path 디렉토리 경로
  * @param extension 확장자 (예: ".txt")
  * @param file_list 결과 파일 리스트
  * @return 성공 시 ERR_SUCCESS, 실패 시 에러 코드
  */
 ErrorCode file_scan_directory(const char *dir_path, const char *extension, FileList *file_list);
 
 /**
  * @brief 파일 리스트 정렬 (자연순서)
  * @param file_list 정렬할 파일 리스트
  */
 void file_list_sort(FileList *file_list);
 
 /**
  * @brief 파일 리스트 해제
  * @param file_list 해제할 파일 리스트
  */
 void file_list_free(FileList *file_list);
 
 /**
  * @brief 파일 존재 여부 확인 (최적화된 stat 호출)
  * @param filepath 파일 경로
  * @return 존재하면 true, 없으면 false
  */
 static inline bool file_exists(const char *filepath) {
     struct stat st;
     return (stat(filepath, &st) == 0);
 }
 
 /**
  * @brief 파일 크기 가져오기
  * @param filepath 파일 경로
  * @return 파일 크기 (바이트), 실패 시 0
  */
 static inline size_t file_get_size(const char *filepath) {
     struct stat st;
     if (stat(filepath, &st) == 0) {
         return st.st_size;
     }
     return 0;
 }
 
 #endif // FILE_UTILS_H