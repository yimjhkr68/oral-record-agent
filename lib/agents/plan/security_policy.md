# 보안 및 비공개 정책

[에이전트 자율 추가] 기록관리 시스템의 필수 요소로 보안 정책 문서 신규 작성

## 접근 제어 (Access Control)

### 비공개 여부 정의
- **공개 (public)**: 모든 사용자 조회 가능
- **비공개 (private)**: 작성자만 조회/편집 가능
- **조건부 공개 (conditional)**: 특정 조건 만족 시 공개 (예: 2년 후 자동 공개)

### 구현 방식
```dart
// 기록 조회 시 접근 제어 로직
bool canViewRecord(Record record, String currentUser) {
  if (record.visibility == 'public') return true;
  if (record.visibility == 'private') return record.recordedBy == currentUser;
  if (record.visibility == 'conditional') {
    // 조건 검사 (예: 시간 기반)
    return checkConditionalPolicy(record);
  }
  return false;
}
```

- searchRecords 실행 시 현재 사용자의 visibility 필터 자동 적용
- 비공개 기록에 대한 접근 시도는 로깅 (감사 추적)

## PII (개인식별정보) 관리

### PII 감지 및 경고
- detectPII 도구로 email, phone, name 등 자동 탐지
- 감지 결과는 Record.detectedPII에 기록
- UI: 감지된 PII 항목 표시, 삭제/마스킹 옵션 제공

### PII 마스킹 전략 [에이전트 자율 추가]
- 메타데이터(구술자명, 면담자명)는 마스킹 불가 (검색 필요)
- 기록 콘텐츠(content)의 PII만 마스킹 처리 가능
- 마스킹 방식: `[email]`, `[phone]`, `[person_name]` 등으로 대체

## 감사 추적 (Audit Trail) [에이전트 자율 추가]

### 기록 이력 관리
- Record 수정 시마다 변경 이력 저장
- 이력 필드: 변경 시각, 변경자, 변경 전/후 내용
- 민감한 필드(visibility, detectedPII) 변경은 필수 기록

### 검색 이력 로깅 [에이전트 자율 추가]
- searchRecords 호출 시 로그: 검색 조건, 결과 수, 시각 (향후 고도화)
- 비공개 기록 접근 시도 기록

## 암호화 [에이전트 자율 추가]
- 향후 적용: 민감한 콘텐츠(PII 많은 기록), 비공개 기록 저장 시 암호화 고려
- 현 단계: 로컬 저장이므로 Hive 기본 암호화 + 향후 전용 암호화 라이브러리 추가

## 데이터 보존 및 삭제 정책 [에이전트 자율 추가]
- 삭제된 기록 자동 복구 불가 (완전 삭제)
- 향후: Soft delete (논리적 삭제) 추가 + 일정 기간 복구 가능하도록 개선
- 메타데이터(Narrator, Session)는 기록 존재 한정으로 관리
