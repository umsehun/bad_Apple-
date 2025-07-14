/**
 * @file audio_manager.c
 * @brief 고성능 오디오 재생 관리 싱글톤 구현부
 * @author BadApple C Team
 * @date 2025-07-05
 */

#ifndef AUDIO_MANAGER_H
#define AUDIO_MANAGER_H

#include <pthread.h>
#include <stdbool.h>
#include <sys/types.h>
 #include <time.h>
 #include <signal.h>
 #include <sys/wait.h>
 #include <unistd.h>
#include "../utils/error_handler.h"
#include "../utils/file_utils.h"

// 오디오 상태 열거형
typedef enum {
    AUDIO_STATE_STOPPED = 0,
    AUDIO_STATE_PLAYING,
    AUDIO_STATE_PAUSED,
    AUDIO_STATE_ERROR
} AudioState;
// 오디오 백엔드 종류
typedef enum {
    AUDIO_BACKEND_FFPLAY = 0,
    AUDIO_BACKEND_SYSTEM
} AudioBackend;

// 오디오 통계 구조체
typedef struct {
    double playback_duration_ms;
    int restart_count;
    bool sync_enabled;
} AudioStats;

// 오디오 매니저 싱글톤 구조체
typedef struct {
    pthread_t audio_thread;             // 오디오 스레드 핸들
    pthread_mutex_t mutex;              // 상태 보호용 뮤텍스
    pthread_cond_t cond;                // 상태 변경 알림용 조건 변수
    bool is_initialized;                // 초기화 완료 여부
    bool should_stop;                   // 정지 플래그
    AudioState state;                   // 현재 오디오 재생 상태
    bool is_looping;                    // 반복 재생 여부
    pid_t ffplay_pid;                   // ffplay 프로세스 PID
    struct timespec start_time;         // 재생 시작 시각
    double duration_sec;                // 재생 총 길이(초)
    AudioStats stats;                   // 성능/상태 통계 정보
    char audio_file_path[512];          // 재생 파일 경로
} AudioManager;

// 싱글톤 인스턴스 가져오기
AudioManager* audio_manager_get_instance(void);

// 오디오 매니저 초기화
ErrorCode audio_manager_init(void);

// 오디오 파일 재생 시작
ErrorCode audio_manager_start_playback(const char* audio_file);

// 오디오 일시정지
ErrorCode audio_manager_pause(void);

// 오디오 재개
ErrorCode audio_manager_resume(void);

// 오디오 정지
ErrorCode audio_manager_stop(void);

// 볼륨 설정 (미구현)
ErrorCode audio_manager_set_volume(float volume);

// 반복 재생 설정
void audio_manager_set_looping(bool looping);

// 재생 상태 조회
AudioState audio_manager_get_state(void);

// 현재 재생 시간 조회 (초)
double audio_manager_get_current_time(void);

// 전체 재생 길이 조회 (초)
double audio_manager_get_duration(void);

// 재생 완료 대기
ErrorCode audio_manager_wait_for_completion(void);

// 통계 정보 조회
AudioStats audio_manager_get_stats(void);

// 리소스 정리 및 스레드 종료
void audio_manager_cleanup(void);

#endif // AUDIO_MANAGER_H