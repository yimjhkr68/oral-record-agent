# 트리플 관리 버그 디버깅 Plan

## 대상 버그 2가지

```
Bug 1. Hive DB 검색 → 404 오류
Bug 2. 트리플 확정 저장 → 블랙 화면
```

---

## 사전 작업 — 현재 코드 전수 파악

수정 전에 반드시 아래 파일들을 열어서 실제 내용을 나에게 보여줘.
추측하지 말고 코드를 직접 읽은 후 보고해.

### 백엔드 파악

```
1. main.py 전체
   → 등록된 router 목록 확인
   → /api/hive 관련 라우트가 있는지

2. api/ 디렉토리 파일 목록
   → router_ontology.py, router_triple.py, router_search.py 외 다른 파일 있는지

3. api/router_triple.py 전체
   → /api/hive 엔드포인트 존재 여부
   → /api/triples/bulk-confirm 엔드포인트 존재 여부
   → 각 엔드포인트의 실제 구현 코드

4. pipeline/hive_pipeline.py 전체
   → HiveToGraphPipeline 클래스 구조
   → Hive 연결 방식 (실제 연결인지 Mock인지)
```

### 프론트엔드 파악

```
5. flutter/lib/screens/triple/triple_screen.dart 전체
   → Step 탭 전환 로직
   → _currentStep 상태 관리 방식

6. flutter/lib/screens/triple/triple_step2_review.dart 전체
   → [전체 확정 저장] 버튼 onPressed 전체 코드
   → bulk-confirm 호출 후 처리 코드
   → mounted 체크 여부

7. flutter/lib/screens/triple/triple_step3_list.dart 전체
   → initState() 에서 API 호출 방식
   → 오류 처리 코드

8. flutter/lib/api/triple_api.dart 전체
   → bulkConfirm() 메서드 구현
   → getHiveRecords() 메서드 구현

9. flutter/lib/providers/triple_provider.dart 전체
   → TripleNotifier 상태 구조
   → confirmAndSave() 또는 유사 메서드
```

파악 완료 후 다음 형식으로 보고해:

```
[백엔드]
  /api/hive/records 라우트: 존재 / 미존재
  /api/triples/bulk-confirm 라우트: 존재 / 미존재
  Hive 연결 방식: 실제 연결 / Mock / 미구현

[프론트엔드]
  bulk-confirm 호출 후 코드: (실제 코드 붙여넣기)
  탭 전환 방식: (실제 코드 붙여넣기)
  mounted 체크: 있음 / 없음
  Step3 initState API 호출: (실제 코드 붙여넣기)
```

---

## Bug 1 디버깅 — Hive DB 검색 404

### 1-1. 원인 판별

사전 파악 결과를 기반으로:

```
Case A: /api/hive/records 라우트 자체가 없음
  → main.py 에 hive router 가 미등록

Case B: 라우트는 있으나 URL 패턴 불일치
  → Flutter 에서 호출하는 URL 과 실제 라우트 URL 다름

Case C: 라우트 있고 URL 맞지만 Hive 연결 오류가 404 로 변환됨
  → 예외 처리에서 HTTPException(404) 를 잘못 사용
```

### 1-2. Case 별 수정

#### Case A 해당 시 — 라우트 신규 추가

`api/router_hive.py` 파일을 새로 만들어:

```python
# api/router_hive.py
from fastapi import APIRouter, Query
from typing import Optional

router = APIRouter(prefix="/api/hive", tags=["hive"])


@router.get("/status")
def hive_status():
    """Hive DB 연결 상태 확인"""
    try:
        # pipeline/hive_pipeline.py 의 연결 테스트
        # 실제 Hive 없으면 {"connected": false} 반환
        return {"connected": False, "message": "Hive DB 미연결 (v4.0 단독 모드)"}
    except Exception as e:
        return {"connected": False, "message": str(e)}


@router.get("/records")
def search_records(query: str = Query(default="", description="검색어")):
    """
    구술기록 검색.
    실제 Hive DB 연결 없으면 빈 목록 반환 (500 오류 금지).
    """
    try:
        # TODO: 실제 Hive 연결 시 hive_pipeline 사용
        # 현재는 Mock 데이터 반환
        if not query:
            return {"records": [], "total": 0}

        # Mock 데이터 (실제 Hive 연결 전까지)
        mock_records = [
            {
                "id": f"mock_{i}",
                "narrator_name": f"구술자{i}",
                "interview_date": "2024-01-01",
                "content_preview": f"{query} 관련 구술 내용 미리보기...",
            }
            for i in range(1, 4)
        ]
        return {"records": mock_records, "total": len(mock_records)}

    except Exception as e:
        # 절대 500 으로 터지지 않음
        return {"records": [], "total": 0, "error": str(e)}


@router.get("/records/{record_id}/content")
def get_record_content(record_id: str):
    """단일 레코드 content 반환"""
    try:
        # Mock
        return {
            "id": record_id,
            "content": f"[Mock] {record_id} 의 구술 내용입니다. 실제 Hive DB 연결 후 교체 예정.",
            "narrator_name": "구술자",
            "interview_date": "2024-01-01",
        }
    except Exception as e:
        return {"error": str(e)}
```

`main.py` 에 라우터 등록:

```python
from api.router_hive import router as hive_router
app.include_router(hive_router)
```

#### Case B 해당 시 — URL 불일치 수정

Flutter `triple_api.dart` 의 getHiveRecords() URL 을 실제 라우트에 맞게 수정.

#### Case C 해당 시 — 예외 처리 수정

404 대신 빈 목록 반환하도록 수정.

### 1-3. Bug 1 검증

```bash
# 서버 재시작 후
curl http://localhost:9000/api/hive/records?query=테스트
# 기대 응답: {"records": [...], "total": N}
# 404 가 아닌 200 이어야 함

curl http://localhost:9000/api/hive/status
# 기대 응답: {"connected": false/true, "message": "..."}
```

Flutter 에서 Hive DB 탭 → "AI" 검색 → 결과 목록 표시 확인.

---

## Bug 2 디버깅 — 확정 저장 후 블랙 화면

### 2-1. 원인 판별 트리

사전 파악한 코드를 기반으로 다음 순서로 원인을 특정해:

```
Step A: bulk-confirm API 자체가 오류인가?
  → curl 로 직접 테스트
  curl -X POST http://localhost:9000/api/triples/bulk-confirm \
    -H "Content-Type: application/json" \
    -d '{"triple_ids": ["test-id-1"]}'
  → 200 이면 API 정상, 오류면 백엔드 문제

Step B: API 정상인데 Flutter 크래시인가?
  → flutter run -d windows 실행 중 터미널의
    빨간 오류 메시지 전체를 복사해서 나에게 보여줘
  → "setState() called after dispose()" 류 메시지 있는지
  → "Null check operator used on a null value" 있는지
  → "RangeError" 또는 "IndexError" 있는지

Step C: 탭 전환 로직 문제인가?
  → triple_screen.dart 에서 Step 3 이동 시
    _currentStep = 2 로 setState 하는 코드 위치 확인
  → API 콜백(async) 안에서 setState 를 mounted 체크 없이 호출하는지
```

### 2-2. 원인별 수정 패턴

#### 패턴 1 — mounted 체크 누락 (가장 흔한 원인)

```dart
// 수정 전 (크래시 원인)
onPressed: () async {
  await tripleApi.bulkConfirm(ids);
  setState(() => _currentStep = 2);  // dispose 후 호출 가능
}

// 수정 후
onPressed: () async {
  try {
    await tripleApi.bulkConfirm(ids);
    if (!mounted) return;           // ← 반드시 체크
    setState(() => _currentStep = 2);
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('저장 실패: $e'), backgroundColor: Colors.red),
    );
  }
}
```

#### 패턴 2 — Riverpod Provider 에서 dispose 후 접근

```dart
// triple_provider.dart 의 confirmAndSave() 가
// ref.read() 를 async gap 이후에 호출하면 크래시

// 수정: async gap 전에 필요한 값을 로컬 변수에 저장
Future<void> confirmAndSave() async {
  final ids = [...state.pendingTriples.map((t) => t.id)]; // 먼저 복사
  await api.bulkConfirm(ids);  // async gap
  state = state.copyWith(pendingTriples: []);  // ref 접근 없이
}
```

#### 패턴 3 — Step 3 초기 로드 시 빈 응답 처리 누락

```dart
// triple_step3_list.dart initState
@override
void initState() {
  super.initState();
  _loadTriples();
}

Future<void> _loadTriples() async {
  try {
    setState(() => _isLoading = true);
    final result = await ref.read(tripleApiProvider).searchTriples();
    if (!mounted) return;
    setState(() {
      _triples = result;
      _isLoading = false;
    });
  } catch (e) {
    if (!mounted) return;
    setState(() {
      _triples = [];      // 빈 목록으로 안전하게 처리
      _isLoading = false;
      _error = e.toString();
    });
  }
}

// build() 에서
if (_isLoading) return const Center(child: CircularProgressIndicator());
if (_error != null) return Center(child: Text('오류: $_error'));
if (_triples.isEmpty) return const Center(child: Text('저장된 트리플이 없습니다.'));
// 정상 목록 표시
```

#### 패턴 4 — bulk-confirm 엔드포인트 미존재

```bash
# 확인
curl -X POST http://localhost:9000/api/triples/bulk-confirm \
  -H "Content-Type: application/json" \
  -d '{"triple_ids": []}'
```

404 이면 백엔드에 추가:

```python
# api/router_triple.py 에 추가
@router.post("/bulk-confirm")
def bulk_confirm_triples(data: dict):
    """pending 트리플 → active 전환 + GraphDB 저장"""
    triple_ids = data.get("triple_ids", [])
    confirmed = 0
    for tid in triple_ids:
        triple = triple_manager.get(tid)
        if triple:
            triple_manager.update(tid, status="active")
            confirmed += 1
    graph_db.force_save()
    return {"confirmed": confirmed, "message": f"{confirmed}개 저장 완료"}
```

### 2-3. Bug 2 검증 순서

```
1. curl 로 bulk-confirm API 200 확인
2. flutter run -d windows 재실행
3. 텍스트 입력 탭에서 짧은 텍스트 입력 (파일 아닌 텍스트로 먼저 테스트)
4. 트리플 생성 → Step 2 이동 확인
5. [전체 확정 저장] 클릭
6. 블랙 화면 없이 Step 3 으로 이동하는지 확인
7. Step 3 에서 저장된 트리플 목록 표시 확인
8. data/triples/graph.json 파일 열어서 트리플 추가됐는지 확인
```

---

## 수정 완료 후 전체 플로우 테스트

두 버그 수정 후 아래 시나리오를 처음부터 끝까지 실행하고 결과를 보고해:

```
시나리오 1 — 텍스트 입력 플로우
  1. 트리플 탭 → Step 1
  2. Confirmed 온톨로지 선택
  3. 텍스트 입력 탭 → 구술 텍스트 입력
  4. [트리플 생성] → 진행 바 표시 → Step 2 자동 이동
  5. 트리플 카드 목록 표시 확인
  6. 카드 1개 수정
  7. 카드 1개 삭제
  8. [전체 확정 저장]
  9. Step 3 이동 확인
  10. 목록에 저장된 트리플 표시 확인

시나리오 2 — Hive DB 플로우
  1. Step 1 → Hive DB 탭
  2. [연결 확인] → 연결됨 또는 "Mock 모드" 표시
  3. 검색어 입력 → [검색] → 결과 목록 표시 (Mock 포함)
  4. 레코드 선택 → [추가]
  5. [트리플 생성] → 완료까지 대기

각 단계 결과를 ✓ / ✗ 로 표시해서 보고해줘.
```

---

## 최종 커밋

두 버그 수정 + 전체 플로우 통과 후:

```bash
git add .
git commit -m "fix: Hive 404 오류 + 확정 저장 블랙 화면 수정

- api/router_hive.py 추가 (Mock 모드 포함)
- bulk-confirm API 추가/수정
- triple_step2_review.dart mounted 체크 추가
- triple_step3_list.dart 빈 목록 안전 처리"
```
