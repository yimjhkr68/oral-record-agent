# Hive 제거 + 이력 관리 기능 추가 Plan

## 변경 방향 요약

```
제거:  Hive DB 연결 관련 코드 전체
유지:  텍스트 직접 입력 / 파일 업로드
추가:  구술기록 입력 이력 관리
추가:  온톨로지 생성 이력 관리
추가:  트리플 생성 대상 + 결과 이력 관리
```

---

## 데이터 모델 설계

### 1. 구술기록 (OralRecord)

```python
@dataclass
class OralRecord:
    id:           str      # uuid 앞 8자
    title:        str      # 사용자 입력 제목 (파일명 또는 직접 입력)
    source_type:  str      # "text" | "file"
    file_name:    str      # 파일 업로드 시 원본 파일명
    content:      str      # 구술 텍스트 전문
    char_count:   int      # 글자 수
    created_at:   str      # 등록 일시
    note:         str      # 메모
```

저장 위치: `data/records/records.json`

---

### 2. 온톨로지 이벤트 (OntologyEvent)

```python
@dataclass
class OntologyEvent:
    id:              str
    event_type:      str   # "created" | "updated" | "confirmed" |
                           # "archived" | "deleted" | "generated" | "merged"
    version_id:      str   # 대상 온톨로지 버전
    detail:          str   # 변경 내용 요약
                           #   generated: "샘플 텍스트 {N}자 기반 AI 생성"
                           #   merged: "Draft [A, B, C] 종합"
                           #   updated: "클래스 {N}개, 속성 {M}개"
                           #   confirmed: "클래스 {N}개, 속성 {M}개 확정"
    before_snapshot: dict  # 변경 전 상태 (update/delete 시)
    after_snapshot:  dict  # 변경 후 상태
    created_at:      str
    user_note:       str   # 사용자 메모
```

저장 위치: `data/history/ontology_events.json`

---

### 3. 트리플 생성 세션 (ExtractionSession)

```python
@dataclass
class ExtractionSession:
    id:                  str
    ontology_version_id: str      # 사용된 온톨로지 버전
    source_record_ids:   list[str]# 대상 구술기록 ID 목록
    status:              str      # "running" | "completed" | "failed"
    total_records:       int      # 처리 대상 수
    processed_records:   int      # 처리 완료 수
    extracted_count:     int      # 추출된 트리플 수 (검토 전)
    confirmed_count:     int      # 확정 저장된 트리플 수
    rejected_count:      int      # 검토 중 삭제된 트리플 수
    modified_count:      int      # 검토 중 수정된 트리플 수
    created_at:          str      # 세션 시작 시각
    completed_at:        str      # 세션 완료 시각
    note:                str
```

저장 위치: `data/history/extraction_sessions.json`

---

## 파일 구조 변경

### 백엔드 변경

```
추가:
  data/records/records.json          ← 구술기록 목록
  data/history/ontology_events.json  ← 온톨로지 이력
  data/history/extraction_sessions.json ← 트리플 생성 세션 이력

  api/router_records.py              ← 구술기록 CRUD API
  api/router_history.py              ← 이력 조회 API
  core/record_store.py               ← 구술기록 파일 영속성
  core/history_store.py              ← 이력 파일 영속성

수정:
  api/router_ontology.py             ← 모든 변경에 이벤트 기록
  api/router_triple.py               ← 세션 생성/완료 기록
  ontology/ontology_manager.py       ← 이벤트 발행 추가

제거:
  api/router_hive.py                 ← 완전 삭제
  core/hive_connector.py             ← 완전 삭제 (있으면)
  pipeline/hive_pipeline.py          ← Hive 연결 부분만 제거
```

### Flutter 변경

```
추가:
  screens/records/
    record_list_screen.dart          ← 구술기록 목록
    record_detail_screen.dart        ← 구술기록 상세 + 이력
  screens/history/
    history_screen.dart              ← 전체 이력 뷰 (탭 구조)
    ontology_history_tab.dart        ← 온톨로지 이벤트 타임라인
    extraction_history_tab.dart      ← 트리플 생성 세션 목록

수정:
  screens/triple/triple_step1_extract.dart
    → Hive DB 탭 제거
    → 저장된 구술기록 선택 탭 추가

  screens/ontology/input_method_bottom_sheet.dart
    → Hive DB 탭 제거
    → 저장된 구술기록 선택 탭 추가

  app.dart
    → 네비게이션에 [기록] [이력] 탭 추가

제거:
  Hive DB 관련 위젯/코드 전체
```

---

## API 설계

### 구술기록 API (router_records.py)

```
POST   /api/records/text
  body: { title, content, note }
  → OralRecord 생성 + records.json 저장

POST   /api/records/file
  body: multipart/form-data (file)
  지원: .txt / .pdf / .docx
  → 텍스트 추출 → OralRecord 생성 + 저장

GET    /api/records/
  ?q=검색어&source_type=text|file
  → 목록 반환 (최신순)

GET    /api/records/{id}
  → 단건 상세 (content 전문 포함)

PATCH  /api/records/{id}
  body: { title, note }
  → 제목/메모만 수정 가능 (content 수정 불가)

DELETE /api/records/{id}
  → 삭제 (트리플 생성에 사용된 기록은 소프트 삭제)

GET    /api/records/{id}/usage
  → 이 기록으로 생성된 ExtractionSession 목록
```

### 이력 API (router_history.py)

```
GET    /api/history/ontology
  ?version_id=&event_type=&limit=50
  → 온톨로지 이벤트 목록 (최신순)

GET    /api/history/ontology/{version_id}
  → 특정 버전의 전체 이력 타임라인

GET    /api/history/extractions
  ?status=&ontology_version=&limit=20
  → 트리플 생성 세션 목록

GET    /api/history/extractions/{session_id}
  → 세션 상세 (처리한 기록 목록 + 결과 통계)

GET    /api/history/summary
  → 전체 요약 통계
    { records: N, ontology_versions: N,
      confirmed_ontologies: N, total_triples: N,
      extraction_sessions: N }
```

---

## Flutter 화면 설계

### 네비게이션 구조 변경

```
현재 4탭:  온톨로지 | 트리플 | 지식그래프 | 설정
변경 6탭:  온톨로지 | 트리플 | 지식그래프 | 기록 | 이력 | 설정
```

---

### 기록 화면 (RecordListScreen)

```
┌─────────────────────────────────────────────────────────┐
│  구술기록                    [+ 텍스트 입력] [+ 파일 업로드] │
├─────────────────────────────────────────────────────────┤
│  검색: [____________]  필터: [전체▼] [텍스트|파일]        │
├─────────────────────────────────────────────────────────┤
│  📄 기록 카드                                            │
│  ┌─────────────────────────────────────────────────┐    │
│  │ [T] 제주 4·3 구술 — 고○○              2026-04-07 │    │
│  │     텍스트 입력 · 1,240자                        │    │
│  │     트리플 생성 2회 · 마지막: 2026-04-07          │    │
│  └─────────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────────┐    │
│  │ [F] 구술채록_2024_001.txt              2026-04-06│    │
│  │     파일 업로드 · 3,820자                        │    │
│  │     트리플 생성 1회                              │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

카드 클릭 → RecordDetailScreen:
```
┌──────────────────────────────────────────────────────────┐
│  제주 4·3 구술 — 고○○                   [수정] [삭제]    │
│  등록: 2026-04-07 · 텍스트 입력 · 1,240자                │
├──────────────────────────────────────────────────────────┤
│  [내용 미리보기]   [트리플 생성 이력]                     │
│                                                          │
│  내용 미리보기 탭:                                       │
│    텍스트 전문 (스크롤)                                  │
│                                                          │
│  트리플 생성 이력 탭:                                    │
│    세션 1: 2026-04-07 · v1.0 · 추출 12개 · 확정 10개    │
│    세션 2: 2026-04-08 · v2.0 · 추출 8개 · 확정 7개      │
└──────────────────────────────────────────────────────────┘
```

---

### 이력 화면 (HistoryScreen)

```
┌──────────────────────────────────────────────────────────┐
│  [온톨로지 이력] [트리플 생성 이력]                       │
├──────────────────────────────────────────────────────────┤

온톨로지 이력 탭 (타임라인):
  ● 2026-04-08  v2.0  확정됨
    클래스 8개, 속성 12개 확정
  ○ 2026-04-08  v2.0  클래스 수정
    Person 설명 변경
  ○ 2026-04-07  v2.0  Draft 종합 생성
    draft-A, draft-B 종합
  ● 2026-04-07  v1.0  확정됨
    클래스 5개, 속성 7개 확정
  ○ 2026-04-07  draft-B  AI 생성
    샘플 텍스트 820자 기반

트리플 생성 이력 탭 (세션 목록):
  세션 카드
  ┌────────────────────────────────────────────────────┐
  │ 2026-04-08  v2.0  완료                             │
  │ 구술기록 3개 처리                                  │
  │ 추출 24개 → 확정 21개 · 삭제 2개 · 수정 1개       │
  │ 소요 시간: 2분 34초                                │
  └────────────────────────────────────────────────────┘
  세션 클릭 → 세션 상세:
    처리한 기록 목록
    각 기록별 추출 트리플 수
    확정/삭제/수정 내역
```

---

### 트리플 Step 1 변경 (Hive 제거)

```
현재 탭: [텍스트 입력] [파일 업로드] [Hive DB]
변경 탭: [텍스트 입력] [파일 업로드] [저장된 기록 선택]

[저장된 기록 선택] 탭:
  검색창 + 기록 목록 (data/records/records.json 에서)
  체크박스로 복수 선택
  → 선택 목록에 추가
```

---

## 구현 순서

### Phase 1 — 백엔드 정리 + 구술기록 관리

```
P1-1. Hive 코드 제거
      - api/router_hive.py 삭제
      - core/hive_connector.py 삭제 (있으면)
      - pipeline/hive_pipeline.py Hive 연결 부분 제거
      - main.py 에서 hive router include 제거
      - requirements.txt 에서 pyhive 등 제거

P1-2. core/record_store.py 구현
      - OralRecord 데이터클래스
      - data/records/records.json 파일 영속성
      - CRUD + 검색

P1-3. api/router_records.py 구현
      - POST /api/records/text
      - POST /api/records/file (텍스트 추출 포함)
      - GET  /api/records/
      - GET  /api/records/{id}
      - PATCH /api/records/{id}
      - DELETE /api/records/{id}

P1-4. 파일 텍스트 추출
      - .txt: 직접 읽기
      - .pdf: pypdf2 또는 pdfplumber
      - .docx: python-docx

P1-5. 테스트
      - tests/test_record_store.py
```

### Phase 2 — 이력 관리 백엔드

```
P2-1. core/history_store.py 구현
      - OntologyEvent, ExtractionSession 데이터클래스
      - 파일 영속성

P2-2. ontology_manager.py 이벤트 발행 추가
      - create() → "created" 이벤트
      - update() → "updated" 이벤트 (before/after 스냅샷)
      - confirm() → "confirmed" 이벤트
      - archive() → "archived" 이벤트
      - generate_from_sample() → "generated" 이벤트
      - merge_drafts() → "merged" 이벤트

P2-3. triple_manager.py 세션 관리 추가
      - 추출 시작: ExtractionSession 생성 (status=running)
      - 추출 완료: extracted_count 업데이트
      - 확정 저장: confirmed/rejected/modified_count 업데이트
      - 세션 완료: status=completed, completed_at 기록

P2-4. api/router_history.py 구현
      - GET /api/history/ontology
      - GET /api/history/ontology/{version_id}
      - GET /api/history/extractions
      - GET /api/history/extractions/{session_id}
      - GET /api/history/summary
```

### Phase 3 — Flutter UI

```
P3-1. 기록 화면 (RecordListScreen + RecordDetailScreen)
      - 목록: 카드 + 검색 + 필터
      - 텍스트 입력 다이얼로그
      - 파일 업로드
      - 상세: 내용 미리보기 + 트리플 생성 이력

P3-2. 이력 화면 (HistoryScreen)
      - 온톨로지 이력 타임라인
      - 트리플 생성 세션 목록 + 상세

P3-3. 앱 네비게이션 6탭으로 확장

P3-4. 트리플 Step 1 변경
      - Hive DB 탭 → 저장된 기록 선택 탭
      - GET /api/records/ 에서 목록 가져와서 체크박스 선택
```

---

## 완료 기준

```
Phase 1:
  □ Hive 관련 코드 전체 삭제 확인
  □ POST /api/records/text → 저장 → GET 조회 성공
  □ POST /api/records/file (.txt) → 텍스트 추출 → 저장 성공
  □ data/records/records.json 파일 생성 확인

Phase 2:
  □ 온톨로지 Draft 생성 → data/history/ontology_events.json 이벤트 기록
  □ 온톨로지 confirm → 이벤트 기록
  □ 트리플 추출 → ExtractionSession 생성 → 완료 시 통계 업데이트
  □ GET /api/history/summary → 정확한 통계 반환

Phase 3:
  □ 기록 화면: 등록 → 목록 표시 → 상세 조회
  □ 이력 화면: 온톨로지 타임라인 표시
  □ 트리플 Step 1: 저장된 기록 선택 탭 동작
  □ 전체 플로우:
      기록 등록 → 온톨로지 선택 → 트리플 생성
      → 검토 → 확정 → 이력에서 세션 확인
```

---

## 제약 조건

```
- Phase 1 완료 확인 후 Phase 2 시작 (단계별 승인)
- Hive 코드 제거 시 pipeline/hive_pipeline.py 는
  클래스 구조는 유지하되 연결 부분만 제거
  (향후 다른 DB 연결로 교체 가능하게)
- 이력은 추가만 가능, 수정/삭제 불가
  (불변 감사 로그 성격)
- 기존 백엔드 테스트(54개) 통과 유지
- Flutter 기존 온톨로지 관리 기능 영향 없어야 함
```

---

## Plan 검토 후 보고 요청

```
1. 네비게이션 6탭 확장 동의 여부
   현재: 온톨로지 | 트리플 | 지식그래프 | 설정
   제안: 온톨로지 | 트리플 | 지식그래프 | 기록 | 이력 | 설정

2. 구술기록 content 수정 허용 여부
   현재 설계: 제목/메모만 수정, content 는 불변
   → 잘못 입력 시 삭제 후 재등록

3. 이력 데이터 보존 기간
   현재 설계: 영구 보존
   → 용량 관리가 필요하면 최근 N개 유지 옵션 추가 가능

보고 후 승인하면 Phase 1부터 시작.
```
