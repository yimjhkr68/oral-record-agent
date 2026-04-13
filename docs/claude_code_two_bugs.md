# 두 가지 500 오류 디버깅 Plan

## 대상 버그

```
Bug A: .docx 파일 업로드 → 트리플 생성 → 500 오류
       파일명: NAR-202603-0006_현봉학_구술기록.docx

Bug B: Draft 종합 → 500 오류 (지속 반복)
```

---

## 사전 작업 — 서버 로그 확인 (필수)

두 버그 수정 전에 반드시 서버 터미널 로그를 확인해야 함.

```
FastAPI 서버가 실행 중인 터미널에서:

1. Bug A 재현:
   - 앱에서 .docx 파일 선택 → [트리플 생성] 클릭
   - 500 오류 발생 직후
   - 터미널의 ERROR + Traceback 전체 복사

2. Bug B 재현:
   - Draft 2개 선택 → [선택 Draft 종합] 클릭
   - 500 오류 발생 직후
   - 터미널의 ERROR + Traceback 전체 복사

두 Traceback 모두 나에게 보고 후 진행.
```

---

## Bug A — .docx 트리플 생성 500 오류

### 원인 판별

```
Case A-1: .docx 텍스트 추출 실패
  로그 패턴: ImportError: No module named 'docx'
             또는 PackageNotFoundError: python-docx
  원인: python-docx 패키지 미설치

Case A-2: 인코딩/파싱 오류
  로그 패턴: UnicodeDecodeError
             또는 zipfile.BadZipFile
  원인: docx 파일이 손상되었거나 실제 docx 형식 아님

Case A-3: 파일 경로 또는 임시 파일 오류
  로그 패턴: FileNotFoundError
             또는 PermissionError
  원인: 업로드된 파일이 서버에 제대로 저장되지 않음

Case A-4: 텍스트 추출 후 AI 호출 오류
  로그 패턴: anthropic.APIError
             또는 json.JSONDecodeError
  원인: 추출된 텍스트가 너무 길거나 AI 응답 파싱 실패

Case A-5: 한글 파일명 처리 오류
  로그 패턴: UnicodeEncodeError
             또는 ContentDisposition 관련 오류
  원인: '현봉학' 등 한글 파일명이 multipart 처리 시 깨짐
```

### 수정 — Case A-1 (가장 가능성 높음)

```bash
# 패키지 설치 확인
cd E:/Oral-record-agent_v4.0
pip show python-docx
pip show pdfplumber

# 없으면 설치
pip install python-docx pdfplumber --break-system-packages

# requirements.txt 추가
echo "python-docx>=1.1.0" >> requirements.txt
echo "pdfplumber>=0.10.0" >> requirements.txt
```

### 수정 — 텍스트 추출 코드 강화

파일 텍스트 추출 담당 파일 찾기:
```bash
grep -r "docx\|extract.*text\|file.*upload" \
  E:/Oral-record-agent_v4.0 --include="*.py" -l
```

찾은 파일에서 텍스트 추출 함수를 아래로 교체:

```python
# utils/file_extractor.py (없으면 신규 생성)
import os
import logging
from pathlib import Path

logger = logging.getLogger(__name__)

def extract_text_from_file(file_path: str, filename: str) -> str:
    """
    파일에서 텍스트 추출.
    지원: .txt / .pdf / .docx
    실패 시 ValueError 발생 (500 대신 400 오류로 처리)
    """
    ext = Path(filename).suffix.lower()

    # ── .txt ──────────────────────────────────────────
    if ext == '.txt':
        try:
            with open(file_path, encoding='utf-8') as f:
                return f.read()
        except UnicodeDecodeError:
            with open(file_path, encoding='cp949') as f:  # 한글 인코딩
                return f.read()

    # ── .docx ─────────────────────────────────────────
    elif ext == '.docx':
        try:
            from docx import Document
        except ImportError:
            raise ValueError(
                "python-docx 패키지가 설치되지 않았습니다. "
                "pip install python-docx 실행 후 서버를 재시작하세요."
            )
        try:
            doc = Document(file_path)
            paragraphs = [p.text for p in doc.paragraphs if p.text.strip()]
            text = '\n'.join(paragraphs)
            if not text.strip():
                raise ValueError("docx 파일에서 텍스트를 추출할 수 없습니다.")
            return text
        except Exception as e:
            raise ValueError(f"docx 파싱 오류: {e}")

    # ── .pdf ──────────────────────────────────────────
    elif ext == '.pdf':
        try:
            import pdfplumber
        except ImportError:
            raise ValueError(
                "pdfplumber 패키지가 설치되지 않았습니다. "
                "pip install pdfplumber 실행 후 서버를 재시작하세요."
            )
        try:
            with pdfplumber.open(file_path) as pdf:
                pages = [page.extract_text() or '' for page in pdf.pages]
            text = '\n'.join(pages).strip()
            if not text:
                raise ValueError("PDF에서 텍스트를 추출할 수 없습니다. (스캔 PDF)")
            return text
        except Exception as e:
            raise ValueError(f"PDF 파싱 오류: {e}")

    else:
        raise ValueError(
            f"지원하지 않는 파일 형식: {ext}. "
            "지원 형식: .txt / .pdf / .docx"
        )
```

### 수정 — API 엔드포인트 오류 처리 강화

파일 업로드 → 트리플 추출 엔드포인트:

```python
# api/router_triple.py 또는 router_records.py 에서
# 파일 처리 엔드포인트 수정

from fastapi import APIRouter, UploadFile, File, HTTPException
import tempfile, os

@router.post("/extract-from-file")
async def extract_triples_from_file(
    file: UploadFile = File(...),
    ontology_version_id: str = Form(...),
):
    # 1. 임시 파일 저장
    suffix = Path(file.filename).suffix
    with tempfile.NamedTemporaryFile(
        delete=False, suffix=suffix
    ) as tmp:
        content = await file.read()
        tmp.write(content)
        tmp_path = tmp.name

    try:
        # 2. 텍스트 추출 (오류 시 400 반환)
        try:
            text = extract_text_from_file(tmp_path, file.filename)
        except ValueError as e:
            raise HTTPException(status_code=400, detail=str(e))

        # 3. 텍스트 길이 제한 (AI 컨텍스트 초과 방지)
        MAX_CHARS = 8000
        if len(text) > MAX_CHARS:
            text = text[:MAX_CHARS]
            logger.warning(
                f"텍스트 {len(text)}자 → {MAX_CHARS}자로 잘림: {file.filename}"
            )

        # 4. 트리플 추출 (오류 시 500 → 명확한 메시지)
        try:
            result = triple_extractor.extract(
                content=text,
                ontology_version_id=ontology_version_id,
                source_record_id=file.filename,
            )
        except ValueError as e:
            raise HTTPException(status_code=422, detail=str(e))
        except Exception as e:
            logger.error(f"트리플 추출 오류: {e}")
            raise HTTPException(
                status_code=500,
                detail=f"AI 트리플 추출 중 오류: {str(e)[:200]}"
            )

        return result

    finally:
        # 5. 임시 파일 반드시 삭제
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)
```

### Bug A 검증

```bash
# curl 로 직접 테스트
curl -X POST http://localhost:9000/api/triples/extract-from-file \
  -F "file=@E:/테스트.txt" \
  -F "ontology_version_id=debug-merge-001"

# 기대: {"added": N, "skipped": N, "triples": [...]}
# 400이면 텍스트 추출 오류 메시지 확인
# 500이면 서버 로그 traceback 확인
```

---

## Bug B — Draft 종합 500 오류 (지속)

### 이전 수정이 적용되지 않은 경우

이전에 수정 지시를 했음에도 동일 오류가 반복되므로,
코드가 실제로 수정됐는지 먼저 확인해야 함.

```bash
# 현재 merge_drafts() 코드 확인
grep -n "merge_drafts\|_ai_merge\|allowed_class\|allowed_pred" \
  E:/Oral-record-agent_v4.0/ontology/ontology_manager.py

# allowed_class, allowed_pred 필터링 코드가 없으면 미적용 상태
```

### 수정 — ontology_manager.py 전체 재확인

```
ontology/ontology_manager.py 전체 내용을 나에게 보여줘.
특히:
  1. OntologyClass 데이터클래스: note, standard_tag 필드 있는지
  2. OntologyPredicate 데이터클래스: note, standard_tag 필드 있는지
  3. merge_drafts() 메서드: 필드 필터링 코드 있는지
  4. generate_from_sample() 메서드: 필드 필터링 코드 있는지
```

### 수정 — 데이터클래스 + 필터링 일괄 적용

```python
# ontology/ontology_manager.py

@dataclass
class OntologyClass:
    name:         str
    label_ko:     str
    color:        str
    description:  str = ""
    examples:     list[str] = field(default_factory=list)
    note:         str = ""
    standard_tag: str = ""
    merge_note:   str = ""

@dataclass
class OntologyPredicate:
    name:         str
    domain:       list[str] = field(default_factory=list)
    range_:       list[str] = field(default_factory=list)
    description:  str = ""
    note:         str = ""
    standard_tag: str = ""
    merge_note:   str = ""

# 공통 필터링 함수 (모든 AI 응답에 적용)
_ALLOWED_CLASS_FIELDS = {
    'name','label_ko','color','description',
    'examples','note','standard_tag','merge_note'
}
_ALLOWED_PRED_FIELDS = {
    'name','domain','range_','description',
    'note','standard_tag','merge_note'
}

def _safe_class(data: dict) -> OntologyClass | None:
    if not isinstance(data, dict): return None
    filtered = {k: v for k, v in data.items()
                if k in _ALLOWED_CLASS_FIELDS}
    try:
        return OntologyClass(**filtered)
    except TypeError:
        return None

def _safe_predicate(data: dict) -> OntologyPredicate | None:
    if not isinstance(data, dict): return None
    filtered = {k: v for k, v in data.items()
                if k in _ALLOWED_PRED_FIELDS}
    try:
        return OntologyPredicate(**filtered)
    except TypeError:
        return None
```

`generate_from_sample()` 과 `merge_drafts()` 양쪽에서
`_safe_class()` / `_safe_predicate()` 사용:

```python
# generate_from_sample() 파싱 부분
version.classes = [
    c for c in (_safe_class(d) for d in parsed.get("classes", []))
    if c is not None
]
version.predicates = [
    p for p in (_safe_predicate(d) for d in parsed.get("predicates", []))
    if p is not None
]

# merge_drafts() 파싱 부분 — 동일하게 적용
```

### Bug B 검증

```bash
# 서버 재시작 후 curl 테스트
curl -X POST http://localhost:9000/api/ontologies/merge \
  -H "Content-Type: application/json" \
  -d '{
    "version_ids": ["draft-20260408192451", "merged-1775643670"],
    "new_version_id": "test-fix-001",
    "description": "버그 수정 후 테스트"
  }'

# 기대: {"version_id": "test-fix-001", "status": "draft", ...}
```

---

## 수정 순서

```
1. 서버 터미널에서 Bug A, Bug B 각각의 Traceback 확인 + 보고
2. Bug A 수정:
   a. pip install python-docx pdfplumber (없으면)
   b. utils/file_extractor.py 신규 생성
   c. 파일 업로드 엔드포인트 오류 처리 강화
3. Bug B 수정:
   a. ontology_manager.py 데이터클래스 필드 추가 확인
   b. _safe_class / _safe_predicate 공통 함수 추가
   c. generate_from_sample + merge_drafts 양쪽 적용
4. 서버 재시작
5. 각 버그 curl 검증
6. Flutter 앱 수동 검증:
   □ .docx 파일 업로드 → 트리플 생성 성공
   □ Draft 2개 선택 → 종합 성공 → 새 Draft 목록 추가
7. pytest tests/ → 101/101 확인
8. git commit
```

---

## 커밋 메시지

```bash
git commit -m "fix: docx 트리플 추출 + 온톨로지 종합 500 오류 수정

Bug A: .docx 파일 트리플 추출 500
  - utils/file_extractor.py: txt/pdf/docx 추출 로직 분리
  - python-docx/pdfplumber 미설치 시 400 오류로 명확한 안내
  - 한글 파일명, 임시 파일 처리 강화
  - 텍스트 8000자 제한 (AI 컨텍스트 초과 방지)

Bug B: Draft 종합 500
  - OntologyClass/Predicate: note, standard_tag, merge_note 필드 추가
  - _safe_class / _safe_predicate 공통 필터링 함수 신규
  - generate_from_sample + merge_drafts 양쪽 적용
  - 이력 기록 실패가 merge 실패로 전파되지 않도록 수정"
```
