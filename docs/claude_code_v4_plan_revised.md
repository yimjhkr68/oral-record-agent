# v4.0 지식그래프 기능 추가 — Plan (PDCA 1단계)

## 프로젝트 현황 (확인된 구조)

```
Oral-record-agent_v4.0/          ← 프로젝트 루트
├── __init__.py
├── ontology/
│   ├── __init__.py
│   └── ontology.py              ← 기존: 상수 정의 (CLASSES, PREDICATES 등)
├── graph/
│   ├── __init__.py
│   └── triple_store.py          ← 기존: 인메모리 TripleStore
├── pipeline/
│   ├── __init__.py
│   └── hive_pipeline.py         ← 기존: Hive 연동
├── ui/
│   └── __init__.py              ← 기존: 비어 있음
├── utils/
│   └── __init__.py              ← 기존: 비어 있음
├── tests/
│   ├── __init__.py
│   ├── test_ontology.py
│   └── test_triple_store.py
└── docs/
    ├── claude_code_v4_plan.md
    └── ontology_v4.md
```

---

## 목표 기능 6가지

```
F1. 온톨로지 CRUDA       — 온톨로지 생성·조회·수정·삭제·아카이브
F2. 온톨로지 자동 생성   — 구술 샘플 텍스트 → AI가 온톨로지 초안 생성
F3. 온톨로지 버전 확정   — 버전별 Draft → Confirmed 관리
F4. 트리플 생성          — 확정된 온톨로지 + 구술자료 → 트리플 추출
F5. 트리플 CRUDA         — 트리플 생성·조회·수정·삭제·아카이브
F6. 지식 검색 UI         — 전체 그래프 시각화 + 검색 시 노드 확대
```

---

## 변경 후 전체 구조

```
Oral-record-agent_v4.0/
│
├── ontology/
│   ├── __init__.py
│   ├── ontology.py               ← 기존 유지 (상수)
│   ├── ontology_manager.py       ← [신규] CRUDA + AI 생성 + 버전 확정 — F1·F2·F3
│   └── ontology_store.py         ← [신규] 온톨로지 파일 영속성
│
├── graph/
│   ├── __init__.py
│   ├── triple_store.py           ← 기존 유지 (인메모리 기반)
│   ├── triple_manager.py         ← [신규] 트리플 CRUDA 비즈니스 로직 — F5
│   └── graph_db.py               ← [신규] 로컬 파일 영속성 — F5
│
├── pipeline/
│   ├── __init__.py
│   ├── hive_pipeline.py          ← 기존 유지
│   └── triple_extractor.py       ← [신규] 확정 온톨로지 기반 트리플 추출 — F4
│
├── api/                          ← [신규 디렉토리]
│   ├── __init__.py
│   ├── router_ontology.py        ← [신규] 온톨로지 API 엔드포인트
│   ├── router_triple.py          ← [신규] 트리플 API 엔드포인트
│   └── router_search.py          ← [신규] 검색 API 엔드포인트
│
├── ui/
│   ├── __init__.py               ← 기존 유지
│   ├── OntologyManager.jsx       ← [신규] 온톨로지 CRUDA 화면 — F1·F2·F3
│   ├── TripleManager.jsx         ← [신규] 트리플 CRUDA 화면 — F4·F5
│   └── KnowledgeGraph.jsx        ← [신규] 전체 그래프 + 검색 화면 — F6
│
├── utils/
│   ├── __init__.py               ← 기존 유지
│   └── file_io.py                ← [신규] 원자적 파일 I/O 유틸
│
├── data/                         ← [신규 디렉토리] 로컬 영속성 저장소
│   ├── .gitignore
│   ├── ontologies/
│   │   ├── drafts/               ← Draft 버전 JSON
│   │   └── confirmed/            ← Confirmed 버전 JSON (읽기 전용)
│   └── triples/
│       ├── graph.json            ← 전체 트리플 그래프
│       └── archive/              ← 아카이브된 트리플 개별 파일
│
├── tests/
│   ├── __init__.py               ← 기존 유지
│   ├── test_ontology.py          ← 기존 유지
│   ├── test_triple_store.py      ← 기존 유지
│   ├── test_ontology_manager.py  ← [신규]
│   ├── test_triple_manager.py    ← [신규]
│   └── test_graph_db.py          ← [신규]
│
└── docs/
    ├── claude_code_v4_plan.md    ← 이 파일
    └── ontology_v4.md
```

---

## 데이터 흐름

```
[구술 샘플 텍스트]
      │
      ▼ F2
[OntologyManager.generate_from_sample()]  ── AI API ──▶ 온톨로지 초안
      │ 저장
      ▼
[data/ontologies/drafts/v1.0.json]
      │
      ▼ F3  confirm()
[data/ontologies/confirmed/v1.0.json]  ← 이후 수정 불가
      │
      ▼ F4
[TripleExtractor.extract(content, ontology_version="v1.0")]
      │           ↑
      │     확정 온톨로지 클래스/속성 주입
      │
      ▼ AI 호출 → 트리플 파싱
[TripleManager.bulk_create()]
      │
      ▼
[GraphDB.save()]  ──▶  data/triples/graph.json  (로컬 파일 자동 저장)
      │
      ▼ F6
[KnowledgeGraph.jsx]  ◀── GET /api/graph / GET /api/graph/search?q=
```

---

## 데이터 모델

### OntologyVersion

```python
# ontology/ontology_manager.py

from enum import Enum
from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional


class OntologyStatus(str, Enum):
    DRAFT     = "draft"       # 편집 가능
    CONFIRMED = "confirmed"   # 확정 — 수정 불가, 트리플 생성에 사용
    ARCHIVED  = "archived"    # 보관 — 조회만 가능


@dataclass
class OntologyClass:
    name:        str
    label_ko:    str
    color:       str
    description: str = ""
    examples:    list[str] = field(default_factory=list)


@dataclass
class OntologyPredicate:
    name:        str
    domain:      list[str] = field(default_factory=list)
    range_:      list[str] = field(default_factory=list)
    description: str = ""


@dataclass
class OntologyVersion:
    version_id:   str
    status:       OntologyStatus = OntologyStatus.DRAFT
    classes:      list[OntologyClass]     = field(default_factory=list)
    predicates:   list[OntologyPredicate] = field(default_factory=list)
    created_at:   str = field(default_factory=lambda: datetime.now().isoformat())
    confirmed_at: Optional[str] = None
    archived_at:  Optional[str] = None
    description:  str = ""
    based_on:     Optional[str] = None   # 이전 버전 ID
```

### Triple (확장)

```python
# graph/triple_manager.py

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
    id:               str = field(default_factory=lambda: str(uuid.uuid4())[:8])
    subject:          str = ""
    subject_type:     str = ""
    predicate:        str = ""
    object:           str = ""
    object_type:      str = ""
    ontology_version: str = ""           # 생성에 사용된 온톨로지 버전
    source_record_id: Optional[str] = None
    confidence:       float = 1.0
    status:           TripleStatus = TripleStatus.ACTIVE
    created_at:       str = field(default_factory=lambda: datetime.now().isoformat())
    updated_at:       Optional[str] = None
    archived_at:      Optional[str] = None
    note:             str = ""
```

### data/triples/graph.json 포맷

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

파일 위치: `ontology/ontology_manager.py`

```python
class OntologyManager:

    DRAFTS_DIR    = "data/ontologies/drafts"
    CONFIRMED_DIR = "data/ontologies/confirmed"

    # ── CRUDA ─────────────────────────────────────────────
    def create(self, version_id: str, description: str = "") -> OntologyVersion:
        """새 Draft 생성. version_id 중복 시 ValueError."""

    def get(self, version_id: str) -> OntologyVersion:
        """버전 조회. 없으면 KeyError."""

    def list_all(self) -> list[OntologyVersion]:
        """전체 버전 목록, 최신순."""

    def update(self, version_id: str, classes=None,
               predicates=None, description=None) -> OntologyVersion:
        """Draft 상태만 수정 가능. 그 외 PermissionError."""

    def delete(self, version_id: str) -> None:
        """Draft 상태만 삭제 가능. 그 외 PermissionError."""

    def archive(self, version_id: str) -> OntologyVersion:
        """Confirmed → Archived. 비가역."""

    # ── AI 자동 생성 (F2) ─────────────────────────────────
    def generate_from_sample(self, sample_text: str,
                              base_version_id: str = None) -> OntologyVersion:
        """
        구술 샘플 → AI 분석 → Draft OntologyVersion 생성 + 파일 저장.
        base_version_id 있으면 해당 버전 기반으로 확장 제안.
        """

    # ── 버전 확정 (F3) ────────────────────────────────────
    def confirm(self, version_id: str) -> OntologyVersion:
        """
        Draft → Confirmed. 비가역.
        data/ontologies/confirmed/{version_id}.json 에 복사본 저장.
        """

    def get_confirmed_versions(self) -> list[OntologyVersion]:
        """Confirmed 상태 버전만 반환."""

    def get_latest_confirmed(self) -> Optional[OntologyVersion]:
        """가장 최근 Confirmed 버전. 없으면 None."""
```

**generate_from_sample() 시스템 프롬프트:**

```
당신은 구술기록 아카이브 전문가다.
제공된 구술 텍스트 샘플을 분석하여 지식그래프 온톨로지를 제안해라.

기존 온톨로지({base_ontology_json})가 있으면 그것을 기반으로 확장 제안해라.
텍스트에서 실제로 등장하는 개념만 포함해라.

반드시 다음 JSON 형식으로만 응답해:
{
  "classes": [
    {
      "name": "영문 PascalCase",
      "label_ko": "한국어 레이블",
      "color": "#hex",
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
```

---

### M2. OntologyStore (영속성)

파일 위치: `ontology/ontology_store.py`

```python
class OntologyStore:
    """OntologyVersion ↔ JSON 파일 변환 담당."""

    def save_draft(self, version: OntologyVersion) -> None:
        """data/ontologies/drafts/{version_id}.json 저장."""

    def save_confirmed(self, version: OntologyVersion) -> None:
        """data/ontologies/confirmed/{version_id}.json 저장 (읽기 전용 복사본)."""

    def load(self, version_id: str) -> OntologyVersion:
        """drafts 또는 confirmed 에서 로드."""

    def load_all(self) -> list[OntologyVersion]:
        """전체 버전 목록 로드."""

    def delete_draft(self, version_id: str) -> None:
        """drafts/{version_id}.json 삭제."""
```

---

### M3. GraphDB (F5 — 영속성)

파일 위치: `graph/graph_db.py`

```python
class GraphDB:
    """
    인메모리 트리플 저장소 + 로컬 파일 자동 저장.
    모든 데이터 변경 후 data/triples/graph.json 에 자동 저장.
    """

    GRAPH_FILE = "data/triples/graph.json"

    def __init__(self, auto_save: bool = True):
        self.auto_save = auto_save
        self._triples: dict[str, Triple] = {}   # id → Triple
        self._nodes:   dict[str, dict]   = {}   # node_id → {type, degree}
        self._load()   # 시작 시 graph.json 에서 복원

    # 내부 I/O
    def _load(self) -> None:
        """graph.json 있으면 로드. 없으면 빈 상태."""

    def _save(self) -> None:
        """
        원자적 쓰기:
          1. graph.json.tmp 에 저장
          2. graph.json.tmp → graph.json rename
        auto_save=True 이면 모든 변경 후 자동 호출.
        """

    # CRUD
    def add(self, triple: Triple) -> bool:
        """추가. 중복(id) 시 False."""

    def get(self, triple_id: str) -> Optional[Triple]:
        """ID로 단건 조회."""

    def update(self, triple_id: str, **kwargs) -> Optional[Triple]:
        """필드 업데이트 + updated_at 자동 갱신."""

    def remove(self, triple_id: str) -> bool:
        """영구 삭제."""

    def query(self, search: str = "",
              include_archived: bool = False) -> dict:
        """
        검색어 기반 서브그래프 반환 (1홉 이웃 포함).
        search 없으면 전체 그래프.
        반환: {"nodes": [...], "triples": [...]}
        """

    def all_triples(self, include_archived: bool = False) -> list[Triple]:
        """전체 트리플 목록."""

    def stats(self) -> dict:
        """{"nodes": N, "triples": N, "active": N, "archived": N}"""

    def force_save(self) -> None:
        """명시적 저장 호출."""

    def export_json(self) -> str:
        """현재 상태를 JSON 문자열로 반환."""
```

---

### M4. TripleManager (F5 — 비즈니스 로직)

파일 위치: `graph/triple_manager.py`

```python
class TripleManager:

    def __init__(self, graph_db: GraphDB):
        self.db = graph_db

    def create(self, subject, subject_type, predicate, object_,
               object_type, ontology_version,
               source_record_id=None, confidence=1.0, note="") -> Triple:
        """생성. 동일 S+P+O 존재 시 기존 반환."""

    def get(self, triple_id: str) -> Triple:
        """ID로 조회. 없으면 KeyError."""

    def search(self, query: str = "",
               ontology_version: str = None,
               status: TripleStatus = TripleStatus.ACTIVE) -> dict:
        """
        검색어 기반 서브그래프 (1홉 확장).
        반환: {"nodes": [...], "triples": [...]}
        """

    def update(self, triple_id: str, predicate=None, object_=None,
               object_type=None, confidence=None, note=None) -> Triple:
        """수정. updated_at 자동 갱신."""

    def delete(self, triple_id: str) -> None:
        """영구 삭제."""

    def archive(self, triple_id: str, reason: str = "") -> Triple:
        """Active → Archived. archived_at 기록."""

    def bulk_create(self, triples: list[dict],
                    ontology_version: str,
                    source_record_id: str = None) -> dict:
        """
        배치 생성. 중복 제외.
        반환: {"added": N, "skipped": N, "triples": [...]}
        """

    def stats(self) -> dict:
        """{"nodes": N, "triples": N, "active": N, "archived": N}"""
```

---

### M5. TripleExtractor (F4)

파일 위치: `pipeline/triple_extractor.py`

```python
class TripleExtractor:
    """
    확정된 온톨로지 버전 기반으로 구술자료에서 트리플 추출.
    Confirmed 버전의 클래스/속성을 AI 프롬프트에 동적 주입.
    """

    def __init__(self, ontology_manager: OntologyManager,
                 triple_manager: TripleManager):
        self.om     = ontology_manager
        self.tm     = triple_manager
        self.client = anthropic.Anthropic()

    def extract(self, content: str,
                ontology_version_id: str,
                source_record_id: str = None) -> dict:
        """
        1. version_id 로 OntologyVersion 조회
           → Confirmed 아니면 ValueError
        2. 클래스/속성을 프롬프트에 주입
        3. AI 호출 → 트리플 JSON 파싱
        4. TripleManager.bulk_create() 저장
        반환: {"added": N, "skipped": N, "triples": [...]}
        """

    def _build_system_prompt(self, ontology: OntologyVersion) -> str:
        """확정 온톨로지 기반 동적 시스템 프롬프트 생성."""
        classes_str = "\n".join(
            f"- {c.name} ({c.label_ko}): {c.description}"
            for c in ontology.classes
        )
        predicates_str = "\n".join(
            f"- {p.name}: {p.description} "
            f"[도메인: {p.domain} → 범위: {p.range_}]"
            for p in ontology.predicates
        )
        return f"""당신은 구술기록 전문 온톨로지 파서입니다.
온톨로지 버전: {ontology.version_id}

사용 가능한 클래스:
{classes_str}

사용 가능한 속성:
{predicates_str}

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

### M6. utils/file_io.py

```python
# utils/file_io.py

import json
import os
from pathlib import Path


def ensure_dir(path: str) -> None:
    """디렉토리 없으면 생성."""
    Path(path).mkdir(parents=True, exist_ok=True)


def atomic_write_json(path: str, data: dict) -> None:
    """
    원자적 JSON 저장.
    tmp 파일에 쓰고 rename → 저장 중 크래시 시 파일 손상 방지.
    """
    tmp_path = path + ".tmp"
    ensure_dir(os.path.dirname(path))
    with open(tmp_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    os.replace(tmp_path, path)   # 원자적 rename


def read_json(path: str) -> dict:
    """JSON 파일 읽기. 없으면 빈 dict."""
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return {}
```

---

### M7. API 라우터

기존 API 프레임워크 확인 후 맞게 작성.
(FastAPI 기준으로 작성하되, 다른 프레임워크면 패턴만 유지하고 문법 조정)

파일 위치: `api/router_ontology.py`, `api/router_triple.py`, `api/router_search.py`

```
# router_ontology.py 엔드포인트
POST   /api/ontologies/                        → create (Draft)
GET    /api/ontologies/                        → list_all
GET    /api/ontologies/{version_id}            → get
PATCH  /api/ontologies/{version_id}            → update (Draft만)
DELETE /api/ontologies/{version_id}            → delete (Draft만)
POST   /api/ontologies/{version_id}/confirm    → Confirmed 전환
POST   /api/ontologies/{version_id}/archive    → Archived 전환
POST   /api/ontologies/generate                → AI 자동 생성
  body: { "sample_text": "...", "base_version_id": "v1.0" }

# router_triple.py 엔드포인트
POST   /api/triples/                           → create
GET    /api/triples/                           → search (?q=&version=&status=)
GET    /api/triples/stats                      → stats
GET    /api/triples/{id}                       → get
PATCH  /api/triples/{id}                       → update
DELETE /api/triples/{id}                       → delete
POST   /api/triples/{id}/archive               → archive
POST   /api/triples/extract                    → 구술자료 → 트리플 추출
  body: { "content": "...", "ontology_version_id": "v1.0",
          "source_record_id": "rec_001" }

# router_search.py 엔드포인트
GET    /api/graph                              → 전체 그래프
GET    /api/graph/search?q={query}            → 서브그래프 (1홉 확장)
GET    /api/graph/node/{node_id}              → 노드 상세 + 연결 트리플
```

---

### M8. UI 컴포넌트

파일 위치: `ui/OntologyManager.jsx`, `ui/TripleManager.jsx`, `ui/KnowledgeGraph.jsx`

#### OntologyManager.jsx 레이아웃

```
┌──────────────────┬─────────────────────────────────────────┐
│  버전 목록       │  편집 패널                               │
│                  │                                          │
│  [+ 새 버전]     │  Draft 선택 시:                         │
│  [샘플에서 생성] │    클래스 목록 (추가/수정/삭제)          │
│                  │    속성 목록  (추가/수정/삭제)           │
│  ● v1.1  Draft   │    [확정하기] → 확인 다이얼로그          │
│  ✓ v1.0  Conf.   │                                          │
│  ○ v0.9  Arch.   │  Confirmed/Archived 선택 시:            │
│                  │    읽기 전용 표시                        │
│                  │    [아카이브] 버튼 (Confirmed만)         │
└──────────────────┴─────────────────────────────────────────┘
```

#### TripleManager.jsx 레이아웃

```
┌─────────────────────────────────────────────────────────────┐
│  온톨로지 버전: [v1.0 ▼]  [구술자료 입력]  검색: [______] │
├──────────────────────────────────────┬──────────────────────┤
│  트리플 테이블                        │  상세/편집 패널      │
│  주어(타입) │ 술어 │ 목적어(타입) │…  │                      │
│  □ 김영수   │ 출생지 │ 안동      │…  │  subject: 김영수     │
│  □ 김영수   │ 참여함 │ 6·25전쟁  │…  │  predicate: 출생지   │
│             │        │           │   │  object: 안동        │
│  [일괄 아카이브]  [일괄 삭제]        │  [수정] [아카이브]   │
└──────────────────────────────────────┴──────────────────────┘
```

#### KnowledgeGraph.jsx 레이아웃

```
┌─────────────────────────────────────────────────────────────┐
│  검색: [____________]  ✕           노드 N · 트리플 N  v1.0  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                                                       │  │
│  │   ○김영수 ──출생지──▶ ○경북안동                      │  │
│  │      │                                                │  │
│  │    참여함                                             │  │
│  │      ▼                                                │  │
│  │   ○6·25전쟁                                          │  │
│  │                                                       │  │
│  │   (전체 화면 D3 포스 그래프)                         │  │
│  │                                                       │  │
│  └───────────────────────────────────────────────────────┘  │
│  ● 인물  ● 장소  ● 사건  ● 시간  ● 기관  …  (범례)         │
└─────────────────────────────────────────────────────────────┘

검색 동작:
  - 매칭 노드:         크기 1.5배 + 노란 테두리 강조
  - 1홉 이웃 노드:     투명도 70% (연결 관계 보존)
  - 비매칭 나머지:     투명도 20% (맥락 유지)
  - 노드 클릭:         상세 팝업 (연결 트리플 목록)
  - 스크롤:            줌 인/아웃
  - 드래그:            노드 고정 이동
```

---

## 신규 테스트 명세

### tests/test_ontology_manager.py

```python
# 검증 항목
def test_create_draft()          # Draft 생성
def test_duplicate_version_id()  # 중복 ID → ValueError
def test_update_draft()          # Draft 수정 가능
def test_update_confirmed_blocked()  # Confirmed 수정 → PermissionError
def test_confirm_version()       # Draft → Confirmed
def test_confirmed_file_saved()  # confirmed/ 폴더에 파일 생성 확인
def test_generate_from_sample()  # AI 호출 → Draft 반환 (mock 처리)
def test_archive_confirmed()     # Confirmed → Archived
def test_get_latest_confirmed()  # 최신 Confirmed 반환
```

### tests/test_graph_db.py

```python
def test_add_and_get()           # 추가 후 조회
def test_auto_save_creates_file()  # 추가 후 graph.json 파일 생성 확인
def test_load_on_init()          # 재초기화 시 파일에서 복원
def test_atomic_write()          # tmp 파일 경유 저장 확인
def test_query_subgraph()        # 검색어 기반 1홉 서브그래프
def test_stats()                 # 통계 정확성
def test_archive_not_delete()    # archive → status 변경, 레코드 유지
```

### tests/test_triple_manager.py

```python
def test_create()                # 트리플 생성
def test_duplicate_returns_existing()  # 중복 S+P+O → 기존 반환
def test_update()                # 수정 + updated_at 갱신
def test_delete()                # 영구 삭제
def test_archive()               # Archived 상태 전환
def test_bulk_create()           # 배치 생성 + 중복 제외
def test_search_with_neighbor()  # 검색 시 1홉 이웃 포함
```

---

## 구현 순서 (Do 단계)

```
Phase A — 코어 백엔드
  A1. utils/file_io.py           원자적 파일 I/O
  A2. ontology/ontology_store.py 온톨로지 파일 영속성
  A3. ontology/ontology_manager.py CRUDA + 버전 확정
      → test_ontology_manager.py 전체 통과
  A4. generate_from_sample() AI 연동
      → AI mock 테스트 통과
  A5. graph/graph_db.py          파일 영속성 트리플 DB
      → test_graph_db.py 전체 통과
  A6. graph/triple_manager.py    CRUDA 비즈니스 로직
      → test_triple_manager.py 전체 통과
  A7. pipeline/triple_extractor.py 확정 온톨로지 기반 추출
      → 통합 플로우 테스트

Phase B — API 레이어
  B1. api/ 디렉토리 + __init__.py
  B2. router_ontology.py
  B3. router_triple.py
  B4. router_search.py
  → 각 엔드포인트 curl 테스트

Phase C — UI
  C1. ui/OntologyManager.jsx
  C2. ui/TripleManager.jsx
  C3. ui/KnowledgeGraph.jsx (D3 전체 화면 + 검색)

Phase D — 통합 검증
  D1. 샘플 텍스트 → AI 온톨로지 생성 → 확정 → 트리플 추출 전체 플로우
  D2. 서버 재시작 후 data/triples/graph.json 에서 데이터 복원 확인
  D3. KnowledgeGraph 검색 → 매칭 노드 확대, 비매칭 희미화 동작 확인
```

---

## 각 Phase 완료 기준

```
Phase A:
  □ pytest tests/ -v → 전체 통과
  □ data/ontologies/confirmed/ 에 JSON 파일 생성 확인
  □ data/triples/graph.json 생성 확인
  □ 프로세스 재시작 후 트리플 데이터 복원 확인

Phase B:
  □ POST /api/ontologies/generate → AI Draft 생성 → GET 조회 성공
  □ POST /api/triples/extract → 트리플 생성 → graph.json 저장 확인

Phase C:
  □ OntologyManager: 샘플 입력 → AI 초안 → 편집 → 확정 화면 동작
  □ TripleManager: 구술자료 입력 → 트리플 추출 → 수정/삭제 동작
  □ KnowledgeGraph: 검색 → 매칭 노드 시각적 강조 동작
```

---

## 제약 조건

```
- 기존 파일 수정 금지 목록:
    ontology/ontology.py       (상수 파일 — 읽기만)
    graph/triple_store.py      (기존 유지 — 신규 파일에서 import)
    pipeline/hive_pipeline.py  (기존 유지)
    tests/test_ontology.py     (기존 유지)
    tests/test_triple_store.py (기존 유지)

- data/ 디렉토리 자동 생성 (없으면 코드에서 생성)
- data/triples/graph.json → .gitignore 에 추가
- Confirmed 온톨로지 → API 레벨에서 수정 요청 차단 (PermissionError)
- graph.json 저장 실패 시 예외 발생 + 롤백 (데이터 손실 방지)
- AI API 호출 실패 시 빈 결과 반환 금지 → 명확한 오류 메시지 반환
```

---

## Plan 검토 후 보고 요청

이 Plan을 검토하고 구현 시작 전에 다음을 나에게 보고해라:

```
1. 현재 API 프레임워크 확인
   → 기존 코드에 FastAPI / Flask / 없음 중 무엇인지
   → router_*.py 작성 방식 결정에 필요

2. UI 실행 방식 확인
   → .jsx 파일을 어떻게 서빙하는지
      (별도 React 앱 / FastAPI static / 기타)

3. data/ 디렉토리 위치 확인
   → 프로젝트 루트(Oral-record-agent_v4.0/) 바로 아래가 맞는지
      아니면 다른 위치를 원하는지

4. 위 Plan에서 설계 변경이 필요하다고 판단되는 부분

보고 후 내가 승인하면 Phase A1 부터 시작해.
```
