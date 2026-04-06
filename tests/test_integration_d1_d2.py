"""
tests/test_integration_d1_d2.py — Phase D 통합 검증

D1. 온톨로지 생성 → 클래스/속성 설정 → 확정 → 트리플 추출 전체 플로우
D2. 서버 재시작(재초기화) 후 data/ 에서 데이터 복원 확인
"""

from __future__ import annotations

import json
import pytest
from pathlib import Path

from ontology.ontology_manager import OntologyClass, OntologyManager, OntologyPredicate, OntologyStatus
from ontology.ontology_store import OntologyStore
from graph.graph_db import GraphDB, Triple
from graph.triple_manager import TripleManager
from pipeline.triple_extractor import TripleExtractor

# 샘플 구술 데이터
SAMPLE_TEXT = """
김영수는 1938년 경상북도 안동에서 태어났다.
그는 6·25전쟁에 참전하였으며, 전쟁 이후 서울로 이주하여 한국일보에서 기자로 일했다.
그의 스승은 이희승 선생이었으며, 서울대학교 국문과를 졸업했다.
"""

ONTOLOGY_CLASSES = [
    OntologyClass(name="Person",       label_ko="인물",   color="#4e79a7",
                  description="구술에 등장하는 사람", examples=["김영수", "이희승"]),
    OntologyClass(name="Place",        label_ko="장소",   color="#59a14f",
                  description="지명 및 장소", examples=["경북안동", "서울"]),
    OntologyClass(name="Event",        label_ko="사건",   color="#e15759",
                  description="역사적 사건", examples=["6·25전쟁"]),
    OntologyClass(name="Organization", label_ko="기관",   color="#76b7b2",
                  description="기관 및 단체", examples=["한국일보", "서울대학교"]),
]

ONTOLOGY_PREDICATES = [
    OntologyPredicate(name="출생지",  domain=["Person"], range_=["Place"],
                      description="인물의 출생 장소"),
    OntologyPredicate(name="참여함",  domain=["Person"], range_=["Event"],
                      description="사건 참여"),
    OntologyPredicate(name="거주지",  domain=["Person"], range_=["Place"],
                      description="거주 장소"),
    OntologyPredicate(name="소속기관",domain=["Person"], range_=["Organization"],
                      description="소속 기관"),
    OntologyPredicate(name="스승",    domain=["Person"], range_=["Person"],
                      description="사제 관계"),
    OntologyPredicate(name="졸업",    domain=["Person"], range_=["Organization"],
                      description="학교 졸업"),
]

SAMPLE_TRIPLES = [
    dict(subject="김영수", subject_type="Person",
         predicate="출생지", object_="경상북도 안동", object_type="Place"),
    dict(subject="김영수", subject_type="Person",
         predicate="참여함", object_="6·25전쟁", object_type="Event"),
    dict(subject="김영수", subject_type="Person",
         predicate="거주지", object_="서울", object_type="Place"),
    dict(subject="김영수", subject_type="Person",
         predicate="소속기관", object_="한국일보", object_type="Organization"),
    dict(subject="김영수", subject_type="Person",
         predicate="스승", object_="이희승", object_type="Person"),
    dict(subject="김영수", subject_type="Person",
         predicate="졸업", object_="서울대학교", object_type="Organization"),
]


# ── 픽스처 ────────────────────────────────────────────────────────────────────

@pytest.fixture
def data_dir(tmp_path):
    return tmp_path / "data"


@pytest.fixture
def store(data_dir):
    return OntologyStore(
        drafts_dir=data_dir / "ontologies" / "drafts",
        confirmed_dir=data_dir / "ontologies" / "confirmed",
    )


@pytest.fixture
def graph_file(data_dir):
    return data_dir / "triples" / "graph.json"


@pytest.fixture
def manager(store):
    return OntologyManager(store=store)


@pytest.fixture
def db(graph_file):
    return GraphDB(graph_file=graph_file, auto_save=True)


@pytest.fixture
def tm(db):
    return TripleManager(graph_db=db)


# ── D1: 전체 플로우 ───────────────────────────────────────────────────────────

class TestD1FullFlow:

    def test_step1_create_ontology_draft(self, manager):
        """1단계: 온톨로지 Draft 생성"""
        v = manager.create("v1.0", description="구술기록 통합 테스트")
        assert v.version_id == "v1.0"
        assert v.status == OntologyStatus.DRAFT

    def test_step2_update_classes_predicates(self, manager):
        """2단계: 클래스 + 속성 설정"""
        manager.create("v1.0")
        v = manager.update("v1.0",
                           classes=ONTOLOGY_CLASSES,
                           predicates=ONTOLOGY_PREDICATES)
        assert len(v.classes)    == len(ONTOLOGY_CLASSES)
        assert len(v.predicates) == len(ONTOLOGY_PREDICATES)

    def test_step3_confirm_ontology(self, manager, store):
        """3단계: Draft → Confirmed 확정"""
        manager.create("v1.0")
        manager.update("v1.0", classes=ONTOLOGY_CLASSES, predicates=ONTOLOGY_PREDICATES)
        v = manager.confirm("v1.0")

        assert v.status == OntologyStatus.CONFIRMED
        assert v.confirmed_at is not None
        # confirmed 파일 존재 확인
        assert (store.confirmed_dir / "v1.0.json").exists()
        # draft 파일 삭제 확인
        assert not (store.drafts_dir / "v1.0.json").exists()

    def test_step4_confirmed_blocks_modification(self, manager):
        """3단계 보조: Confirmed는 수정/삭제 불가"""
        manager.create("v1.0")
        manager.confirm("v1.0")
        with pytest.raises(PermissionError):
            manager.update("v1.0", description="수정 시도")

    def test_step5_create_triples(self, manager, tm):
        """4단계: 확정된 온톨로지 기반 트리플 생성"""
        manager.create("v1.0")
        manager.update("v1.0", classes=ONTOLOGY_CLASSES, predicates=ONTOLOGY_PREDICATES)
        manager.confirm("v1.0")

        result = tm.bulk_create(
            [{**t, "object": t.pop("object_")} for t in [dict(t) for t in SAMPLE_TRIPLES]],
            ontology_version="v1.0",
            source_record_id="rec_001",
        )
        assert result["added"]   == len(SAMPLE_TRIPLES)
        assert result["skipped"] == 0

    def test_step6_graph_json_created(self, manager, tm, graph_file):
        """5단계: data/triples/graph.json 파일 생성 확인"""
        manager.create("v1.0")
        manager.confirm("v1.0")

        for t in SAMPLE_TRIPLES:
            tm.create(ontology_version="v1.0", **t)

        assert graph_file.exists(), "graph.json 이 생성되지 않았습니다"
        data = json.loads(graph_file.read_text(encoding="utf-8"))
        assert data["version"] == "4.0"
        assert len(data["triples"]) == len(SAMPLE_TRIPLES)
        assert data["stats"]["active"] == len(SAMPLE_TRIPLES)

    def test_step7_search_subgraph(self, manager, tm):
        """6단계: 검색 서브그래프 (1홉 포함)"""
        manager.create("v1.0")
        manager.confirm("v1.0")
        for t in SAMPLE_TRIPLES:
            tm.create(ontology_version="v1.0", **t)

        result = tm.search("김영수")
        node_ids = {n["id"] for n in result["nodes"]}

        # 매칭 노드
        assert "김영수" in node_ids
        # 1홉 이웃 (연결된 모든 노드)
        assert "경상북도 안동" in node_ids
        assert "6·25전쟁"    in node_ids
        assert "서울"        in node_ids
        assert "한국일보"    in node_ids

    def test_step8_stats(self, manager, tm):
        """7단계: 통계 정합성"""
        manager.create("v1.0")
        manager.confirm("v1.0")
        for t in SAMPLE_TRIPLES:
            tm.create(ontology_version="v1.0", **t)

        s = tm.stats()
        assert s["triples"] == len(SAMPLE_TRIPLES)
        assert s["active"]  == len(SAMPLE_TRIPLES)
        assert s["archived"] == 0
        # 노드 = 김영수(1) + 장소(2) + 사건(1) + 기관(2) + 인물(1: 이희승) = 7
        assert s["nodes"] == 7


# ── D2: 재시작 후 데이터 복원 ─────────────────────────────────────────────────

class TestD2PersistenceReload:

    def test_ontology_survives_restart(self, data_dir):
        """온톨로지: 재초기화 후 Confirmed 버전 복원"""
        store = OntologyStore(
            drafts_dir=data_dir / "ontologies" / "drafts",
            confirmed_dir=data_dir / "ontologies" / "confirmed",
        )
        m1 = OntologyManager(store=store)
        m1.create("v1.0")
        m1.update("v1.0", classes=ONTOLOGY_CLASSES)
        m1.confirm("v1.0")

        # 재초기화 (서버 재시작 시뮬레이션)
        m2 = OntologyManager(store=store)
        v = m2.get("v1.0")
        assert v.status == OntologyStatus.CONFIRMED
        assert len(v.classes) == len(ONTOLOGY_CLASSES)
        assert v.classes[0].name == "Person"

    def test_triples_survive_restart(self, graph_file):
        """트리플: 재초기화 후 graph.json 에서 트리플 복원"""
        db1 = GraphDB(graph_file=graph_file, auto_save=True)
        tm1 = TripleManager(db1)
        for t in SAMPLE_TRIPLES:
            tm1.create(ontology_version="v1.0", **t)
        triple_ids = {t.id for t in db1.all_triples()}

        # 재초기화
        db2 = GraphDB(graph_file=graph_file, auto_save=False)
        tm2 = TripleManager(db2)

        restored_ids = {t.id for t in db2.all_triples()}
        assert restored_ids == triple_ids, "재시작 후 트리플 ID 불일치"
        assert db2.stats()["triples"] == len(SAMPLE_TRIPLES)

    def test_nodes_survive_restart(self, graph_file):
        """노드: 재초기화 후 노드 정보 복원"""
        db1 = GraphDB(graph_file=graph_file, auto_save=True)
        tm1 = TripleManager(db1)
        for t in SAMPLE_TRIPLES:
            tm1.create(ontology_version="v1.0", **t)

        db2 = GraphDB(graph_file=graph_file, auto_save=False)
        assert "김영수" in db2._nodes
        assert db2._nodes["김영수"]["type"] == "Person"

    def test_graph_json_format(self, graph_file):
        """graph.json 포맷 검증"""
        db = GraphDB(graph_file=graph_file, auto_save=True)
        tm = TripleManager(db)
        for t in SAMPLE_TRIPLES:
            tm.create(ontology_version="v1.0", **t)

        data = json.loads(graph_file.read_text(encoding="utf-8"))
        assert "version"      in data
        assert "last_updated" in data
        assert "stats"        in data
        assert "nodes"        in data
        assert "triples"      in data

        # 트리플 필드 검증
        first = data["triples"][0]
        for field in ["id", "subject", "subject_type", "predicate",
                      "object", "object_type", "ontology_version",
                      "status", "created_at", "confidence"]:
            assert field in first, f"누락된 필드: {field}"
