# 요구사항 정의 (Requirements)

## 앱 개요
- 이름: 구술기록관리 에이전트
- 플랫폼: Flutter (Android / iOS / Web 가능)
- 형태: 독립형 애플리케이션 (외부 시스템 연동 없음)
- 핵심 기능: 다양한 입력 유형(음성/파일/텍스트)에서 구술기록을 수집하고, 메타데이터 관리/저장/분류/검색/요약, PII 감지, 내보내기 지원
- 메타데이터: 구술자, 면담자, 면담 정보(일시/장소/회차/유형/언어), 기록 분류(대분류/소분류), 비공개 여부, 핵심 키워드 태그
- 로컬 저장소: Hive
- AI: Anthropic Claude API (전처리 및 후처리, 요약, 분류, 메타데이터 추론 등)
- 상태관리: Riverpod

## 입력 유형
1. 실시간 음성 녹음: 앱 내 마이크로 직접 녹음 → 자동 전사
2. 음성 파일 업로드: 기존 mp3/wav/m4a 파일 가져오기 → 전사
3. 녹취문 문서 등록: 텍스트/txt/docx/pdf 문서 업로드 또는 복사-붙여넣기 (전사 과정 없이 직접 저장)
4. 직접 텍스트 입력: 짧은 메모/요약을 직접 타이핑
   - 모든 입력 유형은 동일한 Record 객체로 저장되며, 이후 분류/검색/요약/PII 감지가 적용됨

## 사용자 스토리
1. 사용자는 실시간 음성 녹음을 시작하고 저장할 수 있다.
2. 사용자는 기존 음성 파일(mp3/wav/m4a)을 앱으로 가져와 저장할 수 있다.
3. 사용자는 녹취문 문서(txt/docx/pdf)를 업로드하거나 텍스트를 직접 붙여넣어 저장할 수 있다.
4. 사용자는 짧은 메모를 직접 타이핑해서 기록으로 등록할 수 있다.
5. 사용자는 저장된 기록(입력 유형 무관)을 자동으로 전사(transcribeAudio, 음성인 경우만) 또는 문서 파싱할 수 있다.
6. 사용자는 기록을 분류(classifyRecord) 및 태깅할 수 있다.
7. 사용자는 구술자, 면담자, 면담 일시/장소/회차, 기록 주제/키워드 등 메타데이터를 입력 및 수정(updateMetadata)할 수 있다.
8. 사용자는 구술자명, 면담 기간, 면담 장소, 주제 분류, 비공개 여부 등 메타데이터 기반 고급 검색(searchRecords)을 수행할 수 있다.
9. 사용자는 동일 구술자의 여러 차수 기록을 연결하여 조회할 수 있다.
10. 사용자는 키워드 또는 날짜로 기록 검색(searchRecords)을 수행할 수 있다.
11. 사용자는 여러 기록을 요약(summarizeRecords)하여 핵심 내용 확인 가능.
12. 사용자는 기록에서 PII를 자동으로 감지(detectPII)하고 경고 받음.
13. 사용자는 선택한 기록을 JSON/텍스트로 내보내기(exportRecord) 가능.
14. 사용자는 기존 기록을 편집 및 삭제할 수 있다.

## 비기능 요구사항
- 오프라인 기본 동작: 기존 로컬 DB 조작은 네트워크 없이 가능
- 반응성 UI: Riverpod 기반 상태 업데이트를 즉시 반영
- 보안: 저장된 PII는 암호화 옵션 고려(향후), 비공개/조건부 공개 기록 접근 제어 필수
- 성능: 500건 이상 기록 검색 시 300ms 이내 응답 목표, 메타데이터 인덱싱으로 최적화
- 테스트: 단위 테스트/통합 테스트 케이스 포함
- 메타데이터 완전성: 구술자, 면담자, 면담 정보는 기록 저장 시 필수 입력

## 메타데이터 기반 검색 요건
- 특정 구술자의 모든 기록 조회
- 특정 기간(면담 일자 범위) 필터링
- 특정 장소의 기록 검색
- 주제 분류(대분류/소분류) 기반 필터링
- 복합 검색: 구술자 + 기간 + 분류 등 조건 결합
- 비공개 여부 필터링 (공개/비공개/조건부 공개)
- 면담 회차 범위 검색 (같은 구술자의 N차~M차 기록)

## 제한 사항
- 외부 시스템(서버, API) 미연동
- AI는 Claude API로 대체, 네트워크 연결 필요

## 처리 흐름
### 음성 녹음 입력 경로
1. 마이크 녹음 시작 → 로컬 파일 생성
2. collectRecord(inputType="audio", audioPath) → Hive 저장
3. (선택) transcribeAudio(recordId) 호출 → Claude API 전사
4. 분류/검색/요약 단계로 진행

### 음성 파일 업로드 경로
1. 파일 선택(File Picker) → mp3/wav/m4a 필터
2. collectRecord(inputType="audio", audioPath) → Hive 저장
3. (선택) transcribeAudio(recordId) 호출 → Claude API 전사

### 녹취문 문서 등록 경로
1. 문서 업로드(txt/docx/pdf) 또는 텍스트 붙여넣기
2. parseDocument(document) 또는 직접 텍스트 → 추출된 텍스트
3. collectRecord(inputType="document", rawText) → Hive 저장 (전사 과정 없음)

### 직접 텍스트 입력 경로
1. 사용자 텍스트 입력
2. collectRecord(inputType="text", rawText) → Hive 저장

## 데이터 내보내기·백업 [에이전트 자율 추가]

### JSON 내보내기 형식
```json
{
  "record": {
    "id": "uuid",
    "title": "제목",
    "content": "본문",
    "inputType": "audio",
    "createdAt": "2023-01-15T10:30:00Z",
    "updatedAt": "2023-01-15T10:30:00Z"
  },
  "metadata": {
    "narrator": { "id": "uuid", "name": "구술자명", "dateOfBirth": "1950-01-01" },
    "interviewer": { "id": "uuid", "name": "면담자명", "affiliation": "소속" },
    "interview_session": {
      "sessionNo": 1,
      "interviewDate": "2023-01-15T10:00:00Z",
      "location": "서울",
      "interviewType": "oral",
      "language": "ko"
    },
    "classification": { "mainCategory": "정치", "subCategory": "민주화운동" },
    "keywords": ["4.19", "학생운동"],
    "visibility": "public"
  },
  "pii_detected": [
    { "type": "email", "value": "[masked]", "position": "line 5" }
  ]
}
```

### 텍스트 내보내기 형식
```
[구술기록 내보내기]
제목: {title}
기록일: {createdAt}
입력 유형: {inputType}

---[메타데이터]---
구술자: {narrator.name} ({narrator.dateOfBirth}), 직급: {narrator.jobTitle}
면담자: {interviewer.name} ({interviewer.affiliation})
면담 일시: {interviewDate} @ {location}
면담 회차: {sessionNo}차
주제 분류: {mainCategory} > {subCategory}
핵심 키워드: {keywords}
비공개 여부: {visibility}

---[본문]---
{content}

---[PII 감지]---
감지된 항목: {detectedPII.count}건
- 이메일: {count}건
- 전화번호: {count}건
- 인명: {count}건
```

### 대량 내보내기 (배치) [에이전트 자율 추가]
- 필터 후 선택 기록들을 Zip 파일로 압축 내보내기
- Zip 구조: `/records_[timestamp]/record_[id].json` 또는 `.txt`
- 생성 파일명: `oral_records_2023-01-15.zip`

### 백업·복원 전략 [에이전트 자율 추가]
- 로컬 백업: 앱 내 "전체 백업" 메뉴 → Zip 생성 → 사용자 다운로드
- 복원: Zip 파일 선택 → Hive box 초기화 → 복구 (향후)
- 향후: 클라우드 동기화 시 서버 백업 추가

### 휴대성 (Portability) [에이전트 자율 추가]
- JSON/TXT 형식은 다른 기록 관리 시스템으로 전환 가능
- 메타데이터는 ISAD(G), Dublin Core 준용 구조로 설계
