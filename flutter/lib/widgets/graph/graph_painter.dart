import 'dart:math';

import 'package:flutter/material.dart';
import 'graph_node_model.dart';
import 'cluster_detector.dart';

/// CustomPainter — LayoutNode + LayoutEdge 기반 그래프 렌더링
class GraphPainter extends CustomPainter {
  final List<LayoutNode> nodes;
  final List<LayoutEdge> edges;
  final List<NarratorCluster> clusters;
  final Map<String, Color> classColors;
  final String? selectedNodeId;

  const GraphPainter({
    required this.nodes,
    required this.edges,
    required this.classColors,
    this.clusters = const [],
    this.selectedNodeId,
  });

  Color _colorForType(String type) =>
      classColors[type] ?? const Color(0xFF94a3b8);

  @override
  void paint(Canvas canvas, Size size) {
    // 0. 군집 배경 (엣지/노드 뒤)
    _drawClusters(canvas);
    // 1. 엣지 (노드 뒤)
    for (final edge in edges) {
      _drawEdge(canvas, edge);
    }
    // 2. 노드
    for (final node in nodes) {
      _drawNode(canvas, node);
    }
  }

  void _drawClusters(Canvas canvas) {
    for (final cluster in clusters) {
      final clusterNodes = nodes
          .where((n) => cluster.nodeIds.contains(n.id) && !n.hidden)
          .toList();
      // 자동 범주: 2개 이상, 사용자 정의 범주: 1개 이상
      final minCount = cluster.isCustom ? 1 : 2;
      if (clusterNodes.length < minCount) continue;
      _drawClusterBackground(canvas, clusterNodes, cluster.color,
          isCustom: cluster.isCustom,
          label: cluster.isCustom ? cluster.displayName : null);
    }
  }

  void _drawClusterBackground(
      Canvas canvas, List<LayoutNode> clusterNodes, Color color,
      {bool isCustom = false, String? label}) {
    final pad = isCustom ? 50.0 : 40.0;
    double minX = clusterNodes.map((n) => n.x - n.radius).reduce(min) - pad;
    double maxX = clusterNodes.map((n) => n.x + n.radius).reduce(max) + pad;
    double minY = clusterNodes.map((n) => n.y - n.radius).reduce(min) - pad;
    double maxY = clusterNodes.map((n) => n.y + n.radius).reduce(max) + pad;

    final rect  = Rect.fromLTRB(minX, minY, maxX, maxY);
    final rrect = RRect.fromRectAndRadius(
        rect, Radius.circular(isCustom ? 24 : 32));

    // 반투명 채우기 (사용자 정의는 약간 더 진하게)
    final fillAlpha = isCustom ? 0.10 : color.a;
    canvas.drawRRect(
        rrect, Paint()..color = color.withValues(alpha: fillAlpha));

    if (isCustom) {
      // 사용자 정의: 점선 테두리
      final borderPaint = Paint()
        ..color = color.withValues(alpha: 0.7)
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke;
      _drawDashedRRect(canvas, rrect, borderPaint);
    } else {
      // 자동 범주: 실선 테두리
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = color.withValues(alpha: (color.a * 4).clamp(0.0, 1.0))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // 사용자 정의 범주: 좌상단 이름 레이블
    if (label != null && label.isNotEmpty) {
      _drawClusterLabel(canvas, minX + 10, minY + 6, label, color);
    }
  }

  /// 점선 RRect 그리기
  void _drawDashedRRect(Canvas canvas, RRect rrect, Paint paint) {
    const dashLen = 7.0;
    const dashGap = 4.0;
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        canvas.drawPath(
          metric.extractPath(dist, (dist + dashLen).clamp(0, metric.length)),
          paint,
        );
        dist += dashLen + dashGap;
      }
    }
  }

  /// 범주 이름 레이블
  void _drawClusterLabel(Canvas canvas, double x, double y,
      String label, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color.withValues(alpha: 0.85),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 180);
    // 레이블 배경 (읽기 쉽게)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 3, y - 2, tp.width + 6, tp.height + 4),
        const Radius.circular(4),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.75),
    );
    tp.paint(canvas, Offset(x, y));
  }

  void _drawEdge(Canvas canvas, LayoutEdge edge) {
    if (edge.hidden) return;
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
    final isHighlighted = edge.highlighted; // 술어 매칭 강조

    // 엣지 선 — 강조 시 파란색 + 굵은 선
    final lineColor = isHighlighted
        ? Colors.blue.shade500.withValues(alpha: op)
        : Colors.blueGrey.shade300.withValues(alpha: op * 0.8);
    final strokeWidth = isHighlighted ? 2.5 : 1.2;

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawLine(lineStart, lineEnd, linePaint);

    // 화살표 머리
    final arrowColor = isHighlighted
        ? Colors.blue.shade600.withValues(alpha: op)
        : Colors.blueGrey.shade400.withValues(alpha: op);
    final arrowPaint = Paint()
      ..color = arrowColor
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

    // 술어 레이블 — 강조 엣지는 항상 표시, 일반 엣지는 충분히 길 때만
    if ((isHighlighted && op > 0.3) || (op > 0.4 && dist > 60)) {
      final mid = (lineStart + lineEnd) / 2;
      final labelColor = isHighlighted
          ? Colors.blue.shade800.withValues(alpha: op)
          : Colors.blueGrey.shade700.withValues(alpha: op);
      final bgColor = isHighlighted
          ? Colors.blue.shade50.withValues(alpha: 0.85 * op)
          : Colors.white.withValues(alpha: 0.7 * op);
      final tp = TextPainter(
        text: TextSpan(
          text: edge.predicate,
          style: TextStyle(
            fontSize: isHighlighted ? 10 : 9,
            fontWeight:
                isHighlighted ? FontWeight.w600 : FontWeight.normal,
            color: labelColor,
            backgroundColor: bgColor,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 120);
      tp.paint(canvas, mid - Offset(tp.width / 2, tp.height / 2));
    }
  }

  void _drawNode(Canvas canvas, LayoutNode node) {
    if (node.hidden) return;
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
      old.clusters != clusters ||
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
