# VS Code와 Claude Code를 완전히 종료한 후 이 스크립트를 실행하세요
# 실행: powershell -ExecutionPolicy Bypass -File "E:\Oral-record-agent\rename_to_v2.ps1"

$src = "E:\Oral-record-agent"
$dst = "E:\Oral-record-agent_v2.0"

if (Test-Path $src) {
    Rename-Item -Path $src -NewName "Oral-record-agent_v2.0"
    Write-Host "완료: $src -> $dst" -ForegroundColor Green
} else {
    Write-Host "이미 변경됨 또는 폴더 없음: $src" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== E 드라이브 Oral 폴더 목록 ===" -ForegroundColor Cyan
Get-ChildItem E:\ | Where-Object { $_.Name -match "oral" -or $_.Name -match "Oral" } | Select-Object Name
