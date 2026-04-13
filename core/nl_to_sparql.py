# -*- coding: utf-8 -*-
"""core/nl_to_sparql.py — 자연어 → SPARQL 변환 (Claude API 활용, v5.0)

ANTHROPIC_API_KEY 미설정 시 graceful degradation:
  - search() → sparql: None, results: [], message: "API 키 미설정"
"""

import json
import os
from pathlib import Path
from typing import Optional

from core.rdf_store import get_rdf_store

# ── 경로 ──────────────────────────────────────────────────────────────────────
_ROOT          = Path(__file__).parent.parent
TEMPLATES_PATH = _ROOT / "data" / "sparql_templates.json"

# ── 시스템 프롬프트 ────────────────────────────────────────────────────────────
_SYSTEM_PROMPT = """\
당신은 구술기록 온톨로지 전문 SPARQL 생성기입니다.
사용자의 자연어 질의를 SPARQL SELECT 쿼리로 변환하세요.

## 네임스페이스

```turtle
PREFIX ora:    <https://yimjhkr68.github.io/oral-history-ontology/core#>
PREFIX j43:    <https://yimjhkr68.github.io/oral-history-ontology/jeju43#>
PREFIX crm:    <http://www.cidoc-crm.org/cidoc-crm/>
PREFIX rico:   <https://www.ica.org/standards/RiC/ontology#>
PREFIX foaf:   <http://xmlns.com/foaf/0.1/>
PREFIX schema: <https://schema.org/>
PREFIX rdfs:   <http://www.w3.org/2000/01/rdf-schema#>
PREFIX owl:    <http://www.w3.org/2002/07/owl#>
```

## 주요 클래스

| 로컬명 | 한국어 | 상위 클래스 |
|--------|--------|------------|
| ora:Narrator | 구술자 | crm:E21_Person |
| ora:OralRecord | 구술기록 | rico:Record |
| ora:RecordingEvent | 채록행위 | crm:E7_Activity |
| ora:Interviewer | 채록자 | crm:E21_Person |
| ora:Place | 장소 | crm:E53_Place |
| ora:Event | 사건/사건 | crm:E5_Event |
| j43:Jeju43Event | 제주4.3사건 | ora:Event |

## 주요 속성

| 속성 | 설명 |
|------|------|
| foaf:name | 이름 |
| schema:birthDate | 생년 |
| crm:P11i_participated_in | 사건 참여 |
| crm:P7_took_place_at | 발생 장소 |
| rico:hasCreator | 기록 생산자 |
| crm:P152_has_parent | 부모 관계 |

## 규칙

1. 반드시 PREFIX 선언을 포함한 완전한 SPARQL SELECT 쿼리로 응답
2. LIMIT 절 포함 (기본 20)
3. 추론이 필요한 경우 property path (+, *) 활용
4. JSON 형식으로만 응답:
   {"sparql": "PREFIX ...", "explanation": "한 줄 설명"}
"""


class NLToSPARQL:
    """자연어 질의를 SPARQL로 변환하고 RDF 그래프에서 실행합니다."""

    def __init__(self):
        self._client = None

    def _get_client(self):
        if self._client is None:
            api_key = os.environ.get("ANTHROPIC_API_KEY", "")
            if not api_key:
                return None
            import anthropic  # type: ignore
            self._client = anthropic.Anthropic(api_key=api_key)
        return self._client

    # ── 자연어 → SPARQL 변환 + 실행 ──────────────────────────────────────────

    def search(self, query: str, limit: int = 20) -> dict:
        """자연어 질의를 SPARQL로 변환한 뒤 RDF 그래프에서 실행합니다."""
        client = self._get_client()
        if client is None:
            return {
                "mode":        "natural",
                "query":       query,
                "sparql":      None,
                "results":     [],
                "count":       0,
                "message":     "ANTHROPIC_API_KEY 미설정. .env 파일을 확인하세요.",
            }

        # Claude API로 SPARQL 생성
        sparql_query, explanation = self._generate_sparql(client, query, limit)
        if sparql_query is None:
            return {
                "mode":    "natural",
                "query":   query,
                "sparql":  None,
                "results": [],
                "count":   0,
                "message": explanation or "SPARQL 생성 실패",
            }

        # RDF 그래프 실행
        rows, error = self._execute_sparql(sparql_query, limit)
        return {
            "mode":        "natural",
            "query":       query,
            "sparql":      sparql_query,
            "explanation": explanation,
            "results":     rows,
            "count":       len(rows),
            "error":       error,
        }

    def _generate_sparql(self, client, query: str, limit: int) -> tuple[Optional[str], Optional[str]]:
        """Claude API를 호출하여 SPARQL 쿼리를 생성합니다."""
        try:
            user_msg = f"자연어 질의: {query}\n최대 결과 수: {limit}"
            response = client.messages.create(
                model="claude-haiku-4-5-20251001",   # 빠른 변환에 최적
                max_tokens=1024,
                system=_SYSTEM_PROMPT,
                messages=[{"role": "user", "content": user_msg}],
            )
            raw = response.content[0].text.strip()

            # JSON 파싱
            import re
            match = re.search(r'\{.*\}', raw, re.DOTALL)
            if match:
                parsed = json.loads(match.group())
                return parsed.get("sparql"), parsed.get("explanation", "")
            return None, "Claude 응답에서 JSON 파싱 실패"
        except Exception as e:
            return None, str(e)

    # ── SPARQL 직접 실행 ───────────────────────────────────────────────────────

    def execute_sparql(self, sparql: str, limit: int = 20) -> dict:
        """SPARQL 쿼리를 RDF 그래프에서 직접 실행합니다."""
        rows, error = self._execute_sparql(sparql, limit)
        return {
            "mode":    "sparql",
            "sparql":  sparql,
            "results": rows,
            "count":   len(rows),
            "error":   error,
        }

    def _execute_sparql(self, sparql: str, limit: int) -> tuple[list[dict], Optional[str]]:
        """rdflib Graph에서 SPARQL을 실행하고 결과를 dict 리스트로 반환합니다."""
        try:
            store = get_rdf_store()
            qr    = store.graph.query(sparql)

            rows: list[dict] = []
            for row in qr:
                if len(rows) >= limit:
                    break
                item: dict = {}
                for var in row.labels:
                    val = row[var]
                    item[str(var)] = str(val) if val is not None else None
                rows.append(item)
            return rows, None
        except Exception as e:
            return [], str(e)

    # ── 템플릿 관리 ────────────────────────────────────────────────────────────

    def get_templates(self) -> dict:
        """내장 템플릿 + 사용자 정의 템플릿을 합쳐서 반환합니다."""
        builtin = self._builtin_templates()
        custom  = self._load_custom_templates()
        return {**builtin, **custom}

    def save_template(self, name: str, description: str, sparql: str) -> dict:
        """사용자 정의 템플릿을 저장합니다."""
        templates = self._load_custom_templates()
        templates[name] = {"description": description, "sparql": sparql}
        TEMPLATES_PATH.parent.mkdir(parents=True, exist_ok=True)
        TEMPLATES_PATH.write_text(
            json.dumps(templates, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        return {"status": "saved", "name": name}

    def _builtin_templates(self) -> dict:
        return {
            "관련_인물_찾기": {
                "description": "모든 구술자 목록",
                "sparql": (
                    "PREFIX ora: <https://yimjhkr68.github.io/oral-history-ontology/core#>\n"
                    "PREFIX foaf: <http://xmlns.com/foaf/0.1/>\n"
                    "PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>\n"
                    "SELECT ?narrator ?label WHERE {\n"
                    "  ?narrator a ora:Narrator .\n"
                    "  OPTIONAL { ?narrator rdfs:label ?label }\n"
                    "} LIMIT 20"
                ),
            },
            "클래스_전체_목록": {
                "description": "RDF 그래프의 모든 OWL 클래스",
                "sparql": (
                    "PREFIX owl:  <http://www.w3.org/2002/07/owl#>\n"
                    "PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>\n"
                    "SELECT ?cls ?label WHERE {\n"
                    "  ?cls a owl:Class .\n"
                    "  OPTIONAL { ?cls rdfs:label ?label FILTER(lang(?label)='ko') }\n"
                    "} ORDER BY ?cls LIMIT 50"
                ),
            },
            "상위클래스_매핑": {
                "description": "클래스-상위클래스 매핑 전체",
                "sparql": (
                    "PREFIX owl:  <http://www.w3.org/2002/07/owl#>\n"
                    "PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>\n"
                    "SELECT ?cls ?parent WHERE {\n"
                    "  ?cls a owl:Class .\n"
                    "  ?cls rdfs:subClassOf ?parent .\n"
                    "} ORDER BY ?cls LIMIT 50"
                ),
            },
            "레이블_없는_클래스": {
                "description": "한국어 레이블이 없는 클래스 탐지",
                "sparql": (
                    "PREFIX owl:  <http://www.w3.org/2002/07/owl#>\n"
                    "PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>\n"
                    "SELECT ?cls WHERE {\n"
                    "  ?cls a owl:Class .\n"
                    "  FILTER NOT EXISTS {\n"
                    "    ?cls rdfs:label ?lbl FILTER(lang(?lbl)='ko')\n"
                    "  }\n"
                    "} LIMIT 20"
                ),
            },
            "트리플_샘플": {
                "description": "그래프 전체 트리플 샘플 (5건)",
                "sparql": "SELECT ?s ?p ?o WHERE { ?s ?p ?o } LIMIT 5",
            },
        }

    def _load_custom_templates(self) -> dict:
        if TEMPLATES_PATH.exists():
            try:
                return json.loads(TEMPLATES_PATH.read_text(encoding="utf-8"))
            except Exception:
                pass
        return {}
