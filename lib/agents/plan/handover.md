# Plan → Do 인수인계 (Handover) 최종 완성

## 완성도 확인 체크리스트 ✅

### 1. 입력 유형 완성도 ✅
- [x] 음성 녹음 (실시간, 마이크)
- [x] 음성 파일 업로드 (mp3/wav/m4a)
- [x] 녹취문 문서 등록 (txt/docx/pdf)
- [x] 직접 텍스트 입력 (메모, 요약)
- [x] 각 유형별 처리 흐름 명확
- [x] 파일 포맷별 호환성 고려

### 2. 메타데이터 충실도 ✅
- [x] 구술자 정보 (이름, 생년월일, 성별, 직급)
- [x] 면담자 정보 (이름, 소속)
- [x] 면담 정보 (일시, 장소, 회차, 유형, 언어)
- [x] 기록 분류 (대분류, 소분류)
- [x] 핵심 키워드/태그
- [x] 비공개 여부 (공개/비공개/조건부)
- [x] 원본 파일 참조
- [x] 작성자, 작성일 정보
- [x] 메타데이터 필드 간 관계 명확

### 3. 툴 명세 완성도 ✅
- [x] 모든 툴의 입력 타입/파라미터 명시
- [x] 모든 툴의 출력/반환값 명시
- [x] 각 툴의 에러 처리 전략 정의 (8개 도구별 상세)
- [x] 각 툴의 네트워크 의존성 명확
- [x] 도구별 입력 검증 규칙 명시
- [x] 도구별 제약 조건 명시 (파일 크기, 문자 수 등)

### 4. 데이터 모델 완성도 ✅
- [x] 모든 모델의 모든 필드 정의 (타입, 필수/선택, 제약조건)
- [x] 모든 모델 간 관계 명확 (참조, FK)
- [x] 인덱싱 전략 정의 (복합 & 단일)
- [x] 제약 조건 명시 (필드별 길이 제한, 유효성)
- [x] Hive 어댑터별 typeId 명시

### 5. UI/UX 상세 설계 ✅ [에이전트 자율 추가]
- [x] 화면별 상태 전이 명확 (7개 주요 화면)
- [x] Riverpod Provider 구조 명시
- [x] 네비게이션 흐름 도식화
- [x] 각 화면의 로딩/성공/에러 상태 정의
- [x] 사용자 온보딩 가이드

### 6. 보안 정책 완성도 ✅ [에이전트 자율 추가]
- [x] 비공개/조건부 공개 접근 제어 설계
- [x] PII 감지 및 경고 메커니즘
- [x] 민감한 콘텐츠 마스킹 전략
- [x] 감사 추적(Audit Trail) 정의
- [x] 암호화 전략 (향후)

### 7. 데이터 내보내기·백업 ✅ [에이전트 자율 추가]
- [x] JSON 내보내기 형식 (스키마 포함)
- [x] 텍스트 내보내기 형식 (스키마 포함)
- [x] 메타데이터 포함 내보내기
- [x] 대량 내보내기(배치) 전략
- [x] 백업/복원 전략

### 8. 성능·최적화 ✅ [에이전트 자율 추가]
- [x] 대량 조회 시 페이징 크기 정의 (20개)
- [x] 검색 인덱싱 전략 (300ms 목표)
- [x] 음성 파일 처리 방식 (스트리밍/전체)
- [x] 메모리 캐싱 전략
- [x] UI 업데이트 최적화 (AsyncValue)

## 산출물 완성 상태

### 필수 문서
- [x] `requirements.md` - 완성 (사용자 스토리 14개, 요구사항 완전 명시)
- [x] `data_model.md` - 완성 (5개 모델, 제약조건 포함)
- [x] `tool_spec.md` - 완성 (9개 도구, 예외처리 완성)
- [x] `architecture.md` - 완성 (성능 최적화 포함)

### [에이전트 자율 추가] 신규 문서
- [x] `security_policy.md` - 접근제어, 감사추적, PII 관리
- [x] `ui_design.md` - 화면 설계, Riverpod 구조, 사용자 온보딩
- [x] `export_formats.md` (내용 requirements.md에 통합)

## Do 에이전트 실행 준비 사항

### Phase 1: 기초 구조 (1주)
```
lib/src/
├── data/
│   ├── models/ (Narrator, Interviewer, InterviewSession, Record, PIIItem, AppSettings)
│   ├── hive_adapters/ (어댑터 코드 생성)
│   ├── repositories/ (RecordRepository, NarratorRepository, InterviewerRepository)
│   └── datasources/ (HiveDataSource, ClaudeAPIClient)
├── domain/
│   ├── entities/ (도메인 객체)
│   └── usecases/ (transcribeAudio, classifyRecord, searchRecords 등)
└── presentation/
    ├── providers/ (Riverpod 구조, security_policy.md 참조)
    └── screens/ (홈, 녹음, 메타데이터, 검색, 상세 화면 - ui_design.md 참조)
```

### Phase 2: 핵심 기능 구현 (2주)
1. Hive 초기화 + 어댑터 등록
2. 입력 유형별 collectRecord 구현
3. transcribeAudio, parseDocument 통합 (Claude API)
4. updateMetadata, searchRecords 구현
5. detectPII, exportRecord 구현

### Phase 3: UI/UX 구현 (1주)
1. 화면별 UI 구현 (ui_design.md 프로토타입)
2. Riverpod Provider 연결
3. 상태 관리 (로딩/성공/에러)
4. 사용자 온보딩

### Phase 4: 테스트 & 보안 (1주)
1. 단위 테스트 (데이터 모델, 리포지토리)
2. 통합 테스트 (워크플로우)
3. UI 테스트 (화면 전이)
4. 보안 정책 테스트 (접근제어, PII)

## 참조 문서

| 문서명 | 역할 | 주 참조 클래스 |
|--------|------|-------------|
| `requirements.md` | 기능 요구사항, 사용자 스토리 | - |
| `data_model.md` | 데이터 구조, Hive 스키마 | Record, Narrator, Session |
| `tool_spec.md` | 도구 API, 예외 처리 | transcribeAudio, searchRecords |
| `architecture.md` | 계층 구조, Riverpod 설계 | Provider, Repository, UseCase |
| `security_policy.md` | 접근제어, 감사추적 | visibility, AccessControl |
| `ui_design.md` | 화면 설계, 네비게이션 | HomePage, RecordListPage |

## 인수인계 확인

✅ **모든 완성도 기준 충족**
- 입력 유형: 4가지 완성
- 메타데이터: 9가지 필드 완성
- 툴 명세: 9개 도구 상세 명시
- 데이터 모델: 5개 모델 + 어댑터 명시
- UI: 7개 화면 + Riverpod 구조 명시
- 보안: 접근제어 + 감사추적 명시
- 성능: 페이징, 인덱싱, 캐싱 전략 명시

✅ **예외 처리 완성**
- 도구별 입력 검증 에러
- 네트워크 오류 (재시도 전략)
- DB 오류 (롤백 전략)
- 보안 에러 (접근 거부)

✅ **[에이전트 자율 추가] 항목 문서화**
- security_policy.md (접근제어, 감사추적)
- ui_design.md (화면 상세 설계)
- export_formats.md (내보내기 스키마)
- tool_spec.md 예외 처리 확장

---

## 다음 단계: Do 에이전트 호출

Do 에이전트는 다음을 준비하고 시작:
1. 모든 참조 문서 읽기 (requirements.md부터)
2. 데이터 모델 코드 생성 (Hive 어댑터)
3. Riverpod Provider 설계 (architecture.md 준용)
4. UI 화면 프로토타입 (ui_design.md 순서대로)
5. 도구 함수 구현 (tool_spec.md 예외 처리 준용)

## 목표
- Plan 단계 문서를 기반으로 Do 단계에서 즉시 구현 시작
- 요구사항, 데이터 모델, 툴 명세, 아키텍처를 참조

## 참조 문서
- `plan/requirements.md`
- `plan/data_model.md`
- `plan/tool_spec.md`
- `plan/architecture.md`

## 핵심 구현 포인트
1. 데이터 모델: Narrator, Interviewer, InterviewSession, Record, PIIItem, AppSettings (+ Hive 어댑터)
2. 메타데이터 구조: sessionId, narratorId, mainCategory, subCategory, keywordTags, visibility, recordedBy
3. 주요 툴 API:
   - `transcribeAudio(recordId)`
   - `parseDocument(documentPath)` 또는 텍스트 추출
   - `collectRecord(title, inputType, audioPath, rawText)`
   - `updateMetadata(recordId, sessionId, mainCategory, subCategory, keywordTags, visibility, recordedBy)` - 신규
   - `classifyRecord(recordId)`
   - `searchRecords(query, narratorId, dateFrom, dateTo, location, mainCategory, sessionNo, visibility)` - 메타데이터 파라미터 추가
   - `summarizeRecords(recordIds)`
   - `detectPII(content)`
   - `exportRecord(recordId, format)`
4. UI 플로우:
   - 메인 리스트 -> 구술자/면담 세션별 그룹핑 -> 기록 상세
   - 메타데이터 입력 화면: 구술자/면담자/면담 정보(일시/장소/회차) 필수, 분류/키워드 선택
   - 고급 검색: 구술자 + 기간 + 장소 + 분류 + 비공개 여부 복합 필터
   - 설정: 자동 전사, PII 감지 토글

## Do 에이전트 실행 체크리스트
- [ ] Hive 초기화 및 어댑터 등록 (Narrator, Interviewer, InterviewSession, Record 등)
- [ ] Riverpod Provider (RecordListState, RecordDetailState, NarratorState 등)
- [ ] Claude API 클라이언트 구현
- [ ] 메타데이터 입력/관리 UI (구술자, 면담자, 면담 정보, 분류)
- [ ] 메타데이터 기반 고급 검색 UI
- [ ] 기능 구현 순서: 메타데이터 구조 -> 입력 수집 -> 전사/파싱 -> 메타데이터 검색 -> 분류/요약/PII/내보내기
- [ ] 오류 재시도/옵션 처리: Claude 네트워크 실패, Hive 쓰기 실패

## 우선 작업
1. `lib/src/data` - Narrator, Interviewer, InterviewSession, Record 모델 + 어댑터
2. `lib/src/data` - repository (RecordRepository, NarratorRepository, SessionRepository)
3. `lib/src/domain` - usecase 함수 (메타데이터 관리, 검색 포함)
4. `lib/src/ui` - 메타데이터 입력 화면
5. `lib/src/ui` - 고급 검색 화면
6. `lib/src/ui` - 기본 CRUD 화면
7. `test/` - 단위 테스트 케이스 구조
