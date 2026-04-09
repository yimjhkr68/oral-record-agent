import 'package:flutter/material.dart';
import 'graph_node_model.dart';

/// CustomPainter — LayoutNode + LayoutEdge 기반 그래프 렌더링
class GraphPainter extends CustomPainter {
  final List<LayoutNode> nodes;
  final List<LayoutEdge> edges;
  final Map<String, Color> classColors;
  final String? selectedNodeId;

  const GraphPainter({
    required this.nodes,
    required this.edges,
    required this.classColors,
    this.selectedNodeId,
  });

  Color _colorForType(String type) =>
      classColors[type] ?? const Color(0xFF94a3b8);

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 엣지 (노드 뒤)
    for (final edge in edges) {
      _drawEdge(canvas, edge);
    }
    // 2. 노드
    for (final node in nodes) {
      _drawNode(canvas, node);
    }
  }

  void _drawEdge(Canvas canvas, LayoutEdge edge) {
    final s = _nodeById(edge.sourceId);
    final t = _nodeById(edge.targetId);
    if (s == null || t == null) return;

    final src = Offset(s.x, s.y);
    final dst = Offset(t.x, t.y);
    final delta = dst - src;
    final dist = delta.distance;
    if (dist < 2) return;

    final dir = delta / dist;
    final lineStart = src + dir * (s.radius + 2);
    final lineEnd = dst - dir * (t.radius + 8);

    final op = edge.opacity;

    // 엣지 선
    final linePaint = Paint()
      ..color = Colors.blueGrey.shade300.withValues(alpha: op * 0.8)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(lineStart, lineEnd, linePaint);

    // 화살표 머리
    final arrowPaint = Paint()
      ..color = Colors.blueGrey.shade400.withValues(alpha: op)
      ..style = PaintingStyle.fill;
    final tip = lineEnd;
    const arrowSize = 7.0;
    final perp = Offset(-dir.dy, dir.dx);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        (tip - dir * arrowSize + perp * (arrowSize * 0.4)).dx,
        (tip - dir * arrowSize + perp * (arrowSize * 0.4)).dy,
      )
      ..lineTo(
        (tip - dir * arrowSize - perp * (arrowSize * 0.4)).dx,
        (tip - dir * arrowSize - perp * (arrowSize * 0.4)).dy,
      )
      ..close();
    canvas.drawPath(path, arrowPaint);

    // 술어 레이블 (엣지 중간, 충분히 길 때만)
    if (op > 0.4 && dist > 60) {
      final mid = (lineStart + lineEnd) / 2;
      final tp = TextPainter(
        text: TextSpan(
          text: edge.predicate,
          style: TextStyle(
            fontSize: 9,
            color: Colors.blueGrey.shade700.withValues(alpha: op),
            backgroundColor: Colors.white.withValues(alpha: 0.7 * op),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 120);
      tp.paint(canvas, mid - Offset(tp.width / 2, tp.height / 2));
    }
  }

  void _drawNode(Canvas canvas, LayoutNode node) {
    final pos = Offset(node.x, node.y);
    final r = node.radius;
    final op = node.opacity;
    final baseColor = _colorForType(node.type);
    final isSelected = node.id == selectedNodeId || node.selected;

    // 그림자
    canvas.drawCircle(
      pos + const Offset(1.5, 2),
      r,
      Paint()..color = Colors.black.withValues(alpha: 0.15 * op),
    );

    // 노드 원 (fill)
    canvas.drawCircle(
      pos,
      r,
      Paint()..color = baseColor.withValues(alpha: 0.9 * op),
    );

    // 강조 테두리 (검색 매칭)
    if (node.highlighted) {
      canvas.drawCircle(
        pos,
        r + 3,
        Paint()
          ..color = Colors.amber.withValues(alpha: op)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    // 선택 테두리
    if (isSelected) {
      canvas.drawCircle(
        pos,
        r,
        Paint()
          ..color = Colors.amber
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    } else {
      canvas.drawCircle(
        pos,
        r,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.5 * op)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }

    // 노드 레이블
    if (op > 0.15) {
      final label = node.id.length > 10
          ? '${node.id.substring(0, 10)}…'
          : node.id;
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: (node.highlighted || isSelected) ? 10 : 9,
            color: Colors.white.withValues(alpha: op),
            fontWeight: (node.highlighted || isSelected)
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: r * 2 - 4);
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  LayoutNode? _nodeById(String id) {
    for (final n in nodes) {
      if (n.id == id) return n;
    }
    return null;
  }

  @override
  bool shouldRepaint(GraphPainter old) =>
      old.nodes != nodes ||
      old.edges != edges ||
      old.selectedNodeId != selectedNodeId;
}

/// 클래스별 고정 색상 팔레트
const graphClassColors = <String, Color>{
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
