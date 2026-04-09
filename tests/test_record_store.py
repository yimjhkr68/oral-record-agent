"""RecordStore 단위 테스트"""
import os
import pytest
import tempfile

# 테스트용 임시 DB 사용
_tmp = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
_tmp.close()
os.environ["DB_PATH"] = _tmp.name

from core.database import init_db
from core.record_store import RecordStore


@pytest.fixture(autouse=True)
def setup_db():
    init_db()
    yield
    # 테이블 비우기 (다음 테스트와 격리)
    from core.database import get_connection
    with get_connection() as conn:
        conn.execute("DELETE FROM session_records")
        conn.execute("DELETE FROM extraction_sessions")
        conn.execute("DELETE FROM oral_records")


@pytest.fixture
def store():
    return RecordStore()


class TestCreateText:
    def test_basic(self, store):
        r = store.create_text("제목1", "내용입니다")
        assert r["id"]
        assert r["title"] == "제목1"
        assert r["content"] == "내용입니다"
        assert r["source_type"] == "text"
        assert r["char_count"] == len("내용입니다")
        assert r["is_deleted"] == 0

    def test_with_note(self, store):
        r = store.create_text("t", "c", note="메모")
        assert r["note"] == "메모"


class TestCreateFile:
    def test_basic(self, store):
        r = store.create_file("interview_001.txt", "인터뷰 내용")
        assert r["file_name"] == "interview_001.txt"
        assert r["title"] == "interview_001"
        assert r["source_type"] == "file"

    def test_no_extension(self, store):
        r = store.create_file("myfile", "내용")
        assert r["title"] == "myfile"


class TestList:
    def test_empty(self, store):
        assert store.list() == []

    def test_returns_latest_first(self, store):
        store.create_text("A", "내용A")
        store.create_text("B", "내용B")
        records = store.list()
        assert len(records) == 2
        assert records[0]["title"] == "B"

    def test_query_filter(self, store):
        store.create_text("제주 4·3", "해방 이후 이야기")
        store.create_text("다른 기록", "전혀 무관한 내용")
        result = store.list(query="제주")
        assert len(result) == 1
        assert result[0]["title"] == "제주 4·3"

    def test_source_type_filter(self, store):
        store.create_text("텍스트 기록", "내용")
        store.create_file("file.txt", "내용")
        assert len(store.list(source_type="text")) == 1
        assert len(store.list(source_type="file")) == 1

    def test_soft_deleted_excluded(self, store):
        r = store.create_text("삭제될 기록", "내용")
        store.delete(r["id"])
        assert store.list() == []


class TestGet:
    def test_existing(self, store):
        r = store.create_text("제목", "전문 내용")
        fetched = store.get(r["id"])
        assert fetched["content"] == "전문 내용"

    def test_nonexistent(self, store):
        assert store.get("no-such-id") is None

    def test_deleted_returns_none(self, store):
        r = store.create_text("제목", "내용")
        store.delete(r["id"])
        assert store.get(r["id"]) is None


class TestUpdate:
    def test_title(self, store):
        r = store.create_text("원래 제목", "내용")
        updated = store.update(r["id"], title="새 제목")
        assert updated["title"] == "새 제목"
        assert updated["content"] == "내용"  # content 불변

    def test_note(self, store):
        r = store.create_text("제목", "내용")
        updated = store.update(r["id"], note="새 메모")
        assert updated["note"] == "새 메모"

    def test_no_changes(self, store):
        r = store.create_text("제목", "내용")
        unchanged = store.update(r["id"])
        assert unchanged["title"] == "제목"


class TestDelete:
    def test_soft_delete(self, store):
        r = store.create_text("제목", "내용")
        assert store.delete(r["id"]) is True
        assert store.get(r["id"]) is None

    def test_nonexistent_returns_false(self, store):
        assert store.delete("ghost-id") is False

    def test_double_delete_returns_false(self, store):
        r = store.create_text("제목", "내용")
        store.delete(r["id"])
        assert store.delete(r["id"]) is False


class TestGetUsage:
    def test_no_usage(self, store):
        r = store.create_text("제목", "내용")
        assert store.get_usage(r["id"]) == []
