"""tests/test_triple_categories.py — Phase C: 범주화 + 확장 검색 테스트"""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from graph.graph_db import GraphDB
from graph.triple_manager import TripleManager


# ── 픽스처 ────────────────────────────────────────────────────────────────────

@pytest.fixture
def tm(tmp_path):
    db = GraphDB(graph_file=tmp_path / "graph.json", auto_save=True)
    return TripleManager(graph_db=db)


@pytest.fixture
def populated(tm):
    """Person·Place·Event 클래스 트리플 세트."""
    tm.create("김영수", "Person",  "출생지",  "경북안동",  "Place",   "v1.0")
    tm.create("김영수", "Person",  "참여함",  "6·25전쟁", "Event",   "v1.0")
    tm.create("박철호", "Person",  "거주지",  "서울",     "Place",   "v1.0")
    tm.create("서울",   "Place",   "포함함",  "강남구",   "Place",   "v1.0")
    tm.create("6·25전쟁","Event",  "발생일",  "1950",     "Time",    "v1.0")
    return tm


@pytest.fixture
def api(tmp_path):
    import api.router_triple as rt
    rt._db = GraphDB(graph_file=tmp_path / "graph.json", auto_save=True)
    rt._tm = TripleManager(graph_db=rt._db)
    rt._extractor = None
    from main import app
    return TestClient(app, raise_server_exceptions=True)


# ── get_categories 단위 테스트 ────────────────────────────────────────────────

def test_categories_all_classes_present(populated):
    result = populated.get_categories()
    names = {c["name"] for c in result["categories"]}
    assert "Person" in names
    assert "Place"  in names
    assert "Event"  in names
    assert "Time"   in names


def test_categories_count_correct(populated):
    result = populated.get_categories()
    cat = {c["name"]: c for c in result["categories"]}
    # Person: 김영수(2번), 박철호(1번) → subject인 트리플 3개 + object 없음 = 3 triple_ids
    assert cat["Person"]["count"] == 3
    # Place: 경북안동, 서울, 강남구 등 → 여러 트리플
    assert cat["Place"]["count"] >= 3


def test_categories_sorted_by_count_desc(populated):
    result = populated.get_categories()
    counts = [c["count"] for c in result["categories"]]
    assert counts == sorted(counts, reverse=True)


def test_categories_total_triples(populated):
    result = populated.get_categories()
    assert result["total_triples"] == 5


def test_categories_triple_ids_unique_per_cat(populated):
    """같은 triple_id가 한 카테고리 안에서 중복되지 않아야 함."""
    result = populated.get_categories()
    for cat in result["categories"]:
        assert len(cat["triple_ids"]) == len(set(cat["triple_ids"]))


def test_categories_filter_by_ontology_version(tm):
    tm.create("A", "Person", "관계", "B", "Place", "v1.0")
    tm.create("C", "Event",  "관계", "D", "Time",  "v2.0")
    result = tm.get_categories(ontology_version="v1.0")
    names = {c["name"] for c in result["categories"]}
    assert "Person" in names and "Place" in names
    assert "Event" not in names and "Time" not in names


def test_categories_status_archived_only(populated):
    # 1개 아카이브
    triples = populated.list_triples()
    populated.archive(triples[0].id)
    archived_result = populated.get_categories(status="archived")
    assert archived_result["total_triples"] == 1
    active_result = populated.get_categories(status="active")
    assert active_result["total_triples"] == 4


def test_categories_empty_when_no_triples(tm):
    result = tm.get_categories()
    assert result["categories"] == []
    assert result["total_triples"] == 0


# ── search_with_categories 단위 테스트 ───────────────────────────────────────

def test_search_returns_triples_and_categories(populated):
    result = populated.search_with_categories("김영수")
    assert "triples" in result
    assert "categories" in result
    assert "total" in result
    assert result["query"] == "김영수"


def test_search_categories_from_result(populated):
    result = populated.search_with_categories("김영수")
    names = {c["name"] for c in result["categories"]}
    # 김영수(Person)가 subject → Person, Place, Event 카테고리 포함
    assert "Person" in names


def test_search_empty_query_returns_all(populated):
    result = populated.search_with_categories("")
    assert result["total"] == 5


def test_search_no_match_returns_empty(populated):
    result = populated.search_with_categories("존재하지않는키워드")
    assert result["total"] == 0
    assert result["categories"] == []


def test_search_categories_count_matches_triples(populated):
    result = populated.search_with_categories("김영수")
    cat_map = {c["name"]: c for c in result["categories"]}
    # 결과 트리플에서 Person 관련 건수가 cat_map의 count와 일치
    triple_ids_with_person = {
        t["id"] for t in result["triples"]
        if t.get("subject_type") == "Person" or t.get("object_type") == "Person"
    }
    assert cat_map.get("Person", {}).get("count", 0) == len(triple_ids_with_person)


# ── API 엔드포인트 테스트 ─────────────────────────────────────────────────────

def _seed(api):
    for subj, s_type, pred, obj, o_type in [
        ("김영수", "Person", "출생지",  "경북안동",  "Place"),
        ("김영수", "Person", "참여함",  "6·25전쟁", "Event"),
        ("박철호", "Person", "거주지",  "서울",     "Place"),
    ]:
        api.post("/api/triples/", json={
            "subject": subj, "subject_type": s_type,
            "predicate": pred, "object": obj, "object_type": o_type,
            "ontology_version": "v1.0",
        }, headers={"x-role": "admin"})


def test_categories_endpoint_status_200(api):
    _seed(api)
    resp = api.get("/api/triples/categories")
    assert resp.status_code == 200


def test_categories_endpoint_structure(api):
    _seed(api)
    data = api.get("/api/triples/categories").json()
    assert "categories" in data
    assert "total_triples" in data
    for cat in data["categories"]:
        assert "name" in cat
        assert "label_ko" in cat
        assert "count" in cat
        assert "triple_ids" in cat


def test_categories_endpoint_correct_names(api):
    _seed(api)
    data = api.get("/api/triples/categories").json()
    names = {c["name"] for c in data["categories"]}
    assert "Person" in names
    assert "Place"  in names
    assert "Event"  in names


def test_search_endpoint_status_200(api):
    _seed(api)
    resp = api.get("/api/triples/search?q=김영수")
    assert resp.status_code == 200


def test_search_endpoint_structure(api):
    _seed(api)
    data = api.get("/api/triples/search?q=김영수").json()
    assert "triples"    in data
    assert "categories" in data
    assert "total"      in data
    assert "query"      in data
    assert data["query"] == "김영수"


def test_search_endpoint_label_ko_fallback(api):
    """온톨로지 버전 지정 없으면 label_ko = name."""
    _seed(api)
    data = api.get("/api/triples/search").json()
    for cat in data["categories"]:
        # label_ko가 없거나 name과 같아야 함 (version 미지정 시 fallback)
        assert cat["label_ko"] == cat.get("label_ko", cat["name"])


def test_search_endpoint_empty_query_returns_all(api):
    _seed(api)
    data = api.get("/api/triples/search").json()
    assert data["total"] == 3


def test_categories_no_role_required(api):
    """categories 엔드포인트는 인증 불필요."""
    resp = api.get("/api/triples/categories")
    assert resp.status_code == 200


def test_search_no_role_required(api):
    """search 엔드포인트는 인증 불필요."""
    resp = api.get("/api/triples/search")
    assert resp.status_code == 200
