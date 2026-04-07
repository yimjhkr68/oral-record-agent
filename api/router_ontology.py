"""api/router_ontology.py — 온톨로지 API 엔드포인트 (F1·F2·F3)"""

from __future__ import annotations

import io
import tempfile
import os
from typing import Optional
from fastapi import APIRouter, HTTPException, UploadFile, File
from pydantic import BaseModel

from ontology.ontology_manager import OntologyClass, OntologyManager, OntologyPredicate

router = APIRouter(prefix="/api/ontologies", tags=["온톨로지"])

# 싱글톤 매니저 (앱 시작 시 한 번 초기화)
_manager: Optional[OntologyManager] = None


def get_manager() -> OntologyManager:
    global _manager
    if _manager is None:
        _manager = OntologyManager()
    return _manager


# ── 요청/응답 스키마 ────────────────────────────────────────────────────────────

class CreateRequest(BaseModel):
    version_id:  str
    description: str = ""


class UpdateRequest(BaseModel):
    classes:     Optional[list[dict]] = None
    predicates:  Optional[list[dict]] = None
    description: Optional[str]        = None


class GenerateRequest(BaseModel):
    sample_text:     str
    base_version_id: Optional[str] = None


class MergeRequest(BaseModel):
    version_ids:    list[str]
    new_version_id: str


# ── 엔드포인트 ─────────────────────────────────────────────────────────────────

@router.post("/", status_code=201)
def create_draft(body: CreateRequest):
    """Draft 온톨로지 버전 생성."""
    try:
        v = get_manager().create(body.version_id, body.description)
    except ValueError as e:
        raise HTTPException(status_code=409, detail=str(e))
    return v


@router.get("/")
def list_all():
    """전체 버전 목록 (최신순)."""
    return get_manager().list_all()


@router.post("/merge", status_code=201)
def merge_drafts(body: MergeRequest):
    """여러 Draft 버전 → AI 종합 병합 → 새 Draft 생성."""
    try:
        return get_manager().merge_drafts(body.version_ids, body.new_version_id)
    except ValueError as e:
        raise HTTPException(status_code=409, detail=str(e))
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/generate", status_code=201)
def generate_from_sample(body: GenerateRequest):
    """구술 샘플 텍스트 → AI 온톨로지 Draft 자동 생성."""
    try:
        return get_manager().generate_from_sample(
            body.sample_text, body.base_version_id
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{version_id}")
def get_version(version_id: str):
    """버전 단건 조회."""
    try:
        return get_manager().get(version_id)
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.patch("/{version_id}")
def update_draft(version_id: str, body: UpdateRequest):
    """Draft 버전 수정."""
    try:
        classes    = [OntologyClass(**c)    for c in body.classes]    if body.classes    else None
        predicates = [OntologyPredicate(**p) for p in body.predicates] if body.predicates else None
        return get_manager().update(version_id, classes=classes,
                                    predicates=predicates,
                                    description=body.description)
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))


@router.delete("/{version_id}", status_code=204)
def delete_draft(version_id: str):
    """Draft 버전 삭제."""
    try:
        get_manager().delete(version_id)
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))


@router.post("/{version_id}/confirm")
def confirm_version(version_id: str):
    """Draft → Confirmed 전환."""
    try:
        return get_manager().confirm(version_id)
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))


@router.post("/{version_id}/archive")
def archive_version(version_id: str):
    """Confirmed → Archived 전환."""
    try:
        return get_manager().archive(version_id)
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.post("/extract-text")
async def extract_text_from_file(file: UploadFile = File(...)):
    """파일(txt/pdf/docx) → 텍스트 추출.
    반환: {"text": "추출된 텍스트", "filename": "파일명", "chars": N}
    """
    filename = file.filename or ""
    ext = os.path.splitext(filename)[1].lower()

    content_bytes = await file.read()

    if ext == ".txt":
        try:
            text = content_bytes.decode("utf-8")
        except UnicodeDecodeError:
            text = content_bytes.decode("cp949", errors="replace")

    elif ext == ".pdf":
        try:
            from pypdf import PdfReader
            reader = PdfReader(io.BytesIO(content_bytes))
            text = "\n".join(
                page.extract_text() or "" for page in reader.pages
            )
        except Exception as e:
            raise HTTPException(status_code=400, detail=f"PDF 파싱 실패: {e}")

    elif ext == ".docx":
        try:
            from docx import Document
            with tempfile.NamedTemporaryFile(suffix=".docx", delete=False) as tmp:
                tmp.write(content_bytes)
                tmp_path = tmp.name
            try:
                doc = Document(tmp_path)
                text = "\n".join(
                    p.text for p in doc.paragraphs if p.text.strip()
                )
            finally:
                os.unlink(tmp_path)
        except Exception as e:
            raise HTTPException(status_code=400, detail=f"DOCX 파싱 실패: {e}")

    else:
        raise HTTPException(
            status_code=415,
            detail=f"지원하지 않는 파일 형식: {ext!r}. txt / pdf / docx만 지원합니다.",
        )

    text = text.strip()
    if not text:
        raise HTTPException(status_code=400, detail="파일에서 텍스트를 추출할 수 없습니다.")

    return {"text": text, "filename": filename, "chars": len(text)}
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
