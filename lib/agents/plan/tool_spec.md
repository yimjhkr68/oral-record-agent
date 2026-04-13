# 툴 명세서 (Tool Spec)

## 공통 제약
- 로컬 DB: Hive
- AI 호출: Anthropic Claude API
- 상태관리: Riverpod

## 툴 목록
1. transcribeAudio
   - 입력: recordId:String (또는 audioFilePath:String)
   - 출력: text:String
   - 설명: 저장된 Record의 오디오 파일이나 음성 파일을 전사. Claude API 호출을 통해 고급 음성 텍스트 변환 수행. 음성 입력(inputType="audio")에만 적용.

2. parseDocument
   - 입력: documentPath:String (또는 rawText:String)
   - 출력: text:String
   - 설명: 녹취문 문서(txt/docx/pdf)에서 텍스트 추출. 문서 형식 파싱 또는 텍스트 정규화 수행 (향후 고도화). Document 입력(inputType="document")에만 적용.

3. collectRecord
   - 입력: title:String, inputType:String ("audio"/"document"/"text"), audioPath:String?, rawText:String?
   - 출력: Record
   - 설명: 새로운 Record 객체 생성 후 Hive에 저장. inputType에 따라 음성 파일 경로 또는 텍스트 컨텐트 처리. 음성/문서인 경우 아직 전사/파싱 전 상태 저장.

4. classifyRecord
   - 입력: recordId:String
   - 출력: classification:String
   - 설명: record.content를 추출하여 카테고리/태그 지정. Claude API를 활용한 NLP 분류.

5. searchRecords
   - 입력: query:String?, tags:List<String>?, dateFrom:DateTime?, dateTo:DateTime?, narratorId:String?, interviewerId:String?, location:String?, mainCategory:String?, sessionNo:int?, visibility:String?
   - 출력: List<Record>
   - 설명: Hive records box에서 쿼리 및 메타데이터 기반 검색. 텍스트 검색(content, title), 날짜 범위, 구술자/면담자, 주제 분류, 비공개 여부 등 복합 조건 필터링 지원. Narrator.id 기반으로 특정 구술자의 모든 기록 조회 가능.

6. updateMetadata
   - 입력: recordId:String, sessionId:String?, mainCategory:String?, subCategory:String?, keywordTags:List<String>?, visibility:String?, recordedBy:String?
   - 출력: Record (수정된 객체)
   - 설명: 저장된 기록의 메타데이터 입력/수정. InterviewSession 정보(구술자, 면담자, 면담일시, 장소, 회차) 와 기록 분류/키워드는 이 도구로 관리. 메타데이터 입력 후 detectPII, classifyRecord 등 재실행 가능.

7. summarizeRecords
   - 입력: recordIds:List<String>
   - 출력: summary:String
   - 설명: 선택된 기록을 결합해 Claude API로 요약.

8. detectPII
   - 입력: content:String
   - 출력: List<PIIItem>
   - 설명: 기록 내 PII 탐지, 결과를 PIIItem 리스트로 반환.

9. exportRecord
   - 입력: recordId:String, format:String ("json"/"txt")
   - 출력: filePath:String
   - 설명: 로컬 파일로 기록 내보내기. 필요 시 다운로드/공유 기능 연결.

## 에이전트 루프
### 실시간 음성 녹음 경로
1. 마이크 녹음 -> collectRecord(inputType="audio", audioPath)
2. transcribeAudio(recordId) -> 전사 텍스트 저장
3. classifyRecord + detectPII
4. 저장/검색/요약/내보내기

### 음성 파일 업로드 경로
1. 파일 선택 -> collectRecord(inputType="audio", audioPath)
2. transcribeAudio(recordId) -> 전사 텍스트 저장
3. 이후 경로는 녹음과 동일

### 녹취문 문서 등록 경로
1. 문서 업로드/텍스트 붙여넣기 -> parseDocument(documentPath) 또는 rawText 추출
2. collectRecord(inputType="document", rawText) -> 바로 저장 (전사 단계 없음)
3. classifyRecord + detectPII
4. 저장/검색/요약/내보내기

### 직접 텍스트 입력 경로
1. 사용자 타이핑 -> collectRecord(inputType="text", rawText)
2. 바로 저장 (전사 단계 없음)
3. classifyRecord + detectPII
4. 저장/검색/요약/내보내기

### 공통 후속 단계
- 저장된 기록 선택 -> classifyRecord + detectPII
- 검색(searchRecords) -> 검색결과 요약(summarizeRecords)
- 검증 후 exportRecord

## 도구별 상세 예외 처리 [에이전트 자율 추가]

### 1. transcribeAudio
- **입력 검증 에러**
  - InvalidRecordError: recordId가 존재하지 않음
  - InvalidAudioFile: 파일 형식 지원 안 함 (mp3/wav/m4a만)
  - FileSizeError: 파일 크기 초과 (500MB 제한)
- **네트워크 에러** (NetworkException)
  - Claude API 호출 실패 → 재시도 3회, 각 재시도 2초 대기
  - 최종 실패 시: "음성 전사 실패. 네트워크 상태를 확인하세요" + 로컬 음성은 보존
- **예외 처리**
  - 전사 과정 중 오류 → Record.content는 공백, Record.status = "transcription_failed"로 표시

### 2. parseDocument
- **입력 검증 에러**
  - InvalidDocumentFormat: txt/docx/pdf 이외 형식
  - FileSizeError: 파일 크기 초과 (50MB 제한)
- **파일 파싱 에러** (DocumentParsingException)
  - 손상된 파일 → 사용자: "문서를 읽을 수 없습니다. 파일을 확인하세요"
  - 복구 불가 시: Record 생성하지 않고 오류 반환
- **예외 처리**: 텍스트 추출 실패 시 빈 문서로 진행 후 사용자에게 경고

### 3. collectRecord
- **입력 검증 에러**
  - InvalidInputType: inputType이 audio/document/text 아님
  - MissingRequiredField: title이 공백
  - MissingMetadata: sessionId 미지정 (필수)
- **DB 쓰기 에러** (DBException)
  - Hive write fail → 재시도 1회, 실패 시: "기록 저장 실패. 디스크 공간 확인"
  - Rollback: 부분 저장 상태 복원
- **예외 처리**: 저장 실패 시 로컬 임시 파일에 백업 후 재시도 옵션 제공

### 4. updateMetadata
- **입력 검증 에러**
  - InvalidRecordId: 기록이 존재하지 않음
  - InvalidSessionId: session이 존재하지 않음
  - InvalidCategory: 허용되지 않은 분류 코드
- **접근 제어 에러** (AccessDeniedException) [에이전트 자율 추가]
  - visibility="private"이고 recordedBy != currentUser → 수정 거부
- **DB 에러**: collectRecord와 동일

### 5. searchRecords
- **입력 검증 에러**
  - InvalidDateRange: dateTo < dateFrom
  - InvalidSessionNo: sessionNo < 0
- **검색 실패** (SearchException)
  - Hive box 손상 → "검색 실패. 앱을 재시작하세요"
  - 메모리 부족 → 페이징 크기 감소 (20개 → 10개)
- **예외 처리**: 부분 검색 결과 반환 + "검색 결과가 불완전합니다" 경고

### 6. summarizeRecords
- **입력 검증 에러**
  - EmptyRecordList: recordIds 배열이 공백
  - RecordNotFound: 일부 recordId가 존재하지 않음
- **네트워크 에러**: transcribeAudio와 동일 (Claude API)
- **예외 처리**: 존재하는 기록만으로 요약 진행 + "일부 기록이 제외됨" 알림

### 7. detectPII
- **입력 검증 에러**
  - EmptyContent: content가 공백
- **AI 오류** (AIServiceException)
  - Claude API 오류 → 재시도 불가, 기록은 저장되지만 detectedPII는 공백
- **예외 처리**: PII 탐지 실패 시 Record는 저장, 사용자: "PII 검사 실패. 수동 검토 권장"

### 8. exportRecord
- **입력 검증 에러**
  - InvalidRecordId: 기록이 존재하지 않음
  - InvalidFormat: format이 json/txt 아님
- **파일 생성 에러** (FileSystemException)
  - 디스크 공간 부족 → "저장 공간 부족"
  - 파일명 충돌 → 자동으로 (1), (2)... 추가
- **접근 제어 에러** [에이전트 자율 추가]
  - visibility="private"이고 현재사용자 != recordedBy → 내보내기 거부
- **예외 처리**: 실패 시 임시 파일 정리 후 오류 반환

## 전역 예외 처리 [에이전트 자율 추가]
- **AppException** (기본 예외)
  - code: 에러 코드 (NETWORK_ERROR, DB_ERROR 등)
  - message: 사용자 친화적 메시지
  - stackTrace: 디버깅 용
- **사용자 피드백 우선순위**
  1. 네트워크 에러 → 재시도 버튼 제공
  2. 입력 검증 에러 → 필드 강조 + 구체적 지시
  3. 시스템 에러 → 기술지원 문의 안내

## 예외 처리
- 네트워크 오류(Claude API) -> 재시도 3회, 실패 시 사용자 피드백
- Hive 쓰기 오류 -> rollback 경고 및 로그 저장
- PII 감지 결과가 있을 경우 확인/삭제 옵션 제공
