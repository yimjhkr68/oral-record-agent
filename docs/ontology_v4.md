# v4.0 지식그래프 온톨로지

## 개요

구술기록관리 에이전트 v4.0의 지식그래프 온톨로지 정의 문서.

---

## 노드 타입 (NodeType)

| 타입 | 설명 | 필수 속성 |
|---|---|---|
| `Record` | 구술 기록 | id, title, display_id |
| `Narrator` | 구술자 | id, name |
| `Interviewer` | 면담자 | id, name |
| `Session` | 면담 세션 | id, interview_date |
| `Category` | 주제 분류 | name |
| `Keyword` | 키워드 태그 | name |
| `Event` | 역사적 사건 (추출) | name |
| `Place` | 장소 (추출) | name |
| `Person` | 인물 언급 (추출) | name |

---

## 관계 타입 (RelationType)

| 관계 | 방향 | 설명 |
|---|---|---|
| `narrated_by` | Record → Narrator | 기록의 구술자 |
| `interviewed_by` | Record → Interviewer | 기록의 면담자 |
| `belongs_to` | Record → Category | 주제 분류 소속 |
| `tagged_with` | Record → Keyword | 키워드 태그 |
| `part_of_session` | Record → Session | 면담 세션 소속 |
| `mentions_event` | Record → Event | 사건 언급 |
| `mentions_place` | Record → Place | 장소 언급 |
| `mentions_person` | Record → Person | 인물 언급 |
| `related_to` | Record ↔ Record | 의미적 유사 기록 |
| `co_narrator` | Narrator ↔ Narrator | 동일 세션 참여 구술자 |

---

## 파이프라인

```
Hive DB (앱)
    ↓ JSON 내보내기
records.json
    ↓ pipeline/hive_pipeline.load_from_json()
TripleStore (networkx DiGraph)
    ↓ (추후)
FastAPI 그래프 엔드포인트 / 시각화
```

---

## 파일 구조

```
E:\Oral-record-agent_v4.0\
├── ontology/ontology.py      # NodeType, RelationType, NODE_SCHEMA
├── graph/triple_store.py     # TripleStore (networkx 기반)
├── pipeline/hive_pipeline.py # JSON → TripleStore 변환
├── ui/                       # 시각화 (추후 구현)
├── tests/
│   ├── test_triple_store.py
│   └── test_ontology.py
└── docs/ontology_v4.md
```
