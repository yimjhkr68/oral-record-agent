# 개발 환경 시작 스크립트
# 1. CORS 프록시 서버를 백그라운드에서 시작
# 2. Flutter Web 앱을 Chrome에서 실행
#
# 사용법: powershell -ExecutionPolicy Bypass -File scripts\start_dev.ps1

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

Write-Host ""
Write-Host "=== 구술기록관리 앱 개발 환경 시작 ===" -ForegroundColor Cyan
Write-Host ""

# 기존 프록시 프로세스 정리
$existingProxy = Get-Process -Name "dart" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like "*proxy_server*" }
if ($existingProxy) {
    Write-Host "기존 프록시 프로세스 종료 중..." -ForegroundColor Yellow
    $existingProxy | Stop-Process -Force
}

# 1. CORS 프록시 서버 시작 (새 창)
Write-Host "1. CORS 프록시 서버 시작 (포트 8080)..." -ForegroundColor Green
$proxyProcess = Start-Process powershell -ArgumentList @(
    "-NoExit",
    "-Command",
    "Set-Location '$projectRoot'; dart run bin/proxy_server.dart"
) -PassThru

# 프록시가 뜰 때까지 대기
Write-Host "   프록시 초기화 대기 중..." -ForegroundColor Gray
Start-Sleep -Seconds 3

# 헬스체크
try {
    $health = Invoke-RestMethod -Uri "http://localhost:8080/health" -TimeoutSec 3
    Write-Host "   프록시 상태: OK (포트 $($health.port))" -ForegroundColor Green
} catch {
    Write-Host "   경고: 프록시 헬스체크 실패 - 수동으로 확인하세요" -ForegroundColor Yellow
}

# 2. Flutter Web 실행
Write-Host ""
Write-Host "2. Flutter Web (Chrome) 시작..." -ForegroundColor Green
Write-Host ""
flutter run -d chrome

# 종료 시 프록시도 같이 종료
Write-Host ""
Write-Host "Flutter 앱 종료됨. 프록시 서버 종료 중..." -ForegroundColor Yellow
if ($proxyProcess -and !$proxyProcess.HasExited) {
    Stop-Process -Id $proxyProcess.Id -Force -ErrorAction SilentlyContinue
}
Write-Host "완료." -ForegroundColor Green
