# Bad Apple PowerShell Player
param(
    [string]$Mode = "ascii",
    [int]$FPS = 120
)

Write-Host "🍎 Bad Apple PowerShell Player" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Yellow

# 콘솔 설정
$Host.UI.RawUI.WindowTitle = "Bad Apple - PowerShell Edition"

# 프레임 디렉토리 확인
$FramesDir = Join-Path $PSScriptRoot "assets\ascii_frames"
if (-not (Test-Path $FramesDir)) {
    Write-Host "❌ 프레임 디렉토리를 찾을 수 없습니다: $FramesDir" -ForegroundColor Red
    Write-Host "💡 먼저 프레임을 생성해주세요." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# 프레임 파일 로드
$Frames = Get-ChildItem -Path $FramesDir -Filter "*.txt" | Sort-Object Name

Write-Host "📁 프레임 디렉토리: $FramesDir" -ForegroundColor Cyan
Write-Host "🎬 총 프레임 수: $($Frames.Count)" -ForegroundColor Cyan
Write-Host "⚡ FPS: $FPS" -ForegroundColor Cyan
Write-Host ""
Write-Host "⏰ 3초 후 재생 시작... (Ctrl+C로 중지)" -ForegroundColor Green

Start-Sleep -Seconds 3

# 재생 시작
$FrameDelay = [math]::Round(1000 / $FPS)

try {
    foreach ($Frame in $Frames) {
        Clear-Host
        $Content = Get-Content $Frame.FullName -Raw
        Write-Host $Content
        Start-Sleep -Milliseconds $FrameDelay
    }
    
    Clear-Host
    Write-Host "🎭 Bad Apple 재생 완료!" -ForegroundColor Green
} catch {
    Write-Host "⚠️ 재생이 중단되었습니다." -ForegroundColor Yellow
}

Write-Host ""
Read-Host "Press Enter to exit"
