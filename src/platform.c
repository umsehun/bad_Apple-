/**
 * @file platform.c
 * @brief 크로스 플랫폼 감지 및 터미널 환경 분석 유틸리티
 * @author BadApple C Team
 * @date 2025-08-04
 * @version 1.0
 *
 * OS, 터미널, 셸 환경을 감지하여 최적화된 설정을 제공합니다.
 * 일회성 실행으로 플랫폼 정보를 JSON 형태로 출력합니다.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/utsname.h>
#include <sys/ioctl.h>
#include <termios.h>
#include <time.h>

#ifdef __APPLE__
#include <sys/sysctl.h>
#endif

#ifdef __linux__
#include <sys/sysinfo.h>
#endif

// AsciiStream 플랫폼 정보 구조체
typedef struct
{
    char os_name[64];       // 운영체제 이름
    char os_version[64];    // OS 버전
    char arch[32];          // 아키텍처 (x86_64, arm64 등)
    char terminal[64];      // 터미널 프로그램 (Terminal.app, iTerm2, PowerShell 등)
    char shell[64];         // 셸 종류 (bash, zsh, powershell 등)
    int terminal_width;     // 터미널 너비
    int terminal_height;    // 터미널 높이
    int supports_ansi;      // ANSI 색상 지원
    int supports_truecolor; // 24비트 트루컬러 지원
    int supports_kitty;     // Kitty 그래픽 프로토콜 지원
    int supports_sixel;     // Sixel 그래픽 지원
    int cpu_cores;          // CPU 코어 수
    long memory_mb;         // 메모리 크기 (MB)
    char cache_path[256];   // 캐시 파일 경로
} AsciiStreamPlatformInfo;

/**
 * @brief 운영체제 정보 감지
 */
static void detect_os_info(AsciiStreamPlatformInfo *info)
{
    struct utsname uname_info;
    if (uname(&uname_info) == 0)
    {
        strncpy(info->os_name, uname_info.sysname, sizeof(info->os_name) - 1);
        strncpy(info->os_version, uname_info.release, sizeof(info->os_version) - 1);
        strncpy(info->arch, uname_info.machine, sizeof(info->arch) - 1);
    }
    else
    {
        strcpy(info->os_name, "Unknown");
        strcpy(info->os_version, "Unknown");
        strcpy(info->arch, "Unknown");
    }

// macOS 추가 정보
#ifdef __APPLE__
    char buffer[256];
    size_t size = sizeof(buffer);
    if (sysctlbyname("kern.version", buffer, &size, NULL, 0) == 0)
    {
        // macOS 버전 파싱
        if (strstr(buffer, "Darwin"))
        {
            strcpy(info->os_name, "macOS");
        }
    }
#endif
}

/**
 * @brief 터미널 프로그램 감지
 */
static void detect_terminal(AsciiStreamPlatformInfo *info)
{
    const char *term_program = getenv("TERM_PROGRAM");
    const char *term = getenv("TERM");
    const char *ssh_client = getenv("SSH_CLIENT");
    const char *wt_session = getenv("WT_SESSION"); // Windows Terminal
    const char *powershell = getenv("POWERSHELL_DISTRIBUTION_CHANNEL");

    // Windows 특화 환경변수들
    const char *conemu_pid = getenv("ConEmuPID");       // ConEmu
    const char *msystem = getenv("MSYSTEM");            // Git Bash/MSYS2
    const char *cygwin = getenv("CYGWIN");              // Cygwin
    const char *wsl_distro = getenv("WSL_DISTRO_NAME"); // WSL

    // Windows PowerShell 감지
    if (powershell)
    {
        strcpy(info->terminal, "PowerShell");
    }
    // Windows Terminal 감지
    else if (wt_session)
    {
        strcpy(info->terminal, "Windows Terminal");
    }
    // ConEmu 감지
    else if (conemu_pid)
    {
        strcpy(info->terminal, "ConEmu");
    }
    // WSL 감지
    else if (wsl_distro)
    {
        snprintf(info->terminal, sizeof(info->terminal), "WSL (%s)", wsl_distro);
    }
    // Git Bash/MSYS2 감지
    else if (msystem)
    {
        if (strcmp(msystem, "MINGW64") == 0 || strcmp(msystem, "MINGW32") == 0)
        {
            strcpy(info->terminal, "Git Bash");
        }
        else
        {
            strcpy(info->terminal, "MSYS2");
        }
    }
    // Cygwin 감지
    else if (cygwin)
    {
        strcpy(info->terminal, "Cygwin");
    }
    // macOS/Linux 터미널 감지
    else if (term_program)
    {
        if (strcmp(term_program, "Apple_Terminal") == 0)
        {
            strcpy(info->terminal, "Terminal.app");
        }
        else if (strcmp(term_program, "iTerm.app") == 0)
        {
            strcpy(info->terminal, "iTerm2");
        }
        else if (strcmp(term_program, "vscode") == 0)
        {
            strcpy(info->terminal, "VS Code Terminal");
        }
        else
        {
            strncpy(info->terminal, term_program, sizeof(info->terminal) - 1);
        }
    }
    // SSH 세션 감지
    else if (ssh_client)
    {
        strcpy(info->terminal, "SSH Session");
    }
    // TERM 환경변수 기반 감지
    else if (term)
    {
        if (strstr(term, "kitty"))
        {
            strcpy(info->terminal, "Kitty");
        }
        else if (strstr(term, "tmux"))
        {
            strcpy(info->terminal, "tmux");
        }
        else if (strstr(term, "screen"))
        {
            strcpy(info->terminal, "GNU Screen");
        }
        else
        {
            strncpy(info->terminal, term, sizeof(info->terminal) - 1);
        }
    }
    else
    {
        strcpy(info->terminal, "Unknown");
    }
}

/**
 * @brief 셸 감지
 */
static void detect_shell(AsciiStreamPlatformInfo *info)
{
    const char *shell = getenv("SHELL");
    const char *powershell = getenv("POWERSHELL_DISTRIBUTION_CHANNEL");

    if (powershell)
    {
        strcpy(info->shell, "powershell");
    }
    else if (shell)
    {
        const char *shell_name = strrchr(shell, '/');
        if (shell_name)
        {
            shell_name++; // '/' 다음 문자부터
        }
        else
        {
            shell_name = shell;
        }
        strncpy(info->shell, shell_name, sizeof(info->shell) - 1);
    }
    else
    {
        strcpy(info->shell, "unknown");
    }
}

/**
 * @brief 색상 및 그래픽 지원 감지
 */
static void detect_graphics_support(AsciiStreamPlatformInfo *info)
{
    const char *term = getenv("TERM");
    const char *colorterm = getenv("COLORTERM");
    const char *term_program = getenv("TERM_PROGRAM");

    // 기본값
    info->supports_ansi = 1; // 대부분의 현대 터미널은 ANSI 지원
    info->supports_truecolor = 0;
    info->supports_kitty = 0;
    info->supports_sixel = 0;

    // 24비트 트루컬러 지원 감지
    if (colorterm && (strstr(colorterm, "truecolor") || strstr(colorterm, "24bit")))
    {
        info->supports_truecolor = 1;
    }

    // 터미널별 특별한 기능 감지
    if (term_program)
    {
        if (strcmp(term_program, "iTerm.app") == 0)
        {
            info->supports_truecolor = 1;
            info->supports_sixel = 1; // iTerm2는 Sixel 지원
        }
    }

    if (term && strstr(term, "kitty"))
    {
        info->supports_truecolor = 1;
        info->supports_kitty = 1; // Kitty 그래픽 프로토콜
    }

    if (term && strstr(term, "256color"))
    {
        info->supports_ansi = 1;
    }
}

/**
 * @brief 터미널 크기 감지
 */
static void detect_terminal_size(AsciiStreamPlatformInfo *info)
{
    struct winsize w;
    int fd = STDOUT_FILENO;

    // STDOUT이 터미널이 아니면 STDERR로 시도
    if (!isatty(fd))
    {
        fd = STDERR_FILENO;
    }

    if (ioctl(fd, TIOCGWINSZ, &w) == 0 && w.ws_col > 0 && w.ws_row > 0)
    {
        info->terminal_width = w.ws_col;
        info->terminal_height = w.ws_row;
    }
    else
    {
        // 터미널 크기 감지 실패 시 fallback
        info->terminal_width = 80;
        info->terminal_height = 24;
    }
}

/**
 * @brief 시스템 리소스 정보 감지
 */
static void detect_system_resources(AsciiStreamPlatformInfo *info)
{
// CPU 코어 수 감지
#ifdef __APPLE__
    size_t size = sizeof(info->cpu_cores);
    if (sysctlbyname("hw.ncpu", &info->cpu_cores, &size, NULL, 0) != 0)
    {
        info->cpu_cores = 1;
    }

    // 메모리 크기 감지 (macOS)
    int64_t memsize;
    size = sizeof(memsize);
    if (sysctlbyname("hw.memsize", &memsize, &size, NULL, 0) == 0)
    {
        info->memory_mb = memsize / (1024 * 1024);
    }
    else
    {
        info->memory_mb = 0;
    }
#elif defined(__linux__)
    info->cpu_cores = sysconf(_SC_NPROCESSORS_ONLN);

    struct sysinfo si;
    if (sysinfo(&si) == 0)
    {
        info->memory_mb = (si.totalram * si.mem_unit) / (1024 * 1024);
    }
    else
    {
        info->memory_mb = 0;
    }
#else
    info->cpu_cores = 1;
    info->memory_mb = 0;
#endif

    if (info->cpu_cores <= 0)
        info->cpu_cores = 1;
}

/**
 * @brief 캐시 파일 경로 설정
 */
static void setup_cache_path(AsciiStreamPlatformInfo *info)
{
    const char *home = getenv("HOME");
    if (!home)
        home = "/tmp";

    snprintf(info->cache_path, sizeof(info->cache_path),
             "%s/.badapple_platform_cache", home);
}

/**
 * @brief 플랫폼 정보를 JSON 형태로 출력
 */
static void print_platform_json(const AsciiStreamPlatformInfo *info)
{
    printf("{\n");
    printf("  \"os_name\": \"%s\",\n", info->os_name);
    printf("  \"os_version\": \"%s\",\n", info->os_version);
    printf("  \"arch\": \"%s\",\n", info->arch);
    printf("  \"terminal\": \"%s\",\n", info->terminal);
    printf("  \"shell\": \"%s\",\n", info->shell);
    printf("  \"terminal_width\": %d,\n", info->terminal_width);
    printf("  \"terminal_height\": %d,\n", info->terminal_height);
    printf("  \"supports_ansi\": %s,\n", info->supports_ansi ? "true" : "false");
    printf("  \"supports_truecolor\": %s,\n", info->supports_truecolor ? "true" : "false");
    printf("  \"supports_kitty\": %s,\n", info->supports_kitty ? "true" : "false");
    printf("  \"supports_sixel\": %s,\n", info->supports_sixel ? "true" : "false");
    printf("  \"cpu_cores\": %d,\n", info->cpu_cores);
    printf("  \"memory_mb\": %ld,\n", info->memory_mb);
    printf("  \"cache_path\": \"%s\",\n", info->cache_path);
    printf("  \"detected_at\": %ld\n", time(NULL));
    printf("}\n");
}
/**
 * @brief 캐시에서 플랫폼 정보 로드
 */
static int load_from_cache(AsciiStreamPlatformInfo *info)
{
    FILE *cache = fopen(info->cache_path, "r");
    if (!cache)
        return 0;

    char line[1024];
    time_t cache_time = 0;
    // 캐시 파일이 24시간 이내에 생성되었는지 확인
    while (fgets(line, sizeof(line), cache))
    {
        if (strstr(line, "\"detected_at\":"))
        {
            sscanf(line, "  \"detected_at\": %ld", &cache_time);
            break;
        }
    }

    time_t now = time(NULL);
    if (now - cache_time > 86400)
    { // 24시간 후 캐시 만료
        fclose(cache);
        return 0;
    }

    // 캐시 파일 전체 내용 출력
    rewind(cache);
    while (fgets(line, sizeof(line), cache))
    {
        printf("%s", line);
    }

    fclose(cache);
    return 1;
}

/**
 * @brief 플랫폼 정보를 캐시에 저장
 */
static void save_to_cache(const AsciiStreamPlatformInfo *info)
{
    FILE *cache = fopen(info->cache_path, "w");
    if (!cache)
        return;

    fprintf(cache, "{\n");
    fprintf(cache, "  \"os_name\": \"%s\",\n", info->os_name);
    fprintf(cache, "  \"os_version\": \"%s\",\n", info->os_version);
    fprintf(cache, "  \"arch\": \"%s\",\n", info->arch);
    fprintf(cache, "  \"terminal\": \"%s\",\n", info->terminal);
    fprintf(cache, "  \"shell\": \"%s\",\n", info->shell);
    fprintf(cache, "  \"terminal_width\": %d,\n", info->terminal_width);
    fprintf(cache, "  \"terminal_height\": %d,\n", info->terminal_height);
    fprintf(cache, "  \"supports_ansi\": %s,\n", info->supports_ansi ? "true" : "false");
    fprintf(cache, "  \"supports_truecolor\": %s,\n", info->supports_truecolor ? "true" : "false");
    fprintf(cache, "  \"supports_kitty\": %s,\n", info->supports_kitty ? "true" : "false");
    fprintf(cache, "  \"supports_sixel\": %s,\n", info->supports_sixel ? "true" : "false");
    fprintf(cache, "  \"cpu_cores\": %d,\n", info->cpu_cores);
    fprintf(cache, "  \"memory_mb\": %ld,\n", info->memory_mb);
    fprintf(cache, "  \"cache_path\": \"%s\",\n", info->cache_path);
    fprintf(cache, "  \"detected_at\": %ld\n", time(NULL));
    fprintf(cache, "}\n");

    fclose(cache);
}

/**
 * @brief 도움말 출력
 */
static void print_usage(const char *program_name)
{
    printf("Usage: %s [OPTIONS]\n", program_name);
    printf("  --no-cache    Force fresh detection (ignore cache)\n");
    printf("  --clear-cache Clear existing cache file\n");
    printf("  --help        Show this help message\n");
    printf("\nOutput: JSON format platform information\n");
}

/**
 * @brief 메인 함수
 */
int main(int argc, char *argv[])
{
    AsciiStreamPlatformInfo info = {0};
    int use_cache = 1;
    int clear_cache = 0;

    // 명령행 인수 처리
    for (int i = 1; i < argc; i++)
    {
        if (strcmp(argv[i], "--no-cache") == 0)
        {
            use_cache = 0;
        }
        else if (strcmp(argv[i], "--clear-cache") == 0)
        {
            clear_cache = 1;
        }
        else if (strcmp(argv[i], "--help") == 0)
        {
            print_usage(argv[0]);
            return 0;
        }
    }

    // 캐시 경로 설정
    setup_cache_path(&info);

    // 캐시 삭제 요청 처리
    if (clear_cache)
    {
        remove(info.cache_path);
        printf("{\"status\": \"cache_cleared\"}\n");
        return 0;
    }

    // 캐시에서 로드 시도
    if (use_cache && load_from_cache(&info))
    {
        return 0; // 캐시에서 성공적으로 로드
    }

    // 새로운 플랫폼 정보 감지
    detect_os_info(&info);
    detect_terminal(&info);
    detect_shell(&info);
    detect_terminal_size(&info);
    detect_graphics_support(&info);
    detect_system_resources(&info);

    // 결과 출력
    print_platform_json(&info);

    // 캐시에 저장
    if (use_cache)
    {
        save_to_cache(&info);
    }

    return 0;
}
