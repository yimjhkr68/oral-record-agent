# 지식그래프 개선 Plan — 군집/드래그/출력

## 작업 목록

```
Fix 1. 군집 범주화 완전화 — 모든 노드가 반드시 하나의 군집에 속함
Fix 2. 군집 박스 겹침 방지 — 충돌 감지 후 분리
Fix 3. 드래그 UX 개선 — 길게 누르기(Long Press)로 드래그 모드 진입
Fix 4. 지식그래프 이미지(PNG)/PDF 출력 기능
```

---

## Fix 1 — 군집 범주화 완전화

### 현재 문제

```
일부 노드가 어떤 군집에도 속하지 않아
군집 박스 밖에 떠다니는 상태.
```

### 원인

```
현재 알고리즘: 구술자의 2홉 이웃만 군집에 포함
→ 구술자와 직접 연결이 없는 노드는 미포함
→ 공유 노드(여러 구술자가 공통으로 연결한 노드)는 중복 포함
```

### 수정 — cluster_detector.dart

```dart
static List<NarratorCluster> detect(
    List<LayoutNode> nodes, List<LayoutEdge> edges) {

  const narratorTypes = {
    'Narrator','OralNarrator','OralHistoryNarrator',
  };

  final narrators = nodes.where((n) => narratorTypes.contains(n.type)).toList();

  // 구술자가 없으면 전체를 하나의 군집으로
  if (narrators.isEmpty) {
    return [NarratorCluster(
      narratorId: '',
      nodeIds: nodes.map((n) => n.id).toSet(),
      color: const Color(0x151565C0),
    )];
  }

  // Step 1: 각 구술자의 연결 그래프 탐색 (BFS, 깊이 무제한)
  Map<String, Set<String>> narratorReach = {};
  for (final narrator in narrators) {
    final visited = <String>{narrator.id};
    final queue = [narrator.id];
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      for (final e in edges) {
        String? neighbor;
        if (e.sourceId == current) neighbor = e.targetId;
        if (e.targetId == current) neighbor = e.sourceId;
        if (neighbor != null && !visited.contains(neighbor)) {
          visited.add(neighbor);
          queue.add(neighbor);
        }
      }
    }
    narratorReach[narrator.id] = visited;
  }

  // Step 2: 노드별 가장 가까운 구술자 배정
  // 각 노드를 가장 적은 홉 수의 구술자 군집에 배정
  Map<String, String> nodeToNarrator = {};

  // 구술자 자신은 자신 군집
  for (final n in narrators) {
    nodeToNarrator[n.id] = n.id;
  }

  // 나머지 노드: BFS 거리가 가장 짧은 구술자 군집에 배정
  final nonNarrators = nodes.where((n) => !narratorTypes.contains(n.type));
  for (final node in nonNarrators) {
    int minDist = 999;
    String? bestNarrator;

    for (final narrator in narrators) {
      final dist = _bfsDistance(narrator.id, node.id, edges);
      if (dist < minDist) {
        minDist = dist;
        bestNarrator = narrator.id;
      }
    }
    // 연결이 전혀 없으면 가장 가까운 구술자에 배정
    nodeToNarrator[node.id] = bestNarrator ?? narrators.first.id;
  }

  // Step 3: 군집 생성
  final palette = [
    const Color(0x151565C0),  // 파랑
    const Color(0x15C62828),  // 빨강
    const Color(0x152E7D32),  // 초록
    const Color(0x156A1B9A),  // 보라
    const Color(0x15EF6C00),  // 주황
    const Color(0x15004D40),  // 청록
  ];

  return narrators.asMap().entries.map((entry) {
    final idx = entry.key;
    final narrator = entry.value;
    final clusterNodes = nodeToNarrator.entries
        .where((e) => e.value == narrator.id)
        .map((e) => e.key)
        .toSet();

    return NarratorCluster(
      narratorId: narrator.id,
      nodeIds: clusterNodes,
      color: palette[idx % palette.length],
    );
  }).toList();
}

// BFS 거리 계산
static int _bfsDistance(String from, String to, List<LayoutEdge> edges) {
  if (from == to) return 0;
  final visited = <String>{from};
  final queue = [(from, 0)];
  while (queue.isNotEmpty) {
    final (current, dist) = queue.removeAt(0);
    for (final e in edges) {
      String? neighbor;
      if (e.sourceId == current) neighbor = e.targetId;
      if (e.targetId == current) neighbor = e.sourceId;
      if (neighbor == to) return dist + 1;
      if (neighbor != null && !visited.contains(neighbor)) {
        visited.add(neighbor);
        queue.add((neighbor, dist + 1));
      }
    }
  }
  return 999; // 연결 없음
}
```

---

## Fix 2 — 군집 박스 겹침 방지

### 알고리즘 — 박스 분리 반복

```dart
// cluster_detector.dart 에 추가

/// 군집 박스들이 겹치지 않도록 노드 위치를 조정
static void separateClusters(
    List<NarratorCluster> clusters,
    List<LayoutNode> nodes,
    {int maxIterations = 50}) {

  for (int iter = 0; iter < maxIterations; iter++) {
    bool anyOverlap = false;

    for (int i = 0; i < clusters.length; i++) {
      for (int j = i + 1; j < clusters.length; j++) {
        final boxI = _clusterBounds(clusters[i], nodes);
        final boxJ = _clusterBounds(clusters[j], nodes);

        if (!boxI.overlaps(boxJ)) continue;
        anyOverlap = true;

        // 겹침 방향 계산
        final cI = boxI.center;
        final cJ = boxJ.center;
        final dx = cI.dx - cJ.dx;
        final dy = cI.dy - cJ.dy;
        final dist = sqrt(dx * dx + dy * dy);
        if (dist < 1) continue;

        // 겹침 크기
        final overlapX = (boxI.width  + boxJ.width)  / 2 - dx.abs() + 20;
        final overlapY = (boxI.height + boxJ.height) / 2 - dy.abs() + 20;

        // 작은 쪽 겹침 방향으로 밀어내기
        final pushX = (overlapX > 0 ? overlapX / 2 : 0) * (dx / dist);
        final pushY = (overlapY > 0 ? overlapY / 2 : 0) * (dy / dist);

        // 군집 I 노드들을 +방향, J 노드들을 -방향으로 이동
        for (final node in nodes) {
          if (clusters[i].nodeIds.contains(node.id)) {
            node.x += pushX * 0.5;
            node.y += pushY * 0.5;
          }
          if (clusters[j].nodeIds.contains(node.id)) {
            node.x -= pushX * 0.5;
            node.y -= pushY * 0.5;
          }
        }
      }
    }

    if (!anyOverlap) break;
  }
}

static Rect _clusterBounds(NarratorCluster cluster, List<LayoutNode> nodes,
    {double padding = 50}) {
  final clusterNodes = nodes.where((n) => cluster.nodeIds.contains(n.id));
  if (clusterNodes.isEmpty) return Rect.zero;

  double minX = clusterNodes.map((n) => n.x - n.radius).reduce(min) - padding;
  double maxX = clusterNodes.map((n) => n.x + n.radius).reduce(max) + padding;
  double minY = clusterNodes.map((n) => n.y - n.radius).reduce(min) - padding;
  double maxY = clusterNodes.map((n) => n.y + n.radius).reduce(max) + padding;

  return Rect.fromLTRB(minX, minY, maxX, maxY);
}
```

### 호출 시점

```dart
// graph_provider.dart loadGraph() 완료 후
state = state.copyWith(clusters: clusters);

// 포스 시뮬레이션 수렴 후 박스 분리 적용
_simTimer = Timer.periodic(const Duration(milliseconds: 16), (t) {
  final converged = _layout.tick();
  if (converged) {
    t.cancel();
    // 수렴 후 박스 분리
    ClusterDetector.separateClusters(
      state.clusters, _layout.nodes);
    state = state.copyWith(
      nodes: [..._layout.nodes],
      isSimulating: false,
      clusters: ClusterDetector.detect(_layout.nodes, state.edges),
    );
    // 화면 맞춤
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitToScreen();
    });
  }
});
```

---

## Fix 3 — 드래그 UX 개선

### 현재 문제

```
팬(Pan)과 드래그가 구분이 안 됨
→ 패닝(화면 이동) 의도인데 노드가 드래그됨
→ 어떻게 노드를 선택하는지 불명확
```

### 새 UX 설계

```
모드 1. 기본 모드:
  - 탭: 노드 선택 → 상세 패널 열기
  - 핀치/스크롤: 줌
  - 화면 빈 곳 드래그: 캔버스 패닝

모드 2. 드래그 모드 (노드 위에서 길게 누르기 0.5초):
  - 길게 누르기(Long Press) → 선택된 노드 진동 피드백 + 드래그 가능
  - 드래그: 노드 이동
  - 손 떼면: 드래그 모드 해제
  - 구술자: 소속 노드 함께 이동

안내 텍스트 (하단):
  "탭: 상세보기  ·  길게 누르기: 노드 이동  ·  핀치/스크롤: 줌"
```

### 구현

```dart
// knowledge_graph_screen.dart

// GestureDetector 교체
GestureDetector(
  // 탭: 노드 선택
  onTapUp: (d) => _onTapCanvas(d, graphState),

  // 길게 누르기: 드래그 모드 시작
  onLongPressStart: (d) => _onLongPressStart(d, graphState),
  onLongPressMoveUpdate: (d) => _onLongPressDrag(d),
  onLongPressEnd: (_) => _onLongPressEnd(),

  child: InteractiveViewer(
    // InteractiveViewer 의 패닝은 노드 드래그 모드가 아닐 때만 활성
    panEnabled: !_isDraggingNode,
    ...
  ),
)

// 상태 변수
bool _isDraggingNode = false;
String? _draggingNodeId;
Offset? _lastDragPosition;

void _onLongPressStart(LongPressStartDetails d, GraphState state) {
  final pos = _toCanvasCoords(d.localPosition);
  for (final node in state.nodes) {
    if ((Offset(node.x, node.y) - pos).distance <= node.radius + 8) {
      setState(() {
        _isDraggingNode  = true;
        _draggingNodeId  = node.id;
        _lastDragPosition = pos;
      });
      // 햅틱 피드백 (모바일)
      HapticFeedback.mediumImpact();
      // 노드 강조 (선택 표시)
      ref.read(graphProvider.notifier).selectNode(node.id);
      return;
    }
  }
}

void _onLongPressDrag(LongPressMoveUpdateDetails d) {
  if (!_isDraggingNode || _draggingNodeId == null) return;
  final pos = _toCanvasCoords(d.localPosition);
  if (_lastDragPosition == null) {
    _lastDragPosition = pos;
    return;
  }
  final delta = pos - _lastDragPosition!;
  _lastDragPosition = pos;
  ref.read(graphProvider.notifier).onNodeDrag(_draggingNodeId!, delta);
}

void _onLongPressEnd() {
  setState(() {
    _isDraggingNode   = false;
    _draggingNodeId   = null;
    _lastDragPosition = null;
  });
  ref.read(graphProvider.notifier).selectNode(null);
}
```

### 커서 힌트 (Windows)

```dart
// Windows 에서 노드 위에 마우스 호버 시 커서 변경
MouseRegion(
  cursor: _isOverNode
      ? SystemMouseCursors.grab
      : SystemMouseCursors.basic,
  onHover: (e) {
    final pos = _toCanvasCoords(e.localPosition);
    final over = graphState.nodes.any(
        (n) => (Offset(n.x, n.y) - pos).distance <= n.radius + 4);
    if (over != _isOverNode) setState(() => _isOverNode = over);
  },
  child: GestureDetector(...),
)
```

---

## Fix 4 — 이미지(PNG)/PDF 출력

### pubspec.yaml 패키지 추가

```yaml
dependencies:
  screenshot: ^2.1.0     # 위젯 → PNG 캡처
  pdf: ^3.10.7           # PDF 생성
  printing: ^5.12.0      # PDF 프리뷰 + 인쇄
```

### 출력 구현

```dart
// flutter/lib/services/graph_export_service.dart

import 'package:screenshot/screenshot.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:file_picker/file_picker.dart';

class GraphExportService {

  /// 위젯을 PNG 로 캡처해서 파일 저장
  static Future<void> exportPng(
      ScreenshotController controller, BuildContext context) async {
    try {
      // 현재 그래프 캡처 (고해상도)
      final bytes = await controller.captureFromLongWidget(
        pixelRatio: 3.0,   // 3배 해상도
      );

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: '지식그래프 PNG 저장',
        fileName: 'knowledge_graph_${DateTime.now().millisecondsSinceEpoch}.png',
        allowedExtensions: ['png'],
        type: FileType.custom,
      );
      if (savePath == null) return;

      await File(savePath).writeAsBytes(bytes);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PNG 저장 완료: $savePath')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// PDF 생성 + 프리뷰/인쇄
  static Future<void> exportPdf(
      ScreenshotController controller, BuildContext context,
      {required int nodeCount, required int edgeCount}) async {
    try {
      final bytes = await controller.captureFromLongWidget(pixelRatio: 2.0);

      await Printing.layoutPdf(
        onLayout: (format) async {
          final doc = pw.Document();
          final image = pw.MemoryImage(bytes);

          doc.addPage(pw.Page(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(20),
            build: (ctx) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // 제목
                pw.Text(
                  '제주 4.3 구술기록 지식그래프',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                // 메타데이터
                pw.Text(
                  '노드 $nodeCount개  ·  트리플 $edgeCount개  ·  '
                  '생성: ${DateTime.now().toString().substring(0, 10)}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 12),
                // 그래프 이미지
                pw.Expanded(
                  child: pw.Image(image, fit: pw.BoxFit.contain),
                ),
              ],
            ),
          ));
          return doc.save();
        },
        name: 'knowledge_graph',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF 생성 실패: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
```

### 출력 버튼 UI

```dart
// knowledge_graph_screen.dart 상단 버튼 영역

// Screenshot 위젯으로 그래프 캔버스를 감싸기
final _screenshotController = ScreenshotController();

// build() 에서
Screenshot(
  controller: _screenshotController,
  child: Stack(children: [
    InteractiveViewer(...),  // 기존 그래프
    // 오버레이 버튼들
  ]),
)

// 출력 버튼 (기존 내보내기 버튼 옆에 추가)
PopupMenuButton<String>(
  icon: const Icon(Icons.print_outlined),
  tooltip: '출력',
  onSelected: (value) async {
    final state = ref.read(graphProvider);
    if (value == 'png') {
      await GraphExportService.exportPng(
          _screenshotController, context);
    } else if (value == 'pdf') {
      await GraphExportService.exportPdf(
          _screenshotController, context,
          nodeCount: state.nodes.length,
          edgeCount: state.edges.length);
    }
  },
  itemBuilder: (_) => [
    const PopupMenuItem(
      value: 'png',
      child: Row(children: [
        Icon(Icons.image_outlined, size: 18),
        SizedBox(width: 8),
        Text('PNG 이미지로 저장'),
      ]),
    ),
    const PopupMenuItem(
      value: 'pdf',
      child: Row(children: [
        Icon(Icons.picture_as_pdf_outlined, size: 18),
        SizedBox(width: 8),
        Text('PDF로 인쇄/저장'),
      ]),
    ),
  ],
),
```

---

## 구현 순서

```
Phase 1 — Fix 1: 군집 범주화 완전화
  1-1. cluster_detector.dart BFS 기반 완전 탐색으로 교체
  1-2. 모든 노드가 군집에 포함되는지 확인

Phase 2 — Fix 2: 군집 박스 겹침 방지
  2-1. separateClusters() 구현
  2-2. 시뮬레이션 수렴 후 자동 호출

Phase 3 — Fix 3: 드래그 UX
  3-1. GestureDetector → LongPress 이벤트로 교체
  3-2. InteractiveViewer panEnabled 드래그 모드 연동
  3-3. Windows 커서 변경
  3-4. 하단 안내 텍스트 업데이트

Phase 4 — Fix 4: 이미지/PDF 출력
  4-1. flutter pub add screenshot pdf printing
  4-2. graph_export_service.dart 생성
  4-3. Screenshot 위젯으로 캔버스 감싸기
  4-4. 출력 팝업 메뉴 추가
```

---

## 완료 기준

```
Phase 1:
  □ 모든 노드가 군집 박스 안에 포함됨
  □ 군집 박스 밖에 떠있는 노드 없음

Phase 2:
  □ 군집 박스끼리 겹치지 않음
  □ 시뮬레이션 수렴 후 자동 분리 완료

Phase 3:
  □ 화면 빈 곳 드래그 → 캔버스 패닝
  □ 노드 위 길게 누르기 → 드래그 모드
  □ 구술자 드래그 → 소속 노드 함께 이동
  □ 하단 안내: "탭: 상세보기 · 길게 누르기: 노드 이동 · 핀치: 줌"

Phase 4:
  □ [출력] 버튼 → PNG / PDF 선택 메뉴
  □ PNG 선택 → 파일 저장 다이얼로그 → 저장
  □ PDF 선택 → 인쇄 프리뷰 창 열림
  □ PDF: 제목 + 메타데이터 + 그래프 이미지 포함
```
