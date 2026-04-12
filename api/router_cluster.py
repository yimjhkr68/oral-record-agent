"""사용자 정의 군집(custom cluster) API"""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from core.cluster_store import ClusterStore

router = APIRouter(prefix="/api/graph", tags=["custom-cluster"])
store = ClusterStore()


# ── 스키마 ────────────────────────────────────────────────────────────────────

class ClusterCreate(BaseModel):
    name: str
    color: str = "#888888"


class ClusterUpdate(BaseModel):
    name: str | None = None
    color: str | None = None


class NodeListBody(BaseModel):
    node_ids: list[str]


# ── 엔드포인트 ────────────────────────────────────────────────────────────────

@router.get("/custom-clusters")
def list_clusters():
    """사용자 정의 군집 목록 + node_overrides 반환"""
    return store.get_full()


@router.post("/custom-clusters", status_code=201)
def create_cluster(body: ClusterCreate):
    """새 사용자 정의 군집 생성"""
    return store.create(name=body.name, color=body.color)


@router.patch("/custom-clusters/{cluster_id}")
def update_cluster(cluster_id: str, body: ClusterUpdate):
    """군집 이름/색상 수정"""
    result = store.update(cluster_id, name=body.name, color=body.color)
    if result is None:
        raise HTTPException(404, f"cluster {cluster_id} not found")
    return result


@router.delete("/custom-clusters/{cluster_id}", status_code=204)
def delete_cluster(cluster_id: str):
    """군집 삭제"""
    if not store.delete(cluster_id):
        raise HTTPException(404, f"cluster {cluster_id} not found")


@router.post("/custom-clusters/{cluster_id}/nodes", status_code=200)
def add_nodes(cluster_id: str, body: NodeListBody):
    """군집에 노드 추가 (다른 군집에서 이동 포함)"""
    result = store.add_nodes(cluster_id, body.node_ids)
    if result is None:
        raise HTTPException(404, f"cluster {cluster_id} not found")
    return result


@router.delete("/custom-clusters/{cluster_id}/nodes")
def remove_nodes(cluster_id: str, body: NodeListBody):
    """군집에서 노드 제거"""
    result = store.remove_nodes(cluster_id, body.node_ids)
    if result is None:
        raise HTTPException(404, f"cluster {cluster_id} not found")
    return result
