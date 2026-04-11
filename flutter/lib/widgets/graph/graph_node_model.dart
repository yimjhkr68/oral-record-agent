
/// 클래스 유형별 기본 반지름 (구술 도메인 중요도 기반)
const Map<String, double> _kBaseRadius = {
  // 구술자 — 가장 크게 (핵심 주체)
  'Narrator':                22.0,
  'OralNarrator':            22.0,
  'OralHistoryNarrator':     22.0,

  // 주요 사건/기록물 — 크게
  'HistoricalEvent':         18.0,
  'HistoricalMassacreEvent': 18.0,
  'OralHistoryRecord':       18.0,
  'NarrativeSession':        18.0,

  // 인물/피해자/장소 — 보통
  'Person':                  16.0,
  'Victim':                  16.0,
  'Survivor':                16.0,
  'Witness':                 15.0,
  'Place':                   16.0,
  'Location':                15.0,

  // 나머지는 기본값(13.0) 사용
};

/// 클래스 유형 + degree 조합으로 반지름 계산
double radiusForNode(String type, int degree) {
  final base = _kBaseRadius[type] ?? 13.0;
  final degreeBonus = (degree * 1.5).clamp(0.0, 14.0);
  return base + degreeBonus;
}

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
  }) : radius = radius ?? radiusForNode(type, degree);

  double get baseRadius => radiusForNode(type, degree);
}

/// 렌더링용 엣지
class LayoutEdge {
  final String sourceId;
  final String targetId;
  final String predicate;
  double opacity;
  bool highlighted; // 술어 검색 매칭 강조

  LayoutEdge({
    required this.sourceId,
    required this.targetId,
    required this.predicate,
    this.opacity = 1.0,
    this.highlighted = false,
  });
}
