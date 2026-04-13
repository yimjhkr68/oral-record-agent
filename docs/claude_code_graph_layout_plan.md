# 지식그래프 — 범주 관리 + 표시/숨김 + 레이아웃 저장 Plan

## 작업 목록

```
F1. 범주별 클래스 패널 — 클래스 목록 표시 + 색상/이름 수정
F2. 범주별 표시/숨김 토글
F3. 노드 위치 저장/불러오기
```

---

## 화면 구조

```
┌──────────────────────────────────────────────────────────────┐
│ 검색창                          노드N·트리플N [↓][🖨][↺][⚙]  │
├───────────────────────────────────────────────────┬──────────┤
│                                                   │ 범주 패널│
│              지식그래프 캔버스                     │ (접기▶) │
│                                                   │         │
│                                                   │ 범주 1  │
│                                                   │ 범주 2  │
│                                                   │ ...     │
├───────────────────────────────────────────────────┴──────────┤
│ ● 범례▶  |  핀치·스크롤 줌  ·  길게 누르기: 이동            │
└──────────────────────────────────────────────────────────────┘
```

우상단 ⚙ 버튼 → 범주 패널 슬라이드인/아웃

---

## F1 — 범주별 클래스 패널

### UI 구조

```
┌─────────────────────────────────────────────────┐
│ 범주 관리                              [✕ 닫기] │
├─────────────────────────────────────────────────┤
│                                                 │
│ 👁 ● 박양순 범주          노드 14개  [편집 ▼]  │
│   ├ ● OralNarrator   ████  박양순                │
│   ├ ● HistoricalEvent████  제주 4.3 사건         │
│   ├ ● Place          ████  서귀포시              │
│   └ ● ...                                       │
│                                                 │
│ 👁 ● 이판석 범주          노드 11개  [편집 ▼]  │
│   ├ ● OralNarrator   ████  이판석                │
│   └ ● ...                                       │
│                                                 │
│ 👁 ○ 미분류              노드 3개               │
│                                                 │
└─────────────────────────────────────────────────┘
```

### 클래스 편집 다이얼로그

```dart
// 클래스 행 탭 → 편집 다이얼로그
AlertDialog(
  title: Text('클래스 편집: OralNarrator'),
  content: Column(children: [

    // 색상 선택
    Row(children: [
      const Text('색상'),
      const Spacer(),
      GestureDetector(
        onTap: () => _pickColor(className),
        child: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: currentColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24),
          ),
        ),
      ),
    ]),

    const SizedBox(height: 16),

    // 표시 이름 (한국어 레이블)
    TextField(
      decoration: const InputDecoration(labelText: '한국어 레이블'),
      controller: TextEditingController(text: labelKo),
    ),

    const SizedBox(height: 16),

    // 이 클래스 노드 크기
    Row(children: [
      const Text('노드 기본 크기'),
      Expanded(
        child: Slider(
          value: baseRadius,
          min: 10, max: 30,
          divisions: 20,
          label: '${baseRadius.round()}',
          onChanged: (v) => setState(() => baseRadius = v),
        ),
      ),
    ]),
  ]),
)
```

---

## F2 — 범주별 표시/숨김

### 데이터 모델

```dart
// flutter/lib/services/graph_visibility_settings.dart

class GraphVisibilitySettings {
  static const _prefix = 'graph_visibility_';
  static final Map<String, bool> _cache = {};

  /// 범주(구술자 ID) 또는 클래스 표시 여부
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_prefix)) {
        final id = key.replaceFirst(_prefix, '');
        _cache[id] = prefs.getBool(key) ?? true;
      }
    }
  }

  static bool isVisible(String id) => _cache[id] ?? true;

  static Future<void> setVisible(String id, bool visible) async {
    _cache[id] = visible;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefix$id', visible);
  }

  static Future<void> resetAll() async {
    _cache.clear();
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith(_prefix)) await prefs.remove(key);
    }
  }
}
```

### 표시/숨김 적용

```dart
// graph_provider.dart — applyVisibility()

void applyVisibility() {
  // 숨겨진 범주의 노드 opacity = 0 (렌더링 skip)
  for (final cluster in state.clusters) {
    final clusterVisible =
        GraphVisibilitySettings.isVisible(cluster.narratorId);

    for (final nodeId in cluster.nodeIds) {
      final node = state.nodes.firstWhere((n) => n.id == nodeId,
          orElse: () => null as dynamic);
      if (node == null) continue;

      // 범주 숨김 → 노드 opacity 0
      node.hidden = !clusterVisible;
    }
  }

  // 엣지: 양쪽 노드 모두 보여야 표시
  for (final edge in state.edges) {
    final srcHidden = state.nodes
        .firstWhere((n) => n.id == edge.sourceId).hidden;
    final tgtHidden = state.nodes
        .firstWhere((n) => n.id == edge.targetId).hidden;
    edge.hidden = srcHidden || tgtHidden;
  }

  state = state.copyWith(nodes: [...state.nodes], edges: [...state.edges]);
}

// LayoutNode 에 hidden 필드 추가
class LayoutNode {
  ...
  bool hidden = false;  // true 면 렌더링 skip
  ...
}

// GraphPainter — hidden 노드/엣지 skip
void _drawNode(Canvas canvas, LayoutNode node) {
  if (node.hidden) return;  // ← 추가
  ...
}

void _drawEdge(Canvas canvas, LayoutEdge edge) {
  if (edge.hidden) return;  // ← 추가
  ...
}
```

### 범주 패널 위젯

```dart
// flutter/lib/screens/graph/cluster_panel.dart

class ClusterPanel extends ConsumerStatefulWidget { ... }

class _ClusterPanelState extends ConsumerState<ClusterPanel> {

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(graphProvider);

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          left: BorderSide(color: AppColors.border),
        ),
      ),
      child: Column(children: [

        // 헤더
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(children: [
            const Icon(Icons.layers_outlined, size: 16,
                color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('범주 관리',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const Spacer(),
            // 전체 표시/숨김
            TextButton(
              onPressed: _toggleAll,
              child: const Text('전체', style: TextStyle(fontSize: 12)),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: widget.onClose,
            ),
          ]),
        ),

        // 범주 목록
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: state.clusters.length,
            itemBuilder: (_, i) {
              final cluster = state.clusters[i];
              final visible =
                  GraphVisibilitySettings.isVisible(cluster.narratorId);

              return _ClusterTile(
                cluster: cluster,
                visible: visible,
                nodes: state.nodes,
                onVisibilityChanged: (v) async {
                  await GraphVisibilitySettings.setVisible(
                      cluster.narratorId, v);
                  ref.read(graphProvider.notifier).applyVisibility();
                },
                onClassEdit: (className) => _showClassEditDialog(className),
              );
            },
          ),
        ),
      ]),
    );
  }

  void _toggleAll() {
    // 하나라도 숨겨져 있으면 전체 표시, 모두 표시면 전체 숨김
    final state = ref.read(graphProvider);
    final anyHidden = state.clusters.any(
        (c) => !GraphVisibilitySettings.isVisible(c.narratorId));

    for (final cluster in state.clusters) {
      GraphVisibilitySettings.setVisible(cluster.narratorId, anyHidden);
    }
    ref.read(graphProvider.notifier).applyVisibility();
    setState(() {});
  }
}

// 범주 타일
class _ClusterTile extends StatefulWidget { ... }

class _ClusterTileState extends State<_ClusterTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final clusterNodes = widget.nodes
        .where((n) => widget.cluster.nodeIds.contains(n.id))
        .toList();

    // 클래스별 그룹
    final byClass = <String, List<LayoutNode>>{};
    for (final n in clusterNodes) {
      byClass.putIfAbsent(n.type, () => []).add(n);
    }

    return Column(children: [
      // 범주 헤더
      InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: widget.visible
                ? widget.cluster.color.withOpacity(0.3)
                : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: widget.visible
                    ? widget.cluster.color.withOpacity(0.5)
                    : AppColors.border),
          ),
          child: Row(children: [
            // 표시/숨김 토글
            GestureDetector(
              onTap: () => widget.onVisibilityChanged(!widget.visible),
              child: Icon(
                widget.visible ? Icons.visibility : Icons.visibility_off,
                size: 16,
                color: widget.visible
                    ? AppColors.primary : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 8),

            // 구술자명
            Expanded(
              child: Text(
                widget.cluster.narratorId,
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: widget.visible
                      ? AppColors.textPrimary : AppColors.textMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // 노드 수
            Text('${clusterNodes.length}개',
                style: const TextStyle(fontSize: 11,
                    color: AppColors.textMuted)),
            const SizedBox(width: 4),

            // 접기/펼치기
            Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                size: 16, color: AppColors.textMuted),
          ]),
        ),
      ),

      // 클래스 목록 (펼침 시)
      if (_expanded)
        Container(
          margin: const EdgeInsets.only(left: 12, top: 2, bottom: 4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: widget.cluster.color.withOpacity(0.4),
                width: 2,
              ),
            ),
          ),
          child: Column(
            children: byClass.entries.map((entry) =>
              _ClassRow(
                className: entry.key,
                nodeCount: entry.value.length,
                color: GraphColorSettings.colorFor(entry.key),
                onEdit: () => widget.onClassEdit(entry.key),
              )
            ).toList(),
          ),
        ),

      const SizedBox(height: 4),
    ]);
  }
}

// 클래스 행
class _ClassRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
        child: Row(children: [
          // 색상 점
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
              color: color, shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          // 클래스명
          Expanded(
            child: Text(className,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ),
          // 노드 수
          Text('$nodeCount',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textMuted,
                  fontFamily: 'monospace')),
          const SizedBox(width: 4),
          // 편집 아이콘
          const Icon(Icons.edit_outlined, size: 13,
              color: AppColors.textMuted),
        ]),
      ),
    );
  }
}
```

---

## F3 — 노드 위치 저장/불러오기

### 저장 데이터 구조

```json
// data/graph_layouts/{layout_name}.json
{
  "name": "2026-04-12 오전 작업",
  "ontology_version": "v1_ontology",
  "saved_at": "2026-04-12T10:30:00",
  "nodes": [
    {"id": "박양순", "x": 450.2, "y": 320.5, "pinned": true},
    {"id": "이판석", "x": 820.1, "y": 480.3, "pinned": true},
    ...
  ]
}
```

### 백엔드 API

```python
# api/router_graph_layout.py 신규

@router.get("/layouts")
def list_layouts():
    """저장된 레이아웃 목록"""
    files = Path("data/graph_layouts").glob("*.json")
    layouts = []
    for f in sorted(files, key=lambda x: x.stat().st_mtime, reverse=True):
        data = json.loads(f.read_text(encoding="utf-8"))
        layouts.append({
            "name":         data["name"],
            "filename":     f.stem,
            "saved_at":     data["saved_at"],
            "node_count":   len(data["nodes"]),
            "ontology_version": data.get("ontology_version", ""),
        })
    return {"layouts": layouts}

@router.post("/layouts")
def save_layout(data: dict):
    """레이아웃 저장"""
    name = data.get("name", "").strip()
    if not name:
        raise HTTPException(400, "레이아웃 이름 필요")

    Path("data/graph_layouts").mkdir(parents=True, exist_ok=True)

    import re, time
    filename = re.sub(r'[^\w가-힣\-]', '_', name)
    filepath = Path(f"data/graph_layouts/{filename}.json")

    payload = {
        "name":             name,
        "ontology_version": data.get("ontology_version", ""),
        "saved_at":         datetime.now().isoformat(),
        "nodes":            data.get("nodes", []),
    }
    filepath.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2),
        encoding="utf-8")

    return {"saved": filename, "name": name}

@router.get("/layouts/{filename}")
def load_layout(filename: str):
    """레이아웃 불러오기"""
    filepath = Path(f"data/graph_layouts/{filename}.json")
    if not filepath.exists():
        raise HTTPException(404, "레이아웃 없음")
    return json.loads(filepath.read_text(encoding="utf-8"))

@router.delete("/layouts/{filename}")
def delete_layout(filename: str):
    filepath = Path(f"data/graph_layouts/{filename}.json")
    if filepath.exists():
        filepath.unlink()
    return {"deleted": filename}
```

### Flutter 저장/불러오기 UI

```dart
// knowledge_graph_screen.dart 상단 버튼 영역에 추가

// 레이아웃 저장 버튼
PopupMenuButton<String>(
  icon: const Icon(Icons.save_outlined),
  tooltip: '레이아웃 저장/불러오기',
  onSelected: (value) {
    if (value == 'save')  _showSaveDialog();
    if (value == 'load')  _showLoadDialog();
  },
  itemBuilder: (_) => [
    const PopupMenuItem(value: 'save',
        child: Row(children: [
          Icon(Icons.save_outlined, size: 18),
          SizedBox(width: 8),
          Text('현재 레이아웃 저장'),
        ])),
    const PopupMenuItem(value: 'load',
        child: Row(children: [
          Icon(Icons.folder_open_outlined, size: 18),
          SizedBox(width: 8),
          Text('저장된 레이아웃 불러오기'),
        ])),
  ],
),

// 저장 다이얼로그
void _showSaveDialog() {
  final ctrl = TextEditingController(
      text: '레이아웃_${DateTime.now().toString().substring(0, 16)}');

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('레이아웃 저장'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: '레이아웃 이름',
            hintText: '예: 2026-04-12 작업본',
          ),
          autofocus: true,
        ),
      ]),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.of(ctx).pop();
            await _saveLayout(ctrl.text.trim());
          },
          child: const Text('저장'),
        ),
      ],
    ),
  );
}

Future<void> _saveLayout(String name) async {
  if (name.isEmpty) return;
  final state = ref.read(graphProvider);

  // 노드 위치 목록
  final nodes = state.nodes.map((n) => {
    'id':     n.id,
    'x':      n.x,
    'y':      n.y,
    'pinned': n.pinned,
  }).toList();

  await ref.read(apiClientProvider).post('/api/graph/layouts', data: {
    'name': name,
    'ontology_version': state.selectedOntologyVersion,
    'nodes': nodes,
  });

  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('레이아웃 저장됨: $name')),
  );
}

// 불러오기 다이얼로그
void _showLoadDialog() async {
  final res = await ref.read(apiClientProvider).get('/api/graph/layouts');
  final layouts = (res.data['layouts'] as List? ?? []);

  if (!mounted) return;
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('레이아웃 불러오기'),
      content: SizedBox(
        width: 380,
        child: layouts.isEmpty
            ? const Text('저장된 레이아웃이 없습니다.')
            : ListView.separated(
                shrinkWrap: true,
                itemCount: layouts.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final layout = layouts[i];
                  return ListTile(
                    title: Text(layout['name']),
                    subtitle: Text(
                      '${layout['saved_at'].substring(0, 16)}  ·  '
                      '노드 ${layout['node_count']}개',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      // 불러오기
                      IconButton(
                        icon: const Icon(Icons.folder_open, size: 18),
                        tooltip: '불러오기',
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          await _loadLayout(layout['filename']);
                        },
                      ),
                      // 삭제
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 18, color: Colors.red),
                        tooltip: '삭제',
                        onPressed: () async {
                          await ref.read(apiClientProvider)
                              .delete('/api/graph/layouts/${layout["filename"]}');
                          Navigator.of(ctx).pop();
                          _showLoadDialog();
                        },
                      ),
                    ]),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('닫기'),
        ),
      ],
    ),
  );
}

Future<void> _loadLayout(String filename) async {
  final res = await ref.read(apiClientProvider)
      .get('/api/graph/layouts/$filename');
  final layoutNodes = res.data['nodes'] as List;

  // 저장된 위치를 현재 노드에 적용
  ref.read(graphProvider.notifier).applyLayout(layoutNodes);

  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('레이아웃 불러옴: ${res.data["name"]}')),
  );
}

// GraphNotifier.applyLayout()
void applyLayout(List layoutNodes) {
  final posMap = {
    for (final n in layoutNodes)
      n['id'] as String: (n['x'] as double, n['y'] as double)
  };

  for (final node in state.nodes) {
    if (posMap.containsKey(node.id)) {
      final (x, y) = posMap[node.id]!;
      node.x = x;
      node.y = y;
      node.pinned = true;
      node.vx = 0;
      node.vy = 0;
    }
  }
  state = state.copyWith(nodes: [...state.nodes]);
}
```

---

## 구현 순서

```
Phase 1 — F3 레이아웃 저장 (백엔드)
  1-1. api/router_graph_layout.py 신규
  1-2. data/graph_layouts/ 디렉토리 생성
  1-3. main.py 라우터 등록
  1-4. curl 테스트 (POST/GET/DELETE)

Phase 2 — F3 레이아웃 저장 (Flutter)
  2-1. GraphNotifier.applyLayout() 추가
  2-2. 저장/불러오기 팝업 메뉴 + 다이얼로그
  2-3. 저장 → 불러오기 플로우 테스트

Phase 3 — F2 범주 표시/숨김
  3-1. graph_visibility_settings.dart 신규
  3-2. LayoutNode.hidden 필드 추가
  3-3. GraphNotifier.applyVisibility()
  3-4. GraphPainter hidden 노드/엣지 skip

Phase 4 — F1 범주 패널 UI
  4-1. cluster_panel.dart 신규
  4-2. knowledge_graph_screen.dart 우측 패널 슬라이드인
  4-3. ⚙ 버튼 → 패널 토글
  4-4. 클래스 편집 다이얼로그 (색상 + 크기)
```

---

## 완료 기준

```
Phase 1~2:
  □ 노드 이동 후 [저장] → 이름 입력 → 저장됨 스낵바
  □ data/graph_layouts/{name}.json 파일 생성 확인
  □ [불러오기] → 목록 표시 → 선택 → 노드 위치 복원

Phase 3:
  □ 범주 👁 클릭 → 해당 범주 노드/엣지 즉시 숨김
  □ 다시 클릭 → 복원
  □ 앱 재시작 후에도 표시 설정 유지

Phase 4:
  □ ⚙ 버튼 → 범주 패널 슬라이드인
  □ 범주별 클래스 목록 표시
  □ 클래스 행 클릭 → 색상/크기 편집 다이얼로그
  □ 저장 → 그래프 즉시 반영
```
