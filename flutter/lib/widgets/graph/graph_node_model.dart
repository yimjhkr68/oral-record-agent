import 'dart:math' as math;

/// 레이아웃 계산용 노드 — GraphNode + 위치/렌더링 상태
class LayoutNode {
  final String id;
  final String type;
  final int degree;

  // 포스 시뮬레이션 위치
  double x;
  double y;
  double vx;
  double vy;
  bool pinned;

  // 렌더링 상태
  double radius;
  double opacity;
  bool highlighted;
  bool selected;

  LayoutNode({
    required this.id,
    required this.type,
    required this.degree,
    this.x = 0,
    this.y = 0,
    this.vx = 0,
    this.vy = 0,
    this.pinned = false,
    double? radius,
    this.opacity = 1.0,
    this.highlighted = false,
    this.selected = false,
  }) : radius = radius ?? (14 + math.min(degree * 2.0, 12));

  double get baseRadius => 14 + math.min(degree * 2.0, 12);
}

/// 렌더링용 엣지
class LayoutEdge {
  final String sourceId;
  final String targetId;
  final String predicate;
  double opacity;

  LayoutEdge({
    required this.sourceId,
    required this.targetId,
    required this.predicate,
    this.opacity = 1.0,
  });
}
