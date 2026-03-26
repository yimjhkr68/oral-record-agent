# UI/UX 상세 설계

[에이전트 자율 추가] 화면별 상태 관리 및 사용자 흐름 명확화

## 화면 목록 및 상태 전이

### 1. 홈 화면 (HomePage)
- 역할: 최근 기록 목록, 빠른 작업 버튼
- 상태:
  - **로딩 상태**: `AsyncValue.loading`
  - **성공 상태**: 최근 기록 N건 표시
  - **에러 상태**: 오류 메시지 + "재시도" 버튼
- 빠른 작업 버튼: "녹음 시작", "파일 업로드", "텍스트 입력"

### 2. 기록 입력 화면 (RecordInputPage)
#### 2-1. 녹음 화면 (RecordingPage)
- 상태: 대기 → 녹음중 → 일시정지 → 완료
- UI: 타이머, 음량 레벨 표시
- 전환: 저장 클릭 → metadataInputPage

#### 2-2. 파일 업로드 화면 (FilePickerPage)
- File Picker (mp3/wav/m4a) → collectRecord 호출
- 상태: 선택 → 업로드중 → 완료
- 다음: metadataInputPage

#### 2-3. 문서/텍스트 입력 화면 (TextInputPage)
- 문서 선택 또는 텍스트 다이렉트 입력
- parseDocument 호출 (문서의 경우)
- 완료 → metadataInputPage

### 3. 메타데이터 입력 화면 (MetadataInputPage) [에이전트 자율 추가]
- **필수 입력**: 구술자, 면담자, 면담 일시
- **선택 입력**: 주제 분류, 키워드 태그, 비공개 여부
- 상태:
  - **입력 중**: 필드 유효성 체크 실시간
  - **제출 중**: `AsyncValue.loading`
  - **성공**: 기록 저장 완료, RecordListPage로 이동
  - **에러**: 유효성 실패 또는 DB 오류
- Riverpod 사용:
  - `narratorProvider` (구술자 선택 드롭다운)
  - `interviewerProvider` (면담자 선택 드롭다운)
  - `metadataFormProvider` (폼 상태 관리)

### 4. 기록 목록 화면 (RecordListPage) [에이전트 자율 추가]
- 기본 표시: 최근순 정렬
- 구술자별 그룹핑 옵션
- 상태:
  - **로딩**: 초기 스크롤
  - **성공**: 목록 표시 (페이징 적용)
  - **에러**: 검색 실패 알림
- Riverpod: `recordListProvider(filters: SearchFilters)`
- 페이징: 20개씩 (스크롤 다운 시 자동 로드)

### 5. 검색·필터 화면 (SearchFilterPage) [에이전트 자율 추가]
- 검색 조건:
  - 구술자 (드롭다운)
  - 날짜 범위 (DateRangePicker)
  - 장소 (텍스트 입력)
  - 주제 분류 (드롭다운)
  - 비공개 여부 (체크박스)
- "검색" 클릭 → searchRecords 호출 → RecordListPage (필터 적용)
- Riverpod: `searchFilterProvider`

### 6. 기록 상세 화면 (RecordDetailPage) [에이전트 자율 추가]
- 표시 정보: 제목, 콘텐츠, 메타데이터, PII 독시트, 최근 수정일
- 버튼 메뉴:
  - "편집": MetadataInputPage
  - "전사": transcribeAudio 호출 (음성인 경우만)
  - "요약": summarizeRecords 호출 (선택 기록들)
  - "내보내기": exportRecord (JSON/TXT 선택)
  - "삭제": 확인 후 Record 삭제
- PII 표시: detectPII 결과 하이라이트 + "마스킹" 버튼
- 상태:
  - **로딩**: 기록 조회 중
  - **성공**: 상세 정보 표시
  - **에러**: 조회 실패

### 7. 설정 화면 (SettingsPage)
- 자동 전사 토글
- PII 감지 활성화 토글
- 내보내기 기본 형식 (JSON/TXT)
- Riverpod: `settingsProvider` (StateNotifier)

## Riverpod 구조

### Provider 설계 [에이전트 자율 추가]
```dart
// 데이터 제공자
final recordRepositoryProvider = Provider((ref) => RecordRepository());
final narratorRepositoryProvider = Provider((ref) => NarratorRepository());

// 상태 관리
final recordListProvider = FutureProvider.family(
  (ref, SearchFilters filters) => 
    ref.watch(recordRepositoryProvider).search(filters)
);

final recordDetailProvider = FutureProvider.family(
  (ref, String recordId) => 
    ref.watch(recordRepositoryProvider).getById(recordId)
);

final metadataFormProvider = StateNotifierProvider(
  (ref) => MetadataFormNotifier()
);

final settingsProvider = StateNotifierProvider(
  (ref) => SettingsNotifier()
);

// 부가 제공자
final narratorListProvider = FutureProvider(
  (ref) => ref.watch(narratorRepositoryProvider).getAll()
);

final interviewerListProvider = FutureProvider(
  (ref) => ref.watch(interviewerRepositoryProvider).getAll()
);
```

## 네비게이션 흐름

```
HomePage
  ├─ [빠른 작업] RecordingPage → MetadataInputPage → RecordListPage
  ├─ [빠른 작업] FilePickerPage → MetadataInputPage → RecordListPage
  ├─ [빠른 작업] TextInputPage → MetadataInputPage → RecordListPage
  ├─ [최근 기록 클릭] RecordDetailPage
  │  └─ [편집] MetadataInputPage → RecordDetailPage (새로고침)
  │  └─ [전사] transcribeAudio 호출 (로딩 상태)
  │  └─ [내보내기] exportRecord (파일 저장)
  ├─ [상단 탭] RecordListPage
  │  ├─ [검색 아이콘] SearchFilterPage → RecordListPage (필터 적용)
  │  └─ [기록 클릭] RecordDetailPage
  └─ [상단 탭] SettingsPage
```

## 사용자 온보딩 [에이전트 자율 추가]
- 첫 실행 시 튜토리얼:
  1. "구술자 정보" 입력 가이드
  2. "면담 정보" 입력 가이드
  3. "기록 입력" 첫 시도
- Riverpod: `onboardingStateProvider` (first_run 체크)

## 접근성 및 다국어 [에이전트 자율 추가]
- 모든 버튼/아이콘에 Tooltip 추가
- 다크 모드 지원 (ThemeData)
- 향후 다국어: ko, en 기본 (i18n 라이브러리 추가 예정)
