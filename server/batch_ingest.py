"""
batch_ingest.py - 앱 JSON 내보내기 → Qdrant 벡터 수집 배치
임베딩: sentence-transformers (로컬, API 키 불필요)
모델: jhgan/ko-sroberta-multitask (768dim, 한국어 특화)
사용법: python batch_ingest.py <records.json 경로>
"""
import sys
import json
import time
import uuid
import httpx
from pathlib import Path

QDRANT_URL    = "http://localhost:6333"
COLLECTION    = "oral_records"
VECTOR_SIZE   = 768   # jhgan/ko-sroberta-multitask
CHUNK_SIZE    = 500
CHUNK_OVERLAP = 100

GREEN  = "\033[92m"
RED    = "\033[91m"
YELLOW = "\033[93m"
CYAN   = "\033[96m"
RESET  = "\033[0m"
BOLD   = "\033[1m"


def print_header():
    print(f"\n{BOLD}{CYAN}{'='*65}")
    print("  제주 4·3 구술 기록 RAG 수집 배치")
    print(f"{'='*65}{RESET}\n")


def check_qdrant() -> bool:
    try:
        r = httpx.get(f"{QDRANT_URL}/healthz", timeout=5)
        return r.status_code == 200
    except Exception:
        return False


def load_model():
    """임베딩 모델 로드 (최초 실행 시 자동 다운로드 ~420MB)"""
    from sentence_transformers import SentenceTransformer
    print(f"임베딩 모델 로드 중 (최초 실행 시 다운로드)...")
    model = SentenceTransformer("jhgan/ko-sroberta-multitask")
    print(f"{GREEN}✓ 모델 로드 완료{RESET}")
    return model


def chunk_text(text: str) -> list:
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


def embed_chunks(model, chunks: list) -> list:
    """로컬 모델로 임베딩 생성"""
    vectors = model.encode(chunks, normalize_embeddings=True)
    return vectors.tolist()


def ensure_collection():
    """컬렉션 확인 및 생성 (차원 불일치 시 재생성)"""
    r = httpx.get(f"{QDRANT_URL}/collections/{COLLECTION}", timeout=10)
    if r.status_code == 200:
        # 기존 컬렉션 차원 확인
        info = r.json()
        existing_size = (
            info.get("result", {})
                .get("config", {})
                .get("params", {})
                .get("vectors", {})
                .get("size")
        )
        if existing_size and existing_size != VECTOR_SIZE:
            print(f"{YELLOW}⚠ 기존 컬렉션 차원({existing_size}) 불일치 → 재생성{RESET}")
            httpx.delete(f"{QDRANT_URL}/collections/{COLLECTION}", timeout=10)
        else:
            print(f"{GREEN}✓ Qdrant 컬렉션 확인: {COLLECTION} ({VECTOR_SIZE}dim){RESET}")
            return

    httpx.put(
        f"{QDRANT_URL}/collections/{COLLECTION}",
        json={"vectors": {"size": VECTOR_SIZE, "distance": "Cosine"}},
        timeout=10,
    ).raise_for_status()
    print(f"{GREEN}✓ Qdrant 컬렉션 생성: {COLLECTION} ({VECTOR_SIZE}dim){RESET}")


def upsert_points(points: list):
    httpx.put(
        f"{QDRANT_URL}/collections/{COLLECTION}/points",
        json={"points": points},
        timeout=30,
    ).raise_for_status()


def process_record(record: dict, narrator_map: dict, model) -> dict:
    record_id     = record.get("id", "")
    display_id    = record.get("displayId", record_id)
    title         = record.get("title", "")
    content       = record.get("content", "").strip()
    summary       = record.get("summary", "").strip()
    narrator_id   = record.get("narratorId", "")
    category      = record.get("mainCategory", "")
    tags          = record.get("keywordTags", [])
    input_type    = record.get("inputType", "")
    narrator_name = narrator_map.get(narrator_id, {}).get("name", "")

    # content 우선, 없으면 summary 활용
    target_text = content or summary
    if not target_text:
        return {"chunks": 0, "status": "skip", "detail": "content 없음"}

    chunks = chunk_text(target_text)
    if not chunks:
        return {"chunks": 0, "status": "skip", "detail": "청크 생성 실패"}

    try:
        vectors = embed_chunks(model, chunks)
    except Exception as e:
        return {"chunks": 0, "status": "error", "detail": f"임베딩 실패: {e}"}

    points = [
        {
            "id": str(uuid.uuid5(uuid.NAMESPACE_DNS, f"{record_id}_{i}")),
            "vector": vector,
            "payload": {
                "record_id":     record_id,
                "display_id":    display_id,
                "title":         title,
                "narrator_id":   narrator_id,
                "narrator_name": narrator_name,
                "main_category": category,
                "keyword_tags":  tags,
                "input_type":    input_type,
                "chunk_index":   i,
                "chunk_total":   len(chunks),
                "text":          chunk,
                "has_summary":   bool(summary),
            },
        }
        for i, (chunk, vector) in enumerate(zip(chunks, vectors))
    ]

    try:
        upsert_points(points)
    except Exception as e:
        return {"chunks": 0, "status": "error", "detail": f"Qdrant 저장 실패: {e}"}

    return {"chunks": len(chunks), "status": "success", "detail": ""}


def main():
    print_header()

    if len(sys.argv) < 2:
        print(f"{YELLOW}사용법: python batch_ingest.py <records.json 경로>{RESET}")
        print(f"예시:   python batch_ingest.py \"C:/Users/samsung/Documents/OralRecordAgent/exports/records_20260405.json\"")
        return

    json_path = Path(sys.argv[1])
    if not json_path.exists():
        print(f"{RED}✗ 파일을 찾을 수 없습니다: {json_path}{RESET}")
        return

    # Qdrant 확인
    print("서버 상태 확인 중...")
    if not check_qdrant():
        print(f"{RED}✗ Qdrant 접근 불가 → docker start qdrant{RESET}")
        return
    print(f"{GREEN}✓ Qdrant 정상{RESET}")
    ensure_collection()

    # 임베딩 모델 로드
    model = load_model()

    # JSON 로드
    print(f"\nJSON 파일 로드: {json_path.name}")
    with open(json_path, encoding="utf-8") as f:
        data = json.load(f)

    records      = data.get("records", [])
    narrators    = data.get("narrators", [])
    narrator_map = {n["id"]: n for n in narrators}

    if not records:
        print(f"{YELLOW}⚠ 처리할 기록이 없습니다.{RESET}")
        return

    print(f"{BOLD}총 {len(records)}건 수집 시작 | 구술자: {len(narrators)}명{RESET}\n")
    print(f"{'번호':<5} {'식별자':<22} {'제목':<28} {'청크':<6} {'상태'}")
    print("-" * 75)

    success, fail, skip = [], [], []
    start_total = time.time()

    for i, record in enumerate(records, 1):
        display_id = record.get("displayId", record.get("id", "")[:8])
        title      = record.get("title", "")[:26]
        print(f"{i:>3}.  {display_id:<22} {title:<28} ", end="", flush=True)

        result = process_record(record, narrator_map, model)

        if result["status"] == "success":
            print(f"{result['chunks']:<6} {GREEN}✓ 성공{RESET}")
            success.append(display_id)
        elif result["status"] == "skip":
            print(f"{'-':<6} {YELLOW}⊘ 건너뜀{RESET} ({result['detail']})")
            skip.append(display_id)
        else:
            print(f"{'-':<6} {RED}✗ 실패{RESET} → {result['detail'][:30]}")
            fail.append((display_id, result["detail"]))

    total_time = time.time() - start_total
    print(f"\n{'='*75}")
    print(f"{BOLD}완료 ({total_time:.1f}초){RESET}")
    print(f"  {GREEN}✓ 성공: {len(success)}건{RESET}")
    print(f"  {YELLOW}⊘ 건너뜀: {len(skip)}건{RESET}")
    print(f"  {RED}✗ 실패: {len(fail)}건{RESET}")

    if fail:
        print(f"\n{RED}실패 목록:{RESET}")
        for name, reason in fail:
            print(f"  - {name}: {reason}")

    if success:
        print(f"\n{CYAN}확인: http://localhost:6333/dashboard → {COLLECTION}{RESET}\n")


if __name__ == "__main__":
    main()
