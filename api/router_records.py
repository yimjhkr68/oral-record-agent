"""구술기록 API"""
import io
from fastapi import APIRouter, HTTPException, UploadFile, File, Query
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from typing import Optional
from core.record_store import RecordStore

router = APIRouter(prefix="/api/records", tags=["records"])
store = RecordStore()


class TextInput(BaseModel):
    title: str
    content: str
    note: str = ""


class RecordUpdate(BaseModel):
    title: Optional[str] = None
    note: Optional[str] = None


# ── 텍스트 입력 ──────────────────────────────────────────────────────────────

@router.post("/text", status_code=201)
def create_text_record(body: TextInput):
    if not body.title.strip():
        raise HTTPException(400, "title 필수")
    if not body.content.strip():
        raise HTTPException(400, "content 필수")
    record = store.create_text(
        title=body.title.strip(),
        content=body.content.strip(),
        note=body.note,
    )
    return record


# ── 파일 업로드 ──────────────────────────────────────────────────────────────

@router.post("/file", status_code=201)
async def create_file_record(
    file: UploadFile = File(...),
    note: str = Query(default=""),
):
    filename = file.filename or "unknown"
    ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""

    raw = await file.read()

    if ext == "txt":
        try:
            content = raw.decode("utf-8")
        except UnicodeDecodeError:
            content = raw.decode("cp949", errors="replace")

    elif ext == "pdf":
        try:
            import pypdf
            reader = pypdf.PdfReader(io.BytesIO(raw))
            content = "\n".join(
                page.extract_text() or "" for page in reader.pages
            ).strip()
        except Exception as e:
            raise HTTPException(422, f"PDF 파싱 실패: {e}")

    elif ext == "docx":
        try:
            import docx
            doc = docx.Document(io.BytesIO(raw))
            content = "\n".join(p.text for p in doc.paragraphs).strip()
        except Exception as e:
            raise HTTPException(422, f"DOCX 파싱 실패: {e}")

    else:
        raise HTTPException(415, f"지원하지 않는 형식: .{ext} (지원: txt, pdf, docx)")

    if not content:
        raise HTTPException(422, "파일에서 텍스트를 추출할 수 없습니다.")

    record = store.create_file(
        file_name=filename,
        content=content,
        note=note,
    )
    return record


# ── 목록 조회 ────────────────────────────────────────────────────────────────

@router.get("/")
def list_records(
    q: str = Query(default=""),
    source_type: str = Query(default=""),
    limit: int = Query(default=100, ge=1, le=500),
):
    records = store.list(query=q, source_type=source_type, limit=limit)
    return {"records": records, "total": len(records)}


# ── 단건 조회 ────────────────────────────────────────────────────────────────

@router.get("/{record_id}")
def get_record(record_id: str):
    record = store.get(record_id)
    if not record:
        raise HTTPException(404, f"레코드를 찾을 수 없습니다: {record_id}")
    return record


# ── 수정 ─────────────────────────────────────────────────────────────────────

@router.patch("/{record_id}")
def update_record(record_id: str, body: RecordUpdate):
    if not store.get(record_id):
        raise HTTPException(404, f"레코드를 찾을 수 없습니다: {record_id}")
    record = store.update(record_id, title=body.title, note=body.note)
    return record


# ── 삭제 (소프트) ─────────────────────────────────────────────────────────────

@router.delete("/{record_id}")
def delete_record(record_id: str):
    ok = store.delete(record_id)
    if not ok:
        raise HTTPException(404, f"레코드를 찾을 수 없습니다: {record_id}")
    return {"deleted": True, "id": record_id}


# ── 사용 이력 ────────────────────────────────────────────────────────────────

@router.get("/{record_id}/usage")
def get_record_usage(record_id: str):
    if not store.get(record_id):
        raise HTTPException(404, f"레코드를 찾을 수 없습니다: {record_id}")
    sessions = store.get_usage(record_id)
    return {"record_id": record_id, "sessions": sessions, "total": len(sessions)}
