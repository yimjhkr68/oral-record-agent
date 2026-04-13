"""api/router_ontology.py — 온톨로지 API 엔드포인트 (F1·F2·F3)"""

from __future__ import annotations

import dataclasses
import tempfile
import os
from typing import Optional
from fastapi import APIRouter, HTTPException, UploadFile, File
from pathlib import Path
from fastapi.responses import FileResponse, JSONResponse
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
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except ValueError as e:
        # 버전 ID 중복 → 409, AI 응답 파싱 실패 → 422
        msg = str(e)
        if "already exists" in msg or "이미 존재" in msg:
            raise HTTPException(status_code=409, detail=msg)
        raise HTTPException(status_code=422, detail=msg)
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


@router.post("/import", status_code=201)
async def import_ontology(
    file:        UploadFile = File(...),
    version_id:  str = "",
    import_mode: str = "new",      # "new" 만 지원 (향후 merge 확장 가능)
    csv_type:    str = "classes",  # "classes" | "predicates" (CSV 전용)
):
    """JSON / CSV 파일 → 새 Draft 생성.

    - JSON: 내보내기 포맷(export_type=ontologies) 또는 단일 버전 JSON
    - CSV 클래스: name, label_ko, color, description, examples 헤더
    - CSV 속성:   name, domain, range_, description 헤더
    """
    import json as _json
    from ontology.ontology_importer import OntologyImporter

    filename = (file.filename or "").lower()
    content_bytes = await file.read()

    try:
        content_text = content_bytes.decode("utf-8-sig")  # BOM 자동 제거
    except UnicodeDecodeError:
        content_text = content_bytes.decode("euc-kr", errors="replace")

    importer = OntologyImporter()
    manager  = get_manager()

    try:
        if filename.endswith(".json"):
            try:
                data = _json.loads(content_text)
            except _json.JSONDecodeError as e:
                raise HTTPException(status_code=400,
                                    detail=f"JSON 파싱 오류: {e}")
            version = importer.from_json(data, version_id=version_id)

        elif filename.endswith(".csv"):
            if csv_type not in ("classes", "predicates"):
                raise HTTPException(
                    status_code=400,
                    detail="csv_type 은 'classes' 또는 'predicates' 이어야 합니다.",
                )
            version = importer.from_csv(content_text,
                                        csv_type=csv_type,
                                        version_id=version_id)
        else:
            raise HTTPException(status_code=400,
                                detail="지원 형식: .json, .csv")

        # version_id 중복 시 suffix 추가
        if version.version_id in [v.version_id for v in manager.list_all()]:
            version.version_id = OntologyImporter._generate_id(
                version.version_id
            )

        # 빈 임포트 거부
        if not version.classes and not version.predicates:
            raise HTTPException(
                status_code=422,
                detail="임포트할 클래스/속성이 없습니다. 파일 형식을 확인하세요.",
            )

        # 매니저에 등록 (캐시 + 파일 저장)
        manager._cache[version.version_id] = version
        manager._store.save_draft(version)

    except HTTPException:
        raise
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"임포트 실패: {e}")

    return {
        "version_id":      version.version_id,
        "classes_count":   len(version.classes),
        "predicates_count": len(version.predicates),
        "description":     version.description,
    }


@router.get("/{version_id}/mappings")
def get_mappings(version_id: str):
    """클래스·속성별 표준 매핑 추천 + 현재 저장값 + 확정 여부 반환."""
    from ontology.standard_mappings import (
        get_class_suggestions_full, get_predicate_suggestions_full,
    )

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
            "suggestions":  get_class_suggestions_full(c.name, max_total=3),
            "is_confirmed": c.mapping_confirmed,
        }
        for c in v.classes
    ]
    predicates = [
        {
            "name":         p.name,
            "label_ko":     p.name,  # predicate에는 label_ko 없음 — name으로 대체
            "current_tag":  p.standard_tag,
            "suggestions":  get_predicate_suggestions_full(p.name),
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


_TEMPLATES_DIR = Path(__file__).parent.parent / "templates"

# (filename, download_name, media_type)
_TEMPLATES: dict[str, tuple[str, str, str]] = {
    "json":           ("ontology_template.json",           "ontology_template.json",           "application/json"),
    "csv_classes":    ("ontology_classes_template.csv",    "ontology_classes_template.csv",    "text/csv; charset=utf-8-sig"),
    "csv_predicates": ("ontology_predicates_template.csv", "ontology_predicates_template.csv", "text/csv; charset=utf-8-sig"),
}


@router.get("/templates/{template_name}")
def download_template(template_name: str):
    """온톨로지 임포트 템플릿 파일 다운로드.
    template_name: "json" | "csv_classes" | "csv_predicates"
    """
    if template_name not in _TEMPLATES:
        raise HTTPException(
            status_code=404,
            detail=f"템플릿 없음: {template_name}. 사용 가능: {list(_TEMPLATES.keys())}",
        )

    filename, download_name, media_type = _TEMPLATES[template_name]
    path = _TEMPLATES_DIR / filename
    if not path.exists():
        raise HTTPException(status_code=404, detail=f"템플릿 파일 없음: {path}")

    return FileResponse(
        path=str(path),
        filename=download_name,
        media_type=media_type,
    )


@router.post("/extract-text")
async def extract_text_from_file(
    file: UploadFile = File(...),
    source: str = "ontology",   # "ontology" | "triple" | "manual"
    auto_register: bool = True,  # 기록 탭 자동 등록 여부
):
    """파일(txt/pdf/docx) → 텍스트 추출 (8000자 제한).
    반환: {"text": "추출된 텍스트", "filename": "파일명", "chars": N, "record_id": "..."}
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

    # 기록 탭 자동 등록
    record_id = None
    if auto_register and text and filename:
        try:
            from core.record_store import RecordStore as _RS
            _rs = _RS()
            rec = _rs.create_file(
                file_name=filename,
                content=text,
                note=f"온톨로지 생성용 파일" if source == "ontology" else "트리플 추출용 파일",
                source=source if source in ("ontology", "triple", "manual") else "ontology",
                raw_bytes=content_bytes,
            )
            record_id = rec["id"]
        except Exception:
            pass  # 기록 등록 실패해도 텍스트 추출은 정상 반환

    return {"text": text, "filename": filename, "chars": len(text),
            "record_id": record_id}


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
