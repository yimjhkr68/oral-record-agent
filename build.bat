@echo off
echo [1/2] 테스트 온톨로지 정리...
python scripts/cleanup_test_ontologies.py
if %errorlevel% neq 0 (
    echo 정리 스크립트 오류 — 중단
    exit /b %errorlevel%
)

echo.
echo [2/2] Flutter Windows 빌드...
cd flutter && flutter build windows --release
