# 온톨로지 종합 500 오류 디버깅 Plan

## 증상

```
화면: 온톨로지 관리 → [선택 Draft 종합] 클릭
오류: DioException [bad response] 500 Internal Server Error
API: POST /api/ontologies/merge
```

---

## Step 1 — 서버 로그 확인 (가장 먼저)

FastAPI 서버가 실행 중인 터미널을 확인해서
500 오류 발생 시 출력된 traceback 전체를 나에게 보여줘.

```
서버 터미널에서:
  ERROR 로 시작하는 줄
  Traceback (most recent call last): 이하 전체
  실제 예외 메시지 마지막 줄
```

---

## Step 2 — 관련 코드 전수 파악

서버 로그 확인과 동시에 아래 파일들을 열어서 전체 내용을 보고해.

```
1. api/router_ontology.py
   → POST /api/ontologies/merge 엔드포인트 코드 전체

2. ontology/ontology_manager.py
   → merge_drafts() 메서드 전체

3. ontology/ontology_store.py (있으면)
   → save_draft() 메서드

4. core/history_store.py (있으면)
   → record_ontology_event() 메서드
```

---

## Step 3 — 원인 판별 트리

Step 1 서버 로그 기반으로 아래 중 해당하는 Case를 특정해.

### Case A — AI API 호출 오류

```
로그 패턴:
  anthropic.APIError 또는
  json.JSONDecodeError 또는
  KeyError: 'triples' 또는 'classes'

원인:
  merge_drafts() 에서 AI 호출 후 응답 파싱 실패
  → AI가 예상 외 형식으로 응답

수정:
  ontology_manager.py 의 merge_drafts() AI 응답 파싱 부분:

  # 수정 전 (취약)
  parsed = json.loads(text)
  classes = parsed['classes']

  # 수정 후 (방어적)
  try:
      clean = text.replace('```json','').replace('```','').strip()
      parsed = json.loads(clean)
  except json.JSONDecodeError as e:
      raise ValueError(f"AI 응답 파싱 실패: {e}\n응답: {text[:200]}")

  classes = parsed.get('classes', [])
  predicates = parsed.get('predicates', [])

  # OntologyClass 생성 시 알려진 필드만 필터링
  allowed_class = {'name','label_ko','color','description','examples','note'}
  allowed_pred  = {'name','domain','range_','description','note'}

  version.classes = [
      OntologyClass(**{k:v for k,v in c.items() if k in allowed_class})
      for c in classes if isinstance(c, dict)
  ]
  version.predicates = [
      OntologyPredicate(**{k:v for k,v in p.items() if k in allowed_pred})
      for p in predicates if isinstance(p, dict)
  ]
```

### Case B — OntologyPredicate / OntologyClass 필드 오류

```
로그 패턴:
  TypeError: __init__() got an unexpected keyword argument 'note'
  또는 유사한 필드명 오류

원인:
  AI 응답에 데이터클래스에 없는 필드 포함

수정:
  ontology/ontology_manager.py 에서
  OntologyPredicate, OntologyClass 데이터클래스에
  note: str = "" 필드 추가

  @dataclass
  class OntologyPredicate:
      name:        str
      domain:      list[str] = field(default_factory=list)
      range_:      list[str] = field(default_factory=list)
      description: str = ""
      note:        str = ""   ← 추가

  @dataclass
  class OntologyClass:
      name:        str
      label_ko:    str
      color:       str
      description: str = ""
      examples:    list[str] = field(default_factory=list)
      note:        str = ""   ← 추가

  그리고 Case A 의 필드 필터링도 함께 적용.
```

### Case C — 파일 저장 오류

```
로그 패턴:
  FileNotFoundError 또는
  PermissionError 또는
  OSError

원인:
  data/ontologies/drafts/ 디렉토리 없거나 쓰기 권한 없음

수정:
  ontology_store.py 또는 ontology_manager.py 의
  저장 메서드에 디렉토리 자동 생성 추가:

  from pathlib import Path
  Path(save_path).parent.mkdir(parents=True, exist_ok=True)
```

### Case D — version_id 중복 오류

```
로그 패턴:
  ValueError: version_id already exists 또는
  KeyError 관련

원인:
  종합 시 생성되는 version_id 가 이미 존재

수정:
  router_ontology.py 의 merge 엔드포인트에서
  new_version_id 가 비어 있으면 자동 생성:

  if not new_version_id:
      import time
      new_version_id = f"merged-{int(time.time())}"
```

### Case E — history_store 오류

```
로그 패턴:
  sqlite3.OperationalError 또는
  NameError: history_store

원인:
  merge 완료 후 이력 기록 시 DB 오류

수정:
  merge_drafts() 또는 router 에서
  history_store 호출 부분을 try-except 로 감싸기:

  try:
      history_store.record_ontology_event(
          event_type="merged", ...
      )
  except Exception as e:
      logger.warning(f"이력 기록 실패 (무시): {e}")
      # 이력 기록 실패가 merge 자체를 실패시키면 안 됨
```

### Case F — request body 파싱 오류

```
로그 패턴:
  422 Unprocessable Entity 또는
  pydantic ValidationError

원인:
  Flutter 에서 보내는 body 형식과 FastAPI 스키마 불일치

수정 확인:
  router_ontology.py 의 merge 엔드포인트 파라미터:
  body: { "version_ids": [...], "new_version_id": "...", "description": "..." }

  Flutter triple_api.dart 또는 ontology_api.dart 에서
  보내는 실제 body 확인:
  → 키 이름이 일치하는지 확인
```

---

## Step 4 — curl 직접 테스트

Flutter 를 거치지 않고 API 를 직접 호출해서
서버 단독 동작을 확인해:

```bash
# 실제 존재하는 Draft 버전 ID 2개 사용
curl -X POST http://localhost:9000/api/ontologies/merge \
  -H "Content-Type: application/json" \
  -d '{
    "version_ids": ["draft-20260409200717", "merged-1775643670"],
    "new_version_id": "test-merge-001",
    "description": "테스트 종합"
  }'
```

응답 결과 전체를 나에게 보여줘.

- 200 → API 정상, Flutter 호출 방식 문제
- 500 → 서버 문제, traceback 확인
- 422 → body 형식 문제

---

## Step 5 — 수정 및 검증

Step 1~4 결과를 바탕으로 해당 Case 수정 후:

```bash
# 서버 재시작
python -m uvicorn main:app --port 9000

# curl 재테스트
curl -X POST http://localhost:9000/api/ontologies/merge \
  -H "Content-Type: application/json" \
  -d '{
    "version_ids": ["draft-20260409200717", "merged-1775643670"],
    "new_version_id": "test-merge-002",
    "description": "수정 후 테스트"
  }'
# 기대 응답: {"version_id": "test-merge-002", "status": "draft", ...}

# Flutter 앱에서 재테스트
# [선택 Draft 종합] → 새 Draft 생성 확인
```

---

## Step 6 — 회귀 테스트

수정 완료 후:

```bash
pytest tests/ -v --tb=short
# 기존 101/101 유지 확인
```

---

## Step 7 — 커밋

```bash
git add .
git commit -m "fix: 온톨로지 종합(merge) 500 오류 수정

- OntologyPredicate/OntologyClass note 필드 추가
- AI 응답 파싱 방어 코드 추가 (필드 필터링)
- 이력 기록 실패가 merge 실패로 전파되지 않도록 수정"
```

---

## 제약 조건

```
- Step 1 서버 로그를 반드시 먼저 확인 (추측 수정 금지)
- 여러 Case 해당 시 모두 수정 (부분 수정 금지)
- Case A + Case B 는 항상 함께 적용
  (AI 응답은 항상 예상 외 필드가 올 수 있음)
- Step 6 테스트 통과 전 커밋 금지
```
