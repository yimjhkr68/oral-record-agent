# -*- coding: utf-8 -*-
"""core/rdf_migration.py — SQLite + JSON 데이터를 RDF로 마이그레이션하는 서비스 (v5.0)

실제 저장소 구조:
  - 온톨로지  : data/ontologies/drafts/*.json  +  data/ontologies/confirmed/*.json
  - 트리플    : data/triples/graph.json
  - 구술기록  : data/oral_record_agent.db  (oral_records 테이블)
"""

import json
import re
import shutil
import sqlite3
from datetime import datetime
from pathlib import Path
from typing import Optional

from rdflib import (
    Graph, Namespace, URIRef, Literal,
    RDF, RDFS, OWL
)
from rdflib.namespace import FOAF, XSD, DCTERMS

# ── 기본 경로 ──────────────────────────────────────────────────────────────────
_ROOT       = Path(__file__).parent.parent
DB_PATH     = _ROOT / "data" / "oral_record_agent.db"
ONT_DIR     = _ROOT / "data" / "ontologies"
TRIPLE_FILE = _ROOT / "data" / "triples" / "graph.json"
RDF_DIR     = _ROOT / "data" / "rdf"
BACKUP_DIR  = _ROOT / "data" / "backups"
STATE_PATH  = _ROOT / "data" / "migration_state.json"

# ── 네임스페이스 접두사 해석 테이블 ─────────────────────────────────────────────
_PREFIX_MAP: dict[str, str] = {
    "foaf":    "http://xmlns.com/foaf/0.1/",
    "cidoc":   "http://www.cidoc-crm.org/cidoc-crm/",
    "crm":     "http://www.cidoc-crm.org/cidoc-crm/",
    "rico":    "https://www.ica.org/standards/RiC/ontology#",
    "schema":  "https://schema.org/",
    "dc":      "http://purl.org/dc/elements/1.1/",
    "dcterms": "http://purl.org/dc/terms/",
    "skos":    "http://www.w3.org/2004/02/skos/core#",
    "owl":     "http://www.w3.org/2002/07/owl#",
    "rdfs":    "http://www.w3.org/2000/01/rdf-schema#",
}


def _resolve_curie(curie: str) -> Optional[str]:
    """'crm:E21_Person' 같은 CURIE를 절대 URI로 변환. 실패 시 None."""
    if ":" not in curie:
        return None
    prefix, local = curie.split(":", 1)
    base = _PREFIX_MAP.get(prefix.strip().lower())
    if base:
        return base + local.strip()
    return None


def _uri_safe(text: str) -> str:
    """한글·공백 등을 URI 안전 문자로 변환."""
    return re.sub(r"[^\w]", "_", str(text)).strip("_") or "Unknown"


def _parse_standard_tag(tag: str) -> list[str]:
    """'foaf:Person · cidoc:E21_Person' → ['foaf:Person', 'cidoc:E21_Person']"""
    if not tag:
        return []
    parts = re.split(r"[·,;\s]+", tag)
    return [p.strip() for p in parts if p.strip() and ":" in p]


# ── RDFMigrationService ────────────────────────────────────────────────────────

class RDFMigrationService:
    """SQLite + JSON 파일 기반 v4.0 데이터를 RDF 그래프로 변환."""

    def __init__(self):
        RDF_DIR.mkdir(parents=True, exist_ok=True)
        BACKUP_DIR.mkdir(parents=True, exist_ok=True)

    # ── 상태 관리 ──────────────────────────────────────────────────────────────

    def get_status(self) -> dict:
        stats = self._count_source_data()
        rdf_exists  = (RDF_DIR / "tmp" / "oral-history.ttl").exists()
        confirmed   = (RDF_DIR / "v1.0" / "oral-history.ttl").exists()
        backup_list = sorted(BACKUP_DIR.glob("oral_record_v4_backup_*.tar.gz"), reverse=True)
        state       = self._load_state()

        return {
            "sqlite": stats,
            "rdf_converted": rdf_exists,
            "rdf_confirmed": confirmed,
            "backup_files":  [f.name for f in backup_list],
            "last_migration": state.get("last_migration"),
            "last_confirmed": state.get("confirmed_at"),
        }

    # ── DB 분석 ────────────────────────────────────────────────────────────────

    def analyze_db(self) -> dict:
        result: dict = {}

        # 온톨로지 버전 분석
        drafts    = list((ONT_DIR / "drafts").glob("*.json"))    if (ONT_DIR / "drafts").exists()    else []
        confirmed = list((ONT_DIR / "confirmed").glob("*.json")) if (ONT_DIR / "confirmed").exists() else []
        sample_classes: list[str] = []
        sample_predicates: list[str] = []
        total_classes = total_predicates = 0

        for f in confirmed + drafts:
            try:
                data = json.loads(f.read_text(encoding="utf-8"))
                cls_list  = data.get("classes", [])
                pred_list = data.get("predicates", [])
                total_classes     += len(cls_list)
                total_predicates  += len(pred_list)
                if not sample_classes:
                    sample_classes    = [c.get("name", "") for c in cls_list[:5]]
                    sample_predicates = [p.get("name", "") for p in pred_list[:5]]
            except Exception:
                pass

        result["ontologies"] = {
            "draft_count":     len(drafts),
            "confirmed_count": len(confirmed),
            "total_classes":   total_classes,
            "total_predicates": total_predicates,
            "sample_classes":  sample_classes,
            "sample_predicates": sample_predicates,
        }

        # 트리플 분석
        triple_stats: dict = {"count": 0, "active": 0, "archived": 0}
        if TRIPLE_FILE.exists():
            try:
                raw = json.loads(TRIPLE_FILE.read_text(encoding="utf-8"))
                triples = raw if isinstance(raw, list) else raw.get("triples", [])
                triple_stats["count"] = len(triples)
                triple_stats["active"]   = sum(1 for t in triples if t.get("status") == "active")
                triple_stats["archived"] = sum(1 for t in triples if t.get("status") == "archived")
            except Exception:
                pass
        result["triples"] = triple_stats

        # 구술기록 분석 (SQLite)
        record_stats: dict = {"count": 0, "columns": []}
        if DB_PATH.exists():
            try:
                conn = sqlite3.connect(str(DB_PATH))
                record_stats["count"] = conn.execute(
                    "SELECT COUNT(*) FROM oral_records WHERE is_deleted=0"
                ).fetchone()[0]
                record_stats["columns"] = [
                    row[1] for row in conn.execute("PRAGMA table_info(oral_records)").fetchall()
                ]
                conn.close()
            except Exception:
                pass
        result["records"] = record_stats

        return {"tables": result}

    # ── 백업 ──────────────────────────────────────────────────────────────────

    def backup(self) -> dict:
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")

        # 데이터 디렉토리 전체를 tar.gz 로 백업
        import tarfile
        archive_path = BACKUP_DIR / f"oral_record_v4_backup_{ts}.tar.gz"
        data_dir     = _ROOT / "data"

        with tarfile.open(str(archive_path), "w:gz") as tar:
            # SQLite DB
            if DB_PATH.exists():
                tar.add(str(DB_PATH), arcname="oral_record_agent.db")
            # 온톨로지 JSON
            if ONT_DIR.exists():
                tar.add(str(ONT_DIR), arcname="ontologies")
            # 트리플
            if TRIPLE_FILE.exists():
                tar.add(str(TRIPLE_FILE), arcname="triples/graph.json")

        size_kb = archive_path.stat().st_size // 1024
        self._save_state({"last_backup": archive_path.name, "backup_at": datetime.now().isoformat()})
        return {"backup_file": archive_path.name, "size_kb": size_kb}

    # ── 마이그레이션 실행 ──────────────────────────────────────────────────────

    def run(self, namespace_uri: str, formats: list[str]) -> dict:
        ORA  = Namespace(namespace_uri)
        CRM  = Namespace("http://www.cidoc-crm.org/cidoc-crm/")
        RICO = Namespace("https://www.ica.org/standards/RiC/ontology#")
        SCH  = Namespace("https://schema.org/")

        g = Graph()
        g.bind("ora",     ORA)
        g.bind("crm",     CRM)
        g.bind("rico",    RICO)
        g.bind("foaf",    FOAF)
        g.bind("schema",  SCH)
        g.bind("dcterms", DCTERMS)
        g.bind("owl",     OWL)

        # 온톨로지 선언
        onto_uri = URIRef(namespace_uri.rstrip("#/"))
        g.add((onto_uri, RDF.type,       OWL.Ontology))
        g.add((onto_uri, RDFS.label,     Literal("한국 구술기록 온톨로지", lang="ko")))
        g.add((onto_uri, OWL.versionInfo, Literal("1.0.0")))
        g.add((onto_uri, DCTERMS.created, Literal(datetime.now().date().isoformat(), datatype=XSD.date)))

        # ── 온톨로지 클래스·속성 변환 ────────────────────────────────────────
        processed_classes: set[str] = set()
        processed_predicates: set[str] = set()

        for src_dir in [ONT_DIR / "confirmed", ONT_DIR / "drafts"]:
            if not src_dir.exists():
                continue
            for f in sorted(src_dir.glob("*.json")):
                try:
                    data = json.loads(f.read_text(encoding="utf-8"))
                except Exception:
                    continue

                # 클래스
                for cls in data.get("classes", []):
                    name = cls.get("name", "")
                    if not name or name in processed_classes:
                        continue
                    processed_classes.add(name)

                    safe    = _uri_safe(name)
                    cls_uri = ORA[safe]
                    g.add((cls_uri, RDF.type,   OWL.Class))
                    g.add((cls_uri, RDFS.label, Literal(name, lang="ko")))
                    label_ko = cls.get("label_ko", "")
                    if label_ko and label_ko != name:
                        g.add((cls_uri, RDFS.label, Literal(label_ko, lang="ko")))
                    desc = cls.get("description", "")
                    if desc:
                        g.add((cls_uri, RDFS.comment, Literal(desc, lang="ko")))

                    # standard_tag → rdfs:subClassOf / owl:equivalentClass
                    for curie in _parse_standard_tag(cls.get("standard_tag", "")):
                        uri = _resolve_curie(curie)
                        if uri:
                            g.add((cls_uri, RDFS.subClassOf, URIRef(uri)))

                    # mappings (ClassMapping 배열)
                    for mapping in cls.get("mappings", []):
                        curie = mapping.get("curie", "")
                        uri   = _resolve_curie(curie)
                        if uri:
                            if mapping.get("is_primary", True):
                                g.add((cls_uri, OWL.equivalentClass, URIRef(uri)))
                            else:
                                g.add((cls_uri, RDFS.subClassOf, URIRef(uri)))

                # 속성(predicate)
                for pred in data.get("predicates", []):
                    name = pred.get("name", "")
                    if not name or name in processed_predicates:
                        continue
                    processed_predicates.add(name)

                    safe     = _uri_safe(name)
                    prop_uri = ORA[safe]
                    g.add((prop_uri, RDF.type,   OWL.ObjectProperty))
                    g.add((prop_uri, RDFS.label, Literal(name, lang="ko")))
                    desc = pred.get("description", "")
                    if desc:
                        g.add((prop_uri, RDFS.comment, Literal(desc, lang="ko")))

                    for d_name in pred.get("domain", []):
                        g.add((prop_uri, RDFS.domain, ORA[_uri_safe(d_name)]))
                    for r_name in pred.get("range_", []):
                        g.add((prop_uri, RDFS.range,  ORA[_uri_safe(r_name)]))

                    for curie in _parse_standard_tag(pred.get("standard_tag", "")):
                        uri = _resolve_curie(curie)
                        if uri:
                            g.add((prop_uri, OWL.equivalentProperty, URIRef(uri)))

        # ── 트리플 변환 ────────────────────────────────────────────────────────
        if TRIPLE_FILE.exists():
            try:
                raw     = json.loads(TRIPLE_FILE.read_text(encoding="utf-8"))
                triples = raw if isinstance(raw, list) else raw.get("triples", [])
                for t in triples:
                    if t.get("status") not in ("active", "archived"):
                        continue
                    s = t.get("subject", "").strip()
                    p = t.get("predicate", "").strip()
                    o = t.get("object", "").strip()
                    if not (s and p and o):
                        continue
                    s_uri = ORA[_uri_safe(s)]
                    p_uri = ORA[_uri_safe(p)]

                    # subject 타입 추가
                    s_type = t.get("subject_type", "")
                    if s_type:
                        g.add((s_uri, RDF.type, ORA[_uri_safe(s_type)]))

                    # object: 타입이 있으면 URI, 없으면 Literal
                    o_type = t.get("object_type", "")
                    if o_type:
                        o_uri = ORA[_uri_safe(o)]
                        g.add((o_uri, RDF.type, ORA[_uri_safe(o_type)]))
                        g.add((s_uri, p_uri, o_uri))
                    else:
                        g.add((s_uri, p_uri, Literal(o)))

                    # 출처 기록
                    src_id = t.get("source_record_id")
                    if src_id:
                        g.add((s_uri, DCTERMS.source, Literal(src_id)))
            except Exception:
                pass

        # ── 구술기록 변환 ──────────────────────────────────────────────────────
        OralRecord = ORA["OralRecord"]
        g.add((OralRecord, RDF.type,   OWL.Class))
        g.add((OralRecord, RDFS.label, Literal("구술기록", lang="ko")))

        if DB_PATH.exists():
            try:
                conn = sqlite3.connect(str(DB_PATH))
                conn.row_factory = sqlite3.Row
                rows = conn.execute(
                    "SELECT id, title, content, created_at FROM oral_records WHERE is_deleted=0"
                ).fetchall()
                for row in rows:
                    rec_uri = ORA[f"record_{_uri_safe(row['id'])}"]
                    g.add((rec_uri, RDF.type,        OralRecord))
                    g.add((rec_uri, RDFS.label,      Literal(row["title"], lang="ko")))
                    g.add((rec_uri, DCTERMS.created, Literal(row["created_at"])))
                    if row["content"]:
                        g.add((rec_uri, DCTERMS.description, Literal(row["content"][:500], lang="ko")))
                conn.close()
            except Exception:
                pass

        # ── 직렬화 ────────────────────────────────────────────────────────────
        tmp_dir = RDF_DIR / "tmp"
        tmp_dir.mkdir(parents=True, exist_ok=True)

        format_map = {
            "turtle":  ("oral-history.ttl",    "turtle"),
            "json-ld": ("oral-history.jsonld",  "json-ld"),
            "xml":     ("oral-history.owl",     "xml"),
        }
        saved: list[str] = []
        for fmt in formats:
            if fmt in format_map:
                fname, rfmt = format_map[fmt]
                out = tmp_dir / fname
                g.serialize(str(out), format=rfmt, encoding="utf-8")
                saved.append(fname)

        triple_count = len(g)
        self._save_state({
            "last_migration": datetime.now().isoformat(),
            "triple_count":   triple_count,
            "confirmed":      False,
        })
        return {
            "triple_count": triple_count,
            "saved_files":  saved,
            "classes_converted":    len(processed_classes),
            "predicates_converted": len(processed_predicates),
        }

    # ── 미리보기 ───────────────────────────────────────────────────────────────

    def preview(self, limit: int = 50) -> dict:
        tmp_ttl = RDF_DIR / "tmp" / "oral-history.ttl"
        if not tmp_ttl.exists():
            return {"error": "마이그레이션을 먼저 실행하세요"}
        g = Graph()
        g.parse(str(tmp_ttl), format="turtle")

        triples: list[dict] = []
        for i, (s, p, o) in enumerate(g):
            if i >= limit:
                break
            triples.append({"s": str(s), "p": str(p), "o": str(o)})

        # Turtle 앞부분 샘플
        turtle_text = g.serialize(format="turtle")
        return {
            "total": len(g),
            "preview_count": len(triples),
            "triples": triples,
            "turtle_sample": turtle_text[:3000],
        }

    # ── 확정 ──────────────────────────────────────────────────────────────────

    def confirm(self) -> dict:
        tmp_dir   = RDF_DIR / "tmp"
        final_dir = RDF_DIR / "v1.0"
        final_dir.mkdir(parents=True, exist_ok=True)

        if not tmp_dir.exists() or not any(tmp_dir.iterdir()):
            return {"error": "확정할 RDF 파일이 없습니다. 마이그레이션을 먼저 실행하세요"}

        copied: list[str] = []
        for f in tmp_dir.iterdir():
            if f.is_file():
                shutil.copy2(f, final_dir / f.name)
                shutil.copy2(f, RDF_DIR / f.name)   # rdf/ 루트에도 최신 복사
                copied.append(f.name)

        self._save_state({
            "confirmed":    True,
            "confirmed_at": datetime.now().isoformat(),
            "confirmed_files": copied,
        })
        return {
            "status":   "confirmed",
            "path":     str(final_dir),
            "files":    copied,
        }

    # ── 롤백 ──────────────────────────────────────────────────────────────────

    def rollback(self) -> dict:
        import tarfile
        backups = sorted(BACKUP_DIR.glob("oral_record_v4_backup_*.tar.gz"), reverse=True)
        if not backups:
            return {"error": "백업 파일이 없습니다. 백업을 먼저 실행하세요"}

        latest = backups[0]
        data_dir = _ROOT / "data"

        with tarfile.open(str(latest), "r:gz") as tar:
            tar.extractall(str(data_dir))

        # RDF 임시 파일 삭제
        tmp_dir = RDF_DIR / "tmp"
        if tmp_dir.exists():
            shutil.rmtree(tmp_dir)

        self._save_state({
            "confirmed":      False,
            "last_rollback":  datetime.now().isoformat(),
            "restored_from":  latest.name,
        })
        return {"status": "rolled_back", "restored_from": latest.name}

    # ── 내부 유틸 ──────────────────────────────────────────────────────────────

    def _count_source_data(self) -> dict:
        """현재 데이터 수 집계."""
        drafts    = len(list((ONT_DIR / "drafts").glob("*.json")))    if (ONT_DIR / "drafts").exists()    else 0
        confirmed = len(list((ONT_DIR / "confirmed").glob("*.json"))) if (ONT_DIR / "confirmed").exists() else 0
        triple_count = 0
        if TRIPLE_FILE.exists():
            try:
                raw = json.loads(TRIPLE_FILE.read_text(encoding="utf-8"))
                triples = raw if isinstance(raw, list) else raw.get("triples", [])
                triple_count = sum(1 for t in triples if t.get("status") == "active")
            except Exception:
                pass
        record_count = 0
        if DB_PATH.exists():
            try:
                conn = sqlite3.connect(str(DB_PATH))
                record_count = conn.execute(
                    "SELECT COUNT(*) FROM oral_records WHERE is_deleted=0"
                ).fetchone()[0]
                conn.close()
            except Exception:
                pass
        return {
            "ontology_drafts":    drafts,
            "ontology_confirmed": confirmed,
            "active_triples":     triple_count,
            "records":            record_count,
        }

    def _load_state(self) -> dict:
        if STATE_PATH.exists():
            try:
                return json.loads(STATE_PATH.read_text(encoding="utf-8"))
            except Exception:
                pass
        return {}

    def _save_state(self, data: dict):
        current = self._load_state()
        current.update(data)
        STATE_PATH.write_text(
            json.dumps(current, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
