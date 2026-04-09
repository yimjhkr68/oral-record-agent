# Hive 제거 + 이력 관리 기능 추가 Plan (SQLite 버전)

## 저장 방식 확정

```
저장소: SQLite (data/oral_record_agent.db 파일 하나)
규모:   구술기록 100건 이하 · 트리플 수천 건
이유:   JSON 대비 검색 빠름, 트랜잭션 안전, 파일 하나로 관리
```

---

## DB 스키마 설계

### 테이블 구조 전체

```sql
-- 1. 구술기록
CREATE TABLE oral_records (
    id           TEXT PRIMARY KEY,
    title        TEXT NOT NULL,
    source_type  TEXT NOT NULL CHECK(source_type IN ('text','file')),
    file_name    TEXT DEFAULT '',
    content      TEXT NOT NULL,
    char_count   INTEGER DEFAULT 0,
    note         TEXT DEFAULT '',
    created_at   TEXT NOT NULL,
    is_deleted   INTEGER DEFAULT 0   -- 소프트 삭제
);

-- 2. 온톨로지 이벤트 이력
CREATE TABLE ontology_events (
    id              TEXT PRIMARY KEY,
    event_type      TEXT NOT NULL,
    -- created / updated / confirmed / archived / deleted
    -- generated / merged
    version_id      TEXT NOT NULL,
    detail          TEXT DEFAULT '',
    before_snapshot TEXT DEFAULT '',   -- JSON 문자열
    after_snapshot  TEXT DEFAULT '',   -- JSON 문자열
    created_at      TEXT NOT NULL,
    user_note       TEXT DEFAULT ''
);

-- 3. 트리플 생성 세션
CREATE TABLE extraction_sessions (
    id                   TEXT PRIMARY KEY,
    ontology_version_id  TEXT NOT NULL,
    status               TEXT DEFAULT 'running',
    -- running / completed / failed
    total_records        INTEGER DEFAULT 0,
    processed_records    INTEGER DEFAULT 0,
    extracted_count      INTEGER DEFAULT 0,
    confirmed_count      INTEGER DEFAULT 0,
    rejected_count       INTEGER DEFAULT 0,
    modified_count       INTEGER DEFAULT 0,
    note                 TEXT DEFAULT '',
    created_at           TEXT NOT NULL,
    completed_at         TEXT DEFAULT ''
);

-- 4. 세션-기록 연결 (다대다)
CREATE TABLE session_records (
    session_id  TEXT NOT NULL,
    record_id   TEXT NOT NULL,
    extracted   INTEGER DEFAULT 0,   -- 해당 기록에서 추출된 트리플 수
    PRIMARY KEY (session_id, record_id)
);

-- 인덱스
CREATE INDEX idx_records_created    ON oral_records(created_at DESC);
CREATE INDEX idx_events_version     ON ontology_events(version_id);
CREATE INDEX idx_events_created     ON ontology_events(created_at DESC);
CREATE INDEX idx_sessions_created   ON extraction_sessions(created_at DESC);
CREATE INDEX idx_session_records    ON session_records(session_id);
```

---

## 파일 구조

### 백엔드 변경

```
추가:
  core/database.py              ← SQLite 연결 + 초기화
  core/record_store.py          ← 구술기록 CRUD
  core/history_store.py         ← 이력 CRUD
  api/router_records.py         ← 구술기록 API
  api/router_history.py         ← 이력 조회 API

수정:
  ontology/ontology_manager.py  ← 모든 변경에 이벤트 기록 추가
  api/router_triple.py          ← 세션 생성/완료 기록 추가
  main.py                       ← 신규 router 등록, DB 초기화

제거:
  api/router_hive.py
  core/hive_connector.py (있으면)
  pipeline/hive_pipeline.py 의 Hive 연결 코드
```

### Flutter 변경

```
추가:
  screens/records/
    record_list_screen.dart
    record_detail_screen.dart
  screens/history/
    history_screen.dart
    ontology_history_tab.dart
    extraction_history_tab.dart
  api/record_api.dart
  api/history_api.dart
  models/oral_record.dart
  models/history.dart
  providers/record_provider.dart
  providers/history_provider.dart

수정:
  app.dart                      ← 6탭 네비게이션
  screens/triple/triple_step1_extract.dart
    → Hive DB 탭 제거
    → 저장된 기록 선택 탭 추가
  screens/ontology/input_method_bottom_sheet.dart
    → Hive DB 탭 제거
    → 저장된 기록 선택 탭 추가

제거:
  Hive DB 관련 위젯/코드 전체
```

---

## 백엔드 구현 명세

### core/database.py

```python
"""SQLite 연결 + 테이블 초기화"""
import sqlite3
import os
from pathlib import Path

DB_PATH = os.environ.get("DB_PATH", "data/oral_record_agent.db")

def get_connection() -> sqlite3.Connection:
    """연결 반환. Row 팩토리 설정으로 dict 처럼 사용."""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")   # 동시 읽기 성능
    conn.execute("PRAGMA foreign_keys=ON")
    return conn

def init_db():
    """앱 시작 시 테이블 없으면 생성."""
    Path(DB_PATH).parent.mkdir(parents=True, exist_ok=True)
    conn = get_connection()
    with conn:
        conn.executescript("""
            CREATE TABLE IF NOT EXISTS oral_records ( ... );
            CREATE TABLE IF NOT EXISTS ontology_events ( ... );
            CREATE TABLE IF NOT EXISTS extraction_sessions ( ... );
            CREATE TABLE IF NOT EXISTS session_records ( ... );
            -- 위 스키마 전체 적용
        """)
    conn.close()
```

### core/record_store.py

```python
class RecordStore:

    def create_text(self, title: str, content: str,
                    note: str = "") -> dict:
        """텍스트 직접 입력으로 기록 생성."""

    def create_file(self, file_name: str, content: str,
                    note: str = "") -> dict:
        """파일 업로드로 기록 생성. 제목은 파일명에서 자동 설정."""

    def list(self, query: str = "",
             source_type: str = "",
             limit: int = 100) -> list[dict]:
        """목록 조회. 최신순. 소프트 삭제 제외."""

    def get(self, record_id: str) -> dict | None:
        """단건 조회. content 전문 포함."""

    def update(self, record_id: str,
               title: str = None, note: str = None) -> dict:
        """제목/메모만 수정. content 수정 불가."""

    def delete(self, record_id: str) -> bool:
        """소프트 삭제 (is_deleted=1)."""

    def get_usage(self, record_id: str) -> list[dict]:
        """이 기록이 사용된 ExtractionSession 목록."""
```

### core/history_store.py

```python
class HistoryStore:

    # ── 온톨로지 이벤트 ─────────────────────────────────────

    def record_ontology_event(
        self,
        event_type: str,
        version_id: str,
        detail: str = "",
        before: dict = None,
        after: dict = None,
        user_note: str = ""
    ) -> dict:
        """이벤트 기록. 추가만 가능, 수정/삭제 없음."""

    def list_ontology_events(
        self,
        version_id: str = "",
        event_type: str = "",
        limit: int = 50
    ) -> list[dict]:
        """온톨로지 이벤트 목록 (최신순)."""

    def get_version_timeline(self, version_id: str) -> list[dict]:
        """특정 버전의 전체 이력 타임라인."""

    # ── 트리플 생성 세션 ─────────────────────────────────────

    def create_session(
        self,
        ontology_version_id: str,
        record_ids: list[str],
        note: str = ""
    ) -> dict:
        """세션 시작. status=running."""

    def update_session_progress(
        self,
        session_id: str,
        processed_records: int,
        extracted_count: int
    ) -> None:
        """추출 진행 중 업데이트."""

    def complete_session(
        self,
        session_id: str,
        confirmed: int,
        rejected: int,
        modified: int
    ) -> dict:
        """세션 완료. status=completed, completed_at 기록."""

    def fail_session(self, session_id: str, error: str) -> None:
        """세션 실패."""

    def list_sessions(
        self,
        status: str = "",
        ontology_version: str = "",
        limit: int = 20
    ) -> list[dict]:
        """세션 목록 (최신순)."""

    def get_session_detail(self, session_id: str) -> dict:
        """세션 상세 + 처리한 기록 목록."""

    # ── 요약 통계 ────────────────────────────────────────────

    def get_summary(self) -> dict:
        """
        전체 요약:
        {
          records: N,
          ontology_versions: N,
          confirmed_ontologies: N,
          total_triples: N,
          extraction_sessions: N,
          last_activity: "2026-04-09"
        }
        """
```

### ontology_manager.py — 이벤트 발행 추가

```python
# 기존 메서드에 이벤트 발행 코드 추가

def create(self, version_id, description=""):
    version = ...  # 기존 로직
    history_store.record_ontology_event(
        event_type="created",
        version_id=version_id,
        detail=f"Draft 생성: {description}"
    )
    return version

def confirm(self, version_id):
    version = ...  # 기존 로직
    history_store.record_ontology_event(
        event_type="confirmed",
        version_id=version_id,
        detail=f"클래스 {len(version.classes)}개, "
               f"속성 {len(version.predicates)}개 확정",
        after=asdict(version)
    )
    return version

def generate_from_sample(self, sample_text, base_version_id=None):
    version = ...  # 기존 로직
    history_store.record_ontology_event(
        event_type="generated",
        version_id=version.version_id,
        detail=f"샘플 텍스트 {len(sample_text)}자 기반 AI 생성"
               + (f" (기반: {base_version_id})" if base_version_id else "")
    )
    return version

# update(), archive(), merge_drafts() 도 동일 패턴
```

### router_triple.py — 세션 관리 추가

```python
@router.post("/extract")
def extract_triples(data: dict):
    session = history_store.create_session(
        ontology_version_id=data["ontology_version_id"],
        record_ids=[data.get("source_record_id", "")]
    )
    try:
        result = triple_extractor.extract(...)

        history_store.update_session_progress(
            session["id"],
            processed_records=1,
            extracted_count=result["added"] + result["skipped"]
        )
        return {**result, "session_id": session["id"]}

    except Exception as e:
        history_store.fail_session(session["id"], str(e))
        raise

@router.post("/bulk-confirm")
def bulk_confirm(data: dict):
    result = triple_manager.bulk_confirm(data["triple_ids"])

    if session_id := data.get("session_id"):
        history_store.complete_session(
            session_id=session_id,
            confirmed=result["confirmed"],
            rejected=data.get("rejected_count", 0),
            modified=data.get("modified_count", 0)
        )
    return result
```

---

## API 설계

### 구술기록 API

```
POST   /api/records/text
  body: { "title": "...", "content": "...", "note": "" }

POST   /api/records/file
  multipart: file (지원: .txt .pdf .docx)
  → 텍스트 자동 추출

GET    /api/records/?q=&source_type=
GET    /api/records/{id}
PATCH  /api/records/{id}   body: { "title", "note" }
DELETE /api/records/{id}
GET    /api/records/{id}/usage
```

### 이력 API

```
GET    /api/history/ontology?version_id=&event_type=&limit=
GET    /api/history/ontology/{version_id}/timeline
GET    /api/history/extractions?status=&ontology_version=&limit=
GET    /api/history/extractions/{session_id}
GET    /api/history/summary
```

---

## Flutter 화면 설계

### 네비게이션 6탭

```
온톨로지 | 트리플 | 지식그래프 | 기록 | 이력 | 설정
```

### 기록 화면

```
┌──────────────────────────────────────────────────┐
│ 구술기록          [+ 텍스트 입력] [+ 파일 업로드] │
├──────────────────────────────────────────────────┤
│ 검색: [__________]  [전체 ▼] [텍스트|파일]       │
├──────────────────────────────────────────────────┤
│ [T] 제주 4·3 구술 — 고○○           2026-04-07   │
│     1,240자 · 트리플 생성 2회                    │
│                                                  │
│ [F] 구술채록_001.txt                2026-04-06   │
│     3,820자 · 트리플 생성 1회                    │
└──────────────────────────────────────────────────┘
```

기록 클릭 → 상세 화면:
```
┌──────────────────────────────────────────────────┐
│ 제주 4·3 구술 — 고○○            [수정] [삭제]   │
│ 2026-04-07 · 텍스트 · 1,240자                   │
├──────────────────────────────────────────────────┤
│ [내용 미리보기]        [트리플 생성 이력]         │
│                                                  │
│ 내용 탭: 텍스트 전문 스크롤                      │
│                                                  │
│ 이력 탭:                                         │
│  2026-04-08  v2.0  추출 8개 · 확정 7개          │
│  2026-04-07  v1.0  추출 12개 · 확정 10개        │
└──────────────────────────────────────────────────┘
```

### 이력 화면

```
┌──────────────────────────────────────────────────┐
│ [온톨로지 이력]      [트리플 생성 이력]           │
├──────────────────────────────────────────────────┤
온톨로지 이력 탭:
  ● 2026-04-08  v2.0  확정됨
    클래스 8개, 속성 12개 확정
  ─
  ○ 2026-04-08  v2.0  클래스 수정
    Person 설명 변경
  ─
  ○ 2026-04-07  v2.0  Draft 종합 생성
    draft-A, draft-B 종합
  ─
  ● 2026-04-07  v1.0  확정됨

트리플 생성 이력 탭:
  2026-04-08  v2.0  완료
  기록 3건 · 추출 24개 → 확정 21개
  ─
  2026-04-07  v1.0  완료
  기록 1건 · 추출 12개 → 확정 10개
```

### 트리플 Step 1 — 입력 방법 탭 변경

```
현재: [텍스트 입력] [파일 업로드] [Hive DB]
변경: [텍스트 입력] [파일 업로드] [저장된 기록 선택]

[저장된 기록 선택] 탭:
  GET /api/records/ → 목록 표시
  체크박스 복수 선택
  → 선택 목록에 추가
```

---

## 구현 순서

```
Phase 1 — 백엔드 기반
  P1-1. requirements.txt: sqlalchemy 또는 sqlite3 직접 사용 확인
  P1-2. core/database.py: SQLite 연결 + 테이블 초기화
  P1-3. core/record_store.py: 구술기록 CRUD
  P1-4. core/history_store.py: 이력 CRUD
  P1-5. api/router_records.py: 구술기록 API
  P1-6. api/router_history.py: 이력 조회 API
  P1-7. main.py: DB 초기화 + router 등록
  P1-8. Hive 코드 전체 제거
  P1-9. tests/test_record_store.py + test_history_store.py

Phase 2 — 기존 기능 이력 연동
  P2-1. ontology_manager.py: 이벤트 발행 추가
  P2-2. router_triple.py: 세션 관리 추가
  P2-3. bulk-confirm API: session_id 처리 추가
  P2-4. 통합 테스트

Phase 3 — Flutter UI
  P3-1. models/oral_record.dart + models/history.dart
  P3-2. api/record_api.dart + api/history_api.dart
  P3-3. providers/record_provider.dart + providers/history_provider.dart
  P3-4. screens/records/: 기록 목록 + 상세
  P3-5. screens/history/: 이력 화면 (온톨로지 + 트리플 생성)
  P3-6. app.dart: 6탭 네비게이션
  P3-7. triple_step1: Hive 탭 → 저장된 기록 탭
  P3-8. input_method_bottom_sheet: Hive 탭 제거
```

---

## 완료 기준

```
Phase 1:
  □ data/oral_record_agent.db 파일 자동 생성
  □ POST /api/records/text → DB 저장 → GET 조회 성공
  □ POST /api/records/file (.txt) → 텍스트 추출 → 저장
  □ Hive 관련 코드 없음 확인 (grep hive)
  □ 기존 54개 테스트 통과

Phase 2:
  □ 온톨로지 confirm → ontology_events 테이블 기록 확인
  □ 트리플 추출 → extraction_sessions 세션 생성 확인
  □ 확정 저장 → 세션 completed 상태 확인
  □ GET /api/history/summary → 정확한 통계

Phase 3:
  □ 기록 등록 → 목록 → 상세 화면 흐름
  □ 이력 화면: 온톨로지 타임라인 표시
  □ 트리플 Step 1: 저장된 기록 선택 탭 동작
  □ 전체 플로우: 기록 등록 → 온톨로지 선택 → 트리플 생성
    → 확정 → 이력에서 세션 확인
```

---

## 제약 조건

```
- sqlite3 는 Python 내장 — 별도 패키지 설치 불필요
- Phase 1 완료 확인 후 Phase 2 시작
- 이력 데이터는 INSERT 만 가능, UPDATE/DELETE 금지
- 기존 data/triples/graph.json 은 유지
  (트리플 데이터는 계속 JSON 파일 사용)
- DB 파일 경로: data/oral_record_agent.db
- .gitignore 에 data/*.db 추가
```
