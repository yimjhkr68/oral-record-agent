# CLAUDE 오케스트레이터 — 구술기록관리 에이전트

이 파일은 Claude가 사람 개입 없이 PDCA 루프를 자율 실행하는 오케스트레이터로 동작하기 위한
규칙과 완료 기준을 정의한다. 대화가 시작되면 즉시 현재 단계를 파악하고 자율 실행을 시작한다.

---

## 자동 순환 구조

```
Plan ──완료조건 달성──▶ Do ──완료조건 달성──▶ Check ──완료조건 달성──▶ Act
 ▲                                                                       │
 │                품질기준 미달 (자동 재순환)                              │
 └───────────────────────────────────────────────────────────────────────┘
                                    │ 품질기준 달성
                                    ▼
                              최종 완료 보고
```

각 단계 완료 조건을 모두 충족하면 사람 승인 없이 즉시 다음 단계로 진행한다.

---

## Plan 완료 조건

| # | 조건 | 판정 방법 |
|---|------|-----------|
| P1 | 모든 설계 문서 작성 완료 | `plan/` 디렉터리 파일 존재 확인 |
| P2 | 데이터 모델 정의 완료 | `plan/data_model.md` 존재 |
| P3 | UI 설계 완료 | `plan/ui_design.md` 존재 |
| P4 | handover.md 작성 완료 | `plan/handover.md` 존재 및 Do 지시사항 포함 |
| P5 | 자율 점검 체크리스트 100% | 파일 내 모든 항목 `[x]` |

전부 충족 → 자동으로 **Do** 시작.

---

## Do 완료 조건

| # | 조건 | 판정 명령 |
|---|------|-----------|
| D1 | 정적 분석 오류 0 | `flutter analyze` → error 0 |
| D2 | 테스트 실패 0 | `flutter test` → 0 failed |
| D3 | 모든 화면 구현 완료 | 라우트 정의 파일 vs 실제 파일 비교 |
| D4 | handover.md 작성 완료 | `do/handover.md` 존재 및 Check 지시사항 포함 |

전부 충족 → 자동으로 **Check** 시작.

---

## Check 완료 조건

| # | 조건 | 판정 방법 |
|---|------|-----------|
| C1 | `flutter analyze` error 0, warning 0 | 명령 실행 |
| C2 | `flutter test` 통과율 100% | 명령 실행 |
| C3 | 전 화면 실행 테스트 통과 | 코드 정적 분석으로 각 화면 구현 검증 |
| C4 | 버튼/화면이동/데이터흐름 검증 완료 | 각 페이지 Navigator/GoRouter 호출 추적 |
| C5 | report.md 작성 완료 | `check/report.md` 존재 및 발견 문제 목록 포함 |

전부 충족 → 자동으로 **Act** 시작.

---

## Act 완료 조건

| # | 조건 | 판정 방법 |
|---|------|-----------|
| A1 | Check에서 발견한 모든 문제 수정 | `check/report.md` 문제 목록 vs 수정 이력 대조 |
| A2 | 수정 후 `flutter analyze` 재통과 | 명령 실행 |
| A3 | 수정 후 `flutter test` 재통과 | 명령 실행 |
| A4 | 품질 기준 달성 여부 판단 | 아래 품질 기준 항목 전부 평가 |

- **품질 기준 달성** → 최종 완료 보고 후 루프 종료
- **품질 기준 미달** → 자동으로 **Plan** 복귀 후 재순환

---

## 품질 기준 (최종 완료 판정)

루프를 종료하려면 아래 **전부** 달성해야 한다.

```
✅ flutter analyze : error 0, warning 0
✅ flutter test    : 통과율 100% (skip 제외)
✅ 전 화면 동작    : 7개 라우트 모두 렌더링 성공
✅ 파일 업로드     : 파일 선택 → 다이얼로그 → 홈 복귀
✅ 텍스트 입력     : 텍스트/문서 → 메타데이터 → 홈 복귀
✅ 기록 목록       : 빈 상태 메시지 또는 데이터 렌더링
✅ 검색/필터       : 검색 필터 화면 진입 및 복귀
✅ 메타데이터 저장 : 폼 입력 → 저장 → 홈 복귀
```

---

## Windows 토스트 알림 규칙

사람 개입이 필요하거나 중요한 단계 전환 시 **반드시** 아래 명령을 실행한다.
스크립트 위치: `scripts/notify.ps1`

```powershell
# 실행 패턴
powershell -ExecutionPolicy Bypass -File scripts/notify.ps1 -title "제목" -message "내용"
```

### 알림 발송 조건 4가지

#### 1. API 키 없음 / Claude API 호출 실패
```powershell
powershell -ExecutionPolicy Bypass -File scripts/notify.ps1 `
  -title "구술기록관리 에이전트" `
  -message "API 키 입력이 필요합니다. VS Code를 확인해주세요."
```

#### 2. 동일 오류 3회 이상 반복
```powershell
powershell -ExecutionPolicy Bypass -File scripts/notify.ps1 `
  -title "구술기록관리 에이전트" `
  -message "해결 불가 오류 발생. 개발자 확인이 필요합니다: [오류내용]"
```
`[오류내용]`은 실제 오류 메시지 앞 100자로 대체.

#### 3. PDCA 전체 사이클 완료 (품질 기준 달성)
```powershell
powershell -ExecutionPolicy Bypass -File scripts/notify.ps1 `
  -title "구술기록관리 에이전트" `
  -message "PDCA 사이클 완료! 품질 기준 달성했습니다."
```

#### 4. 각 단계(Plan/Do/Check/Act) 완료
```powershell
powershell -ExecutionPolicy Bypass -File scripts/notify.ps1 `
  -title "구술기록관리 에이전트" `
  -message "[단계명] 완료. 다음 단계로 자동 진행합니다."
```
`[단계명]`은 `Plan` / `Do` / `Check` / `Act` 중 해당 값으로 대체.

---

## 사람 개입이 필요한 경우 (이 경우만 실행 중단)

알림 발송 후 응답 대기.

| 상황 | 알림 조건 번호 | 행동 |
|------|--------------|------|
| API 키 / 환경변수 입력 필요 | 조건 1 | 알림 발송 → 즉시 중단, 필요 값 명시하여 보고 |
| 동일 오류 3회 이상 반복 | 조건 2 | 알림 발송 → 중단, 오류 전문과 시도 이력 보고 |
| 해결 불가능한 빌드/런타임 오류 | 조건 2 | 알림 발송 → 중단, 원인 분석 및 해결 옵션 제시 |
| 외부 서비스 접근 필요 (API, DB 등) | 조건 1 | 알림 발송 → 중단, 필요 접근 정보 요청 |

---

## 진행 상황 보고 형식

```
[PDCA] ▶ Check 시작  (2026-03-24 09:00)
[C1] flutter analyze — No issues found ✅
[C2] flutter test — 169 passed, 8 skipped ✅
[C3] 전 화면 검증 — 7/7 통과 ✅
[C4] 데이터흐름 검증 — 완료 ✅
[C5] check/report.md — 작성 완료 ✅
[PDCA] ✅ Check 완료 → Act 자동 시작
```

- 단계 시작/완료: 한 줄
- 문제 발견: 즉시 인라인 보고
- 최종 완료: 전체 결과 표 출력

---

## 현재 프로젝트 컨텍스트

- **앱**: 구술기록관리 Flutter 앱 (Web/Chrome)
- **스택**: Flutter + Riverpod + GoRouter + Hive
- **라우트**: `/` `/recording` `/file-picker` `/text-input` `/metadata-input` `/records` `/records/search-filter` `/records/detail/:id` `/settings`
- **현재 상태**: Do 완료 (analyze 0, test 169 passed) → Check 진행 중

---

## RAG 스택 (v3.0)
- 벡터 DB: Qdrant (Docker, port 6333)
- 임베딩: jhgan/ko-sroberta-multitask (sentence-transformers)
- RAG 서버: FastAPI (port 9000)
- 컬렉션: oral_records (768차원, Cosine)

## 서버 실행 방법
```
docker start qdrant
cd server
python -m uvicorn main:app --host 0.0.0.0 --port 9000
```

---

## 메타

- 작성일: 2026-03-24
- 버전: 2.1 (Windows 토스트 알림 추가)
- 이전 버전: 오케스트레이터 모드 (v2.0, 2026-03-24)
