"""
ingest.py - 수집 파이프라인
- POST /ingest/file  : 파일 업로드 → 텍스트 추출 → 임베딩 → Qdrant
- POST /ingest/record: 앱 Record JSON → 임베딩 → Qdrant (자동화용)
"""
import os
import uuid
import hashlib
from pathlib import Path
from typing import Optional
from functools import lru_cache

from fastapi import APIRouter, UploadFile, File, HTTPException
from pydantic import BaseModel
from qdrant_client.models import PointStruct

from qdrant_client_helper import get_client, ensure_collection, COLLECTION

router = APIRouter()

CHUNK_SIZE    = 500
CHUNK_OVERLAP = 100


# ── 임베딩 모델 (싱글턴) ───────────────────────────────────────

@lru_cache(maxsize=1)
def get_model():
    from sentence_transformers import SentenceTransformer
    print("[Ingest] 임베딩 모델 로드 중...")
    model = SentenceTransformer("jhgan/ko-sroberta-multitask")
    print("[Ingest] 임베딩 모델 로드 완료")
    return model


def embed_texts(texts: list[str]) -> list[list[float]]:
    model = get_model()
    vectors = model.encode(texts, normalize_embeddings=True)
    return vectors.tolist()


# ── 텍스트 추출 ────────────────────────────────────────────────

def extract_text_from_docx(path: str) -> str:
    from docx import Document
    doc = Document(path)
    return "\n".join(p.text for p in doc.paragraphs if p.text.strip())


def extract_text_from_pdf(path: str) -> str:
    from pypdf import PdfReader
    reader = PdfReader(path)
    return "\n".join(page.extract_text() or "" for page in reader.pages)


def extract_text(path: str) -> str:
    ext = Path(path).suffix.lower()
    if ext == ".docx":
        return extract_text_from_docx(path)
    elif ext == ".pdf":
        return extract_text_from_pdf(path)
    raise ValueError(f"지원하지 않는 파일 형식: {ext}")


# ── 청킹 ───────────────────────────────────────────────────────

def chunk_text(text: str) -> list[str]:
    if not text or not text.strip():
        return []
    chunks = []
    start = 0
    while start < len(text):
        chunk = text[start:start + CHUNK_SIZE].strip()
        if chunk:
            chunks.append(chunk)
        start += CHUNK_SIZE - CHUNK_OVERLAP
    return chunks


# ── Qdrant 저장 ────────────────────────────────────────────────

def save_to_qdrant(
    record_id: str,
    display_id: str,
    title: str,
    narrator_id: str,
    narrator_name: str,
    main_category: str,
    keyword_tags: list[str],
    input_type: str,
    has_summary: bool,
    chunks: list[str],
    vectors: list[list[float]],
):
    points = [
        PointStruct(
            id=str(uuid.uuid5(uuid.NAMESPACE_DNS, f"{record_id}_{i}")),
            vector=vectors[i],
            payload={
                "record_id":     record_id,
                "display_id":    display_id,
                "title":         title,
                "narrator_id":   narrator_id,
                "narrator_name": narrator_name,
                "main_category": main_category,
                "keyword_tags":  keyword_tags,
                "input_type":    input_type,
                "chunk_index":   i,
                "chunk_total":   len(chunks),
                "text":          chunks[i],
                "has_summary":   has_summary,
            },
        )
        for i in range(len(chunks))
    ]
    get_client().upsert(collection_name=COLLECTION, points=points)


# ── 엔드포인트 1: 파일 업로드 ──────────────────────────────────

class IngestResult(BaseModel):
    filename:  str
    chunks:    int
    status:    str
    record_id: Optional[str] = None


@router.post("/file", response_model=IngestResult)
async def ingest_file(file: UploadFile = File(...)):
    """파일 업로드 → 텍스트 추출 → 임베딩 → Qdrant"""
    ensure_collection()

    tmp_path = f"/tmp/{file.filename}"
    content_bytes = await file.read()
    with open(tmp_path, "wb") as f:
        f.write(content_bytes)

    try:
        text = extract_text(tmp_path)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"텍스트 추출 실패: {e}")

    if not text.strip():
        raise HTTPException(status_code=400, detail="추출된 텍스트가 없습니다.")

    chunks = chunk_text(text)
    vectors = embed_texts(chunks)

    file_id = hashlib.md5(file.filename.encode()).hexdigest()
    save_to_qdrant(
        record_id=file_id,
        display_id=file.filename,
        title=file.filename,
        narrator_id="",
        narrator_name="",
        main_category="",
        keyword_tags=[],
        input_type="document",
        has_summary=False,
        chunks=chunks,
        vectors=vectors,
    )

    return IngestResult(
        filename=file.filename,
        chunks=len(chunks),
        status="success",
        record_id=file_id,
    )


# ── 엔드포인트 2: 앱 Record 단건 수집 (자동화용) ──────────────

class RecordIngestRequest(BaseModel):
    """Flutter Record 모델과 동일한 구조"""
    id:           str
    title:        str
    content:      str
    summary:      Optional[str] = None
    inputType:    str = "text"
    narratorId:   str = ""
    narratorName: str = ""          # 앱에서 resolve해서 전달
    mainCategory: str = "기타"
    keywordTags:  list[str] = []
    displayId:    Optional[str] = None


class RecordIngestResult(BaseModel):
    record_id:  str
    display_id: str
    chunks:     int
    status:     str


@router.post("/record", response_model=RecordIngestResult)
async def ingest_record(req: RecordIngestRequest):
    """앱이 기록 저장 후 자동 호출 → 임베딩 → Qdrant upsert"""
    ensure_collection()

    # content 우선, 없으면 summary 활용
    target_text = req.content.strip() or (req.summary or "").strip()
    if not target_text:
        return RecordIngestResult(
            record_id=req.id,
            display_id=req.displayId or req.id,
            chunks=0,
            status="skip",
        )

    chunks = chunk_text(target_text)
    if not chunks:
        return RecordIngestResult(
            record_id=req.id,
            display_id=req.displayId or req.id,
            chunks=0,
            status="skip",
        )

    vectors = embed_texts(chunks)
    display_id = req.displayId or req.id

    save_to_qdrant(
        record_id=req.id,
        display_id=display_id,
        title=req.title,
        narrator_id=req.narratorId,
        narrator_name=req.narratorName,
        main_category=req.mainCategory,
        keyword_tags=req.keywordTags,
        input_type=req.inputType,
        has_summary=bool(req.summary),
        chunks=chunks,
        vectors=vectors,
    )

    return RecordIngestResult(
        record_id=req.id,
        display_id=display_id,
        chunks=len(chunks),
        status="success",
    )


# ── 엔드포인트 3: 기록 삭제 시 Qdrant에서도 제거 ──────────────

@router.delete("/record/{record_id}")
async def delete_record(record_id: str):
    """앱에서 기록 삭제 시 Qdrant 포인트도 함께 삭제"""
    from qdrant_client.models import Filter, FieldCondition, MatchValue
    get_client().delete(
        collection_name=COLLECTION,
        points_selector=Filter(
            must=[
                FieldCondition(
                    key="record_id",
                    match=MatchValue(value=record_id),
                )
            ]
        ),
    )
    return {"status": "deleted", "record_id": record_id}
