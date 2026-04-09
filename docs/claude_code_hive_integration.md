# v3.0 Hive DB 연결 코드 → v4.0 통합

## 목표

v3.0 저장소의 실제 Hive DB 연결 코드를 v4.0에 통합한다.
Mock 코드를 실제 연결 코드로 교체하여 Hive DB 검색이 동작하게 한다.

---

## Step 1 — v3.0 코드 전수 파악

아래 경로의 파일들을 열어서 내용을 나에게 보여줘.
추측하지 말고 실제 파일을 읽어서 보고해.

```
E:/Oral-record-agent_v3.0/ 디렉토리 전체 구조 먼저 확인:
  find E:/Oral-record-agent_v3.0 -type f | grep -v __pycache__ | grep -v .git | sort

그 다음 아래 파일들을 순서대로 열어서 전체 내용 보고:

1. Hive 연결 관련 파일 찾기:
   grep -r "hive" E:/Oral-record-agent_v3.0 --include="*.py" -l
   grep -r "Hive" E:/Oral-record-agent_v3.0 --include="*.py" -l

2. 찾은 파일들 전체 내용

3. E:/Oral-record-agent_v3.0/requirements.txt
   → Hive 관련 패키지 확인 (pyhive, impyla, thrift 등)

4. E:/Oral-record-agent_v3.0/.env 또는 config.py
   → Hive 연결 설정값 (host, port, database, auth 방식)
```

보고 형식:
```
[v3.0 Hive 관련 파일 목록]
  - 파일경로1
  - 파일경로2

[Hive 연결 방식]
  라이브러리: pyhive / impyla / 기타
  연결 설정: host=, port=, database=, auth=

[구술기록 테이블 구조]
  테이블명:
  주요 컬럼: id, narrator_name, content, ...

[v3.0 에서 content 를 가져오는 실제 코드]
  (코드 붙여넣기)
```

---

## Step 2 — v4.0 현재 상태 파악

```
현재 v4.0 의 Hive 관련 파일 확인:

1. E:/Oral-record-agent_v4.0/api/router_hive.py 전체
   → Mock 코드인지 실제 연결인지

2. E:/Oral-record-agent_v4.0/pipeline/hive_pipeline.py 전체
   → v3.0 코드와 어떻게 다른지

3. E:/Oral-record-agent_v4.0/requirements.txt
   → pyhive 등 Hive 패키지 있는지
```

---

## Step 3 — 비교 분석 및 통합 계획 수립

Step 1, 2 파악 결과를 바탕으로:

```
다음을 나에게 보고해:

1. v3.0 과 v4.0 의 Hive 연결 코드 차이점
   - 동일한 부분
   - 다른 부분
   - v4.0 에서 누락된 부분

2. v4.0 requirements.txt 에 추가 필요한 패키지 목록

3. 통합 시 예상되는 충돌 또는 주의사항

보고 후 내가 승인하면 Step 4 진행.
```

---

## Step 4 — 통합 실행

Step 3 보고 후 내 승인을 받은 뒤 진행.

### 4-1. requirements.txt 업데이트

v3.0 에서 사용하는 Hive 패키지를
`E:/Oral-record-agent_v4.0/requirements.txt` 에 추가.

```bash
cd E:/Oral-record-agent_v4.0
pip install [v3.0의 Hive 패키지] --break-system-packages
```

### 4-2. Hive 연결 설정 통합

`E:/Oral-record-agent_v4.0/.env` 에
v3.0 의 Hive 연결 설정값 추가:

```
# Hive DB (v3.0 호환)
HIVE_HOST=
HIVE_PORT=
HIVE_DATABASE=
HIVE_USERNAME=
HIVE_PASSWORD=
HIVE_AUTH=
```

실제 값은 v3.0 의 .env 또는 config.py 에서 복사.
단, 비밀번호/인증정보는 .env 에만 저장하고 코드에 하드코딩 금지.

### 4-3. HiveConnector 공통 모듈 생성

`E:/Oral-record-agent_v4.0/core/` 디렉토리를 새로 만들고:

```python
# E:/Oral-record-agent_v4.0/core/__init__.py
# (빈 파일)

# E:/Oral-record-agent_v4.0/core/hive_connector.py
"""
Hive DB 연결 공통 모듈.
v3.0 코드 기반, v4.0 에서 재사용.
향후 v5.0+ 에서도 이 파일을 core/ 로 가져가서 사용.
"""
import os
from typing import Optional

# v3.0 의 실제 연결 코드를 여기에 이식
# (Step 1 에서 파악한 코드 기반으로 작성)

class HiveConnector:
    def __init__(self):
        self.host     = os.environ.get("HIVE_HOST", "localhost")
        self.port     = int(os.environ.get("HIVE_PORT", "10000"))
        self.database = os.environ.get("HIVE_DATABASE", "default")
        self.username = os.environ.get("HIVE_USERNAME", "")
        self.password = os.environ.get("HIVE_PASSWORD", "")
        self.auth     = os.environ.get("HIVE_AUTH", "NONE")
        self._conn    = None

    def connect(self):
        """연결. 실패 시 None 반환 (예외 전파 안 함)."""
        # v3.0 실제 연결 코드 이식
        pass

    def is_connected(self) -> bool:
        """연결 상태 확인."""
        pass

    def search_records(self, query: str, limit: int = 20) -> list[dict]:
        """
        구술기록 검색.
        미연결 시 빈 목록 반환.
        """
        pass

    def get_record(self, record_id: str) -> Optional[dict]:
        """단건 조회."""
        pass

    def get_content(self, record_id: str) -> Optional[str]:
        """content 필드만 반환."""
        pass

    def close(self):
        """연결 종료."""
        pass
```

### 4-4. router_hive.py 실제 연결 코드로 교체

```python
# E:/Oral-record-agent_v4.0/api/router_hive.py
from fastapi import APIRouter, Query
from core.hive_connector import HiveConnector

router = APIRouter(prefix="/api/hive", tags=["hive"])
connector = HiveConnector()


@router.get("/status")
def hive_status():
    connected = connector.is_connected()
    return {
        "connected": connected,
        "message": "Hive DB 연결됨" if connected else "Hive DB 미연결"
    }


@router.get("/records")
def search_records(query: str = Query(default="")):
    try:
        records = connector.search_records(query)
        return {"records": records, "total": len(records)}
    except Exception as e:
        return {"records": [], "total": 0, "error": str(e)}


@router.get("/records/{record_id}")
def get_record(record_id: str):
    record = connector.get_record(record_id)
    if not record:
        return {"error": "레코드를 찾을 수 없습니다."}
    return record


@router.get("/records/{record_id}/content")
def get_content(record_id: str):
    content = connector.get_content(record_id)
    if content is None:
        return {"error": "content 를 찾을 수 없습니다."}
    return {"id": record_id, "content": content}
```

### 4-5. pipeline/hive_pipeline.py 업데이트

기존 hive_pipeline.py 의 연결 방식을
HiveConnector 를 사용하도록 교체:

```python
# pipeline/hive_pipeline.py 상단 import 교체
from core.hive_connector import HiveConnector

class HiveToGraphPipeline:
    def __init__(self, triple_store):
        self.hive  = HiveConnector()   # ← 직접 연결 대신 HiveConnector 사용
        self.store = triple_store
        ...
```

---

## Step 5 — 검증

### 5-1. 백엔드 검증

```bash
cd E:/Oral-record-agent_v4.0

# 서버 재시작
set ANTHROPIC_API_KEY=sk-ant-...
python -m uvicorn main:app --port 9000

# 연결 상태 확인
curl http://localhost:9000/api/hive/status

# 검색 테스트
curl "http://localhost:9000/api/hive/records?query=안동"
```

기대 결과:
```json
{"connected": true, "message": "Hive DB 연결됨"}
{"records": [...실제 데이터...], "total": N}
```

### 5-2. Flutter 앱 검증

```bash
cd E:/Oral-record-agent_v4.0/flutter
flutter run -d windows
```

확인 순서:
```
□ 트리플 탭 → Step 1 → Hive DB 탭
□ [연결 확인] → 녹색 "연결됨"
□ 검색어 입력 → [검색] → 실제 구술기록 목록 표시
□ 레코드 선택 → [추가] → 선택 목록에 추가
□ [트리플 생성] → AI 추출 → Step 2 이동
□ 검토 후 [전체 확정 저장] → Step 3 이동 (블랙 화면 없음)
□ data/triples/graph.json 에 트리플 저장 확인
```

---

## Step 6 — 정리 및 커밋

```bash
cd E:/Oral-record-agent_v4.0

git add core/ api/router_hive.py pipeline/hive_pipeline.py requirements.txt
git commit -m "feat: v3.0 Hive DB 연결 코드 통합

- core/hive_connector.py 신규 생성 (v3.0 코드 이식)
- api/router_hive.py Mock → 실제 연결로 교체
- pipeline/hive_pipeline.py HiveConnector 사용으로 통합
- requirements.txt Hive 패키지 추가

향후 v5.0 단일저장소 구조에서 core/ 를 그대로 재사용 예정"
```

---

## 제약 조건

```
- v3.0 저장소 파일은 읽기만 (수정 금지)
- 인증정보(비밀번호 등)는 .env 에만 저장, 코드에 하드코딩 금지
- .env 는 .gitignore 에 포함되어 있는지 확인
- Step 3 보고 후 내 승인 없이 Step 4 진행 금지
- Hive DB 연결 불가 환경에서도 앱이 정상 실행되어야 함
  (연결 실패 시 빈 목록 반환, 500 오류 금지)
```
