# 구술기록관리 에이전트 v5.0 — Claude Code 프롬프트

## 📌 시작 전 필독 문서

```
E:\Oral-record-agent_v5.0\docs\v5.0-PDCA-plan.md   ← 전체 설계 + 코드
E:\Oral-record-agent_v5.0\docs\master-prompt.md     ← 전체 구현 순서
E:\Oral-record-agent_v5.0\CLAUDE.md                 ← 이 파일 (규칙)
```

**작업 시작 시 반드시 위 세 파일을 먼저 읽어.**

---

## 프로젝트 개요

구술기록을 수집·분석하여 온톨로지와 지식그래프를 생성하고,
RDF/OWL로 변환하여 구술기록 온톨로지를 공표하는 시스템.

- **경로**: `E:\Oral-record-agent_v5.0`
- **기술스택**: FastAPI(포트 9000) + Flutter Windows
- **Python**: 3.10+
- **개발방식**: PDCA 사이클 (docs/master-prompt.md 참조)

---

## 현재 구현 상태

```
✅ Feature 1: RDF 마이그레이션 백엔드 완료
✅ Feature 2: 온톨로지 편집기 백엔드 완료
✅ Feature 3: 품질 검증 대시보드
✅ Feature 4: 추론 검색
✅ Feature 5: 공표 관리자
✅ Feature 6: RDF 내보내기 통합
✅ Flutter UI 전체
```

> 각 Feature 완료 시 이 파일의 체크박스를 ✅ 로 업데이트해줘.

---

## 디렉토리 구조

```
E:\Oral-record-agent_v5.0\
├── main.py                        # FastAPI 앱 (포트 9000, v5.0.0)
├── requirements.txt
├── CLAUDE.md                      # 이 파일
├── docs/
│   ├── v5.0-PDCA-plan.md          # 전체 설계 문서
│   └── master-prompt.md           # 전체 구현 순서
├── api/
│   ├── router_ontology.py         # [v4.0 유지]
│   ├── router_triple.py           # [v4.0 유지]
│   ├── router_search.py           # [v4.0 유지]
│   ├── router_records.py          # [v4.0 유지]
│   ├── router_graph_layout.py     # [v4.0 유지]
│   ├── router_cluster.py          # [v4.0 유지]
│   ├── router_published_ontology.py # [v4.0 유지]
│   ├── router_settings.py         # [v4.0 유지]
│   ├── router_history.py          # [v4.0 유지]
│   ├── router_rdf_migration.py    # [v5.0 ✅]
│   ├── router_rdf_ontology.py     # [v5.0 ✅]
│   ├── router_rdf_export.py       # [v5.0 ⬜]
│   ├── router_rdf_validate.py     # [v5.0 ⬜]
│   ├── router_semantic_search.py  # [v5.0 ⬜]
│   └── router_rdf_publish.py      # [v5.0 ⬜]
├── core/
│   ├── database.py                # [v4.0 유지]
│   ├── rdf_store.py               # [v5.0 ✅]
│   ├── rdf_migration.py           # [v5.0 ✅]
│   ├── rdf_validator.py           # [v5.0 ⬜]
│   ├── rdf_publisher.py           # [v5.0 ⬜]
│   ├── owl_reasoner.py            # [v5.0 ⬜]
│   └── nl_to_sparql.py            # [v5.0 ⬜]
├── data/
│   ├── oral_record.db             # SQLite (절대 덮어쓰기 금지)
│   ├── backups/                   # DB 백업
│   ├── rdf/
│   │   ├── oral-history.ttl
│   │   ├── oral-history.jsonld
│   │   ├── oral-history.owl
│   │   ├── tmp/
│   │   └── v1.0/
│   ├── migration_state.json
│   ├── validation_results.json
│   ├── publish_history.json
│   └── sparql_templates.json
├── ontology/
│   ├── core/oral-history.ttl
│   └── domain/jeju43.ttl
└── flutter/lib/
    ├── screens/
    │   └── rdf_management/        # [v5.0 ⬜ Flutter]
    └── services/
        └── rdf_api_service.dart   # [v5.0 ⬜ Flutter]
```

---

## 절대 규칙

```
❌ 기존 /api/* 엔드포인트 수정·삭제 금지
❌ data/oral_record.db 덮어쓰기 금지
❌ 백업 없이 마이그레이션 실행 금지
❌ 한글 URI 사용 금지 (ora:Narrator O / ora:구술자 X)
❌ CHECK 통과 전 다음 Feature 진행 금지
```

---

## 기술 스택

```python
# 서버 실행
python -m uvicorn main:app --port 9000 --reload

# 신규 패키지 (v5.0)
rdflib>=7.0.0
owlready2>=0.46
sparqlwrapper>=2.0.0
```

```
# RDF 네임스페이스
ora:  https://yimjhkr68.github.io/oral-history-ontology/core#
j43:  https://yimjhkr68.github.io/oral-history-ontology/jeju43#
crm:  http://www.cidoc-crm.org/cidoc-crm/
rico: https://www.ica.org/standards/RiC/ontology#
```

---

## 코드 규칙

```python
# 인코딩 명시
g.serialize(path, format="turtle", encoding="utf-8")

# 한글 Literal — lang 태그 필수
Literal("구술자", lang="ko")   # ✅
Literal("구술자")              # ❌

# URI — 반드시 영문
ORA["Narrator"]   # ✅
ORA["구술자"]     # ❌

# 라우터 — prefix와 tags 필수
router = APIRouter(prefix="/rdf/migration", tags=["RDF 마이그레이션"])

# 상태 변경 시 항상 파일에 기록
self._save_state({"last_action": "...", "timestamp": "..."})
```

---

## Flutter 규칙

```
- 기존 탭 (온톨로지/트리플/그래프/기록/검색/설정) 순서·디자인 변경 금지
- 다크 테마 + 앰버+청록 색상 + Noto Serif KR 폰트 유지
- 신규 "RDF 관리" 탭을 기존 탭 오른쪽 끝에 추가
- 상태관리: 기존 Riverpod 방식 유지
- HTTP 호출: 기존 http 패키지 방식 유지
```

---

*oral-record-agent v5.0 | CLAUDE.md*
