# 트리플 관리 전면 재진단 + UI 개선 Plan

## 현재 증상

```
1. 저장된 트리플이 "저장된 트리플이 없습니다" 로 표시
   → 실제로는 113개 트리플이 있음 (그래프에서 확인)
   → 검색 테스트 중 사라진 것 → 상태 버그

2. 키워드 검색이 잘 안 됨
   → 입력 즉시 적용 방식 → 중간 입력 중 오동작

3. 패싯 버튼(클래스 필터) 클릭 시 필터링 미동작

4. UI 개선 요구:
   → 검색창 + [검색] 버튼 분리
   → 패싯 클릭 → 해당 클래스 트리플 즉시 표시
```

---

## Step 1 — 데이터 상태 진단

```bash
# 1. 실제 저장된 트리플 수 확인
curl http://localhost:9000/api/triples/?status=active
# → total 과 items 배열 확인

# 2. 전체 트리플 (아카이브 포함)
curl "http://localhost:9000/api/triples/?include_archived=true"

# 3. graph.json 직접 확인
python -c "
import json
with open('data/triples/graph.json', encoding='utf-8') as f:
    d = json.load(f)
print('노드:', len(d.get('nodes',{})))
print('트리플:', len(d.get('triples',[])))
active = [t for t in d.get('triples',[]) if t.get('status')=='active']
print('active:', len(active))
"
```

---

## Step 2 — 트리플 사라진 원인 파악

```
flutter/lib/screens/triple/triple_step3_list.dart 전체 내용 보여줘.

특히:
  1. _loadTriples() 메서드 — API 호출 방식
  2. _searchTriples() 메서드 — 검색 시 상태 업데이트 방식
  3. _triples 상태 변수 초기화 시점
  4. 필터(패싯) 클릭 시 _triples 가 어떻게 변하는지

그리고:
flutter/lib/providers/triple_provider.dart 전체 내용 보여줘.
```

---

## Step 3 — API 엔드포인트 정확성 확인

```bash
# 검색어 없이 전체 조회
curl "http://localhost:9000/api/triples/"

# 클래스 필터
curl "http://localhost:9000/api/triples/?subject_type=Narrator"

# 키워드 검색
curl "http://localhost:9000/api/triples/?q=오복순"

# 각 응답의 total + items 수 보고
```

---

## Step 4 — 수정 사항

### 4-1. 트리플 목록 초기 로드 수정

```dart
// triple_step3_list.dart

class _TripleStep3ListState extends State<TripleStep3List> {
  List<dynamic> _triples = [];
  bool _isLoading = false;
  String _error = '';

  // 현재 필터 상태
  String _searchInput = '';      // 입력창 텍스트 (즉시 반영 안 함)
  String _appliedSearch = '';    // 실제 적용된 검색어 ([검색] 버튼 후)
  String _classFilter = '';      // 패싯 필터

  @override
  void initState() {
    super.initState();
    // build 완료 후 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadTriples();
    });
  }

  Future<void> _loadTriples({String search = '', String classFilter = ''}) async {
    if (!mounted) return;
    setState(() { _isLoading = true; _error = ''; });

    try {
      final params = <String, String>{};
      if (search.isNotEmpty) params['q'] = search;
      if (classFilter.isNotEmpty) params['subject_type'] = classFilter;

      final response = await ref.read(apiClientProvider)
          .get('/api/triples/', params: params);

      if (!mounted) return;

      final items = response.data['items'] as List? ?? [];
      setState(() {
        _triples   = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _triples   = [];
        _isLoading = false;
        _error     = '로드 실패: $e';
      });
    }
  }

  // [검색] 버튼 클릭 시만 호출
  void _applySearch() {
    setState(() => _appliedSearch = _searchInput);
    _loadTriples(search: _searchInput, classFilter: _classFilter);
  }

  // 패싯 클릭 시 즉시 필터링
  void _applyClassFilter(String className) {
    setState(() {
      _classFilter = _classFilter == className ? '' : className;
    });
    _loadTriples(search: _appliedSearch, classFilter: _classFilter);
  }

  // 검색 초기화
  void _clearSearch() {
    setState(() {
      _searchInput   = '';
      _appliedSearch = '';
      _classFilter   = '';
    });
    _loadTriples();
  }
```

### 4-2. UI 레이아웃 수정

```dart
@override
Widget build(BuildContext context) {
  return Column(children: [

    // ── 검색창 + [검색] 버튼 ───────────────────────
    Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Row(children: [
        Expanded(
          child: TextField(
            decoration: const InputDecoration(
              hintText: '주어 / 술어 / 목적어 검색',
              prefixIcon: Icon(Icons.search, size: 18),
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: (v) => setState(() => _searchInput = v),
            onSubmitted: (_) => _applySearch(),  // Enter 키도 검색
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _applySearch,
          child: const Text('검색'),
        ),
        if (_appliedSearch.isNotEmpty || _classFilter.isNotEmpty) ...[
          const SizedBox(width: 4),
          TextButton(
            onPressed: _clearSearch,
            child: const Text('초기화'),
          ),
        ],
      ]),
    ),

    // ── 패싯 버튼 (클래스 필터) ────────────────────
    SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _classFacets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final facet = _classFacets[i];
          final isSelected = _classFilter == facet['class'];
          return FilterChip(
            label: Text('${facet["class"]} ${facet["count"]}',
                style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? Colors.white : null)),
            selected: isSelected,
            onSelected: (_) => _applyClassFilter(facet['class']),
            backgroundColor: isSelected
                ? _colorForClass(facet['class'])
                : null,
            selectedColor: _colorForClass(facet['class']),
            avatar: CircleAvatar(
              radius: 5,
              backgroundColor: _colorForClass(facet['class']),
            ),
          );
        },
      ),
    ),

    // ── 현재 필터 상태 표시 ───────────────────────
    if (_appliedSearch.isNotEmpty || _classFilter.isNotEmpty)
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(children: [
          Text('${_triples.length}개 결과',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          if (_classFilter.isNotEmpty) ...[
            const SizedBox(width: 8),
            Chip(
              label: Text(_classFilter,
                  style: const TextStyle(fontSize: 11)),
              onDeleted: () => _applyClassFilter(_classFilter),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ]),
      ),

    // ── [전체 내보내기] 버튼 ──────────────────────
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.download_outlined, size: 16),
          label: Text(_appliedSearch.isEmpty && _classFilter.isEmpty
              ? '전체 내보내기 (${_triples.length})'
              : '필터 결과 내보내기 (${_triples.length})'),
          onPressed: _exportTriples,
        ),
      ]),
    ),

    const Divider(height: 1),

    // ── 활성/아카이브 탭 ──────────────────────────
    DefaultTabController(
      length: 2,
      child: Column(children: [
        const TabBar(tabs: [Tab(text: '활성'), Tab(text: '아카이브')]),
        SizedBox(
          height: MediaQuery.of(context).size.height - 280,
          child: TabBarView(children: [
            _buildTripleList(
                _triples.where((t) => t['status'] == 'active').toList()),
            _buildTripleList(
                _triples.where((t) => t['status'] == 'archived').toList()),
          ]),
        ),
      ]),
    ),
  ]);
}
```

### 4-3. 패싯 카운트 API 추가

```python
# api/router_triple.py 에 추가

@router.get("/facets")
def get_facets():
    """클래스별 트리플 수 반환 (패싯 버튼용)"""
    all_triples = graph_db.all_triples(include_archived=False)

    from collections import Counter
    subject_counts = Counter(t.subject_type for t in all_triples)
    object_counts  = Counter(t.object_type  for t in all_triples)

    # 합산 (주어 또는 목적어로 등장하는 클래스)
    all_classes = set(subject_counts) | set(object_counts)
    facets = [
        {
            "class": cls,
            "count": subject_counts.get(cls, 0) + object_counts.get(cls, 0)
        }
        for cls in sorted(all_classes,
                          key=lambda c: -(subject_counts.get(c, 0)
                                          + object_counts.get(c, 0)))
    ]
    return {"facets": facets}
```

```dart
// Flutter 에서 패싯 로드
Future<void> _loadFacets() async {
  try {
    final res = await ref.read(apiClientProvider).get('/api/triples/facets');
    if (!mounted) return;
    setState(() {
      _classFacets = List<Map<String, dynamic>>.from(
          res.data['facets'] ?? []);
    });
  } catch (_) {}
}

@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    _loadFacets();
    _loadTriples();
  });
}
```

### 4-4. API 검색 파라미터 수정

```python
# api/router_triple.py GET /api/triples/

@router.get("/")
def list_triples(
    q:            str = "",
    subject_type: str = "",
    status:       str = "active",
    limit:        int = 500,
):
    """트리플 목록. q=키워드, subject_type=클래스 필터"""
    all_triples = graph_db.all_triples(
        include_archived=(status == "archived" or status == "all")
    )

    result = all_triples

    # 상태 필터
    if status == "active":
        result = [t for t in result if t.status.value == "active"]
    elif status == "archived":
        result = [t for t in result if t.status.value == "archived"]

    # 키워드 필터 (주어, 술어, 목적어 모두 검색)
    if q:
        q_lower = q.lower()
        result = [
            t for t in result
            if q_lower in t.subject.lower()
            or q_lower in t.predicate.lower()
            or q_lower in t.object.lower()
        ]

    # 클래스 필터 (주어 타입)
    if subject_type:
        result = [t for t in result if t.subject_type == subject_type]

    from dataclasses import asdict
    return {
        "total": len(result),
        "items": [asdict(t) for t in result[:limit]],
    }
```

---

## Step 5 — 전체 검증 시나리오

```
수정 완료 후 아래를 순서대로 테스트:

1. Step 3 진입 시 트리플 목록 즉시 표시
   □ "저장된 트리플이 없습니다" → 실제 목록 표시
   □ 활성 탭: N개, 아카이브 탭: N개

2. 패싯 버튼
   □ "Narrator 28" 클릭 → Narrator 관련 트리플만 표시
   □ 다시 클릭 → 전체 복원
   □ "Place 23" 클릭 → Place 관련 트리플만 표시

3. 키워드 검색
   □ "오복순" 입력 → 버튼 클릭 전 목록 변화 없음
   □ [검색] 클릭 → 오복순 관련 트리플만 표시
   □ Enter 키 → 동일하게 검색
   □ [초기화] 클릭 → 전체 목록 복원

4. 패싯 + 검색 조합
   □ "Narrator" 패싯 선택 + "오복순" 검색
   → Narrator 타입 중 오복순 관련만 표시

5. 내보내기
   □ [전체 내보내기] → JSON 파일 저장
   □ 필터 적용 후 [필터 결과 내보내기] → 필터된 것만 저장
```

---

## 제약

```
- Step 1~3 결과를 보고 후 수정 시작
- 트리플이 실제로 DB에 있는지 먼저 확인
  (없으면 데이터 문제 → 트리플 재생성 필요)
- API 수정 후 curl 테스트 완료 후 Flutter 수정
- 기존 101개 테스트 통과 유지
```
