# Bad Apple for Windows

Windows용 Bad Apple ASCII 애니메이션 플레이어입니다.

## 시스템 요구사항

- Windows 7 이상
- Git Bash, WSL, MSYS2, 또는 Cygwin
- 최소 4GB RAM
- 터미널 크기: 80x24 이상 권장

## 설치 및 실행

### 1. 압축 해제
배포 패키지를 적절한 위치에 압축 해제합니다.

### 2. Windows용 플레이어 실행
```bash
# Git Bash, WSL, MSYS2에서:
./wplay.sh

# 또는 기본 플레이어:
./play.sh
```

### 3. PowerShell에서 실행 (네이티브)
```powershell
# PowerShell 7+ 또는 Windows PowerShell 5.1에서:
.\badapple.ps1
```

## 지원 환경

- ✅ WSL (Windows Subsystem for Linux)
- ✅ MSYS2
- ✅ Git Bash
- ✅ Cygwin
- ✅ PowerShell 5.1+
- ✅ PowerShell Core 7+

## 트러블슈팅

### 실행 권한 오류
```bash
chmod +x *.sh
```

### 컴파일러 오류
1. MSYS2 설치: https://www.msys2.org/
2. 빌드 도구 설치:
```bash
pacman -S mingw-w64-x86_64-gcc make
```

### 터미널 크기 문제
Windows Terminal 또는 ConEmu 사용을 권장합니다.

## 추가 정보

- 프로젝트 홈페이지: https://github.com/your-repo/bad-apple
- 이슈 리포트: https://github.com/your-repo/bad-apple/issues

