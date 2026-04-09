import 'dart:math';
import 'package:flutter/painting.dart';
import 'graph_node_model.dart';

/// Spring-Embedder 알고리즘 (간소화 버전)
/// 100노드 이하에서 충분한 성능
class ForceLayout {
  final List<LayoutNode> nodes;
  final List<LayoutEdge> edges;
  final Size canvasSize;

  static const double repulsion    = 3000.0;
  static const double attraction   = 0.08;
  static const double idealLength  = 120.0;
  static const double damping      = 0.85;
  static const double centerPull   = 0.002;

  ForceLayout({
    required this.nodes,
    required this.edges,
    required this.canvasSize,
  });

  /// 초기 위치 — 원형 배치 (랜덤보다 수렴 빠름)
  void initPositions() {
    if (nodes.isEmpty) return;
    final cx = canvasSize.width / 2;
    final cy = canvasSize.height / 2;
    final r = min(cx, cy) * 0.6;
    for (int i = 0; i < nodes.length; i++) {
      final angle = 2 * pi * i / nodes.length;
      nodes[i].x = cx + r * cos(angle);
      nodes[i].y = cy + r * sin(angle);
      nodes[i].vx = 0;
      nodes[i].vy = 0;
    }
  }

  /// 1 틱 시뮬레이션. 수렴 시 true 반환.
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
      n.vx += (cx - n.x) * centerPull;
      n.vy += (cy - n.y) * centerPull;
    }
    // 4. 위치 업데이트
    double maxV = 0;
    for (final n in nodes) {
      if (n.pinned) continue;
      n.vx *= damping;
      n.vy *= damping;
      n.x += n.vx;
      n.y += n.vy;
      final v = n.vx.abs() + n.vy.abs();
      if (v > maxV) maxV = v;
    }
    return maxV < 0.5; // 수렴 시 true
  }

  void _applyRepulsion(LayoutNode a, LayoutNode b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist < 1e-6) return;
    final force = repulsion / (dist * dist);
    final fx = force * dx / dist;
    final fy = force * dy / dist;
    if (!a.pinned) { a.vx += fx; a.vy += fy; }
    if (!b.pinned) { b.vx -= fx; b.vy -= fy; }
  }

  void _applyAttraction(LayoutNode s, LayoutNode t) {
    final dx = t.x - s.x;
    final dy = t.y - s.y;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist < 1e-6) return;
    final force = attraction * (dist - idealLength);
    final fx = force * dx / dist;
    final fy = force * dy / dist;
    if (!s.pinned) { s.vx += fx; s.vy += fy; }
    if (!t.pinned) { t.vx -= fx; t.vy -= fy; }
  }

  LayoutNode? _nodeById(String id) {
    for (final n in nodes) {
      if (n.id == id) return n;
    }
    return null;
  }
}
