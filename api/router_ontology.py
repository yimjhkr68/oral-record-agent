"""api/router_ontology.py — 온톨로지 API 엔드포인트 (F1·F2·F3)"""

from __future__ import annotations

import dataclasses
import tempfile
import os
from typing import Optional
from fastapi import APIRouter, HTTPException, UploadFile, File
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from ontology.ontology_manager import (
    ClassMapping, OntologyClass, OntologyManager, OntologyPredicate,
    _safe_class, _safe_predicate,
)

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
    description:    str = ""


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
        return get_manager().merge_drafts(
            body.version_ids, body.new_version_id, body.description
        )
    except ValueError as e:
        raise HTTPException(status_code=409, detail=str(e))
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except RuntimeError as e:
        # AI API 호출 실패 (크레딧 부족, 네트워크 오류 등)
        raise HTTPException(status_code=502, detail=str(e))
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
        classes = (
            [c for c in (_safe_class(d) for d in body.classes) if c is not None]
            if body.classes is not None else None
        )
        predicates = (
            [p for p in (_safe_predicate(d) for d in body.predicates) if p is not None]
            if body.predicates is not None else None
        )
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


@router.get("/{version_id}/download")
def download_ontology(version_id: str):
    """온톨로지 JSON 파일 다운로드 (Draft 포함 전체)."""
    try:
        v = get_manager().get(version_id)
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))
    data = dataclasses.asdict(v)
    data["status"] = v.status.value  # Enum → str
    return JSONResponse(
        content=data,
        headers={
            "Content-Disposition": f'attachment; filename="{version_id}.json"',
        },
    )


@router.post("/{version_id}/archive")
def archive_version(version_id: str):
    """Confirmed → Archived 전환."""
    try:
        return get_manager().archive(version_id)
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.post("/extract-text")
async def extract_text_from_file(file: UploadFile = File(...)):
    """파일(txt/pdf/docx) → 텍스트 추출 (8000자 제한).
    반환: {"text": "추출된 텍스트", "filename": "파일명", "chars": N}
    """
    from utils.file_extractor import extract_text_from_file as _extract

    filename = file.filename or ""
    ext = os.path.splitext(filename)[1].lower()
    content_bytes = await file.read()

    suffix = ext or ".tmp"
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
        tmp.write(content_bytes)
        tmp_path = tmp.name

    try:
        try:
            text = _extract(tmp_path, filename)
        except ValueError as e:
            raise HTTPException(status_code=400, detail=str(e))
    finally:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)

    return {"text": text, "filename": filename, "chars": len(text)}


# ── 공표 클래스 매핑 CRUD ────────────────────────────────────────────────────────

class MappingItem(BaseModel):
    curie:       str
    ontology_id: str
    is_primary:  bool  = True
    confidence:  float = 1.0
    note:        str   = ""


class MappingsUpdateRequest(BaseModel):
    mappings: list[MappingItem]


@router.put("/{version_id}/classes/{class_name}/mappings")
def update_class_mappings(
    version_id: str, class_name: str, body: MappingsUpdateRequest
):
    """Draft 버전의 특정 클래스 매핑 전체 교체.

    body.mappings 목록으로 해당 클래스의 mappings를 완전히 대체한다.
    빈 목록을 보내면 매핑이 전부 삭제된다.
    """
    manager = get_manager()
    try:
        version = manager.get(version_id)
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))

    if version.status.value != "draft":
        raise HTTPException(
            status_code=403,
            detail=f"Draft 상태만 매핑 수정 가능합니다. 현재 상태: {version.status}",
        )

    # 클래스 탐색
    target = next((c for c in version.classes if c.name == class_name), None)
    if target is None:
        raise HTTPException(
            status_code=404,
            detail=f"클래스를 찾을 수 없습니다: {class_name!r}",
        )

    # 매핑 교체
    target.mappings = [
        ClassMapping(
            curie=m.curie,
            ontology_id=m.ontology_id,
            is_primary=m.is_primary,
            confidence=m.confidence,
            note=m.note,
        )
        for m in body.mappings
    ]

    # 버전 저장 (update()는 status 체크를 포함하므로 직접 save)
    manager._store.save_draft(version)

    import dataclasses
    return dataclasses.asdict(version)
