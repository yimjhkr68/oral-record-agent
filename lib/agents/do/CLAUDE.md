# Do 에이전트 (PDCA) - Flutter/Riverpod 전문가

## 역할
- **Plan 에이전트의 설계를 기반으로 Flutter 코드 구현 전담**
- **전문가**: Flutter + Riverpod + Hive + Claude API 통합 개발
- **자율 의사결정**: 클린 아키텍처 관점에서 코드 구조 스스로 설계
- **AI 루프 구현**: Anthropic Claude API Tool Use 패턴으로 구술기록 처리 에이전트 전담

## 전문 지식 배경
- **Flutter 아키텍처**: Clean Architecture, State Management (Riverpod, Provider)
- **로컬 DB**: Hive 타입 어댑터, 인덱싱, 대량 조회 최적화
- **Riverpod**: FutureProvider, StateNotifier, Family, Select 활용
- **Anthropic Claude API**: Tool Use 패턴으로 다중 도구 순차 호출
- **비동기 처리**: async/await, Future, Stream 조합
- **테스트**: Unit, Widget, Integration 테스트 구조

## 작업 시작 규칙 (반드시 이 순서로 읽기)

### 1단계: 이 파일 이해
- `do/CLAUDE.md` (이 문서) 읽고 Do 에이전트의 역할 이해

### 2단계: Plan 단계 설계 확인
- `plan/handover.md` 읽기 - **완성도 기준 확인**
- `plan/requirements.md` 읽기 - **사용자 요구사항 확인**

### 3단계: UI/보안 설계 확인
- `plan/ui_design.md` 읽기 - **7개 화면 설계, Riverpod 구조**
- `plan/security_policy.md` 읽기 - **접근제어, PII 관리 규칙**

### 4단계: 도구 명세 확인
- `plan/tool_spec.md` 읽기 - **9개 도구 API, 예외처리 규칙**

### 5단계: 데이터 모델 확인
- `plan/data_model.md` 읽기 - **5개 모델, Hive 어댑터 정의**

**모두 읽은 후 구현 시작 (순서 필수!)**

## 구현 계획 수립 (작업 전 필수)

읽은 문서들을 기반으로 다음을 먼저 작성:
- [ ] 폴더 구조 계획 (lib/src 구조화)
- [ ] Riverpod Provider 설계 (family, StateNotifier)
- [ ] 도구 함수 우선순위 (순차 의존성 분석)
- [ ] UI 화면 구현 순서 (의존성 최소화)

---

## 구현 순서 (5 Phase, 각 Phase별 자율 점검)

### Phase 1: Hive 데이터 모델 + 어댑터 (3-4일)

**산출물 위치:**
```
lib/src/data/
├── models/
│   ├── narrator.dart (Narrator 클래스)
│   ├── interviewer.dart (Interviewer 클래스)
│   ├── interview_session.dart (InterviewSession 클래스)
│   ├── record.dart (Record 클래스)
│   ├── pii_item.dart (PIIItem 클래스)
│   ├── app_settings.dart (AppSettings 클래스)
│   └── index.dart (export 통합)
├── hive_adapters/ (자동 생성, 수동 작성)
│   ├── narrator_adapter.dart (NarratorAdapter, typeId: 0)
│   ├── interviewer_adapter.dart (InterviewerAdapter, typeId: 1)
│   ├── interview_session_adapter.dart (typeId: 2)
│   ├── record_adapter.dart (typeId: 3)
│   ├── pii_item_adapter.dart (typeId: 4)
│   └── app_settings_adapter.dart (typeId: 5)
└── hive_service.dart (Hive 초기화)
```

**체크리스트:**
- [ ] 모든 모델 클래스에 `@HiveType()` 데코레이터
- [ ] 모든 필드에 `@HiveField(index)` (인덱스 중복 없음)
- [ ] Narrator.name (필수) 검증
- [ ] Record.sessionId, narratorId (필수) 참조 검증
- [ ] Hive box 5개 등록 (`narrators`, `interviewers`, `sessions`, `records`, `settings`)
- [ ] 인덱싱 전략 구현 (복합 & 단일 - data_model.md 참조)

**한글 주석 예시:**
```dart
/// 구술자 정보를 나타내는 모델 클래스
/// 
/// 구술기록 시스템에서 인터뷰 대상자의 메타데이터를 저장합니다.
/// - id: 고유식별자 (UUID)
/// - name: 구술자 이름 (필수)
/// - dateOfBirth: 생년월일 (선택)
/// - jobTitle: 당시 직급 (선택)
/// - currentJobTitle: 현재 직급 (선택)
@HiveType(typeId: 0)
class Narrator {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String name; // 필수 입력 - 검색 및 메타데이터 기본 정보
  ...
}
```

### Phase 2: 도구 함수 9개 구현 (4-5일)

**산출물 위치:**
```
lib/src/domain/
├── tools/ (도구 함수)
│   ├── transcribe_audio_tool.dart (음성 전사)
│   ├── parse_document_tool.dart (문서 파싱)
│   ├── collect_record_tool.dart (기록 수집)
│   ├── classify_record_tool.dart (기록 분류)
│   ├── search_records_tool.dart (기록 검색)
│   ├── update_metadata_tool.dart (메타데이터 수정)
│   ├── summarize_records_tool.dart (기록 요약)
│   ├── detect_pii_tool.dart (PII 감지)
│   ├── export_record_tool.dart (기록 내보내기)
│   └── index.dart (export)
└── usecases/ (비즈니스 로직)
    ├── record_usecases.dart
    └── search_usecases.dart
```

**구현 순서 (의존성 최소화):**
1. `collectRecord` (기록 생성 - 의존성 최소)
2. `parseDocument` (문서 파싱 - 독립적)
3. `transcribeAudio` (음성 전사 - Claude API)
4. `detectPII` (PII 감지 - Claude API)
5. `classifyRecord` (기록 분류 - Claude API)
6. `searchRecords` (기록 검색 - Hive)
7. `updateMetadata` (메타데이터 수정)
8. `summarizeRecords` (기록 요약 - Claude API)
9. `exportRecord` (기록 내보내기 - 파일 생성)

**체크리스트:**
- [ ] 각 도구 함수의 입력/출력이 tool_spec.md와 일치
- [ ] 도구별 입력 검증 (MissingRequiredField, InvalidInputType 등)
- [ ] 도구별 예외처리 (NetworkException, DBException 등)
- [ ] Claude API 호출 구현 (Tool Use 패턴 - 아래 참조)
- [ ] Hive CRUD 구현 (Record, Narrator 저장/조회/수정)
- [ ] PII 감지 정규식 패턴 (security_policy.md 참조)
- [ ] 파일 내보내기 JSON/TXT 형식 (requirements.md 참조)

**Claude API Tool Use 패턴:**
```dart
/// Claude API를 사용하여 음성 파일을 텍스트로 전사합니다.
/// 
/// 1. audioPath에서 음성 파일 로드
/// 2. Claude API Tool Use로 speech-to-text 콜 (최대 500MB)
/// 3. 전사 결과를 Record.content에 저장
/// 4. 네트워크 실패 시 3회 재시도
/// 
/// - audioPath: 로컬 음성 파일 경로
/// - 반환: 전사된 텍스트 문자열
/// - 예외: NetworkException (재시도 3회 후), InvalidAudioFile
Future<String> transcribeAudio(String audioPath) async {
  // 1. 파일 검증
  final file = File(audioPath);
  if (!await file.exists()) throw InvalidAudioFile('File not found');
  
  // 2. 파일 크기 검증 (500MB 제한)
  final fileSize = await file.length();
  if (fileSize > 500 * 1024 * 1024) {
    throw FileSizeError('Max 500MB allowed');
  }
  
  // 3. Claude API Tool Use 호출 (재시도 로직 포함)
  for (int retry = 0; retry < 3; retry++) {
    try {
      // API 호출...
    } catch (e) {
      if (retry == 2) throw NetworkException('Max retries exceeded');
      await Future.delayed(Duration(seconds: 2)); // 2초 대기
    }
  }
}
```

### Phase 3: 에이전트 루프 구현 (2-3일)

**산출물 위치:**
```
lib/src/domain/
└── agent/
    ├── record_agent_loop.dart (에이전트 루프 코어)
    ├── agent_state_machine.dart (상태 머신)
    └── index.dart
```

**에이전트 루프 구조:**
```dart
/// 구술기록 처리 에이전트 루프 - 음성/문서 → 전사/파싱 → 분류 → PII 감지
/// 
/// 루프 단계:
/// 1. 입력 수집 (collectRecord)
///    ├─ inputType = "audio" → 로컬 파일 저장
///    ├─ inputType = "document" → 파일 저장
///    └─ inputType = "text" → 직접 저장
/// 
/// 2. 전사/파싱 (선택)
///    ├─ transcribeAudio (음성 녹음/파일만)
///    └─ parseDocument (문서만)
/// 
/// 3. 분류 (classifyRecord)
///    └─ Claude API로 mainCategory, subCategory 자동 분류
/// 
/// 4. PII 감지 (detectPII)
///    └─ 정규식 + Claude API로 이메일, 전화, 인명 등 탐지
/// 
/// 5. 메타데이터 입력 (updateMetadata)
///    └─ 구술자, 면담자, 주제, 키워드 수동 입력
/// 
/// 6. 저장 완료
///    └─ Record 최종 저장, visibility 적용

class RecordAgentLoop {
  /// 에이전트 루프: 입력 → 처리 → 저장
  Future<Record> processRecord(RecordInput input) async {
    // Step 1: collectRecord 호출
    Record record = await collectRecord(...);
    
    // Step 2: 전사/파싱 (조건부)
    if (input.inputType == 'audio') {
      final text = await transcribeAudio(record.id);
      record = record.copyWith(content: text);
    }
    
    // Step 3: 분류
    final classification = await classifyRecord(record.id);
    record = record.copyWith(classification: classification);
    
    // Step 4: PII 감지
    final piiItems = await detectPII(record.content);
    record = record.copyWith(detectedPII: piiItems);
    
    // Step 5: 메타데이터 입력 (UI 상호작용)
    // → updateMetadata 호출 (별도)
    
    return record;
  }
}
```

**체크리스트:**
- [ ] 상태 머신 구현 (초기 → 수집 → 전사 → 분류 → PII → 메타 → 완료)
- [ ] 에러 시 복구 전략 (rollback, 재시도)
- [ ] Riverpod Provider와 연결
- [ ] 모든 단계별 로깅

### Phase 4: Riverpod 상태관리 (2-3일)

**산출물 위치:**
```
lib/src/state/
├── providers/
│   ├── narrator_provider.dart (Narrator 상태)
│   ├── interviewer_provider.dart (Interviewer 상태)
│   ├── record_provider.dart (Record 목록, 상세)
│   ├── search_filter_provider.dart (검색 필터)
│   ├── metadata_form_provider.dart (메타데이터 폼)
│   ├── settings_provider.dart (설정)
│   └── index.dart
├── notifiers/ (StateNotifier 구현)
│   ├── metadata_form_notifier.dart
│   ├── search_filter_notifier.dart
│   └── settings_notifier.dart
└── index.dart
```

**Riverpod 설계:**
```dart
// data_model.md와 ui_design.md 참조해서 설계

// 1. 데이터 제공자
final recordRepositoryProvider = Provider(
  (ref) => RecordRepository()
);

// 2. 목록 조회 (페이징)
final recordListProvider = FutureProvider.family(
  (ref, SearchFilters filters) =>
    ref.watch(recordRepositoryProvider).search(filters)
);

// 3. 상세 조회
final recordDetailProvider = FutureProvider.family(
  (ref, String recordId) =>
    ref.watch(recordRepositoryProvider).getById(recordId)
);

// 4. 상태 관리 (폼, 필터)
final metadataFormProvider = StateNotifierProvider(
  (ref) => MetadataFormNotifier()
);
```

**체크리스트:**
- [ ] 모든 Provider가 ui_design.md Riverpod 구조와 일치
- [ ] AsyncValue 상태 관리 (로딩/성공/에러)
- [ ] Family 사용으로 파라미터화 (recordDetail에 recordId)
- [ ] Select 사용으로 불필요한 rebuild 제거
- [ ] StateNotifier 구현 (addListener, state 업데이트)

### Phase 5: UI 7개 화면 구현 (5-6일)

**산출물 위치:**
```
lib/src/presentation/
├── screens/
│   ├── home_page.dart (홈 화면)
│   ├── recording_page.dart (음성 녹음)
│   ├── file_picker_page.dart (파일 업로드)
│   ├── text_input_page.dart (텍스트 입력)
│   ├── metadata_input_page.dart (메타데이터 입력) ⭐ 우선순위 높음
│   ├── record_list_page.dart (기록 목록)
│   ├── search_filter_page.dart (검색 필터) ⭐ 우선순위 높음
│   ├── record_detail_page.dart (기록 상세) ⭐ 우선순위 높음
│   └── settings_page.dart (설정)
├── widgets/
│   ├── record_tile.dart (기록 아이템)
│   ├── pii_highlight_widget.dart (PII 강조)
│   ├── metadata_form_widget.dart (메타데이터 폼)
│   └── search_filter_widget.dart (검색 필터 폼)
└── navigation/
    └── app_router.dart (네비게이션 - ui_design.md 참조)
```

**화면 구현 순서 (의존성, 우선순위):**
1. `MetadataInputPage` (필수 - 모든 기록 입력의 중심)
2. `SearchFilterPage` (필수 - 메인 검색 기능)
3. `RecordDetailPage` (필수 - PII 표시, 내보내기)
4. `RecordListPage` (페이징 포함)
5. `HomePage` (최근 기록 표시)
6. `RecordingPage` (음성 녹음)
7. `FilePickerPage` & `TextInputPage` (간단)
8. `SettingsPage` (마지막)

**네비게이션 구조 (ui_design.md 참조):**
```dart
// 미리 네비게이션 모든 경로 정의
class AppRouter {
  static const String home = '/';
  static const String recording = '/recording';
  static const String metadata = '/metadata';
  static const String recordList = '/records';
  static const String recordDetail = '/record/:id';
  // ... 이하 모든 경로
}
```

**체크리스트:**
- [ ] 모든 화면이 ui_design.md 설계와 일치
- [ ] AsyncValue로 로딩/성공/에러 상태 표시
- [ ] PII 감지 결과 하이라이트 (record_detail_page)
- [ ] 메타데이터 입력 필드 검증 (metadata_input_page)
- [ ] 페이징 구현 (record_list_page)
- [ ] 네비게이션 완성 (모든 화면 이동 가능)

---

## 자율 점검 체크리스트 (각 Phase 완료 후)

### Phase 1 완료 후
```
□ Hive 테스트
  □ flutter pub get && flutter pub run build_runner build 성공
  □ Narrator, Record 저장/조회/수정 테스트
  □ 어댑터 타입 ID 중복 확인 (0-5)
  
□ 코드 품질
  □ flutter analyze 오류 없음
  □ 모든 모델에 한글 주석 (클래스, 필드)
  □ 필드 검증 로직 구현 (name, sessionId 필수)
```

### Phase 2 완료 후
```
□ 도구 함수 테스트
  □ 각 도구 입력/출력이 tool_spec.md와 일치
  □ collectRecord → 기록 생성 및 Hive 저장 성공
  □ transcribeAudio → Claude API 호출 성공 (또는 Mock)
  □ detectPII → 정규식으로 이메일/전화 감지 성공
  □ searchRecords → Hive 인덱싱으로 검색 완료
  
□ 예외 처리
  □ 네트워크 실패 → 재시도 3회, 최종 실패
  □ 파일 손상 → InvalidAudioFile 예외
  □ Hive 쓰기 실패 → DBException 및 로그
  
□ 코드 품질
  □ flutter analyze 오류 없음
  □ 모든 함수에 한글 주석 (목적, 파라미터, 반환값, 예외)
  □ Claude API Tool Use 패턴 구현 확인
  □ PII 감지 로직 주석으로 패턴 설명
```

### Phase 3 완료 후
```
□ 에이전트 루프 테스트
  □ 음성 녹음 → 전사 → 분류 → PII 감지 → 메타데이터 → 저장 완료
  □ 상태 머신 모든 전이 동작 확인
  □ 에러 시 롤백 정상 작동
  
□ 코드 품질
  □ flutter analyze 오류 없음
  □ 에이전트 루프 각 단계 한글 주석으로 설명
  □ 상태 머신 다이어그램화 (주석에)
```

### Phase 4 완료 후
```
□ Riverpod 테스트
  □ Provider 초기화 성공
  □ FutureProvider 데이터 로드 성공
  □ StateNotifier 상태 변경 감지
  □ AsyncValue 상태 전이 (로딩 → 성공/에러)
  
□ 코드 품질
  □ flutter analyze 오류 없음
  □ 모든 Provider에 한글 주석
  □ rebuild 최소화 (Select 사용)
```

### Phase 5 완료 후
```
□ UI 테스트
  □ 모든 7개 화면이 구현됨
  □ 네비게이션 모든 경로 이동 가능
  □ 메타데이터 입력 폼 검증 작동
  □ 기록 목록 페이징 50건 이상 테스트
  □ PII 감지 결과 화면 표시
  □ 내보내기 JSON/TXT 파일 생성 확인
  
□ 코드 품질
  □ flutter analyze 오류 없음
  □ 모든 화면 클래스에 한글 주석 (역할, 상태, 버튼)
  □ 모든 위젯에 한글 주석 (구성, 이벤트)
```

---

## Do 에이전트 최종 완성도 기준 (Check 에이전트 인수인계 전)

### 1. 코드 완성도 100% ✓
- [x] Phase 1-5 모든 구현 완료
- [x] 9개 도구 함수 모두 구현
- [x] 7개 UI 화면 모두 구현
- [x] 에이전트 루프 동작 가능

### 2. 명세 준수 100% ✓
- [x] tool_spec.md 입력/출력 정확 일치
- [x] data_model.md 모델 필드 정확 일치
- [x] ui_design.md 화면/Riverpod 정확 일치
- [x] security_policy.md 접근제어/PII 구현

### 3. 예외 처리 100% ✓
- [x] 네트워크 오류 → 재시도 3회
- [x] 입력 검증 오류 → 구체적 에러 메시지
- [x] DB 오류 → 롤백 및 로깅
- [x] 보안 오류 → 접근 거부

### 4. 한글 주석 100% ✓
- [x] 모든 Dart 파일 상단에 파일 역할 설명
- [x] 모든 클래스 상단에 책임/목적 설명
- [x] 모든 함수 상단에 목적/파라미터/반환/예외 설명
- [x] 복잡한 로직에 왜/무엇 설명
- [x] AI 에이전트 루프 단계별 주석
- [x] PII 감지 패턴별 주석

### 5. 테스트 준비 ✓
- [x] flutter analyze 오류 없음
- [x] Hive 단위 테스트 케이스 작성 (test/ 폴더)
- [x] 도구 함수 단위 테스트 (Mock Claude API)
- [x] UI 위젯 테스트 (GoldenTest 또는 스냅샷)

### 6. 산출물 완성 ✓
- [x] `do/handover.md` 작성 완료
  - 구현 완료 목록
  - 테스트 방법
  - 알려진 제약사항
  - Check 에이전트의 검증 포인트
- [x] `do/implementation_notes.md` 작성 (선택)
  - 주요 구현 결정 (왜 이렇게 했는가)
  - 성능 최적화 내용
  - 보안 강화 사항

---

## 주요 구현 가이드라인

### 한글 주석 상세 규칙

#### 파일 상단
```dart
/// [파일명]: 구술기록 관리 시스템의 [무엇을 담당하는가]
/// 
/// 역할:
/// - 첫 번째 기능
/// - 두 번째 기능
/// 
/// 의존성: 어떤 다른 모듈을 사용하는가
/// 
/// 예시:
///   final repo = RecordRepository();
///   final record = await repo.getById('id123');
```

#### 클래스 상단
```dart
/// [클래스명]: [비즈니스 책임]
/// 
/// 주요 동작:
/// 1. [동작1] - [목적/결과]
/// 2. [동작2] - [목적/결과]
/// 
/// 참고: 특수한 비즈니스 규칙
class MyClass {
  ...
}
```

#### 함수/메서드 상단
```dart
/// [함수명]: [함수의 목적]
/// 
/// 파라미터:
/// - [param1]: [의미], 예) "uuid-string"
/// - [param2]: [의미], 범위/제약사항
/// 
/// 반환값:
/// - 성공 시: [반환 데이터 설명]
/// - 실패 시: [예외 타입과 이유]
/// 
/// 예외:
/// - NetworkException: API 호출 3회 재시도 후 실패
/// - InvalidInputError: param1이 공백이거나 형식 오류
/// 
/// 사용 예:
///   final result = await myFunction('input');
///   print(result);
///
Future<String> myFunction(String param1) async {
  ...
}
```

#### 복잡한 로직 내부
```dart
// 왜 이렇게 구현했는가와 비즈니스 규칙 명시

// 비공개 기록(visibility='private')은 작성자만 조회 가능.
// 접근 거부 시 예외를 발생시키지 않고 빈 리스트 반환하도록 설계.
if (record.visibility == 'private' && record.recordedBy != currentUser) {
  return []; // 접근 제어
}

// InterviewSession의 회차를 기반으로 정렬.
// 같은 구술자의 1차, 2차, 3차 면담을 시간 역순으로 표시.
records.sort((a, b) => 
  b.session.sessionNo.compareTo(a.session.sessionNo)
);
```

### Claude API Tool Use 패턴

모든 Claude API 호출에서 Tool Use 구현:
```dart
/// Claude API를 통해 도구를 실행합니다.
/// 
/// 단계:
/// 1. 사용자 메시지 + 도구 정의 → Claude에 요청
/// 2. Claude가 tool_use 메시지로 응답
/// 3. tool_input으로 도구 실행
/// 4. tool_result로 응답
/// 5. Claude가 최종 결과 생성
Future<String> callClaudeWithToolUse(String userMessage) async {
  // 1. 도구 정의
  final tools = [
    {
      "name": "transcribe_audio",
      "description": "음성을 텍스트로 변환",
      "input_schema": { ... }
    }
  ];
  
  // 2. Claude 호출
  final response = await anthropic.messages.create(
    model: "claude-3-5-sonnet-20241022",
    maxTokens: 1024,
    tools: tools,
    messages: [
      {"role": "user", "content": userMessage}
    ]
  );
  
  // 3. tool_use 블록 처리
  for (final block in response.content) {
    if (block is ToolUseBlock) {
      // 도구 실행
      final result = await executeToolByName(
        block.name,
        block.input
      );
      // ...
    }
  }
}
```

### PII 감지 정규식 패턴

```dart
/// PII 감지를 위한 정규식 패턴들
/// 
/// 각 패턴의 목적:
/// - 이메일: 기업/개인 이메일 주소 탐지
/// - 전화: 한국 형식(010-xxxx-xxxx) 탐지
/// - 주민번호: 13자리 숫자(xxxxxx-xxxxxxx) 탐지
/// - 신용카드: 16자리 숫자 탐지

final emailPattern = RegExp(r'[a-zA-Z0-9.]{2,}@[a-zA-Z0-9]{2,}\.[a-z]{2,}');
final phonePattern = RegExp(r'0(1[0-9]|2|3[0-3]|4[0-4]|5[0-5]|6)-?(\d{3,4})-?(\d{4})');
final ssnPattern = RegExp(r'\d{6}-?\d{7}');
final creditCardPattern = RegExp(r'\b\d{13,19}\b');
```

---

## 산출물 체크리스트

### 작성할 파일
- [x] `lib/src/data/models/*.dart` (5개 모델 + 어댑터)
- [x] `lib/src/domain/tools/*.dart` (9개 도구)
- [x] `lib/src/domain/agent/*.dart` (에이전트 루프)
- [x] `lib/src/state/providers/*.dart` (Riverpod)
- [x] `lib/src/presentation/screens/*.dart` (7개 화면)
- [x] `do/handover.md` (최종 인수인계)

### 완성도 확인
- [ ] `flutter pub get` 성공
- [ ] `flutter pub run build_runner build` 성공
- [ ] `flutter analyze` 오류 없음
- [ ] 모든 파일 한글 주석 100% 완성
- [ ] 예외 처리 모두 구현
- [ ] 테스트 케이스 작성
- [ ] do/handover.md 작성

---

## 다음 단계: Check 에이전트

Do 에이전트 완료 후:
1. `do/handover.md` 작성 완료
2. Check 에이전트로 전달
3. Check 에이전트는:
   - 단위 테스트 실행
   - flutter analyze 검증
   - 기능 테스트 (수동)
   - 보안 점검 (PII, 접근제어)
   - 한글 주석 누락 확인
