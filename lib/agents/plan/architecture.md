# 아키텍처 설계 (Architecture)

## 전반 구조
- Presentation Layer: Flutter UI (컴포넌트 기반)
- State Layer: Riverpod (Provider/StateNotifier)
- Domain Layer: 서비스/UseCase (transcribe, classify, search 등)
- Data Layer: Hive 저장소 + API 클라이언트 (Claude)

## 주요 패키지 구조
- `lib/src/ui/` : 화면 (Home, RecordDetail, RecordList, Settings, Summary)
- `lib/src/state/` : Riverpod Provider 및 상태
- `lib/src/domain/` : 비즈니스 로직, use-case 함수
- `lib/src/data/` : Hive DAO, 모델 어댑터, Claude API 통합
- `lib/src/core/` : 예외, 로깅, 상수, 유틸리티

## 데이터 흐름
1. UI 호출 -> Riverpod Provider 업데이트
2. StateNotifier/ProviderNotifier에서 Domain Usecase 호출
3. Usecase에서 데이터 레포지토리(Hive/Claude)에 접근
4. 결과 반환 -> UI 갱신

## 는 단위
- `RecordRepository` (Hive CRUD + 인덱스)
- `ClaudeService` (Anthropic Claude REST 클라이언트)
- `PIIService` (detectPII/PIIItem 관리)
- `ExportService` (파일 생성 및 저장)

## 에러 처리 전략
- UI : `AsyncValue`를 활용해 로딩/성공/에러 상태 분기
- 로깅 : Sentry 또는 로컬 로그캠핑(향후)
- 예외 : `AppException` / `NetworkException` / `DBException`

## 테스트 구조
- `test/unit/data` (레포지토리, 모델)
- `test/unit/domain` (usecase)
- `test/widget` (화면)
- `test/integration` (전체 워크플로우)

## 성능·최적화 가이드라인 [에이전트 자율 추가]

### 대량 조회 시 페이징
- 기본 페이지 크기: 20개 기록
- 초기 로드: 첫 페이지만 로드, 스크롤 시 다음 페이지 자동 로드
- 메모리 부족 시: 페이지 크기 감소 (20 → 10 → 5)
- Riverpod: `recordListProvider.family(page: int, pageSize: int)`

### 검색 인덱싱
- 기본 목표: 500건 검색 시 300ms 이내
- Hive 인덱싱:
  - 복합 인덱싱: `(createdAt, narratorId, mainCategory)`
  - 단일 인덱싱: `sessionId`, `visibility`, `interviewDate`
- 쿼리 최적화: 전문 검색(full-text) 대신 메타데이터 기반 필터 우선 적용

### 음성 파일 처리
- 스트리밍 전사: transcribeAudio 호출 시 청크 단위 처리 (향후)
- 현 단계: 전체 파일 업로드 후 전사 (단순성)
- 파일 캐싱: 전사 완료 후 로컬에서 제거 (선택)

### 메모리상 Record 캐싱 [에이전트 자율 추가]
- Riverpod의 `StateNotifier`를 활용해 현재 페이지의 기록만 메모리 유지
- 페이지 변경 시 이전 페이지 메모리 해제
- 단일 기록 상세 조회 후 목록으로 돌아올 때 캐시 재사용

### UI 업데이트 최적화 [에이전트 자율 추가]
- Riverpod의 `AsyncValue` 사용으로 부분 업데이트 (전체 rebuild 방지)
- Provider 재계산 최소화: 필요한 Provider만 watch
- 예: `MetadataForm` 수정 시 `RecordListProvider` 재계산 배제

### 로깅 및 디버깅
- 개발 환경: 전체 로그 출력 (선택 기능)
- 프로덕션: 에러 로그만, Sentry 연동 (향후)
- 성능 프로파일링: Flutter DevTools로 성능 모니터링
