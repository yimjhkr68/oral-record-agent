# -*- coding: utf-8 -*-
"""core/rdf_store.py — rdflib Graph 래퍼 + 싱글톤 (v5.0)

역할:
  - data/rdf/oral-history.ttl 파일을 읽어 메모리 Graph 유지
  - 변경 발생 시 파일 저장 + 변경 이력(change_log) 기록
  - 버전 정보(version_info.json) 관리
  - 앱 전체에서 get_rdf_store() 로 동일 인스턴스 공유
"""

import json
import re
from datetime import datetime
from pathlib import Path
from typing import Optional

from rdflib import (
    Graph, Namespace, URIRef, Literal,
    RDF, RDFS, OWL
)
from rdflib.namespace import DCTERMS, XSD

# ── 기본 경로 ──────────────────────────────────────────────────────────────────
_ROOT        = Path(__file__).parent.parent
RDF_DIR      = _ROOT / "data" / "rdf"
TTL_PATH     = RDF_DIR / "oral-history.ttl"
VERSION_PATH = RDF_DIR / "version_info.json"
CHANGELOG_PATH = RDF_DIR / "change_log.json"

# 기본 네임스페이스
_DEFAULT_NS = "https://yimjhkr68.github.io/oral-history-ontology/core#"
ORA = Namespace(_DEFAULT_NS)


# ── RDFStore ──────────────────────────────────────────────────────────────────

class RDFStore:
    """rdflib Graph 싱글톤 래퍼."""

    def __init__(self):
        RDF_DIR.mkdir(parents=True, exist_ok=True)
        self.graph = Graph()
        self._bind_prefixes()
        self._load()

    def _bind_prefixes(self):
        self.graph.bind("ora",     ORA)
        self.graph.bind("crm",     Namespace("http://www.cidoc-crm.org/cidoc-crm/"))
        self.graph.bind("rico",    Namespace("https://www.ica.org/standards/RiC/ontology#"))
        self.graph.bind("foaf",    Namespace("http://xmlns.com/foaf/0.1/"))
        self.graph.bind("schema",  Namespace("https://schema.org/"))
        self.graph.bind("dcterms", DCTERMS)
        self.graph.bind("owl",     OWL)

    def _load(self):
        """TTL 파일이 있으면 로드, 없으면 빈 그래프 유지."""
        if TTL_PATH.exists():
            try:
                self.graph.parse(str(TTL_PATH), format="turtle")
            except Exception as e:
                # 파싱 실패 시 빈 그래프 유지
                self.graph = Graph()
                self._bind_prefixes()

    def reload(self):
        """파일에서 그래프를 다시 로드합니다."""
        self.graph = Graph()
        self._bind_prefixes()
        self._load()

    # ── 직렬화 ────────────────────────────────────────────────────────────────

    def save(self, log_entry: Optional[dict] = None):
        """그래프를 TTL 파일로 저장하고 변경 이력을 기록합니다."""
        RDF_DIR.mkdir(parents=True, exist_ok=True)
        self.graph.serialize(str(TTL_PATH), format="turtle", encoding="utf-8")
        if log_entry:
            self._append_log(log_entry)

    def serialize(self, format: str = "turtle") -> str:
        """그래프를 문자열로 직렬화합니다."""
        return self.graph.serialize(format=format)

    # ── 버전 관리 ─────────────────────────────────────────────────────────────

    def get_version(self) -> dict:
        """현재 버전 정보를 반환합니다."""
        if VERSION_PATH.exists():
            try:
                return json.loads(VERSION_PATH.read_text(encoding="utf-8"))
            except Exception:
                pass
        # 그래프에서 versionInfo 읽기
        onto_uri = URIRef(_DEFAULT_NS.rstrip("#/"))
        for _, _, v in self.graph.triples((onto_uri, OWL.versionInfo, None)):
            version_str = str(v)
            return {"version": version_str, "source": "graph"}
        return {"version": "1.0.0", "source": "default"}

    def bump_version(self, bump_type: str = "patch") -> dict:
        """버전을 증가시킵니다.

        bump_type:
          'patch' → 1.0.0 → 1.0.1  (속성·레이블 수정)
          'minor' → 1.0.0 → 1.1.0  (클래스 추가)
          'major' → 1.0.0 → 2.0.0  (클래스 삭제/구조 변경)
        """
        current = self.get_version().get("version", "1.0.0")
        parts = current.split(".")
        if len(parts) != 3:
            parts = ["1", "0", "0"]
        major, minor, patch = int(parts[0]), int(parts[1]), int(parts[2])

        if bump_type == "major":
            major += 1; minor = 0; patch = 0
        elif bump_type == "minor":
            minor += 1; patch = 0
        else:  # patch
            patch += 1

        new_version = f"{major}.{minor}.{patch}"

        # 그래프 내 versionInfo 갱신
        onto_uri = URIRef(_DEFAULT_NS.rstrip("#/"))
        self.graph.remove((onto_uri, OWL.versionInfo, None))
        self.graph.add((onto_uri, OWL.versionInfo, Literal(new_version)))

        # 파일 저장
        info = {
            "version":    new_version,
            "bump_type":  bump_type,
            "bumped_at":  datetime.now().isoformat(),
        }
        VERSION_PATH.write_text(json.dumps(info, ensure_ascii=False, indent=2), encoding="utf-8")
        self.save(log_entry={
            "action":    f"version_bump_{bump_type}",
            "version":   new_version,
            "timestamp": datetime.now().isoformat(),
        })
        return info

    # ── 변경 이력 ─────────────────────────────────────────────────────────────

    def _append_log(self, entry: dict):
        """change_log.json 에 이력 항목 추가."""
        logs: list = []
        if CHANGELOG_PATH.exists():
            try:
                logs = json.loads(CHANGELOG_PATH.read_text(encoding="utf-8"))
            except Exception:
                pass
        logs.append(entry)
        # 최근 200건만 유지
        if len(logs) > 200:
            logs = logs[-200:]
        CHANGELOG_PATH.write_text(json.dumps(logs, ensure_ascii=False, indent=2), encoding="utf-8")

    def get_changelog(self, limit: int = 50) -> list:
        if not CHANGELOG_PATH.exists():
            return []
        try:
            logs = json.loads(CHANGELOG_PATH.read_text(encoding="utf-8"))
            return logs[-limit:][::-1]  # 최신 순
        except Exception:
            return []

    # ── 클래스 조회 ────────────────────────────────────────────────────────────

    def list_classes(self) -> list[dict]:
        """OWL 클래스 목록을 반환합니다."""
        sparql = """
            PREFIX owl:  <http://www.w3.org/2002/07/owl#>
            PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
            SELECT DISTINCT ?cls ?label_ko ?label_en ?parent ?comment ?deprecated
            WHERE {
                ?cls a owl:Class .
                OPTIONAL { ?cls rdfs:label ?label_ko FILTER(lang(?label_ko) = "ko") }
                OPTIONAL { ?cls rdfs:label ?label_en FILTER(lang(?label_en) = "en") }
                OPTIONAL { ?cls rdfs:subClassOf ?parent }
                OPTIONAL { ?cls rdfs:comment ?comment FILTER(lang(?comment) = "ko") }
                OPTIONAL { ?cls owl:deprecated ?deprecated }
            }
            ORDER BY ?cls
        """
        results = []
        seen: set[str] = set()
        for row in self.graph.query(sparql):
            uri = str(row.cls)
            if uri in seen:
                continue
            seen.add(uri)
            results.append({
                "uri":        uri,
                "local":      uri.split("#")[-1].split("/")[-1],
                "label_ko":   str(row.label_ko)  if row.label_ko  else "",
                "label_en":   str(row.label_en)  if row.label_en  else "",
                "parent":     str(row.parent)    if row.parent    else "",
                "description": str(row.comment)  if row.comment   else "",
                "deprecated": bool(row.deprecated) if row.deprecated else False,
            })
        return results

    def get_class(self, uri: str) -> Optional[dict]:
        """특정 클래스 상세 정보를 반환합니다."""
        u = URIRef(uri)
        if (u, RDF.type, OWL.Class) not in self.graph:
            return None

        label_ko = label_en = parent = description = ""
        deprecated = False
        parents: list[str] = []
        equiv_classes: list[str] = []

        for _, _, v in self.graph.triples((u, RDFS.label, None)):
            if isinstance(v, Literal):
                if v.language == "ko":
                    label_ko = str(v)
                elif v.language == "en":
                    label_en = str(v)

        for _, _, v in self.graph.triples((u, RDFS.subClassOf, None)):
            parents.append(str(v))

        for _, _, v in self.graph.triples((u, OWL.equivalentClass, None)):
            equiv_classes.append(str(v))

        for _, _, v in self.graph.triples((u, RDFS.comment, None)):
            if isinstance(v, Literal) and v.language == "ko":
                description = str(v)

        for _, _, v in self.graph.triples((u, OWL.deprecated, None)):
            deprecated = True

        # 이 클래스를 domain/range로 사용하는 속성
        properties_as_domain: list[str] = []
        properties_as_range:  list[str] = []
        for prop, _, _ in self.graph.triples((None, RDFS.domain, u)):
            properties_as_domain.append(str(prop))
        for prop, _, _ in self.graph.triples((None, RDFS.range, u)):
            properties_as_range.append(str(prop))

        return {
            "uri":          uri,
            "local":        uri.split("#")[-1].split("/")[-1],
            "label_ko":     label_ko,
            "label_en":     label_en,
            "parents":      parents,
            "equiv_classes": equiv_classes,
            "description":  description,
            "deprecated":   deprecated,
            "props_domain": properties_as_domain,
            "props_range":  properties_as_range,
        }

    # ── 속성(Property) 조회 ──────────────────────────────────────────────────

    def list_properties(self) -> list[dict]:
        """OWL ObjectProperty + DatatypeProperty 목록을 반환합니다."""
        sparql = """
            PREFIX owl:  <http://www.w3.org/2002/07/owl#>
            PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
            SELECT DISTINCT ?prop ?label_ko ?domain ?range ?deprecated
            WHERE {
                { ?prop a owl:ObjectProperty } UNION { ?prop a owl:DatatypeProperty }
                OPTIONAL { ?prop rdfs:label ?label_ko FILTER(lang(?label_ko) = "ko") }
                OPTIONAL { ?prop rdfs:domain ?domain }
                OPTIONAL { ?prop rdfs:range  ?range  }
                OPTIONAL { ?prop owl:deprecated ?deprecated }
            }
            ORDER BY ?prop
        """
        results: list[dict] = []
        seen: set[str] = set()
        for row in self.graph.query(sparql):
            uri = str(row.prop)
            if uri in seen:
                continue
            seen.add(uri)
            results.append({
                "uri":        uri,
                "local":      uri.split("#")[-1].split("/")[-1],
                "label_ko":   str(row.label_ko) if row.label_ko else "",
                "domain":     str(row.domain)   if row.domain   else "",
                "range":      str(row.range)    if row.range    else "",
                "deprecated": bool(row.deprecated) if row.deprecated else False,
            })
        return results


# ── 싱글톤 접근 ───────────────────────────────────────────────────────────────

_store: Optional[RDFStore] = None


def get_rdf_store() -> RDFStore:
    """앱 전체에서 동일한 RDFStore 인스턴스를 반환합니다."""
    global _store
    if _store is None:
        _store = RDFStore()
    return _store


def reset_rdf_store():
    """테스트·재로드용 — 싱글톤을 초기화합니다."""
    global _store
    _store = None
