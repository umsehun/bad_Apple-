/**
 * @file frame_manager.c
 * @brief 고성능 ASCII 프레임 관리 싱글톤 구현부
 * @author BadApple C Team
 * @date 2025-07-05
 */

#include "frame_manager.h"
#include <string.h>
#include <time.h>
#include <sys/mman.h>

// 싱글톤 인스턴스
static FrameManager g_frame_manager = {0};
static pthread_once_t g_once_control = PTHREAD_ONCE_INIT;

// CRC32 테이블 (체크섬 계산용)
static uint32_t crc32_table[256];
static bool crc32_table_initialized = false;

/**
 * @brief CRC32 테이블 초기화
 */
static void init_crc32_table(void) {
    const uint32_t polynomial = 0xEDB88320;
    for (uint32_t i = 0; i < 256; i++) {
        uint32_t crc = i;
        for (int j = 8; j > 0; j--) {
            if (crc & 1) {
                crc = (crc >> 1) ^ polynomial;
            } else {
                crc >>= 1;
            }
        }
        crc32_table[i] = crc;
    }
    crc32_table_initialized = true;
}

/**
 * @brief CRC32 체크섬 계산
 */
static uint32_t calculate_crc32(const char *data, size_t length) {
    if (!crc32_table_initialized) {
        init_crc32_table();
    }
    
    uint32_t crc = 0xFFFFFFFF;
    for (size_t i = 0; i < length; i++) {
        uint8_t byte = (uint8_t)data[i];
        crc = crc32_table[(crc ^ byte) & 0xFF] ^ (crc >> 8);
    }
    return crc ^ 0xFFFFFFFF;
}

/**
 * @brief 싱글톤 초기화 (한 번만 실행)
 */
static void init_frame_manager_once(void) {
    memset(&g_frame_manager, 0, sizeof(FrameManager));
    
    // 뮤텍스 초기화
    pthread_mutex_init(&g_frame_manager.mutex, NULL);
    
    g_frame_manager.is_initialized = false;
    g_frame_manager.is_looping = false;
    g_frame_manager.current_frame = 0;
}

FrameManager* frame_manager_get_instance(void) {
    pthread_once(&g_once_control, init_frame_manager_once);
    return &g_frame_manager;
}

ErrorCode frame_manager_init(const char *frames_dir) {
    PERF_START(frame_loading);
    
    CHECK_PTR(frames_dir, ERR_INVALID_PARAM);
    
    FrameManager *fm = frame_manager_get_instance();
    pthread_mutex_lock(&fm->mutex);
    
    // 이미 초기화된 경우 정리 후 재초기화
    if (fm->is_initialized) {
        // 기존 리소스 해제
        if (fm->memory_pool) {
            munmap(fm->memory_pool, fm->memory_pool_size);
            fm->memory_pool = NULL;
        }
        xfree((void**)&fm->frames);
        memset(&fm->stats, 0, sizeof(FrameStats));
    }
    
    // 디렉토리에서 프레임 파일 스캔
    FileList file_list;
    ErrorCode result = file_scan_directory(frames_dir, ".txt", &file_list);
    if (result != ERR_SUCCESS) {
        pthread_mutex_unlock(&fm->mutex);
        error_log(ERR_FRAME_LOAD, __FUNCTION__, __LINE__, "Failed to scan frame directory");
        return ERR_FRAME_LOAD;
    }
    
    // 파일명 정렬 (자연순서)
    file_list_sort(&file_list);
    
    fm->total_frames = file_list.count;
    fm->frames = xmalloc(fm->total_frames * sizeof(Frame));
    
    // 총 메모리 크기 계산 (1차 스캔)
    size_t total_size = 0;
    for (size_t i = 0; i < file_list.count; i++) {
        char filepath[512];
        snprintf(filepath, sizeof(filepath), "%s/%s", frames_dir, file_list.filenames[i]);
        total_size += file_get_size(filepath);
    }
    
    // 통합 메모리 풀 할당 (mmap 사용)
    fm->memory_pool_size = total_size + (4096 * file_list.count); // 여유분 추가
    fm->memory_pool = mmap(NULL, fm->memory_pool_size, 
                          PROT_READ | PROT_WRITE, 
                          MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    
    if (fm->memory_pool == MAP_FAILED) {
        file_list_free(&file_list);
        pthread_mutex_unlock(&fm->mutex);
        error_log(ERR_MEMORY_ALLOC, __FUNCTION__, __LINE__, "Failed to allocate memory pool");
        return ERR_MEMORY_ALLOC;
    }
    
    fm->memory_pool_used = 0;
    
    // 각 프레임 로딩 (2차 스캔 - 실제 데이터 로딩)
    for (size_t i = 0; i < file_list.count; i++) {
        char filepath[512];
        snprintf(filepath, sizeof(filepath), "%s/%s", frames_dir, file_list.filenames[i]);
        
        FileBuffer buffer;
        result = file_load_mmap(filepath, &buffer);
        if (result != ERR_SUCCESS) {
            continue; // 실패한 프레임은 건너뛰기
        }
        
        // 메모리 풀에서 공간 할당
        char *frame_data = fm->memory_pool + fm->memory_pool_used;
        
        // 데이터 복사
        memcpy(frame_data, buffer.data, buffer.size);
        
        // 프레임 정보 설정
        fm->frames[i].data = frame_data;
        fm->frames[i].size = buffer.size;
        fm->frames[i].checksum = calculate_crc32(frame_data, buffer.size);
        
        fm->memory_pool_used += buffer.size;
        fm->stats.total_frame_size += buffer.size;
        
        file_buffer_free(&buffer);
    }
    
    // 메모리 어드바이스 설정 (순차 접근 최적화)
    madvise(fm->memory_pool, fm->memory_pool_used, MADV_SEQUENTIAL);
    
    // 통계 정보 업데이트
    fm->stats.frames_loaded = fm->total_frames;
    fm->stats.total_memory_used = fm->memory_pool_used;
    fm->current_frame = 0;
    fm->is_initialized = true;
    
    file_list_free(&file_list);
    pthread_mutex_unlock(&fm->mutex);
    
    PERF_END(frame_loading);
    
    return ERR_SUCCESS;
}

const char* frame_manager_get_next_frame(size_t* frame_size) {
    FrameManager *fm = frame_manager_get_instance();
    if (!fm->is_initialized || fm->total_frames == 0) {
        return NULL;
    }
    
    pthread_mutex_lock(&fm->mutex);
    
    // 현재 프레임 가져오기
    Frame *current = &fm->frames[fm->current_frame];
    
    if (frame_size) {
        *frame_size = current->size;
    }
    
    // 다음 프레임으로 이동
    fm->current_frame++;
    if (fm->current_frame >= fm->total_frames) {
        if (fm->is_looping) {
            fm->current_frame = 0;
        } else {
            fm->current_frame = fm->total_frames - 1; // 마지막 프레임에서 정지
        }
    }
    
    pthread_mutex_unlock(&fm->mutex);
    
    return current->data;
}

const char* frame_manager_get_current_frame(size_t* frame_size) {
    FrameManager *fm = frame_manager_get_instance();
    if (!fm->is_initialized || fm->total_frames == 0) {
        return NULL;
    }
    
    pthread_mutex_lock(&fm->mutex);
    Frame *current = &fm->frames[fm->current_frame];
    
    if (frame_size) {
        *frame_size = current->size;
    }
    
    pthread_mutex_unlock(&fm->mutex);
    
    return current->data;
}

ErrorCode frame_manager_seek_to_frame(size_t frame_index) {
    FrameManager *fm = frame_manager_get_instance();
    if (!fm->is_initialized) {
        return ERR_INVALID_PARAM;
    }
    
    if (frame_index >= fm->total_frames) {
        return ERR_INVALID_PARAM;
    }
    
    pthread_mutex_lock(&fm->mutex);
    fm->current_frame = frame_index;
    pthread_mutex_unlock(&fm->mutex);
    
    return ERR_SUCCESS;
}

void frame_manager_set_looping(bool looping) {
    FrameManager *fm = frame_manager_get_instance();
    pthread_mutex_lock(&fm->mutex);
    fm->is_looping = looping;
    pthread_mutex_unlock(&fm->mutex);
}

void frame_manager_reset(void) {
    FrameManager *fm = frame_manager_get_instance();
    pthread_mutex_lock(&fm->mutex);
    fm->current_frame = 0;
    pthread_mutex_unlock(&fm->mutex);
}

FrameStats frame_manager_get_stats(void) {
    FrameManager *fm = frame_manager_get_instance();
    pthread_mutex_lock(&fm->mutex);
    FrameStats stats = fm->stats;
    pthread_mutex_unlock(&fm->mutex);
    return stats;
}

size_t frame_manager_optimize_memory(void) {
    FrameManager *fm = frame_manager_get_instance();
    pthread_mutex_lock(&fm->mutex);
    
    // 메모리 풀 압축 (사용되지 않는 공간 해제)
    if (fm->memory_pool && fm->memory_pool_used < fm->memory_pool_size) {
        size_t unused = fm->memory_pool_size - fm->memory_pool_used;
        pthread_mutex_unlock(&fm->mutex);
        return unused;
    }
    
    pthread_mutex_unlock(&fm->mutex);
    return 0;
}

void frame_manager_cleanup(void) {
    FrameManager *fm = frame_manager_get_instance();
    pthread_mutex_lock(&fm->mutex);
    
    if (fm->memory_pool) {
        munmap(fm->memory_pool, fm->memory_pool_size);
        fm->memory_pool = NULL;
    }
    
    xfree((void**)&fm->frames);
    
    memset(&fm->stats, 0, sizeof(FrameStats));
    fm->total_frames = 0;
    fm->current_frame = 0;
    fm->is_initialized = false;
    fm->is_looping = false;
    fm->memory_pool_size = 0;
    fm->memory_pool_used = 0;
    
    pthread_mutex_unlock(&fm->mutex);
}
