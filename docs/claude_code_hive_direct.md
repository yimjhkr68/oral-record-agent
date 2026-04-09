# Hive DB 직접 연결 통합 Plan

## 연결 방식 확정

```
v4.0 FastAPI
    ↕ 직접 연결 (pyhive 또는 impyla)
로컬 Hive DB (본 PC 설치)
    ↕
구술기록 테이블 (content 필드)
```

---

## Step 1 — 로컬 Hive DB 환경 파악

작업 전 반드시 확인. 아래를 실행해서 결과를 나에게 보고해.

### 1-1. Hive 서버 실행 상태 확인

```bash
# Hive 서버 포트 확인 (기본 10000)
netstat -ano | findstr :10000

# HiveServer2 프로세스 확인
tasklist | findstr -i hive
tasklist | findstr -i java
```

### 1-2. v3.0 Hive 연결 설정 확인

```bash
# v3.0 환경변수 파일 확인
cat E:/Oral-record-agent_v3.0/.env
cat E:/Oral-record-agent_v3.0/config.py 2>/dev/null || echo "없음"

# v3.0 에서 Hive 연결하는 실제 코드 확인
grep -r "connect\|host\|port\|database\|HiveServer" \
  E:/Oral-record-agent_v3.0 --include="*.py" -n
```

### 1-3. 구술기록 테이블 구조 확인

```bash
# v3.0 코드에서 테이블명과 컬럼명 확인
grep -r "SELECT\|FROM\|narrator\|content\|interview" \
  E:/Oral-record-agent_v3.0 --include="*.py" -n
```

보고 형식:
```
[Hive 서버]
  상태: 실행 중 / 중지
  포트: 10000 (기본) / 기타
  호스트: localhost / 기타

[연결 설정]
  라이브러리: pyhive / impyla / 기타
  host:
  port:
  database:
  username:
  password:
  auth:

[테이블 구조]
  테이블명:
  컬럼: id, narrator_name, content, interview_date, ...
```

---

## Step 2 — v4.0 패키지 설치

Step 1 결과에서 확인된 라이브러리 기준으로 설치.

### pyhive 방식인 경우

```bash
cd E:/Oral-record-agent_v4.0
pip install pyhive thrift thrift-sasl --break-system-packages
pip install pyhive[hive] --break-system-packages
```

### impyla 방식인 경우

```bash
pip install impyla thrift thrift-sasl --break-system-packages
```

### requirements.txt 업데이트

```
# Hive DB 직접 연결
pyhive[hive]>=0.7.0
thrift>=0.16.0
thrift-sasl>=0.4.3
# 또는
impyla>=0.18.0
```

---

## Step 3 — core/hive_connector.py 작성

`E:/Oral-record-agent_v4.0/core/` 디렉토리 생성 후 파일 작성.

```python
# E:/Oral-record-agent_v4.0/core/__init__.py
# (빈 파일)
```

```python
# E:/Oral-record-agent_v4.0/core/hive_connector.py
"""
Hive DB 직접 연결 모듈.
v3.0 연결 방식 기반, v4.0 에서 재사용.
환경변수로 연결 설정 관리.
"""
import os
import logging
from typing import Optional
from dotenv import load_dotenv

load_dotenv()
logger = logging.getLogger(__name__)


class HiveConnector:

    def __init__(self):
        self.host     = os.environ.get("HIVE_HOST", "localhost")
        self.port     = int(os.environ.get("HIVE_PORT", "10000"))
        self.database = os.environ.get("HIVE_DATABASE", "default")
        self.username = os.environ.get("HIVE_USERNAME", "")
        self.password = os.environ.get("HIVE_PASSWORD", "")
        self.auth     = os.environ.get("HIVE_AUTH", "NONE")
        self.table    = os.environ.get("HIVE_TABLE", "oral_records")
        self._conn    = None

    # ── 연결 관리 ────────────────────────────────────────────

    def connect(self) -> bool:
        """
        Hive 연결 시도.
        성공: True, 실패: False (예외 전파 안 함).
        """
        try:
            # v3.0 에서 확인된 실제 연결 방식으로 교체
            # pyhive 방식:
            from pyhive import hive
            self._conn = hive.connect(
                host=self.host,
                port=self.port,
                database=self.database,
                username=self.username,
                password=self.password,
                auth=self.auth,
            )
            logger.info(f"Hive 연결 성공: {self.host}:{self.port}/{self.database}")
            return True
        except Exception as e:
            logger.warning(f"Hive 연결 실패: {e}")
            self._conn = None
            return False

    def is_connected(self) -> bool:
        """연결 상태 확인."""
        if self._conn is None:
            return False
        try:
            cursor = self._conn.cursor()
            cursor.execute("SELECT 1")
            cursor.close()
            return True
        except Exception:
            self._conn = None
            return False

    def ensure_connected(self) -> bool:
        """연결 안 되어 있으면 재연결 시도."""
        if not self.is_connected():
            return self.connect()
        return True

    def close(self):
        """연결 종료."""
        if self._conn:
            try:
                self._conn.close()
            except Exception:
                pass
            self._conn = None

    # ── 데이터 조회 ──────────────────────────────────────────

    def search_records(self, query: str = "", limit: int = 20) -> list[dict]:
        """
        구술기록 검색.
        query: 구술자명 또는 content 키워드
        미연결 시 빈 목록 반환 (예외 없음).
        """
        if not self.ensure_connected():
            logger.warning("Hive 미연결 — 빈 목록 반환")
            return []

        try:
            cursor = self._conn.cursor()

            if query:
                sql = f"""
                    SELECT id, narrator_name, interview_date,
                           SUBSTR(content, 1, 200) AS content_preview
                    FROM {self.table}
                    WHERE narrator_name LIKE '%{query}%'
                       OR content LIKE '%{query}%'
                    LIMIT {limit}
                """
            else:
                sql = f"""
                    SELECT id, narrator_name, interview_date,
                           SUBSTR(content, 1, 200) AS content_preview
                    FROM {self.table}
                    LIMIT {limit}
                """

            cursor.execute(sql)
            columns = [desc[0].split(".")[-1] for desc in cursor.description]
            rows = cursor.fetchall()
            cursor.close()

            return [dict(zip(columns, row)) for row in rows]

        except Exception as e:
            logger.error(f"검색 오류: {e}")
            return []

    def get_record(self, record_id: str) -> Optional[dict]:
        """단건 조회."""
        if not self.ensure_connected():
            return None
        try:
            cursor = self._conn.cursor()
            cursor.execute(
                f"SELECT * FROM {self.table} WHERE id = '{record_id}' LIMIT 1"
            )
            columns = [desc[0].split(".")[-1] for desc in cursor.description]
            row = cursor.fetchone()
            cursor.close()
            if row:
                return dict(zip(columns, row))
            return None
        except Exception as e:
            logger.error(f"레코드 조회 오류: {e}")
            return None

    def get_content(self, record_id: str) -> Optional[str]:
        """content 필드만 반환."""
        record = self.get_record(record_id)
        if record:
            return record.get("content")
        return None

    def get_recent_records(self, limit: int = 50) -> list[dict]:
        """최근 레코드 목록 (검색어 없이 전체)."""
        return self.search_records(query="", limit=limit)
```

---

## Step 4 — .env 설정

`E:/Oral-record-agent_v4.0/.env` 에 추가:

```bash
# Hive DB 직접 연결 설정
# Step 1 에서 확인한 실제 값으로 교체
HIVE_HOST=localhost
HIVE_PORT=10000
HIVE_DATABASE=default
HIVE_USERNAME=
HIVE_PASSWORD=
HIVE_AUTH=NONE
HIVE_TABLE=oral_records   # 실제 테이블명으로 교체
```

`.gitignore` 에 `.env` 포함 여부 확인:
```bash
grep ".env" E:/Oral-record-agent_v4.0/.gitignore
# 없으면 추가
echo ".env" >> E:/Oral-record-agent_v4.0/.gitignore
```

---

## Step 5 — router_hive.py 교체

```python
# E:/Oral-record-agent_v4.0/api/router_hive.py
from fastapi import APIRouter, Query
from core.hive_connector import HiveConnector

router = APIRouter(prefix="/api/hive", tags=["hive"])

# 싱글톤 — 앱 전체에서 하나의 연결 공유
_connector: HiveConnector = None

def get_connector() -> HiveConnector:
    global _connector
    if _connector is None:
        _connector = HiveConnector()
        _connector.connect()
    return _connector


@router.get("/status")
def hive_status():
    conn = get_connector()
    connected = conn.is_connected()
    return {
        "connected": connected,
        "host": conn.host,
        "port": conn.port,
        "database": conn.database,
        "message": "Hive DB 연결됨" if connected else "Hive DB 미연결",
    }


@router.post("/reconnect")
def hive_reconnect():
    """연결 끊겼을 때 재연결."""
    conn = get_connector()
    conn.close()
    success = conn.connect()
    return {"success": success, "connected": conn.is_connected()}


@router.get("/records")
def search_records(q: str = Query(default="")):
    conn = get_connector()
    records = conn.search_records(query=q)
    return {"records": records, "total": len(records)}


@router.get("/records/recent")
def recent_records(limit: int = 20):
    conn = get_connector()
    records = conn.get_recent_records(limit=limit)
    return {"records": records, "total": len(records)}


@router.get("/records/{record_id}")
def get_record(record_id: str):
    conn = get_connector()
    record = conn.get_record(record_id)
    if not record:
        return {"error": f"레코드를 찾을 수 없습니다: {record_id}"}
    return record


@router.get("/records/{record_id}/content")
def get_content(record_id: str):
    conn = get_connector()
    content = conn.get_content(record_id)
    if content is None:
        return {"error": f"content 없음: {record_id}"}
    return {"id": record_id, "content": content}
```

---

## Step 6 — main.py 라우터 등록 확인

```python
# main.py 에 아래가 있는지 확인, 없으면 추가
from api.router_hive import router as hive_router
app.include_router(hive_router)
```

---

## Step 7 — Flutter 설정화면 [재연결] 버튼 추가

```dart
// flutter/lib/screens/settings/settings_screen.dart
// Hive DB 섹션에 [재연결] 버튼 추가

ElevatedButton(
  onPressed: () async {
    final res = await ref.read(apiClientProvider)
        .post('/api/hive/reconnect');
    if (!mounted) return;
    final ok = res.data['connected'] == true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Hive DB 재연결 성공' : 'Hive DB 재연결 실패'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
    _checkHiveConnection();   // 상태 갱신
  },
  child: const Text('Hive DB 재연결'),
),
```

---

## Step 8 — 검증

### 8-1. 백엔드 직접 테스트

```bash
# 서버 재시작
set ANTHROPIC_API_KEY=sk-ant-...
python -m uvicorn main:app --port 9000

# Hive 연결 상태
curl http://localhost:9000/api/hive/status
# 기대: {"connected": true, "host": "localhost", ...}

# 레코드 검색
curl "http://localhost:9000/api/hive/records?q=안동"
# 기대: {"records": [...실제 데이터...], "total": N}

# 최근 레코드
curl http://localhost:9000/api/hive/records/recent
# 기대: 최근 20개 레코드
```

### 8-2. Flutter 통합 테스트

```
□ 설정 탭 → Hive DB 연결됨 (녹색)
□ 트리플 탭 → Step 1 → Hive DB 탭
□ 검색창에 구술자명 입력 → 실제 레코드 목록 표시
□ 레코드 선택 → 추가 → 선택 목록에 카드 추가
□ [트리플 생성] → AI 추출 → Step 2 이동
□ 검토 후 [전체 확정 저장] → Step 3 이동
□ data/triples/graph.json 트리플 저장 확인
```

---

## Step 9 — 커밋

```bash
cd E:/Oral-record-agent_v4.0
git add core/ api/router_hive.py requirements.txt .gitignore
git commit -m "feat: Hive DB 로컬 직접 연결 통합

- core/hive_connector.py 신규 생성
  - 직접 연결 (pyhive)
  - 재연결 자동 처리
  - 미연결 시 빈 목록 반환 (앱 크래시 방지)
- api/router_hive.py Mock → 실제 연결로 교체
- POST /api/hive/reconnect 엔드포인트 추가
- .env Hive 연결 설정 추가"
```

---

## 제약 조건

```
- Step 1 Hive 환경 확인 결과를 반드시 먼저 보고
  → 실제 테이블명/컬럼명 확인 후 Step 3 코드에 반영
- 인증정보는 .env 에만, 코드 하드코딩 금지
- Hive 미연결 상태에서도 앱 정상 실행 (빈 목록 반환)
- pyhive import 실패 시 오류 메시지 명확히 출력
- Step 1 결과 보고 후 내가 승인하면 Step 2 진행
```
