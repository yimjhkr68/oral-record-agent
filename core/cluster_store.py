"""사용자 정의 군집(custom cluster) 파일 기반 저장소"""
import json
import uuid
from datetime import datetime, timezone
from pathlib import Path
from threading import Lock

CLUSTER_FILE = Path("data/graph_custom_clusters.json")

_lock = Lock()


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")


class ClusterStore:

    def _load(self) -> dict:
        if not CLUSTER_FILE.exists():
            return {"clusters": [], "node_overrides": {}}
        with open(CLUSTER_FILE, encoding="utf-8") as f:
            return json.load(f)

    def _save(self, data: dict):
        CLUSTER_FILE.parent.mkdir(parents=True, exist_ok=True)
        with open(CLUSTER_FILE, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)

    # ── 조회 ─────────────────────────────────────────────────────────────────

    def list_clusters(self) -> list[dict]:
        with _lock:
            return self._load()["clusters"]

    def get_node_overrides(self) -> dict:
        with _lock:
            return self._load()["node_overrides"]

    def get_full(self) -> dict:
        """clusters + node_overrides 전체 반환"""
        with _lock:
            return self._load()

    # ── 생성 / 수정 / 삭제 ───────────────────────────────────────────────────

    def create(self, name: str, color: str = "#888888") -> dict:
        with _lock:
            data = self._load()
            cluster = {
                "id": f"custom-{uuid.uuid4().hex[:8]}",
                "name": name,
                "color": color,
                "created_at": _now(),
                "node_ids": [],
            }
            data["clusters"].append(cluster)
            self._save(data)
            return cluster

    def update(self, cluster_id: str, name: str | None = None,
               color: str | None = None) -> dict | None:
        with _lock:
            data = self._load()
            for c in data["clusters"]:
                if c["id"] == cluster_id:
                    if name is not None:
                        c["name"] = name
                    if color is not None:
                        c["color"] = color
                    self._save(data)
                    return c
            return None

    def delete(self, cluster_id: str) -> bool:
        with _lock:
            data = self._load()
            before = len(data["clusters"])
            data["clusters"] = [
                c for c in data["clusters"] if c["id"] != cluster_id
            ]
            # node_overrides 에서도 제거
            data["node_overrides"] = {
                nid: cid
                for nid, cid in data["node_overrides"].items()
                if cid != cluster_id
            }
            if len(data["clusters"]) < before:
                self._save(data)
                return True
            return False

    # ── 노드 추가 / 제거 ─────────────────────────────────────────────────────

    def add_nodes(self, cluster_id: str, node_ids: list[str]) -> dict | None:
        with _lock:
            data = self._load()
            target = None
            for c in data["clusters"]:
                if c["id"] == cluster_id:
                    target = c
                    break
            if target is None:
                return None

            # 노드를 다른 custom cluster에서 제거 → 이 cluster로 이동
            for nid in node_ids:
                data["node_overrides"][nid] = cluster_id
                if nid not in target["node_ids"]:
                    target["node_ids"].append(nid)
                # 다른 cluster의 node_ids에서 제거
                for c in data["clusters"]:
                    if c["id"] != cluster_id and nid in c["node_ids"]:
                        c["node_ids"].remove(nid)

            self._save(data)
            return target

    def remove_nodes(self, cluster_id: str, node_ids: list[str]) -> dict | None:
        with _lock:
            data = self._load()
            target = None
            for c in data["clusters"]:
                if c["id"] == cluster_id:
                    target = c
                    break
            if target is None:
                return None

            for nid in node_ids:
                if nid in target["node_ids"]:
                    target["node_ids"].remove(nid)
                # override 도 제거
                data["node_overrides"].pop(nid, None)

            self._save(data)
            return target
