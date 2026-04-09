# 지식그래프 화면 완성 Plan

## 현재 상태

```
flutter/lib/screens/graph/knowledge_graph_screen.dart
  → 뼈대만 존재 ("지식그래프 준비 중" 텍스트만 표시)
  → 실제 그래프 시각화 미구현
```

---

## 목표 화면

```
┌─────────────────────────────────────────────────────────────┐
│  [검색창____________] ✕    노드 47 · 트리플 83 · v2.0  [↺]  │
│ ┌───────────────────────────────────────────────────────┐   │
│ │                                                       │   │
│ │    ○김영수 ──출생지──▶ ○경북안동                     │   │
│ │       │                    │                          │   │
│ │     참여함              발생장소                      │   │
│ │       ▼                    ▼                          │   │
│ │    ○6·25전쟁 ◀──발생시기── ○1950년                  │   │
│ │                                                       │   │
│ │         (전체 화면 인터랙티브 그래프)                 │   │
│ │                                                       │   │
│ └───────────────────────────────────────────────────────┘   │
│  ● 인물  ● 장소  ● 사건  ● 시간  ● 기관  ● 주제  …(범례)   │
└─────────────────────────────────────────────────────────────┘

검색 시:
  매칭 노드:    크기 1.5배 + 노란 테두리
  1홉 이웃:     투명도 70%
  나머지:       투명도 20%

노드 클릭:
  상세 BottomSheet → 연결 트리플 목록
```

---

## 기술 선택 — CustomPainter + InteractiveViewer

Flutter에서 그래프를 그리는 방법은 두 가지입니다.

```
선택지 A: graphview 패키지
  장점: 구현 빠름
  단점: 커스터마이징 한계, 대용량 노드 성능 저하, 포스 시뮬레이션 없음

선택지 B: CustomPainter + InteractiveViewer (선택)
  장점: 완전한 커스터마이징, 포스 레이아웃 직접 구현, 성능 제어 가능
  단점: 코드량 많음
  → 100건 이하 소규모 + 검색 강조 효과 필요 → B 선택
```

---

## 파일 구조

```
flutter/lib/
├── screens/graph/
│   ├── knowledge_graph_screen.dart     ← 메인 화면 (교체)
│   ├── graph_search_bar.dart           ← 검색창 오버레이 위젯
│   ├── graph_legend.dart               ← 하단 범례 위젯
│   └── node_detail_sheet.dart          ← 노드 클릭 시 BottomSheet
│
├── widgets/graph/
│   ├── graph_painter.dart              ← CustomPainter (핵심)
│   ├── force_layout.dart               ← 포스 레이아웃 알고리즘
│   └── graph_node_model.dart           ← 레이아웃용 노드 모델
│
└── providers/
    └── graph_provider.dart             ← 그래프 상태 관리
```

---

## 데이터 모델 (graph_node_model.dart)

```dart
/// 레이아웃 계산용 노드 — GraphNode + 위치 정보
class LayoutNode {
  final String id;
  final String type;
  final int degree;

  // 포스 시뮬레이션 위치
  double x;
  double y;
  double vx;  // 속도 x
  double vy;  // 속도 y
  bool pinned; // 드래그로 고정된 상태

  // 렌더링 상태
  double radius;       // degree 에 비례: 14 + min(degree * 2, 12)
  double opacity;      // 검색 필터: 1.0 / 0.7 / 0.2
  bool highlighted;    // 검색 매칭: 노란 테두리
  bool selected;       // 클릭 선택

  LayoutNode({
    required this.id,
    required this.type,
    required this.degree,
    this.x = 0, this.y = 0,
    this.vx = 0, this.vy = 0,
    this.pinned = false,
    this.radius = 16,
    this.opacity = 1.0,
    this.highlighted = false,
    this.selected = false,
  });
}

/// 렌더링용 엣지
class LayoutEdge {
  final String sourceId;
  final String targetId;
  final String predicate;
  double opacity;  // 검색 필터

  LayoutEdge({
    required this.sourceId,
    required this.targetId,
    required this.predicate,
    this.opacity = 1.0,
  });
}
```

---

## 포스 레이아웃 (force_layout.dart)

```dart
/// Spring-Embedder 알고리즘 (간소화 버전)
/// 100노드 이하에서 충분한 성능
class ForceLayout {
  final List<LayoutNode> nodes;
  final List<LayoutEdge> edges;
  final Size canvasSize;

  // 파라미터
  static const double REPULSION   = 3000.0;  // 노드 간 반발력
  static const double ATTRACTION  = 0.08;    // 엣지 인력
  static const double IDEAL_LENGTH = 120.0;  // 엣지 이상 길이
  static const double DAMPING     = 0.85;    // 속도 감쇠
  static const double CENTER_PULL = 0.002;   // 중심 인력

  ForceLayout({
    required this.nodes,
    required this.edges,
    required this.canvasSize,
  });

  /// 초기 위치 — 원형 배치 (랜덤보다 수렴 빠름)
  void initPositions() {
    final cx = canvasSize.width / 2;
    final cy = canvasSize.height / 2;
    final r = min(cx, cy) * 0.6;
    for (int i = 0; i < nodes.length; i++) {
      final angle = 2 * pi * i / nodes.length;
      nodes[i].x = cx + r * cos(angle);
      nodes[i].y = cy + r * sin(angle);
    }
  }

  /// 1 틱 시뮬레이션. 수렴 여부 반환.
  bool tick() {
    // 1. 반발력 (모든 노드 쌍)
    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        _applyRepulsion(nodes[i], nodes[j]);
      }
    }
    // 2. 엣지 인력
    for (final edge in edges) {
      final s = _nodeById(edge.sourceId);
      final t = _nodeById(edge.targetId);
      if (s != null && t != null) _applyAttraction(s, t);
    }
    // 3. 중심 인력
    final cx = canvasSize.width / 2;
    final cy = canvasSize.height / 2;
    for (final n in nodes) {
      if (n.pinned) continue;
      n.vx += (cx - n.x) * CENTER_PULL;
      n.vy += (cy - n.y) * CENTER_PULL;
    }
    // 4. 위치 업데이트
    double maxV = 0;
    for (final n in nodes) {
      if (n.pinned) continue;
      n.vx *= DAMPING;
      n.vy *= DAMPING;
      n.x += n.vx;
      n.y += n.vy;
      maxV = max(maxV, n.vx.abs() + n.vy.abs());
    }
    return maxV < 0.5; // 수렴 시 true
  }

  void _applyRepulsion(LayoutNode a, LayoutNode b) { ... }
  void _applyAttraction(LayoutNode s, LayoutNode t) { ... }
  LayoutNode? _nodeById(String id) =>
      nodes.cast<LayoutNode?>().firstWhere((n) => n?.id == id, orElse: () => null);
}
```

---

## GraphPainter (graph_painter.dart)

```dart
class GraphPainter extends CustomPainter {
  final List<LayoutNode> nodes;
  final List<LayoutEdge> edges;
  final Map<String, Color> classColors;
  final String? selectedNodeId;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 엣지 그리기 (노드 뒤에)
    for (final edge in edges) {
      _drawEdge(canvas, edge);
    }
    // 2. 노드 그리기
    for (final node in nodes) {
      _drawNode(canvas, node);
    }
  }

  void _drawEdge(Canvas canvas, LayoutEdge edge) {
    final s = _nodeById(edge.source);
    final t = _nodeById(edge.target);
    if (s == null || t == null) return;

    final paint = Paint()
      ..color = Colors.grey.withOpacity(edge.opacity * 0.6)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // 엣지 선
    canvas.drawLine(Offset(s.x, s.y), Offset(t.x, t.y), paint);

    // 화살표 머리
    _drawArrowHead(canvas, s, t, paint);

    // 술어 레이블 (엣지 중간)
    if (edge.opacity > 0.5) {
      _drawEdgeLabel(canvas, s, t, edge.predicate, edge.opacity);
    }
  }

  void _drawNode(Canvas canvas, LayoutNode node) {
    final color = classColors[node.type] ?? Colors.grey;
    final opacity = node.opacity;

    // 강조 테두리 (검색 매칭)
    if (node.highlighted) {
      final glowPaint = Paint()
        ..color = Colors.amber.withOpacity(opacity)
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(Offset(node.x, node.y), node.radius + 3, glowPaint);
    }

    // 선택 테두리
    if (node.selected) {
      final selectPaint = Paint()
        ..color = Colors.white.withOpacity(opacity)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(Offset(node.x, node.y), node.radius + 2, selectPaint);
    }

    // 노드 원
    final fillPaint = Paint()
      ..color = color.withOpacity(opacity * 0.9)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(node.x, node.y), node.radius, fillPaint);

    // 노드 레이블 (ID 앞 5자)
    _drawNodeLabel(canvas, node, opacity);
  }

  @override
  bool shouldRepaint(GraphPainter old) =>
      old.nodes != nodes || old.edges != edges || old.selectedNodeId != selectedNodeId;
}
```

---

## GraphProvider (graph_provider.dart)

```dart
class GraphState {
  final List<LayoutNode> nodes;
  final List<LayoutEdge> edges;
  final String searchQuery;
  final String? selectedNodeId;
  final bool isLoading;
  final String? error;
  final Map<String, dynamic> stats;  // {nodes: N, triples: N}
  final bool isSimulating;

  const GraphState({...});
  GraphState copyWith({...}) { ... }
}

class GraphNotifier extends StateNotifier<GraphState> {

  /// 전체 그래프 로드
  Future<void> loadGraph() async {
    state = state.copyWith(isLoading: true);
    final data = await graphApi.getFullGraph();
    // GraphData → LayoutNode + LayoutEdge 변환
    final nodes = data.nodes.map((n) => LayoutNode(
      id: n.id, type: n.type, degree: n.degree,
      radius: 14 + min(n.degree * 2.0, 12),
    )).toList();
    final edges = data.triples.map((t) => LayoutEdge(
      sourceId: t.subject, targetId: t.object, predicate: t.predicate,
    )).toList();

    // 포스 레이아웃 초기화
    _layout = ForceLayout(nodes: nodes, edges: edges, canvasSize: _canvasSize);
    _layout.initPositions();

    state = state.copyWith(nodes: nodes, edges: edges, isLoading: false,
      stats: {'nodes': nodes.length, 'triples': edges.length});

    _startSimulation();
  }

  /// 포스 시뮬레이션 — 60fps, 수렴 시 정지
  void _startSimulation() {
    _simTimer?.cancel();
    state = state.copyWith(isSimulating: true);
    _simTimer = Timer.periodic(const Duration(milliseconds: 16), (t) {
      final converged = _layout.tick();
      state = state.copyWith(nodes: [..._layout.nodes]);
      if (converged) {
        t.cancel();
        state = state.copyWith(isSimulating: false);
      }
    });
  }

  /// 검색 — 매칭/이웃/나머지 투명도 설정
  void search(String query) {
    if (query.isEmpty) {
      // 전체 복원
      for (final n in state.nodes) {
        n.opacity = 1.0;
        n.highlighted = false;
      }
      for (final e in state.edges) { e.opacity = 1.0; }
      state = state.copyWith(searchQuery: '', nodes: [...state.nodes]);
      return;
    }

    final q = query.toLowerCase();
    final matched = state.nodes
        .where((n) => n.id.toLowerCase().contains(q))
        .map((n) => n.id)
        .toSet();

    // 1홉 이웃 수집
    final neighbors = <String>{};
    for (final e in state.edges) {
      if (matched.contains(e.sourceId)) neighbors.add(e.targetId);
      if (matched.contains(e.targetId)) neighbors.add(e.sourceId);
    }

    // 투명도 적용
    for (final n in state.nodes) {
      if (matched.contains(n.id)) {
        n.opacity = 1.0;
        n.highlighted = true;
        n.radius = (14 + min(n.degree * 2.0, 12)) * 1.5; // 1.5배
      } else if (neighbors.contains(n.id)) {
        n.opacity = 0.7;
        n.highlighted = false;
        n.radius = 14 + min(n.degree * 2.0, 12); // 원래 크기
      } else {
        n.opacity = 0.2;
        n.highlighted = false;
        n.radius = 14 + min(n.degree * 2.0, 12);
      }
    }
    for (final e in state.edges) {
      e.opacity = (matched.contains(e.sourceId) || matched.contains(e.targetId))
          ? 0.8 : 0.1;
    }

    state = state.copyWith(searchQuery: query, nodes: [...state.nodes]);
  }

  /// 노드 드래그
  void onNodeDrag(String nodeId, Offset delta) {
    final node = state.nodes.firstWhere((n) => n.id == nodeId);
    node.x += delta.dx;
    node.y += delta.dy;
    node.pinned = true;
    node.vx = 0;
    node.vy = 0;
    state = state.copyWith(nodes: [...state.nodes]);
  }

  /// 노드 선택
  void selectNode(String? nodeId) {
    for (final n in state.nodes) { n.selected = n.id == nodeId; }
    state = state.copyWith(selectedNodeId: nodeId, nodes: [...state.nodes]);
  }
}
```

---

## KnowledgeGraphScreen (knowledge_graph_screen.dart)

```dart
class KnowledgeGraphScreen extends ConsumerStatefulWidget { ... }

class _KnowledgeGraphScreenState
    extends ConsumerState<KnowledgeGraphScreen> {

  final TransformationController _transformCtrl = TransformationController();
  Offset? _dragStart;
  String? _draggingNodeId;

  @override
  void initState() {
    super.initState();
    // 화면 진입 시 그래프 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(graphProvider.notifier).loadGraph();
    });
  }

  @override
  Widget build(BuildContext context) {
    final graphState = ref.watch(graphProvider);

    return Scaffold(
      body: Stack(
        children: [

          // ── 1. 그래프 캔버스 (전체 화면) ─────────────────
          InteractiveViewer(
            transformationController: _transformCtrl,
            minScale: 0.1,
            maxScale: 5.0,
            boundaryMargin: const EdgeInsets.all(double.infinity),
            child: GestureDetector(
              onTapUp: (d) => _onTapCanvas(d, graphState),
              onPanStart: (d) => _onPanStart(d, graphState),
              onPanUpdate: (d) => _onPanUpdate(d),
              onPanEnd: (_) => _draggingNodeId = null,
              child: graphState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : graphState.nodes.isEmpty
                      ? _emptyView()
                      : CustomPaint(
                          size: const Size(3000, 3000), // 대형 캔버스
                          painter: GraphPainter(
                            nodes: graphState.nodes,
                            edges: graphState.edges,
                            classColors: _classColors,
                            selectedNodeId: graphState.selectedNodeId,
                          ),
                        ),
            ),
          ),

          // ── 2. 상단 오버레이 (검색 + 통계) ───────────────
          Positioned(
            top: 12, left: 12, right: 12,
            child: GraphSearchBar(
              onSearch: (q) => ref.read(graphProvider.notifier).search(q),
              stats: graphState.stats,
              isSimulating: graphState.isSimulating,
            ),
          ),

          // ── 3. 하단 범례 ──────────────────────────────────
          Positioned(
            bottom: 12, left: 12, right: 12,
            child: GraphLegend(classColors: _classColors),
          ),

          // ── 4. 새로고침 버튼 ─────────────────────────────
          Positioned(
            top: 12, right: 12,
            child: FloatingActionButton.small(
              onPressed: () => ref.read(graphProvider.notifier).loadGraph(),
              child: const Icon(Icons.refresh),
            ),
          ),

          // ── 5. 로딩 오버레이 ─────────────────────────────
          if (graphState.isLoading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x88000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  /// 캔버스 탭 → 노드 클릭 감지
  void _onTapCanvas(TapUpDetails d, GraphState state) {
    final pos = _toCanvasCoords(d.localPosition);
    for (final node in state.nodes) {
      final dist = (Offset(node.x, node.y) - pos).distance;
      if (dist <= node.radius + 4) {
        ref.read(graphProvider.notifier).selectNode(node.id);
        _showNodeDetail(node.id, state);
        return;
      }
    }
    ref.read(graphProvider.notifier).selectNode(null);
  }

  /// 노드 드래그
  void _onPanStart(DragStartDetails d, GraphState state) {
    final pos = _toCanvasCoords(d.localPosition);
    for (final node in state.nodes) {
      if ((Offset(node.x, node.y) - pos).distance <= node.radius + 4) {
        _draggingNodeId = node.id;
        _dragStart = pos;
        return;
      }
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_draggingNodeId == null) return;
    ref.read(graphProvider.notifier)
        .onNodeDrag(_draggingNodeId!, d.delta);
  }

  /// 노드 상세 BottomSheet
  void _showNodeDetail(String nodeId, GraphState state) {
    showModalBottomSheet(
      context: context,
      builder: (_) => NodeDetailSheet(
        nodeId: nodeId,
        nodes: state.nodes,
        edges: state.edges,
      ),
    );
  }

  Offset _toCanvasCoords(Offset local) {
    final inv = Matrix4.inverted(_transformCtrl.value);
    final v = inv.transform3(Vector3(local.dx, local.dy, 0));
    return Offset(v.x, v.y);
  }
}
```

---

## NodeDetailSheet (node_detail_sheet.dart)

```dart
// 노드 클릭 시 하단에서 올라오는 시트
// 내용:
//   - 노드 ID + 클래스 타입 배지
//   - 연결 트리플 목록
//     발신(outgoing): 이 노드 → 술어 → 목적어
//     수신(incoming): 주어 → 술어 → 이 노드
//   - [이 노드로 검색] 버튼 → GraphNotifier.search(nodeId)
```

---

## GraphSearchBar (graph_search_bar.dart)

```dart
// 반투명 카드 위에 배치
// 내용:
//   - 검색 TextField (debounce 300ms)
//   - ✕ 버튼 → 검색 초기화
//   - 우측: "노드 N · 트리플 N" 텍스트
//   - 시뮬레이션 중: "레이아웃 계산 중..." 표시
```

---

## GraphLegend (graph_legend.dart)

```dart
// 하단 반투명 카드
// 클래스별 색상 점 + 한국어 레이블
// 가로 스크롤 (클래스 12개)
const Map<String, Color> classColors = {
  'Person':           Color(0xFFf59e0b),
  'Place':            Color(0xFF10b981),
  'Event':            Color(0xFFef4444),
  'Time':             Color(0xFF8b5cf6),
  'Organization':     Color(0xFF3b82f6),
  'Object':           Color(0xFFf97316),
  'Topic':            Color(0xFFec4899),
  'NarrativeSession': Color(0xFF14b8a6),
  'Community':        Color(0xFF06b6d4),
  'Policy':           Color(0xFF7c3aed),
  'Emotion':          Color(0xFFf43f5e),
  'Collection':       Color(0xFF64748b),
};
```

---

## 구현 순서

```
Phase C-1: 기반 구조
  - graph_node_model.dart (LayoutNode, LayoutEdge)
  - force_layout.dart (ForceLayout — tick() 구현)
  - graph_provider.dart (GraphNotifier — loadGraph, search)

Phase C-2: 렌더링
  - graph_painter.dart (GraphPainter — 노드, 엣지, 화살표, 레이블)
  - knowledge_graph_screen.dart 교체
    (InteractiveViewer + CustomPaint + Stack 오버레이)

Phase C-3: UI 위젯
  - graph_search_bar.dart
  - graph_legend.dart
  - node_detail_sheet.dart

Phase C-4: 검증
  - flutter run -d windows
  - 그래프 로드 → 포스 레이아웃 수렴 확인
  - 검색 → 매칭 강조 / 비매칭 희미화 확인
  - 노드 드래그 → 고정 확인
  - 노드 클릭 → BottomSheet 확인
  - 줌 인/아웃 확인
```

---

## 완료 기준

```
Phase C-1:
  □ ForceLayout.tick() 100회 반복 → 노드 위치 수렴 확인 (단위 테스트)
  □ graphProvider.loadGraph() → GET /api/graph 정상 호출

Phase C-2:
  □ flutter run -d windows 실행
  □ 지식그래프 탭 → 노드/엣지 화면 표시
  □ 포스 시뮬레이션 → 수렴 후 정지 (isSimulating false)
  □ 노드 크기가 degree에 비례하는지 육안 확인

Phase C-3:
  □ 검색창 입력 → 300ms 후 필터 적용
  □ 매칭 노드: 1.5배 크기 + 노란 테두리
  □ 비매칭 노드: 투명도 20%
  □ ✕ 클릭 → 전체 그래프 복원
  □ 노드 클릭 → NodeDetailSheet 표시
  □ 노드 드래그 → 위치 고정 (pinned)
  □ InteractiveViewer 줌/패닝 동작
  □ 하단 범례 클래스 색상 표시

Phase C-4 (트리플 0개일 때):
  □ "그래프 데이터가 없습니다. 트리플을 먼저 생성하세요." 안내 표시
```

---

## 제약 조건

```
- Phase C-1 완료 확인 후 C-2 시작 (단계별 승인)
- 노드 100개 이상 시 성능 저하 가능
  → 현재 소규모(100건 이하)이므로 최적화는 추후 필요 시
- CustomPaint 크기: 3000x3000 (포스 레이아웃 공간)
  → InteractiveViewer 로 줌/패닝
- 엣지 레이블은 opacity > 0.5 인 경우만 렌더링
  (전체 표시 시 가독성 저하)
- 포스 시뮬레이션은 16ms 간격(60fps), 수렴 시 자동 정지
- Phase C-1 완료 후 나에게 보고, 승인 후 C-2 진행
```
