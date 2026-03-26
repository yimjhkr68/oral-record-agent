# 데이터 모델 설계 (Data Model)

## 개념 모델

### Narrator(구술자)
- o id: String (UUID)
- o name: String (필수)
- o dateOfBirth: DateTime?
- o gender: String? ("M"/"F"/"Other")
- o jobTitle: String? (당시 직급)
- o currentJobTitle: String? (현재 직급)
- o biography: String? (약전)
- o createdAt: DateTime
- o updatedAt: DateTime

### Interviewer(면담자)
- o id: String (UUID)
- o name: String (필수)
- o affiliation: String? (소속)
- o createdAt: DateTime
- o updatedAt: DateTime

### InterviewSession(면담 세션)
- o id: String (UUID)
- o narratorId: String (구술자 ID)
- o interviewerId: String (면담자 ID)
- o sessionNo: int (회차, 예: 1, 2, 3...)
- o interviewDate: DateTime (면담 일시)
- o location: String? (면담 장소)
- o interviewType: String ("oral"/"document"/"phone" 등)
- o language: String (사용 언어, 기본값: "ko")
- o notes: String? (면담 노트)
- o createdAt: DateTime
- o updatedAt: DateTime

### Record(기록)
- o id: String (UUID)
- o title: String (필수, 1-200자)
- o content: String (전사된 텍스트 또는 문서 내용, 필수)
- o inputType: String ("audio"/"document"/"text", 필수)
- o originalAudioPath: String? (원본 음성 파일 경로, inputType="audio"일 때만)
- o originalDocPath: String? (원본 문서 파일 경로, inputType="document"일 때만)
- **메타데이터 필드:**
  - o sessionId: String (필수, InterviewSession ID 참조)
  - o narratorId: String (필수, Narrator ID 참조)
  - o mainCategory: String (필수, 주제 대분류)
  - o subCategory: String? (선택, 주제 소분류)
  - o keywordTags: List<String> (선택, 1-20개 태그)
  - o visibility: String (필수, "public"/"private"/"conditional")
  - o recordedBy: String (필수, 기록 작성자명)
- o tags: List<String> (임시 태그, 최대 20개)
- o classification: String? (자동 분류 결과, 선택)
- o summary: String? (AI 요약, 선택)
- o detectedPII: List<PIIItem> (감지된 PII 목록)
- o createdAt: DateTime
- o updatedAt: DateTime

- PIIItem
  - o type: String ("email", "phone", "name", etc.)
  - o value: String
  - o startIndex: int
  - o endIndex: int

- AppSettings
  - o id: String (fixed key)
  - o language: String
  - o autoTranscribe: bool
  - o piiDetectionEnabled: bool
  - o exportFormat: String ("json"/"txt")

## Hive 어댑터
- NarratorAdapter (typeId 0)
- InterviewerAdapter (typeId 1)
- InterviewSessionAdapter (typeId 2)
- RecordAdapter (typeId 3)
- PIIItemAdapter (typeId 4)
- AppSettingsAdapter (typeId 5)

## DB 구조
- Hive box `narrators` (Narrator 객체 목록)
- Hive box `interviewers` (Interviewer 객체 목록)
- Hive box `sessions` (InterviewSession 객체 목록)
- Hive box `records` (Record 객체 목록)
- Hive box `settings` (AppSettings 단일 객체)

## 관계 및 인덱싱
- Record.sessionId → InterviewSession.id (면담 세션 연결)
- InterviewSession.narratorId → Narrator.id (구술자 추적)
- InterviewSession.interviewerId → Interviewer.id (면담자 추적)
- records 인덱싱
  - primaryKey: createdAt, narratorId, mainCategory(복합)
  - secondary: sessionId, visibility, interviewDate
- Narrator.id 기반 전체 기록 조회 최적화

## 동일 구술자 면담 회차 연결
- Narrator.id를 기준으로 여러 InterviewSession 생성
- 각 Session.sessionNo로 회차 구분 (1차, 2차...)
- Record.sessionId를 통해 각 기록이 어느 회차에 속하는지 추적
- UI에서 "구술자 > 회차별 기록" 구조로 조회 가능

## 모델 확장
- 추후 다음 필드를 추가할 수 있음
  - 음성 감정 분석 결과
  - 사용자가 표기한 중요도 등급
  - 공유 상태/소유자 정보
  - Narrator의 사진/프로필 이미지
