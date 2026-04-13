"""
query.py - RAG 질의 엔진
임베딩: sentence-transformers (로컬, API 키 불필요)
생성:   Claude API (ANTHROPIC_API_KEY)
"""
import os
from functools import lru_cache
from pathlib import Path
from dotenv import load_dotenv

import anthropic
import httpx
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

# .env 절대경로 로드 (server/ 위 v3.0 루트)
_env_path = Path(__file__).resolve().parent.parent / ".env"
load_dotenv(_env_path)
print(f"[query] .env 경로: {_env_path} | 존재: {_env_path.exists()}")

QDRANT_URL        = os.getenv("QDRANT_URL", "http://localhost:6333")
ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY", "")
COLLECTION        = "oral_records"
print(f"[query] API KEY 로드: {'✓' if ANTHROPIC_API_KEY else '✗ 없음'}")
VECTOR_SIZE       = 768
TOP_K             = 5

router = APIRouter()


# ── 임베딩 모델 (싱글턴) ───────────────────────────────────────

@lru_cache(maxsize=1)
def get_model():
    """서버 시작 후 첫 요청 시 1회만 로드"""
    from sentence_transformers import SentenceTransformer
    print("[RAG] 임베딩 모델 로드 중...")
    model = SentenceTransformer("jhgan/ko-sroberta-multitask")
    print("[RAG] 임베딩 모델 로드 완료")
    return model


def embed_query(query: str) -> list[float]:
    model = get_model()
    vector = model.encode([query], normalize_embeddings=True)
    return vector[0].tolist()


# ── Qdrant 검색 ────────────────────────────────────────────────

def search_qdrant(query_vector: list[float], top_k: int = TOP_K) -> list[dict]:
    response = httpx.post(
        f"{QDRANT_URL}/collections/{COLLECTION}/points/search",
        json={
            "vector": query_vector,
            "limit": top_k,
            "with_payload": True,
        },
        timeout=10,
    )
    response.raise_for_status()
    results = response.json().get("result", [])
    return [
        {
            "text":          r["payload"].get("text", ""),
            "display_id":    r["payload"].get("display_id", ""),
            "record_id":     r["payload"].get("record_id", ""),
            "title":         r["payload"].get("title", ""),
            "narrator_name": r["payload"].get("narrator_name", ""),
            "main_category": r["payload"].get("main_category", ""),
            "keyword_tags":  r["payload"].get("keyword_tags", []),
            "score":         round(r["score"], 4),
        }
        for r in results
    ]


# ── Claude 답변 생성 ───────────────────────────────────────────

SYSTEM_PROMPT = """당신은 제주 4.3 구술 기록 아카이브의 전문 사서입니다.
사용자의 질문에 대해 제공된 구술 기록을 바탕으로 답변하세요.

답변 형식:
- 첫 문장: 질문 주제에 대한 전체 요약 (1문장)
- 이후 2~3문장: 주요 구술자들의 증언을 종합한 내용
- 총 3~4문장으로 간결하게 작성
- 마크다운(##, **, ---)사용 금지
- 구술자 이름과 기록ID는 출처 목록에 있으므로 본문에 포함하지 않음
- 자료에 없는 내용은 추측하지 않음
- 답변은 최대 5문장을 넘지 않도록 하되, 반드시 완성된 문장으로 끝내세요."""


def generate_answer(query: str, contexts: list[dict]) -> str:
    if not contexts:
        return "관련 구술 기록을 찾을 수 없습니다."

    context_text = "\n\n".join(
        f"[{c['display_id']} | {c['title']} | 구술자: {c['narrator_name']} | 관련도: {c['score']}]\n{c['text']}"
        for c in contexts
    )

    client = anthropic.Anthropic(api_key=ANTHROPIC_API_KEY)
    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=2048,
        system=SYSTEM_PROMPT,
        messages=[
            {
                "role": "user",
                "content": (
                    f"다음 구술 기록 자료를 참고하여 질문에 답변해주세요.\n\n"
                    f"=== 참고 자료 ===\n{context_text}\n\n"
                    f"=== 질문 ===\n{query}"
                ),
            }
        ],
    )
    return response.content[0].text


# ── 엔드포인트 ─────────────────────────────────────────────────

class QueryRequest(BaseModel):
    query: str
    top_k: int = TOP_K


class Source(BaseModel):
    display_id:    str
    record_id:     str
    title:         str
    narrator_name: str
    main_category: str
    keyword_tags:  list[str]
    score:         float
    text:          str


class QueryResponse(BaseModel):
    answer:  str
    sources: list[Source]
    query:   str


@router.post("/", response_model=QueryResponse)
async def query_records(req: QueryRequest):
    """질문 → 벡터 검색 → Claude 답변 생성"""
    if not req.query.strip():
        raise HTTPException(status_code=400, detail="질문을 입력하세요.")

    # 1. 질의 임베딩
    try:
        query_vector = embed_query(req.query)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"임베딩 실패: {e}")

    # 2. Qdrant 검색
    try:
        contexts = search_qdrant(query_vector, top_k=req.top_k)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"검색 실패: {e}")

    # 3. Claude 답변 생성
    try:
        answer = generate_answer(req.query, contexts)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"답변 생성 실패: {e}")

    return QueryResponse(
        answer=answer,
        sources=[Source(**c) for c in contexts],
        query=req.query,
    )
