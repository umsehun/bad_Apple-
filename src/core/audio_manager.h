/**
 * @file audio_manager.h
 * @brief 고성능 오디오 재생 관리 싱글톤
 * @author BadApple C Team
 * @date 2025-07-05
 * @version 1.0
 * 
 * 백그라운드 스레드 기반 오디오 재생과 동기화 제공
 */

#ifndef AUDIO_MANAGER_H
#define AUDIO_MANAGER_H

#include <pthread.h>
#include <stdbool.h>
#include <stdint.h>
#include "../utils/error_handler.h"

// 오디오 백엔드 종류
typedef enum {
    AUDIO_BACKEND_FFPLAY = 0,    // FFmpeg ffplay 사용
    AUDIO_BACKEND_SYSTEM         // 시스템 기본 플레이어
} AudioBackend;

// 오디오 상태 열거형
typedef enum {
    AUDIO_STATE_STOPPED = 0,
    AUDIO_STATE_PLAYING,
    AUDIO_STATE_PAUSED,
    AUDIO_STATE_ERROR
} AudioState;

// 오디오 통계 구조체
typedef struct {
    double playback_time_sec;    // 재생 시간 (초)
    uint64_t bytes_played;       // 재생된 바이트 수
    uint32_t sample_rate;        // 샘플레이트
    uint16_t channels;           // 채널 수
    uint16_t bits_per_sample;    // 비트 레이트
    bool is_synchronized;        // 동기화 상태
    double playback_duration_ms; // 재생 지속 시간
    int restart_count;           // 재시작 횟수
    bool sync_enabled;           // 동기화 활성화 여부
} AudioStats;

// 싱글톤 오디오 매니저
typedef struct {
    pthread_t audio_thread;      // 오디오 재생 스레드
    pthread_mutex_t mutex;       // 스레드 안전성
    pthread_cond_t cond;         // 조건 변수
    
    AudioBackend audio_backend;  // 오디오 백엔드 타입
    AudioState state;            // 현재 재생 상태
    bool is_initialized;         // 초기화 상태
    bool should_stop;            // 정지 플래그
    bool is_looping;             // 루프 재생 여부
    
    char audio_file_path[512];   // 오디오 파일 경로
    pid_t ffplay_pid;            // ffplay 프로세스 ID
    
    // 동기화 관련
    struct timespec start_time;  // 재생 시작 시간
    double duration_sec;         // 총 재생 시간
    
    // 통계 정보
    AudioStats stats;
} AudioManager;

/**
 * @brief 싱글톤 인스턴스 접근 (Thread-Safe)
 * @return AudioManager 싱글톤 인스턴스
 */
AudioManager* audio_manager_get_instance(void);

/**
 * @brief 오디오 매니저 초기화
 * @return 성공 시 ERR_SUCCESS, 실패 시 에러 코드
 */
ErrorCode audio_manager_init(void);

/**
 * @brief 오디오 파일 로드 및 재생 시작
 * @param audio_file 오디오 파일 경로
 * @return 성공 시 ERR_SUCCESS, 실패 시 에러 코드
 */
ErrorCode audio_manager_start_playback(const char* audio_file);

/**
 * @brief 오디오 재생 일시정지
 * @return 성공 시 ERR_SUCCESS, 실패 시 에러 코드
 */
ErrorCode audio_manager_pause(void);

/**
 * @brief 오디오 재생 재개
 * @return 성공 시 ERR_SUCCESS, 실패 시 에러 코드
 */
ErrorCode audio_manager_resume(void);

/**
 * @brief 오디오 재생 정지
 * @return 성공 시 ERR_SUCCESS, 실패 시 에러 코드
 */
ErrorCode audio_manager_stop(void);

/**
 * @brief 오디오 볼륨 설정
 * @param volume 볼륨 (0.0 ~ 1.0)
 * @return 성공 시 ERR_SUCCESS, 실패 시 에러 코드
 */
ErrorCode audio_manager_set_volume(float volume);

/**
 * @brief 루프 재생 설정
 * @param looping 루프 재생 여부
 */
void audio_manager_set_looping(bool looping);

/**
 * @brief 현재 재생 상태 가져오기
 * @return 현재 AudioState
 */
AudioState audio_manager_get_state(void);

/**
 * @brief 현재 재생 위치 가져오기 (초)
 * @return 현재 재생 위치
 */
double audio_manager_get_current_time(void);

/**
 * @brief 총 재생 시간 가져오기 (초)
 * @return 총 재생 시간
 */
double audio_manager_get_duration(void);

/**
 * @brief 재생 완료까지 대기
 * @return 성공 시 ERR_SUCCESS, 실패 시 에러 코드
 */
ErrorCode audio_manager_wait_for_completion(void);

/**
 * @brief 오디오 통계 가져오기
 * @return AudioStats 구조체 복사본
 */
AudioStats audio_manager_get_stats(void);

/**
 * @brief 오디오 매니저 정리 및 해제
 */
void audio_manager_cleanup(void);

/**
 * @brief 오디오 매니저 상태 체크
 * @return 초기화되고 사용 가능하면 true
 */
static inline bool audio_manager_is_ready(void) {
    AudioManager *am = audio_manager_get_instance();
    return am && am->is_initialized;
}

/**
 * @brief 재생 중인지 확인
 * @return 재생 중이면 true
 */
static inline bool audio_manager_is_playing(void) {
    AudioManager *am = audio_manager_get_instance();
    return am && am->state == AUDIO_STATE_PLAYING;
}

/**
 * @brief 재생 진행률 (0.0 ~ 1.0)
 * @return 진행률 (0.0 = 시작, 1.0 = 끝)
 */
static inline double audio_manager_get_progress(void) {
    AudioManager *am = audio_manager_get_instance();
    if (!am || am->duration_sec <= 0) return 0.0;
    double current = audio_manager_get_current_time();
    return current / am->duration_sec;
}

#endif // AUDIO_MANAGER_H
