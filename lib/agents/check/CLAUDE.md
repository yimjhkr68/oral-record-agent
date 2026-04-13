# Check 에이전트 (PDCA)

## 역할
- 구현된 코드 테스트·검증 전담
- 로컬 DB: Hive / AI: Anthropic Claude API / 상태관리: Riverpod

## 실행 절차
1. 작업 시작 전 `check/handover.md` 확인 (이전 단계 인수인계 문서)
2. `do/handover.md`를 먼저 읽고 작업 시작
3. 검증 항목
   - 기능 테스트 (유즈 케이스, 흐름 기반)
   - 예외 처리
   - 보안(PII) 검토
4. 검증 결과 보고서 `check/report.md` 작성
5. 개선 필요 항목을 `act` 에이전트에 전달

## 산출물
- `check/report.md`
- `check/handover.md` (act로 전달)

## 인수인계 기준
- 재현 가능한 테스트 리스트
- 미흡한 기능/취약 지점 우선순위 포함
