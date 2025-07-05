/**
 * @file file_utils.c
 * @brief 파일 유틸리티 구현부
 */

#include "file_utils.h"
#include <string.h>
#include <stdlib.h>
#include <stdbool.h>

// 자연순서 비교 함수 (프레임 번호 정렬용)
static int natural_compare(const void *a, const void *b) {
    const char *str1 = *(const char **)a;
    const char *str2 = *(const char **)b;
    
    // 숫자 부분 추출하여 비교
    const char *num1 = strrchr(str1, '_');
    const char *num2 = strrchr(str2, '_');
    
    if (num1 && num2) {
        int n1 = atoi(num1 + 1);
        int n2 = atoi(num2 + 1);
        return n1 - n2;
    }
    
    return strcmp(str1, str2);
}

ErrorCode file_load_mmap(const char *filepath, FileBuffer *buffer) {
    CHECK_PTR(filepath, ERR_INVALID_PARAM);
    CHECK_PTR(buffer, ERR_INVALID_PARAM);
    
    // 초기화
    memset(buffer, 0, sizeof(FileBuffer));
    
    // 파일 열기
    buffer->fd = open(filepath, O_RDONLY);
    CHECK_SYSCALL(buffer->fd, "Failed to open file for mmap");
    
    // 파일 크기 가져오기
    struct stat st;
    if (fstat(buffer->fd, &st) < 0) {
        close(buffer->fd);
        return ERR_FILE_READ;
    }
    buffer->size = st.st_size;
    
    // 빈 파일 처리
    if (buffer->size == 0) {
        close(buffer->fd);
        buffer->data = NULL;
        buffer->is_mapped = false;
        return ERR_SUCCESS;
    }
    
    // mmap 실행
    buffer->data = mmap(NULL, buffer->size, PROT_READ, MAP_PRIVATE, buffer->fd, 0);
    if (buffer->data == MAP_FAILED) {
        close(buffer->fd);
        error_log(ERR_FILE_READ, __FUNCTION__, __LINE__, "mmap failed");
        return ERR_FILE_READ;
    }
    
    buffer->is_mapped = true;
    
    // 메모리 어드바이스 (순차 읽기 최적화)
    madvise(buffer->data, buffer->size, MADV_SEQUENTIAL);
    
    return ERR_SUCCESS;
}

void file_buffer_free(FileBuffer *buffer) {
    if (!buffer) return;
    
    if (buffer->is_mapped && buffer->data) {
        munmap(buffer->data, buffer->size);
    }
    
    if (buffer->fd > 0) {
        close(buffer->fd);
    }
    
    memset(buffer, 0, sizeof(FileBuffer));
}

ErrorCode file_scan_directory(const char *dir_path, const char *extension, FileList *file_list) {
    CHECK_PTR(dir_path, ERR_INVALID_PARAM);
    CHECK_PTR(extension, ERR_INVALID_PARAM);
    CHECK_PTR(file_list, ERR_INVALID_PARAM);
    
    // 초기화
    memset(file_list, 0, sizeof(FileList));
    file_list->capacity = 32; // 초기 용량
    file_list->filenames = xmalloc(file_list->capacity * sizeof(char*));
    
    DIR *dir = opendir(dir_path);
    if (!dir) {
        free(file_list->filenames);
        error_log(ERR_FILE_OPEN, __FUNCTION__, __LINE__, "Failed to open directory");
        return ERR_FILE_OPEN;
    }
    
    struct dirent *entry;
    size_t ext_len = strlen(extension);
    
    while ((entry = readdir(dir)) != NULL) {
        // 정규 파일만 처리
        if (entry->d_type != DT_REG) continue;
        
        // 확장자 검사
        size_t name_len = strlen(entry->d_name);
        if (name_len < ext_len) continue;
        
        const char *file_ext = entry->d_name + name_len - ext_len;
        if (strcmp(file_ext, extension) != 0) continue;
        
        // 용량 확장 필요시
        if (file_list->count >= file_list->capacity) {
            file_list->capacity *= 2;
            file_list->filenames = xrealloc(file_list->filenames, 
                                          file_list->capacity * sizeof(char*));
        }
        
        // 파일명 복사
        file_list->filenames[file_list->count] = xmalloc(name_len + 1);
        strcpy(file_list->filenames[file_list->count], entry->d_name);
        file_list->count++;
    }
    
    closedir(dir);
    
    if (file_list->count == 0) {
        free(file_list->filenames);
        error_log(ERR_FILE_READ, __FUNCTION__, __LINE__, "No matching files found");
        return ERR_FILE_READ;
    }
    
    return ERR_SUCCESS;
}

void file_list_sort(FileList *file_list) {
    if (!file_list || file_list->count == 0) return;
    
    qsort(file_list->filenames, file_list->count, sizeof(char*), natural_compare);
}

void file_list_free(FileList *file_list) {
    if (!file_list) return;
    
    for (size_t i = 0; i < file_list->count; i++) {
        free(file_list->filenames[i]);
    }
    
    free(file_list->filenames);
    memset(file_list, 0, sizeof(FileList));
}
