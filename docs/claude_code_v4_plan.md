# v4.0 지식그래프 기능 추가 — Plan (PDCA 1단계)

## 개요

v3.0 구술기록관리 에이전트에 지식그래프 기능을 추가한다.
이 문서는 **Plan** 단계로, 구현 전 전체 설계를 확정한다.
코드 작성 전에 이 Plan을 완전히 이해하고, 불명확한 부분은 나에게 먼저 질문해라.

---

## 목표 기능 6가지

```
F1. 온톨로지 CRUDA       — 온톨로지 생성·조회·수정·삭제·아카이브
F2. 온톨로지 자동 생성   — 구술 샘플 텍스트 → AI가 온톨로지 초안 생성
F3. 온톨로지 버전 확정   — 버전별 확정(Confirmed) 관리
F4. 트리플 생성          — 확정된 온톨로지 + 구술자료 → 트리플 추출
F5. 트리플 CRUDA         — 트리플 생성·조회·수정·삭제·아카이브
F6. 지식 검색 UI         — 전체 그래프 시각화 + 검색 시 노드 확대
```

---

## 아키텍처 설계

### 전체 구조

```
src/v4/
├── ontology/
│   ├── ontology.py          ← (기존) 기본 상수
│   ├── ontology_manager.py  ← [신규] OntologyManager — F1·F2·F3
│   └── ontology_store.py    ← [신규] 온톨로지 파일 영속성
│
├── graph/
│   ├── triple_store.py      ← (기존) 인메모리 TripleStore — F5 확장
│   ├── triple_manager.py    ← [신규] TripleManager — CRUDA 비즈니스 로직
│   └── graph_db.py          ← [신규] GraphDB — 로컬 파일 영속성
│
├── pipeline/
│   ├── hive_pipeline.py     ← (기존)
│   └── triple_extractor.py  ← [신규] 확정 온톨로지 기반 트리플 추출 — F4
│
├── api/
│   ├── __init__.py
│   ├── router_ontology.py   ← [신규] 온톨로지 API 엔드포인트
│   ├── router_triple.py     ← [신규] 트리플 API 엔드포인트
│   └── router_search.py     ← [신규] 검색 API 엔드포인트
│
├── ui/
│   ├── OntologyManager.jsx  ← [신규] 온톨로지 CRUDA 화면 — F1·F2·F3
│   ├── TripleManager.jsx    ← [신규] 트리플 CRUDA 화면 — F4·F5
│   └── KnowledgeGraph.jsx   ← [신규] 전체 그래프 + 검색 화면 — F6
│
└── utils/
    └── file_io.py           ← [신규] 공통 파일 I/O 유틸

data/v4/                     ← 로컬 영속성 저장소
├── ontologies/
│   ├── v1.0.json
│   ├── v1.1.json
│   └── confirmed/
│       └── v1.0.json        ← 확정된 버전 (읽기 전용)
└── triples/
    ├── graph.json           ← 전체 트리플 그래프
    └── archive/
        └── [archived_id].json

tests/v4/
├── test_ontology_manager.py ← [신규]
├── test_triple_manager.py   ← [신규]
├── test_graph_db.py         ← [신규]
├── test_triple_store.py     ← (기존)
└── test_ontology.py         ← (기존)
```

### 데이터 흐름

```
[구술 샘플 텍스트]
      │
      ▼ F2
[OntologyManager.generate_from_sample()]  ── AI API ──▶ 온톨로지 초안
      │
      ▼ F3
[OntologyManager.confirm_version()]  ──▶ data/v4/ontologies/confirmed/vX.json
      │
      ▼ F4
[TripleExtractor.extract(content, ontology_version)]  ── AI API ──▶ Triple[]
      │
      ▼ F5
[TripleManager.add() / update() / delete() / archive()]
      │
      ▼
[GraphDB.save()]  ──▶ data/v4/triples/graph.json  (로컬 파일 영속성)
      │
      ▼ F6
[KnowledgeGraph UI]  ◀── GraphDB.load() / search()
```

---

## 데이터 모델 상세

### OntologyVersion

```python
# src/v4/ontology/ontology_manager.py

from enum import Enum
from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional

class OntologyStatus(str, Enum):
    DRAFT     = "draft"      # 편집 가능
    CONFIRMED = "confirmed"  # 확정 — 수정 불가, 트리플 생성에 사용
    ARCHIVED  = "archived"   # 보관 — 조회만 가능

@dataclass
class OntologyClass:
    name:        str                    # 예: "Person"
    label_ko:    str                    # 예: "인물"
    color:       str                    # 예: "#f59e0b"
    description: str = ""
    examples:    list[str] = field(default_factory=list)

@dataclass
class OntologyPredicate:
    name:        str                    # 예: "출생지"
    domain:      list[str] = field(default_factory=list)   # 허용 주어 타입
    range_:      list[str] = field(default_factory=list)   # 허용 목적어 타입
    description: str = ""

@dataclass
class OntologyVersion:
    version_id:   str                   # 예: "v1.0"
    status:       OntologyStatus = OntologyStatus.DRAFT
    classes:      list[OntologyClass]      = field(default_factory=list)
    predicates:   list[OntologyPredicate]  = field(default_factory=list)
    created_at:   str = field(default_factory=lambda: datetime.now().isoformat())
    confirmed_at: Optional[str] = None
    description:  str = ""
    based_on:     Optional[str] = None  # 이전 버전 ID (파생 시)
```

### Triple (확장)

```python
# src/v4/graph/triple_manager.py

from enum import Enum
from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional
import uuid

class TripleStatus(str, Enum):
    ACTIVE   = "active"
    ARCHIVED = "archived"

@dataclass
class Triple:
    id:                str = field(default_factory=lambda: str(uuid.uuid4())[:8])
    subject:           str = ""
    subject_type:      str = ""
    predicate:         str = ""
    object:            str = ""
    object_type:       str = ""
    ontology_version:  str = ""          # 생성에 사용된 온톨로지 버전
    source_record_id:  Optional[str] = None
    confidence:        float = 1.0
    status:            TripleStatus = TripleStatus.ACTIVE
    created_at:        str = field(default_factory=lambda: datetime.now().isoformat())
    updated_at:        Optional[str] = None
    archived_at:       Optional[str] = None
    note:              str = ""          # 수동 편집 메모
```

### GraphDB 저장 포맷 (graph.json)

```json
{
  "version": "4.0",
  "last_updated": "2025-01-01T00:00:00",
  "stats": { "nodes": 0, "triples": 0 },
  "nodes": {
    "김영수": { "id": "김영수", "type": "Person", "degree": 3 }
  },
  "triples": [
    {
      "id": "a1b2c3d4",
      "subject": "김영수",
      "subject_type": "Person",
      "predicate": "출생지",
      "object": "경상북도 안동",
      "object_type": "Place",
      "ontology_version": "v1.0",
      "source_record_id": "rec_001",
      "confidence": 1.0,
      "status": "active",
      "created_at": "2025-01-01T00:00:00",
      "updated_at": null,
      "archived_at": null,
      "note": ""
    }
  ]
}
```

---

## 구현 명세 — 모듈별

### M1. OntologyManager (F1·F2·F3)

```python
# src/v4/ontology/ontology_manager.py

class OntologyManager:

    # ── CRUDA ─────────────────────────────────────────────
    def create(self, version_id: str, description: str = "") -> OntologyVersion:
        """새 Draft 온톨로지 생성. version_id 중복 시 ValueError."""

    def get(self, version_id: str) -> OntologyVersion:
        """버전 조회. 없으면 KeyError."""

    def list_all(self) -> list[OntologyVersion]:
        """전체 버전 목록 (최신순)."""

    def update(self, version_id: str, classes=None, predicates=None,
               description=None) -> OntologyVersion:
        """Draft 상태만 수정 가능. Confirmed/Archived 시 PermissionError."""

    def delete(self, version_id: str) -> None:
        """Draft 상태만 삭제 가능."""

    def archive(self, version_id: str) -> OntologyVersion:
        """Confirmed → Archived. 되돌릴 수 없음."""

    # ── AI 자동 생성 (F2) ─────────────────────────────────
    def generate_from_sample(self, sample_text: str,
                              base_version_id: str = None) -> OntologyVersion:
        """
        구술 샘플 텍스트 → AI 분석 → OntologyVersion(Draft) 생성 및 저장.
        base_version_id 가 있으면 해당 버전을 기반으로 확장 제안.
        반환: 새로 생성된 Draft OntologyVersion
        """

    # ── 버전 확정 (F3) ────────────────────────────────────
    def confirm(self, version_id: str) -> OntologyVersion:
        """
        Draft → Confirmed. 되돌릴 수 없음.
        확정 시: data/v4/ontologies/confirmed/[version_id].json 에 복사본 저장.
        """

    def get_confirmed_versions(self) -> list[OntologyVersion]:
        """Confirmed 상태 버전만 반환."""

    def get_latest_confirmed(self) -> Optional[OntologyVersion]:
        """가장 최근 Confirmed 버전. 없으면 None."""
```

**generate_from_sample() AI 프롬프트 설계:**

```
system: |
  너는 구술기록 아카이브 전문가다.
  제공된 구술 텍스트 샘플을 분석하여 지식그래프 온톨로지를 제안해라.

  반드시 다음 JSON 형식으로만 응답해:
  {
    "classes": [
      {
        "name": "영문 클래스명 (PascalCase)",
        "label_ko": "한국어 레이블",
        "color": "#hex색상",
        "description": "정의",
        "examples": ["예시1", "예시2"]
      }
    ],
    "predicates": [
      {
        "name": "속성명 (한국어 동사형)",
        "domain": ["허용 주어 클래스"],
        "range_": ["허용 목적어 클래스"],
        "description": "의미 설명"
      }
    ]
  }

  기존 온톨로지({base_ontology})가 있으면 그것을 기반으로 확장 제안해라.
  텍스트에서 실제로 등장하는 개념만 포함해라.

user: [sample_text]
```

---

### M2. TripleManager + GraphDB (F4·F5·영속성)

```python
# src/v4/graph/triple_manager.py

class TripleManager:

    def __init__(self, graph_db: GraphDB):
        self.db = graph_db

    # ── CRUDA ─────────────────────────────────────────────
    def create(self, subject, subject_type, predicate, object_,
               object_type, ontology_version, source_record_id=None,
               confidence=1.0, note="") -> Triple:
        """트리플 생성. 중복(S+P+O) 시 기존 것 반환."""

    def get(self, triple_id: str) -> Triple:
        """ID로 단건 조회."""

    def search(self, query: str = "", ontology_version: str = None,
               status: TripleStatus = TripleStatus.ACTIVE) -> dict:
        """
        검색어 기반 서브그래프 반환 (1홉 이웃 포함).
        query가 없으면 전체 그래프.
        반환: {"nodes": [...], "triples": [...]}
        """

    def update(self, triple_id: str, predicate=None, object_=None,
               object_type=None, confidence=None, note=None) -> Triple:
        """트리플 수정. updated_at 자동 갱신."""

    def delete(self, triple_id: str) -> None:
        """영구 삭제."""

    def archive(self, triple_id: str, reason: str = "") -> Triple:
        """Active → Archived. archived_at 기록."""

    def bulk_create(self, triples: list[dict],
                    ontology_version: str,
                    source_record_id: str = None) -> dict:
        """
        배치 생성. 중복 제외 후 삽입.
        반환: {"added": N, "skipped": N, "triples": [...]}
        """

    def stats(self) -> dict:
        """{"nodes": N, "triples": N, "active": N, "archived": N}"""
```

```python
# src/v4/graph/graph_db.py

class GraphDB:
    """
    인메모리 트리플 스토어 + 로컬 파일 영속성.
    모든 mutation 후 자동으로 graph.json 저장.
    """

    GRAPH_FILE = "data/v4/triples/graph.json"

    def __init__(self, auto_save: bool = True):
        self.auto_save = auto_save
        self._triples: dict[str, Triple] = {}   # id → Triple
        self._nodes: dict[str, dict] = {}        # node_id → {type, degree}
        self._load()                             # 시작 시 파일에서 로드

    def _load(self) -> None:
        """graph.json 파일이 있으면 로드. 없으면 빈 상태로 시작."""

    def _save(self) -> None:
        """graph.json 에 전체 상태 저장. auto_save=True 일 때 mutation 후 자동 호출."""

    def add(self, triple: Triple) -> bool: ...
    def get(self, triple_id: str) -> Optional[Triple]: ...
    def update(self, triple_id: str, **kwargs) -> Optional[Triple]: ...
    def remove(self, triple_id: str) -> bool: ...
    def query(self, search: str = "", include_archived: bool = False) -> dict: ...
    def all_triples(self, include_archived: bool = False) -> list[Triple]: ...
    def stats(self) -> dict: ...
    def export_json(self) -> str: ...
    def force_save(self) -> None: ...
```

---

### M3. TripleExtractor (F4)

```python
# src/v4/pipeline/triple_extractor.py

class TripleExtractor:
    """
    확정된 온톨로지 버전 기반으로 구술자료에서 트리플 추출.
    OntologyManager에서 confirmed 버전을 가져와 AI 프롬프트에 주입.
    """

    def __init__(self, ontology_manager: OntologyManager,
                 triple_manager: TripleManager):
        self.om = ontology_manager
        self.tm = triple_manager
        self.client = anthropic.Anthropic()

    def extract(self, content: str, ontology_version_id: str,
                source_record_id: str = None) -> dict:
        """
        1. version_id 로 OntologyVersion 조회 (Confirmed 아니면 ValueError)
        2. 해당 온톨로지 클래스/속성을 AI 프롬프트에 주입
        3. AI 호출 → 트리플 JSON 파싱
        4. TripleManager.bulk_create() 로 저장
        반환: {"added": N, "skipped": N, "triples": [...]}
        """

    def _build_prompt(self, ontology: OntologyVersion) -> str:
        """확정 온톨로지 기반 동적 시스템 프롬프트 생성."""
        classes_desc = "\n".join(
            f"- {c.name} ({c.label_ko}): {c.description}"
            for c in ontology.classes
        )
        predicates_desc = "\n".join(
            f"- {p.name}: {p.description} [도메인: {p.domain} → 범위: {p.range_}]"
            for p in ontology.predicates
        )
        return f"""당신은 구술기록 전문 온톨로지 파서입니다.
온톨로지 버전: {ontology.version_id}

사용 가능한 클래스:
{classes_desc}

사용 가능한 속성:
{predicates_desc}

반드시 다음 JSON 형식으로만 응답하세요:
{{
  "triples": [
    {{
      "subject": "주어",
      "subjectType": "클래스명",
      "predicate": "속성명",
      "object": "목적어",
      "objectType": "클래스명",
      "confidence": 0.0~1.0
    }}
  ]
}}"""
```

---

### M4. API 라우터

```python
# src/v4/api/router_ontology.py  (FastAPI 기준 — 기존 프레임워크에 맞춰 조정)

# POST   /api/v4/ontologies/                    → create (Draft)
# GET    /api/v4/ontologies/                    → list_all
# GET    /api/v4/ontologies/{version_id}        → get
# PATCH  /api/v4/ontologies/{version_id}        → update (Draft만)
# DELETE /api/v4/ontologies/{version_id}        → delete (Draft만)
# POST   /api/v4/ontologies/{version_id}/confirm   → confirm → Confirmed
# POST   /api/v4/ontologies/{version_id}/archive   → archive → Archived
# POST   /api/v4/ontologies/generate            → generate_from_sample
#   body: { "sample_text": "...", "base_version_id": "v1.0" (optional) }

# src/v4/api/router_triple.py

# POST   /api/v4/triples/                       → create
# GET    /api/v4/triples/                       → search (query param: q, version, status)
# GET    /api/v4/triples/{id}                   → get
# PATCH  /api/v4/triples/{id}                   → update
# DELETE /api/v4/triples/{id}                   → delete
# POST   /api/v4/triples/{id}/archive           → archive
# POST   /api/v4/triples/extract                → extract from content
#   body: { "content": "...", "ontology_version_id": "v1.0", "source_record_id": "..." }
# GET    /api/v4/triples/stats                  → stats

# src/v4/api/router_search.py

# GET    /api/v4/graph                          → 전체 그래프 (nodes + triples)
# GET    /api/v4/graph/search?q={query}         → 서브그래프 (1홉 확장)
# GET    /api/v4/graph/node/{node_id}           → 노드 상세 + 연결 트리플
```

---

### M5. UI 컴포넌트 (React/JSX)

#### OntologyManager.jsx

```
레이아웃: 좌측 버전 목록 패널 | 우측 편집 패널

버전 목록 패널:
  - 버전별 카드 (버전ID, 상태 배지: Draft/Confirmed/Archived, 날짜)
  - [+ 새 버전] 버튼 → 빈 Draft 생성
  - [샘플에서 생성] 버튼 → 텍스트 입력 모달 → AI 생성 → Draft 저장

편집 패널 (Draft 선택 시):
  - 클래스 목록 (추가/수정/삭제 가능)
  - 속성 목록 (추가/수정/삭제 가능)
  - [확정하기] 버튼 → 확인 다이얼로그 → confirm API 호출
  - [아카이브] 버튼 (Confirmed 선택 시만 활성)

편집 패널 (Confirmed/Archived 선택 시):
  - 읽기 전용 표시
```

#### TripleManager.jsx

```
레이아웃: 상단 필터 바 | 메인 트리플 테이블 | 우측 상세/편집 패널

상단:
  - 온톨로지 버전 선택 드롭다운 (Confirmed 버전만)
  - [구술자료 입력] 버튼 → 텍스트 입력 → extract API → 결과 확인 후 저장
  - 검색/필터 (주어, 술어, 목적어, 상태)

트리플 테이블:
  - 컬럼: 주어(타입), 술어, 목적어(타입), 확신도, 출처, 상태, 액션
  - 행 클릭 → 우측 상세 패널
  - 행 체크박스 → 일괄 아카이브/삭제

상세/편집 패널:
  - 트리플 정보 표시
  - [수정] 클릭 → 인라인 편집
  - [아카이브] / [삭제] 버튼
  - 메모 입력란
```

#### KnowledgeGraph.jsx

```
레이아웃: 전체 화면 D3 그래프 | 좌측 오버레이 검색 패널 | 하단 오버레이 범례

D3 포스 그래프 (전체 화면):
  - 노드 크기: degree(연결수)에 비례
  - 노드 색상: 온톨로지 클래스별
  - 엣지 방향: 화살표 + 술어 레이블
  - 줌/패닝: 마우스 휠 + 드래그
  - 노드 클릭: 상세 정보 팝업

검색 기능:
  - 검색창에 입력 → 매칭 노드 식별
  - 매칭 노드: 확대 + 강조 (노란 테두리, 반경 1.5배)
  - 비매칭 노드: 투명도 30%로 희미하게
  - 매칭 노드의 1홉 이웃: 투명도 70% (연결 관계 보존)
  - 검색 결과 없음: 전체 그래프 유지

상태 표시:
  - 우상단: 노드 N개 · 트리플 N개 · 온톨로지 버전
  - 하단 범례: 클래스별 색상
```

---

## 영속성 설계 상세

### 파일 저장 규칙

```
data/v4/
├── ontologies/
│   ├── draft_v1.0.json      ← Draft 버전 (편집 가능)
│   ├── draft_v1.1.json
│   └── confirmed/
│       └── v1.0.json        ← Confirmed 복사본 (절대 수정 금지)
└── triples/
    ├── graph.json           ← 전체 그래프 (active + archived 포함)
    └── archive/             ← 필요 시 개별 백업

data/v4/.gitignore 내용:
  # 트리플 데이터는 git에서 제외 (용량 관리)
  triples/graph.json
```

### GraphDB 자동 저장 시점

```
- Triple 추가 후
- Triple 수정 후
- Triple 삭제/아카이브 후
- 명시적 force_save() 호출 시

저장 방식: 원자적 쓰기 (temp 파일에 쓰고 rename)
  tmp_path = graph.json.tmp
  write(tmp_path)
  rename(tmp_path → graph.json)
```

---

## 구현 순서 (Do 단계 실행 순서)

```
Phase A — 백엔드 코어
  A1. GraphDB + 파일 영속성 구현 + 테스트
  A2. OntologyManager (CRUD + 파일 저장) 구현 + 테스트
  A3. OntologyManager.generate_from_sample() 구현 + 테스트
  A4. OntologyManager.confirm() 구현 + 테스트
  A5. TripleManager (CRUDA) 구현 + 테스트
  A6. TripleExtractor (확정 온톨로지 기반) 구현 + 테스트

Phase B — API 레이어
  B1. router_ontology.py (기존 프레임워크 방식 따라)
  B2. router_triple.py
  B3. router_search.py

Phase C — UI
  C1. OntologyManager.jsx
  C2. TripleManager.jsx
  C3. KnowledgeGraph.jsx (D3 전체 화면 + 검색)

Phase D — 통합 테스트
  D1. 온톨로지 생성 → 확정 → 트리플 추출 전체 플로우
  D2. 파일 영속성 (재시작 후 데이터 복원)
  D3. 그래프 검색 + 노드 확대 동작
```

---

## 검증 기준 (Check 단계 기준)

각 Phase 완료 시 다음을 확인해야 한다:

```
Phase A 완료 기준:
  □ pytest tests/v4/ — 전체 통과
  □ GraphDB: 재시작 후 data/v4/triples/graph.json 에서 데이터 복원 확인
  □ OntologyManager: Draft → Confirmed 전환 후 수정 시도 → PermissionError 확인
  □ TripleExtractor: Confirmed 버전 클래스/속성만 사용하는지 확인

Phase B 완료 기준:
  □ curl 또는 httpie 로 각 엔드포인트 응답 확인
  □ POST /generate → AI 호출 → Draft 저장 → GET 으로 조회 가능

Phase C 완료 기준:
  □ 온톨로지 샘플 입력 → AI 초안 생성 → 편집 → 확정 화면 흐름
  □ 구술자료 입력 → 트리플 추출 → 테이블 표시 → 수정/삭제 동작
  □ KnowledgeGraph: 검색어 입력 → 매칭 노드 확대, 비매칭 희미화 동작
```

---

## 제약 조건

```
- 기존 v1~v3 코드 수정 금지
- Confirmed 상태 온톨로지는 절대 수정 불가 (API 레벨에서 차단)
- graph.json 저장 실패 시 예외 발생 + 롤백 (데이터 손실 방지)
- AI API 호출 실패 시 적절한 오류 메시지 반환 (빈 결과 아님)
- data/v4/ 디렉토리 없으면 자동 생성
- 기존 .vscode/ 설정 병합 (덮어쓰기 금지)
```

---

## Plan 검토 요청

위 Plan을 검토한 뒤 다음을 나에게 보고해라:

```
1. 기존 v3.0 코드에서 API 프레임워크가 무엇인지 (FastAPI / Flask / 없음)
   → router_*.py 를 어떤 방식으로 작성할지 결정 필요

2. 기존 Hive 연결 코드 위치
   → hive_pipeline.py import 경로 확정 필요

3. data/v4/ 디렉토리를 어디에 만들 것인지 (프로젝트 루트 기준)

4. UI 프레임워크 확인 (React 단독 / Next.js / 기타)
   → OntologyManager.jsx 등의 라우팅 방식 결정 필요

5. 위 Plan 중 설계 변경이 필요하다고 판단되는 부분

보고 후 내가 승인하면 Phase A 부터 순서대로 구현 시작해.
```
