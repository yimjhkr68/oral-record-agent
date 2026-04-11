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


class RenameRequest(BaseModel):
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
def list_all(
    status: Optional[str] = None,
    has_standard_tag: Optional[bool] = None,
):
    """전체 버전 목록 (최신순). status / has_standard_tag 필터 지원."""
    return get_manager().list_all(status=status, has_standard_tag=has_standard_tag)


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
    except ValueError as e:
        # AI 응답 파싱 실패
        raise HTTPException(status_code=422, detail=str(e))
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
    except ValueError as e:
        # AI 응답 파싱 실패 — 재시도 가능한 클라이언트 오류
        raise HTTPException(status_code=422, detail=str(e))
    except RuntimeError as e:
        # AI API 호출 실패 (크레딧, 네트워크 등)
        raise HTTPException(status_code=502, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ── 일괄 내보내기 ──────────────────────────────────────────────────────────────

class ExportRequest(BaseModel):
    version_ids: list[str]


@router.post("/export")
def export_ontologies(body: ExportRequest):
    """선택한 버전들을 JSON 파일로 내보내기. 최대 100건 제한."""
    import json
    from datetime import datetime
    from fastapi.responses import Response

    if not body.version_ids:
        raise HTTPException(status_code=400, detail="version_ids 필요")
    if len(body.version_ids) > 100:
        raise HTTPException(status_code=400, detail="최대 100건까지 선택 가능합니다")

    manager = get_manager()
    items = []
    for vid in body.version_ids:
        try:
            v = manager.get(vid)
        except KeyError:
            continue  # 없는 버전은 건너뜀
        items.append({
            "version_id":   v.version_id,
            "status":       v.status.value,
            "description":  v.description,
            "created_at":   v.created_at,
            "confirmed_at": v.confirmed_at,
            "classes": [
                {
                    "name":         c.name,
                    "label_ko":     c.label_ko,
                    "color":        c.color,
                    "description":  c.description,
                    "examples":     c.examples,
                    "standard_tag": c.standard_tag,
                }
                for c in v.classes
            ],
            "predicates": [
                {
                    "name":         p.name,
                    "domain":       p.domain,
                    "range_":       p.range_,
                    "description":  p.description,
                    "standard_tag": p.standard_tag,
                }
                for p in v.predicates
            ],
        })

    export_data = {
        "export_type": "ontologies",
        "exported_at": datetime.now().isoformat(),
        "total":       len(items),
        "items":       items,
    }
    filename = f"ontologies_export_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    return Response(
        content=json.dumps(export_data, ensure_ascii=False, indent=2),
        media_type="application/json",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.get("/{version_id}/mappings")
def get_mappings(version_id: str):
    """클래스·속성별 표준 매핑 추천 + 현재 저장값 + 확정 여부 반환."""
    from ontology.standard_mappings import get_class_suggestions, get_predicate_suggestions

    try:
        v = get_manager().get(version_id)
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))

    classes = [
        {
            "name":         c.name,
            "label_ko":     c.label_ko,
            "color":        c.color,
            "current_tag":  c.standard_tag,
            "suggestions":  get_class_suggestions(c.name),
            "is_confirmed": c.mapping_confirmed,
        }
        for c in v.classes
    ]
    predicates = [
        {
            "name":         p.name,
            "label_ko":     p.name,  # predicate에는 label_ko 없음 — name으로 대체
            "current_tag":  p.standard_tag,
            "suggestions":  get_predicate_suggestions(p.name),
            "is_confirmed": p.mapping_confirmed,
        }
        for p in v.predicates
    ]
    return {"classes": classes, "predicates": predicates}


class MappingPatchItem(BaseModel):
    name:      str
    tag:       str
    confirmed: bool = False


class MappingPatchRequest(BaseModel):
    classes:    list[MappingPatchItem] = []
    predicates: list[MappingPatchItem] = []


@router.patch("/{version_id}/mappings")
def patch_mappings(version_id: str, body: MappingPatchRequest):
    """클래스·속성의 standard_tag 및 mapping_confirmed 일괄 업데이트."""
    manager = get_manager()
    try:
        v = manager.get(version_id)
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))

    # 클래스 업데이트
    class_index = {c.name: c for c in v.classes}
    for item in body.classes:
        if item.name in class_index:
            class_index[item.name].standard_tag      = item.tag
            class_index[item.name].mapping_confirmed = item.confirmed

    # 속성 업데이트
    pred_index = {p.name: p for p in v.predicates}
    for item in body.predicates:
        if item.name in pred_index:
            pred_index[item.name].standard_tag      = item.tag
            pred_index[item.name].mapping_confirmed = item.confirmed

    # 저장 (status 체크 없이 직접 save — confirmed/archived도 매핑 확정 가능)
    manager._store.save_draft(v)

    updated_classes    = sum(1 for item in body.classes    if item.name in class_index)
    updated_predicates = sum(1 for item in body.predicates if item.name in pred_index)
    return {
        "version_id":         version_id,
        "updated_classes":    updated_classes,
        "updated_predicates": updated_predicates,
    }


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
def delete_draft(version_id: str, force: bool = False):
    """온톨로지 버전 삭제. force=true 이면 Confirmed/Archived도 삭제."""
    try:
        get_manager().delete(version_id, force=force)
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))


@router.patch("/{version_id}/rename")
def rename_version(version_id: str, body: RenameRequest):
    """버전 ID(이름) 변경. 참조 트리플의 ontology_version 필드도 함께 업데이트."""
    try:
        result = get_manager().rename(version_id, body.new_version_id)
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except ValueError as e:
        raise HTTPException(status_code=409, detail=str(e))

    # 이 버전을 참조하는 트리플의 ontology_version 업데이트
    try:
        from api.router_triple import get_triple_manager
        tm = get_triple_manager()
        for t in tm.db.all_triples(include_archived=True):
            if t.ontology_version == version_id:
                tm.db.update(t.id, ontology_version=body.new_version_id)
    except Exception:
        pass  # 트리플 미존재 시 무시

    return result


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
