/**
 * @file frame_manager.h
 * @brief 고성능 ASCII 프레임 관리 싱글톤
 * @author BadApple C Team
 * @date 2025-07-05
 * @version 1.0
 * 
 * 메모리 풀 기반 프레임 캐싱과 최적화된 접근 제공
 */

#ifndef FRAME_MANAGER_H
#define FRAME_MANAGER_H

#include <stddef.h>
#include <stdbool.h>
#include <stdint.h>
#include <pthread.h>
#include "../utils/error_handler.h"
#include "../utils/file_utils.h"

// 성능 통계 구조체
typedef struct {
    double avg_load_time_ms;     // 평균 로딩 시간
    size_t total_memory_used;    // 총 메모리 사용량
    double cache_hit_ratio;      // 캐시 히트율
    size_t frames_loaded;        // 로딩된 프레임 수
    size_t total_frame_size;     // 전체 프레임 데이터 크기
    double avg_frame_size;       // 평균 프레임 크기
    size_t cache_hits;           // 캐시 히트 수
    size_t cache_misses;         // 캐시 미스 수
    double total_load_time_ms;   // 총 로딩 시간
} FrameStats;

// 프레임 데이터 구조체
typedef struct {
    char *data;                  // 프레임 ASCII 데이터
    size_t size;                 // 데이터 크기
    uint32_t checksum;           // 데이터 무결성 체크
} Frame;

// 싱글톤 프레임 매니저
typedef struct {
    Frame *frames;               // 프레임 배열
    size_t total_frames;         // 총 프레임 수
    size_t current_frame;        // 현재 프레임 인덱스
    bool is_initialized;         // 초기화 상태
    bool is_looping;             // 루프 재생 여부
    pthread_mutex_t mutex;       // 스레드 안전성
    
    // 성능 최적화
    char *memory_pool;           // 통합 메모리 풀
    size_t memory_pool_size;     // 메모리 풀 크기
    size_t memory_pool_used;     // 사용된 메모리 크기
    
    // 통계 정보
    FrameStats stats;
} FrameManager;

/**
 * @brief 싱글톤 인스턴스 가져오기 (스레드 안전)
 * @return 프레임 매니저 인스턴스
 */
FrameManager* frame_manager_get_instance(void);

/**
 * @brief 프레임 매니저 초기화 및 프레임 로딩
 * @param frames_dir ASCII 프레임이 있는 디렉토리 경로
 * @return 성공 시 ERR_SUCCESS, 실패 시 에러 코드
 */
ErrorCode frame_manager_init(const char *frames_dir);

/**
 * @brief 다음 프레임 가져오기 (최적화된 접근)
 * @param frame_size 프레임 크기를 저장할 포인터 (nullable)
 * @return 프레임 데이터 포인터, 실패 시 NULL
 */
const char* frame_manager_get_next_frame(size_t* frame_size);

/**
 * @brief 현재 프레임 가져오기
 * @param frame_size 프레임 크기를 저장할 포인터 (nullable)
 * @return 프레임 데이터 포인터, 실패 시 NULL
 */
const char* frame_manager_get_current_frame(size_t* frame_size);

/**
 * @brief 특정 프레임으로 이동
 * @param frame_index 프레임 인덱스
 * @return 성공 시 ERR_SUCCESS, 실패 시 에러 코드
 */
ErrorCode frame_manager_seek_to_frame(size_t frame_index);

/**
 * @brief 프레임 재생 상태 설정
 * @param looping 루프 재생 여부
 */
void frame_manager_set_looping(bool looping);

/**
 * @brief 프레임 재생 리셋 (처음으로)
 */
void frame_manager_reset(void);

/**
 * @brief 성능 통계 가져오기
 * @return FrameStats 구조체 복사본
 */
FrameStats frame_manager_get_stats(void);

/**
 * @brief 메모리 사용량 최적화
 * @return 해제된 메모리 크기 (바이트)
 */
size_t frame_manager_optimize_memory(void);

/**
 * @brief 프레임 매니저 정리 및 해제
 */
void frame_manager_cleanup(void);

/**
 * @brief 프레임 매니저 상태 체크
 * @return 초기화되고 사용 가능하면 true
 */
static inline bool frame_manager_is_ready(void) {
    FrameManager *fm = frame_manager_get_instance();
    return fm && fm->is_initialized && fm->total_frames > 0;
}

/**
 * @brief 현재 프레임 진행률 (0.0 ~ 1.0)
 * @return 진행률 (0.0 = 시작, 1.0 = 끝)
 */
static inline double frame_manager_get_progress(void) {
    FrameManager *fm = frame_manager_get_instance();
    if (!fm || fm->total_frames == 0) return 0.0;
    return (double)fm->current_frame / (double)fm->total_frames;
}

/**
 * @brief 총 프레임 수 가져오기
 * @return 총 프레임 수
 */
static inline size_t frame_manager_get_total_frames(void) {
    FrameManager *fm = frame_manager_get_instance();
    return fm ? fm->total_frames : 0;
}

/**
 * @brief 프레임 프리로딩 (백그라운드 로딩)
 * @param start_index 시작 인덱스
 * @param count 로딩할 프레임 수
 * @return 성공 시 ERR_SUCCESS, 실패 시 에러 코드
 */
ErrorCode frame_manager_preload(size_t start_index, size_t count);

#endif // FRAME_MANAGER_H
