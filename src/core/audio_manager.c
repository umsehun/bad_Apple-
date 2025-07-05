/**
 * @file audio_manager.c
 * @brief 고성능 오디오 재생 관리 싱글톤 구현부
 * @author BadApple C Team
 * @date 2025-07-05
 */

#include "audio_manager.h"
#include "../utils/file_utils.h"
#include <string.h>
#include <time.h>
#include <signal.h>
#include <sys/wait.h>
#include <unistd.h>

// 싱글톤 인스턴스
static AudioManager g_audio_manager = {0};
static pthread_once_t g_once_control = PTHREAD_ONCE_INIT;

/**
 * @brief 현재 시간 가져오기 (초 단위)
 */
static double get_current_time_sec(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1000000000.0;
}

/**
 * @brief 두 timespec 간의 차이 계산 (초 단위)
 */
static double timespec_diff(const struct timespec *start, const struct timespec *end) {
    return (end->tv_sec - start->tv_sec) + (end->tv_nsec - start->tv_nsec) / 1000000000.0;
}

/**
 * @brief 오디오 백그라운드 스레드 함수
 */
static void* audio_thread_func(void *arg) {
    AudioManager *am = (AudioManager*)arg;
    
    while (!am->should_stop) {
        pthread_mutex_lock(&am->mutex);
        
        if (am->state == AUDIO_STATE_PLAYING) {
            // ffplay 프로세스 상태 확인
            if (am->ffplay_pid > 0) {
                int status;
                pid_t result = waitpid(am->ffplay_pid, &status, WNOHANG);
                
                if (result > 0) {
                    // 프로세스가 종료됨
                    if (am->is_looping) {
                        // 루프 재생인 경우 재시작
                        pthread_mutex_unlock(&am->mutex);
                        audio_manager_start_playback(am->audio_file_path);
                        continue;
                    } else {
                        // 일반 재생 완료
                        am->state = AUDIO_STATE_STOPPED;
                        am->ffplay_pid = 0;
                    }
                } else if (result < 0) {
                    // 에러 발생
                    am->state = AUDIO_STATE_ERROR;
                    am->ffplay_pid = 0;
                }
            }
        }
        
        pthread_cond_broadcast(&am->cond);
        pthread_mutex_unlock(&am->mutex);
        
        // 10ms 대기
        usleep(10000);
    }
    
    return NULL;
}

/**
 * @brief 싱글톤 초기화 (한 번만 실행)
 */
static void init_audio_manager_once(void) {
    memset(&g_audio_manager, 0, sizeof(AudioManager));
    
    // 뮤텍스와 조건 변수 초기화
    pthread_mutex_init(&g_audio_manager.mutex, NULL);
    pthread_cond_init(&g_audio_manager.cond, NULL);
    
    g_audio_manager.state = AUDIO_STATE_STOPPED;
    g_audio_manager.is_initialized = false;
    g_audio_manager.should_stop = false;
    g_audio_manager.is_looping = false;
    g_audio_manager.ffplay_pid = 0;
}

AudioManager* audio_manager_get_instance(void) {
    pthread_once(&g_once_control, init_audio_manager_once);
    return &g_audio_manager;
}

ErrorCode audio_manager_init(void) {
    AudioManager *am = audio_manager_get_instance();
    pthread_mutex_lock(&am->mutex);
    
    if (am->is_initialized) {
        pthread_mutex_unlock(&am->mutex);
        return ERR_SUCCESS;
    }
    
    // 백그라운드 스레드 시작
    if (pthread_create(&am->audio_thread, NULL, audio_thread_func, am) != 0) {
        pthread_mutex_unlock(&am->mutex);
        error_log(ERR_THREAD_CREATE, __FUNCTION__, __LINE__, "Failed to create audio thread");
        return ERR_THREAD_CREATE;
    }
    
    am->is_initialized = true;
    pthread_mutex_unlock(&am->mutex);
    
    return ERR_SUCCESS;
}

ErrorCode audio_manager_start_playback(const char* audio_file) {
    CHECK_PTR(audio_file, ERR_INVALID_PARAM);
    
    AudioManager *am = audio_manager_get_instance();
    if (!am->is_initialized) {
        return ERR_AUDIO_INIT;
    }
    
    pthread_mutex_lock(&am->mutex);
    
    // 기존 재생 중단
    if (am->ffplay_pid > 0) {
        kill(am->ffplay_pid, SIGTERM);
        waitpid(am->ffplay_pid, NULL, 0);
        am->ffplay_pid = 0;
    }
    
    // 파일 존재 확인
    if (!file_exists(audio_file)) {
        pthread_mutex_unlock(&am->mutex);
        error_log(ERR_FILE_OPEN, __FUNCTION__, __LINE__, "Audio file not found");
        return ERR_FILE_OPEN;
    }
    
    // 오디오 파일 경로 저장
    strncpy(am->audio_file_path, audio_file, sizeof(am->audio_file_path) - 1);
    am->audio_file_path[sizeof(am->audio_file_path) - 1] = '\0';
    
    // ffplay 프로세스 시작
    pid_t pid = fork();
    if (pid == 0) {
        // 자식 프로세스: ffplay 실행
        const char *args[] = {
            "ffplay",
            "-nodisp",           // 비디오 디스플레이 비활성화
            "-autoexit",         // 재생 완료 시 자동 종료
            "-loglevel", "quiet", // 로그 출력 최소화
            audio_file,
            NULL
        };
        
        // 표준 출력/에러 리다이렉트
        freopen("/dev/null", "w", stdout);
        freopen("/dev/null", "w", stderr);
        
        execvp("ffplay", (char* const*)args);
        
        // execvp 실패 시
        _exit(127);
    } else if (pid > 0) {
        // 부모 프로세스
        am->ffplay_pid = pid;
        am->state = AUDIO_STATE_PLAYING;
        clock_gettime(CLOCK_MONOTONIC, &am->start_time);
        
        // 통계 초기화
        memset(&am->stats, 0, sizeof(AudioStats));
        am->stats.is_synchronized = true;
    } else {
        // fork 실패
        pthread_mutex_unlock(&am->mutex);
        error_log(ERR_AUDIO_INIT, __FUNCTION__, __LINE__, "Failed to fork ffplay process");
        return ERR_AUDIO_INIT;
    }
    
    pthread_mutex_unlock(&am->mutex);
    return ERR_SUCCESS;
}

ErrorCode audio_manager_pause(void) {
    AudioManager *am = audio_manager_get_instance();
    if (!am->is_initialized) {
        return ERR_AUDIO_INIT;
    }
    
    pthread_mutex_lock(&am->mutex);
    
    if (am->state == AUDIO_STATE_PLAYING && am->ffplay_pid > 0) {
        // SIGSTOP을 보내서 일시정지
        if (kill(am->ffplay_pid, SIGSTOP) == 0) {
            am->state = AUDIO_STATE_PAUSED;
        } else {
            am->state = AUDIO_STATE_ERROR;
        }
    }
    
    pthread_mutex_unlock(&am->mutex);
    return ERR_SUCCESS;
}

ErrorCode audio_manager_resume(void) {
    AudioManager *am = audio_manager_get_instance();
    if (!am->is_initialized) {
        return ERR_AUDIO_INIT;
    }
    
    pthread_mutex_lock(&am->mutex);
    
    if (am->state == AUDIO_STATE_PAUSED && am->ffplay_pid > 0) {
        // SIGCONT를 보내서 재개
        if (kill(am->ffplay_pid, SIGCONT) == 0) {
            am->state = AUDIO_STATE_PLAYING;
        } else {
            am->state = AUDIO_STATE_ERROR;
        }
    }
    
    pthread_mutex_unlock(&am->mutex);
    return ERR_SUCCESS;
}

ErrorCode audio_manager_stop(void) {
    AudioManager *am = audio_manager_get_instance();
    if (!am->is_initialized) {
        return ERR_AUDIO_INIT;
    }
    
    pthread_mutex_lock(&am->mutex);
    
    if (am->ffplay_pid > 0) {
        kill(am->ffplay_pid, SIGTERM);
        waitpid(am->ffplay_pid, NULL, 0);
        am->ffplay_pid = 0;
    }
    
    am->state = AUDIO_STATE_STOPPED;
    
    pthread_mutex_unlock(&am->mutex);
    return ERR_SUCCESS;
}

ErrorCode audio_manager_set_volume(float volume) {
    (void)volume; // ffplay의 볼륨 제어는 복잡하므로 향후 구현
    return ERR_SUCCESS;
}

void audio_manager_set_looping(bool looping) {
    AudioManager *am = audio_manager_get_instance();
    pthread_mutex_lock(&am->mutex);
    am->is_looping = looping;
    pthread_mutex_unlock(&am->mutex);
}

AudioState audio_manager_get_state(void) {
    AudioManager *am = audio_manager_get_instance();
    pthread_mutex_lock(&am->mutex);
    AudioState state = am->state;
    pthread_mutex_unlock(&am->mutex);
    return state;
}

double audio_manager_get_current_time(void) {
    AudioManager *am = audio_manager_get_instance();
    if (!am->is_initialized || am->state != AUDIO_STATE_PLAYING) {
        return 0.0;
    }
    
    struct timespec current_time;
    clock_gettime(CLOCK_MONOTONIC, &current_time);
    
    pthread_mutex_lock(&am->mutex);
    double elapsed = timespec_diff(&am->start_time, &current_time);
    pthread_mutex_unlock(&am->mutex);
    
    return elapsed;
}

double audio_manager_get_duration(void) {
    AudioManager *am = audio_manager_get_instance();
    pthread_mutex_lock(&am->mutex);
    double duration = am->duration_sec;
    pthread_mutex_unlock(&am->mutex);
    return duration;
}

ErrorCode audio_manager_wait_for_completion(void) {
    AudioManager *am = audio_manager_get_instance();
    if (!am->is_initialized) {
        return ERR_AUDIO_INIT;
    }
    
    pthread_mutex_lock(&am->mutex);
    
    while (am->state == AUDIO_STATE_PLAYING && !am->should_stop) {
        pthread_cond_wait(&am->cond, &am->mutex);
    }
    
    pthread_mutex_unlock(&am->mutex);
    return ERR_SUCCESS;
}

AudioStats audio_manager_get_stats(void) {
    AudioManager *am = audio_manager_get_instance();
    pthread_mutex_lock(&am->mutex);
    AudioStats stats = am->stats;
    pthread_mutex_unlock(&am->mutex);
    return stats;
}

void audio_manager_cleanup(void) {
    AudioManager *am = audio_manager_get_instance();
    pthread_mutex_lock(&am->mutex);
    
    // 정지 플래그 설정
    am->should_stop = true;
    
    // ffplay 프로세스 종료
    if (am->ffplay_pid > 0) {
        kill(am->ffplay_pid, SIGTERM);
        waitpid(am->ffplay_pid, NULL, 0);
        am->ffplay_pid = 0;
    }
    
    am->state = AUDIO_STATE_STOPPED;
    am->is_initialized = false;
    
    pthread_cond_broadcast(&am->cond);
    pthread_mutex_unlock(&am->mutex);
    
    // 스레드 종료 대기
    if (am->audio_thread) {
        pthread_join(am->audio_thread, NULL);
    }
    
    // 뮤텍스와 조건 변수 해제
    pthread_mutex_destroy(&am->mutex);
    pthread_cond_destroy(&am->cond);
}
