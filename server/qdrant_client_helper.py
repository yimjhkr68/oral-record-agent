import os
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams

QDRANT_URL  = os.getenv("QDRANT_URL", "http://localhost:6333")
COLLECTION  = "oral_records"
VECTOR_SIZE = 1024  # Anthropic text-embedding-3 기본 차원

_client: QdrantClient | None = None


def get_client() -> QdrantClient:
    global _client
    if _client is None:
        _client = QdrantClient(url=QDRANT_URL)
    return _client


def ensure_collection():
    """컬렉션이 없으면 생성"""
    client = get_client()
    existing = [c.name for c in client.get_collections().collections]
    if COLLECTION not in existing:
        client.create_collection(
            collection_name=COLLECTION,
            vectors_config=VectorParams(
                size=VECTOR_SIZE,
                distance=Distance.COSINE,
            ),
        )
        print(f"[Qdrant] 컬렉션 생성: {COLLECTION}")
    else:
        print(f"[Qdrant] 컬렉션 확인: {COLLECTION}")
