import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/triple.dart';
import '../../providers/graph_provider.dart';

// ── 클래스별 고정 색상 팔레트 ──────────────────────────────────────────────────
const _classColors = <String, Color>{
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

Color _colorForType(String type) =>
    _classColors[type] ?? const Color(0xFF94a3b8);

// ── 레이아웃 노드 ────────────────────────────────────────────────────────────
class _LayoutNode {
  final GraphNode data;
  Offset pos;
  Offset vel = Offset.zero;

  _LayoutNode(this.data, this.pos);
}

// ── Force-directed 레이아웃 계산 ──────────────────────────────────────────────
List<_LayoutNode> _runForceLayout(
  List<GraphNode> nodes,
  List<Triple> triples, {
  int iterations = 300,
  double width = 800,
  double height = 600,
}) {
  if (nodes.isEmpty) return [];
  final rng = math.Random(42);
  final layout = nodes
      .map((n) => _LayoutNode(
          n, Offset(rng.nextDouble() * width, rng.nextDouble() * height)))
      .toList();
  final idx = {for (var i = 0; i < layout.length; i++) layout[i].data.id: i};

  const double k = 80.0;        // spring constant
  const repulsion = 6000.0;
  const damping = 0.85;

  for (int iter = 0; iter < iterations; iter++) {
    final cooling = 1.0 - iter / iterations;

    // repulsion
    for (int i = 0; i < layout.length; i++) {
      for (int j = i + 1; j < layout.length; j++) {
        final delta = layout[i].pos - layout[j].pos;
        final dist = delta.distance.clamp(1.0, double.infinity);
        final force = delta / dist * (repulsion / (dist * dist));
        layout[i].vel += force;
        layout[j].vel -= force;
      }
    }

    // attraction (edges)
    for (final t in triples) {
      final si = idx[t.subject];
      final oi = idx[t.object];
      if (si == null || oi == null) continue;
      final delta = layout[oi].pos - layout[si].pos;
      final dist = delta.distance.clamp(1.0, double.infinity);
      final force = delta / dist * ((dist - k) * 0.05);
      layout[si].vel += force;
      layout[oi].vel -= force;
    }

    // integrate
    for (final n in layout) {
      n.vel *= damping * cooling;
      n.pos += n.vel;
      n.pos = Offset(
        n.pos.dx.clamp(40.0, width - 40),
        n.pos.dy.clamp(40.0, height - 40),
      );
    }
  }
  return layout;
}

// ── CustomPainter ────────────────────────────────────────────────────────────
class _GraphPainter extends CustomPainter {
  final List<_LayoutNode> nodes;
  final List<Triple> triples;
  final Map<String, int> degreeMap;
  final String searchQuery;
  final String? selectedNodeId;

  const _GraphPainter({
    required this.nodes,
    required this.triples,
    required this.degreeMap,
    required this.searchQuery,
    required this.selectedNodeId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final posMap = {for (final n in nodes) n.data.id: n.pos};

    // highlight sets
    Set<String> matchIds = {};
    Set<String> neighborIds = {};
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      for (final n in nodes) {
        if (n.data.id.toLowerCase().contains(q) ||
            n.data.type.toLowerCase().contains(q)) {
          matchIds.add(n.data.id);
        }
      }
      for (final t in triples) {
        if (matchIds.contains(t.subject)) { neighborIds.add(t.object); }
        if (matchIds.contains(t.object)) { neighborIds.add(t.subject); }
      }
      neighborIds.removeAll(matchIds);
    }

    // edges
    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final arrowPaint = Paint()..style = PaintingStyle.fill;
    final labelStyle = TextStyle(
      fontSize: 9,
      color: Colors.blueGrey.shade700,
      backgroundColor: Colors.white.withValues(alpha: 0.7),
    );

    for (final t in triples) {
      final src = posMap[t.subject];
      final dst = posMap[t.object];
      if (src == null || dst == null) continue;

      double opacity = 1.0;
      if (searchQuery.isNotEmpty) {
        final involvedInMatch =
            matchIds.contains(t.subject) || matchIds.contains(t.object);
        final involvedInNeighbor =
            neighborIds.contains(t.subject) || neighborIds.contains(t.object);
        if (!involvedInMatch && !involvedInNeighbor) opacity = 0.08;
        else if (involvedInNeighbor && !involvedInMatch) opacity = 0.35;
      }

      edgePaint.color = Colors.blueGrey.shade300.withValues(alpha: opacity);
      arrowPaint.color = Colors.blueGrey.shade400.withValues(alpha: opacity);

      // line (shortened to not overlap node circles)
      final delta = dst - src;
      final dist = delta.distance;
      if (dist < 2) continue;
      final dir = delta / dist;
      final srcR = _nodeRadius(t.subject, degreeMap);
      final dstR = _nodeRadius(t.object, degreeMap);
      final lineStart = src + dir * (srcR + 2);
      final lineEnd = dst - dir * (dstR + 8);
      canvas.drawLine(lineStart, lineEnd, edgePaint);

      // arrowhead
      final tip = lineEnd;
      final arrowSize = 7.0;
      final perp = Offset(-dir.dy, dir.dx);
      final path = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo((tip - dir * arrowSize + perp * (arrowSize * 0.4)).dx,
            (tip - dir * arrowSize + perp * (arrowSize * 0.4)).dy)
        ..lineTo((tip - dir * arrowSize - perp * (arrowSize * 0.4)).dx,
            (tip - dir * arrowSize - perp * (arrowSize * 0.4)).dy)
        ..close();
      canvas.drawPath(path, arrowPaint);

      // predicate label (mid-edge)
      if (opacity > 0.1 && dist > 60) {
        final mid = (lineStart + lineEnd) / 2;
        final tp = TextPainter(
          text: TextSpan(text: t.predicate, style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 100);
        tp.paint(canvas, mid - Offset(tp.width / 2, tp.height / 2));
      }
    }

    // nodes
    for (final n in nodes) {
      final pos = n.pos;
      final r = _nodeRadius(n.data.id, degreeMap);
      final baseColor = _colorForType(n.data.type);
      final isMatch = matchIds.contains(n.data.id);
      final isNeighbor = neighborIds.contains(n.data.id);
      final isSelected = n.data.id == selectedNodeId;

      double opacity = 1.0;
      if (searchQuery.isNotEmpty && !isMatch && !isNeighbor) {
        opacity = 0.18;
      } else if (isNeighbor) {
        opacity = 0.65;
      }

      // shadow
      canvas.drawCircle(
        pos + const Offset(1.5, 2),
        r,
        Paint()..color = Colors.black.withValues(alpha: 0.15 * opacity),
      );

      // fill
      canvas.drawCircle(
        pos,
        r,
        Paint()..color = baseColor.withValues(alpha: 0.9 * opacity),
      );

      // border
      Color borderColor;
      double borderWidth;
      if (isMatch || isSelected) {
        borderColor = Colors.amber;
        borderWidth = 2.5;
      } else {
        borderColor = Colors.white.withValues(alpha: 0.5 * opacity);
        borderWidth = 1.0;
      }
      canvas.drawCircle(
        pos,
        r,
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth,
      );

      // label
      if (opacity > 0.1) {
        final label = n.data.id.length > 10
            ? '${n.data.id.substring(0, 10)}…'
            : n.data.id;
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              fontSize: (isMatch || isSelected) ? 10 : 9,
              color: Colors.white.withValues(alpha: opacity),
              fontWeight: (isMatch || isSelected)
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: r * 2 - 4);
        tp.paint(
            canvas, pos - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  double _nodeRadius(String id, Map<String, int> degreeMap) {
    final deg = degreeMap[id] ?? 0;
    return (18.0 + math.sqrt(deg.toDouble()) * 5).clamp(18.0, 48.0);
  }

  @override
  bool shouldRepaint(_GraphPainter old) =>
      old.searchQuery != searchQuery ||
      old.selectedNodeId != selectedNodeId ||
      old.nodes != nodes;
}

// ── 메인 화면 ─────────────────────────────────────────────────────────────────

class KnowledgeGraphScreen extends ConsumerStatefulWidget {
  const KnowledgeGraphScreen({super.key});

  @override
  ConsumerState<KnowledgeGraphScreen> createState() =>
      _KnowledgeGraphScreenState();
}

class _KnowledgeGraphScreenState
    extends ConsumerState<KnowledgeGraphScreen> {
  final _searchCtrl = TextEditingController();
  List<_LayoutNode> _layout = [];
  Map<String, int> _degreeMap = {};
  GraphData? _graphData;
  String? _selectedNodeId;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _rebuildLayout(GraphData data) {
    final degreeMap = <String, int>{};
    for (final t in data.triples) {
      degreeMap[t.subject] = (degreeMap[t.subject] ?? 0) + 1;
      degreeMap[t.object]  = (degreeMap[t.object]  ?? 0) + 1;
    }
    final n = data.nodes.length;
    final w = math.max(600.0, math.sqrt(n.toDouble()) * 120);
    final h = w * 0.75;
    final layout = _runForceLayout(data.nodes, data.triples,
        iterations: n > 80 ? 150 : 300, width: w, height: h);

    setState(() {
      _graphData = data;
      _layout = layout;
      _degreeMap = degreeMap;
      _selectedNodeId = null;
    });
  }

  void _onTapCanvas(Offset localPos, TransformationController tc) {
    // inverse transform from InteractiveViewer
    final scene = MatrixUtils.transformPoint(
        Matrix4.inverted(tc.value), localPos);

    String? hit;
    double bestDist = double.infinity;
    for (final n in _layout) {
      final r = 18.0 + math.sqrt(((_degreeMap[n.data.id] ?? 0)).toDouble()) * 5;
      final d = (n.pos - scene).distance;
      if (d <= r && d < bestDist) {
        bestDist = d;
        hit = n.data.id;
      }
    }
    if (hit != null) {
      setState(() => _selectedNodeId = hit == _selectedNodeId ? null : hit);
      if (hit != _selectedNodeId) _showNodeSheet(hit);
    } else {
      setState(() => _selectedNodeId = null);
    }
  }

  void _showNodeSheet(String nodeId) {
    final node = _layout.firstWhere((n) => n.data.id == nodeId,
        orElse: () => _layout.first);
    final triples = _graphData?.triples ?? [];
    final connected =
        triples.where((t) => t.subject == nodeId || t.object == nodeId).toList();
    final outgoing = connected.where((t) => t.subject == nodeId).toList();
    final incoming = connected.where((t) => t.object == nodeId).toList();
    final color = _colorForType(node.data.type);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.25,
        maxChildSize: 0.75,
        expand: false,
        builder: (_, scroll) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color,
                  child: Text(nodeId[0].toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nodeId,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(node.data.type,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                _StatPill('나가는', outgoing.length),
                const SizedBox(width: 6),
                _StatPill('들어오는', incoming.length),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.all(12),
                children: [
                  if (outgoing.isNotEmpty) ...[
                    const _SheetHeader('나가는 관계'),
                    ...outgoing.map((t) => _TripleRow(t, nodeId)),
                  ],
                  if (incoming.isNotEmpty) ...[
                    const _SheetHeader('들어오는 관계'),
                    ...incoming.map((t) => _TripleRow(t, nodeId)),
                  ],
                  if (connected.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('연결된 트리플 없음',
                            style: TextStyle(color: Colors.grey)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(graphDataProvider, (_, next) => next.whenData(_rebuildLayout));
    final graphAsync = ref.watch(graphDataProvider);
    final query = ref.watch(graphQueryProvider);
    final tc = TransformationController();

    return Scaffold(
      body: graphAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('오류: $e', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => ref.invalidate(graphDataProvider),
              child: const Text('다시 시도'),
            ),
          ]),
        ),
        data: (_) {
          if (_layout.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.hub_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 12),
                Text(
                  query.isEmpty
                      ? '그래프 데이터가 없습니다.\n트리플을 추출하면 그래프가 생성됩니다.'
                      : '"$query" 검색 결과가 없습니다.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                if (query.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      _searchCtrl.clear();
                      ref.read(graphQueryProvider.notifier).state = '';
                    },
                    child: const Text('전체 그래프 보기'),
                  ),
                ],
              ]),
            );
          }

          // canvas size
          final xs = _layout.map((n) => n.pos.dx).toList();
          final ys = _layout.map((n) => n.pos.dy).toList();
          final canvasW = (xs.reduce(math.max) + 80).toDouble();
          final canvasH = (ys.reduce(math.max) + 80).toDouble();

          return Stack(children: [
            // graph canvas
            GestureDetector(
              onTapUp: (d) => _onTapCanvas(d.localPosition, tc),
              child: InteractiveViewer(
                transformationController: tc,
                constrained: false,
                boundaryMargin: const EdgeInsets.all(200),
                minScale: 0.05,
                maxScale: 5.0,
                child: CustomPaint(
                  size: Size(canvasW, canvasH),
                  painter: _GraphPainter(
                    nodes: _layout,
                    triples: _graphData?.triples ?? [],
                    degreeMap: _degreeMap,
                    searchQuery: query,
                    selectedNodeId: _selectedNodeId,
                  ),
                ),
              ),
            ),

            // ── 상단 오버레이: 검색 + 통계 ─────────────────────────────────
            Positioned(
              top: 12, left: 12, right: 12,
              child: Row(children: [
                Expanded(
                  child: Material(
                    elevation: 2,
                    borderRadius: BorderRadius.circular(10),
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: '노드 검색...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  ref.read(graphQueryProvider.notifier).state = '';
                                  setState(() {});
                                },
                              )
                            : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 4),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onSubmitted: (v) {
                        ref.read(graphQueryProvider.notifier).state = v.trim();
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // stats pill
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '노드 ${_layout.length}  ·  트리플 ${_graphData?.triples.length ?? 0}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ]),
            ),

            // ── 하단 오버레이: 범례 ─────────────────────────────────────────
            Positioned(
              bottom: 12, left: 12,
              child: _Legend(),
            ),

            // ── 줌 힌트 ─────────────────────────────────────────────────────
            Positioned(
              bottom: 12, right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '핀치/스크롤 줌  ·  드래그 이동  ·  노드 탭으로 상세',
                  style: TextStyle(fontSize: 10, color: Colors.white70),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

// ── 범례 ──────────────────────────────────────────────────────────────────────
class _Legend extends StatefulWidget {
  @override
  State<_Legend> createState() => _LegendState();
}

class _LegendState extends State<_Legend> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: _expanded
              ? Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: _classColors.entries.map((e) {
                    return Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(
                            color: e.value,
                            shape: BoxShape.circle,
                          )),
                      const SizedBox(width: 4),
                      Text(e.key,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10)),
                    ]);
                  }).toList(),
                )
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  ...(_classColors.entries.take(5).map((e) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                            color: e.value, shape: BoxShape.circle)),
                  ))),
                  const Text('범례 ▸',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 10)),
                ]),
        ),
      ),
    );
  }
}

// ── 보조 위젯 ─────────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final String label;
  final int value;
  const _StatPill(this.label, this.value);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.blueGrey.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('$label $value',
            style: const TextStyle(fontSize: 11)),
      );
}

class _SheetHeader extends StatelessWidget {
  final String text;
  const _SheetHeader(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(text,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary)),
      );
}

class _TripleRow extends StatelessWidget {
  final Triple triple;
  final String focusId;
  const _TripleRow(this.triple, this.focusId);

  @override
  Widget build(BuildContext context) {
    final isSubject = triple.subject == focusId;
    final other = isSubject ? triple.object : triple.subject;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Text(
          isSubject ? '→' : '←',
          style: TextStyle(
              color: isSubject
                  ? Theme.of(context).colorScheme.primary
                  : Colors.orange,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: RichText(
            text: TextSpan(
              style: DefaultTextStyle.of(context)
                  .style
                  .copyWith(fontSize: 12),
              children: [
                TextSpan(
                  text: triple.predicate,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600),
                ),
                const TextSpan(text: '  '),
                TextSpan(text: other),
              ],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
    );
  }
}
