import 'dart:math';

import 'package:flutter/material.dart';
import 'graph_node_model.dart';

class NarratorCluster {
  final String narratorId;   // auto: narrator node ID / custom: "custom-xxx"
  final String displayName;  // UI에 표시할 이름
  final Set<String> nodeIds;
  final Color color;
  final bool isCustom;

  NarratorCluster({
    required this.narratorId,
    String? displayName,
    required this.nodeIds,
    required this.color,
    this.isCustom = false,
  }) : displayName = displayName ?? narratorId;

  /// 백엔드 custom-clusters JSON → NarratorCluster
  factory NarratorCluster.fromCustomJson(Map<String, dynamic> json) {
    final hex = (json['color'] as String? ?? '#888888').replaceFirst('#', '');
    final colorInt = int.tryParse('0xFF$hex') ?? 0xFF888888;
    return NarratorCluster(
      narratorId: json['id'] as String,
      displayName: json['name'] as String,
      nodeIds: Set<String>.from((json['node_ids'] as List? ?? [])),
      color: Color(colorInt).withValues(alpha: 0.18),
      isCustom: true,
    );
  }
}

class ClusterDetector {
  static const _narratorTypes = {
    'Narrator',
    'OralNarrator',
    'OralHistoryNarrator',
  };

  static const _palette = [
    Color(0x1A1565C0), // 파랑
    Color(0x1AC62828), // 빨강
    Color(0x1A2E7D32), // 초록
    Color(0x1A6A1B9A), // 보라
    Color(0x1AEF6C00), // 주황
    Color(0x1A004D40), // 청록
  ];

  /// 구술자 중심 BFS 완전 탐색 — 모든 노드가 반드시 하나의 군집에 속함
  ///
  /// [nodeOverrides] — 사용자 정의 범주로 이동된 노드 ID 집합.
  /// 해당 노드는 자동 범주 배정에서 제외됨.
  static List<NarratorCluster> detect(
      List<LayoutNode> nodes, List<LayoutEdge> edges,
      {Map<String, String> nodeOverrides = const {}}) {
    // 사용자 정의 범주로 이동된 노드는 자동 범주에서 제외
    final overridden = nodeOverrides.keys.toSet();
    final autoNodes =
        nodes.where((n) => !overridden.contains(n.id)).toList();

    final narrators =
        autoNodes.where((n) => _narratorTypes.contains(n.type)).toList();

    // 구술자가 없으면 전체를 하나의 군집으로
    if (narrators.isEmpty) {
      if (autoNodes.isEmpty) return [];
      return [
        NarratorCluster(
          narratorId: '',
          nodeIds: autoNodes.map((n) => n.id).toSet(),
          color: _palette[0],
        ),
      ];
    }

    // Step 1: 각 노드를 가장 가까운 구술자 군집에 배정
    final nodeToNarrator = <String, String>{};

    // 구술자 자신은 자신 군집
    for (final n in narrators) {
      nodeToNarrator[n.id] = n.id;
    }

    // 나머지 노드: BFS 거리가 가장 짧은 구술자에 배정
    final nonNarrators =
        autoNodes.where((n) => !_narratorTypes.contains(n.type));
    for (final node in nonNarrators) {
      int minDist = 999999;
      String? bestNarrator;

      for (final narrator in narrators) {
        final dist = _bfsDistance(narrator.id, node.id, edges);
        if (dist < minDist) {
          minDist = dist;
          bestNarrator = narrator.id;
        }
      }

      // 연결이 전혀 없어도 첫 번째 구술자에 배정 (고립 노드 처리)
      nodeToNarrator[node.id] = bestNarrator ?? narrators.first.id;
    }

    // Step 2: 군집 생성
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
        color: _palette[idx % _palette.length],
      );
    }).toList();
  }

  /// 군집 박스들이 겹치지 않도록 노드 위치를 조정 (최대 maxIterations 반복)
  static void separateClusters(
      List<NarratorCluster> clusters,
      List<LayoutNode> nodes, {
      int maxIterations = 50,
  }) {
    for (int iter = 0; iter < maxIterations; iter++) {
      bool anyOverlap = false;

      for (int i = 0; i < clusters.length; i++) {
        for (int j = i + 1; j < clusters.length; j++) {
          final boxI = _clusterBounds(clusters[i], nodes);
          final boxJ = _clusterBounds(clusters[j], nodes);

          if (!boxI.overlaps(boxJ)) continue;
          anyOverlap = true;

          // 두 박스 중심 간 방향 벡터
          final cI = boxI.center;
          final cJ = boxJ.center;
          final dx = cI.dx - cJ.dx;
          final dy = cI.dy - cJ.dy;
          final dist = sqrt(dx * dx + dy * dy);
          if (dist < 1) continue;

          // 겹침 크기 계산
          final overlapX = (boxI.width + boxJ.width) / 2 - dx.abs() + 20;
          final overlapY = (boxI.height + boxJ.height) / 2 - dy.abs() + 20;

          // 각 방향으로 밀어낼 양
          final pushX = (overlapX > 0 ? overlapX / 2 : 0) * (dx / dist);
          final pushY = (overlapY > 0 ? overlapY / 2 : 0) * (dy / dist);

          // 군집 I는 +방향, 군집 J는 -방향으로 이동
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

  /// 군집의 노드 위치 기반 바운딩 박스 (패딩 포함)
  static Rect _clusterBounds(NarratorCluster cluster, List<LayoutNode> nodes,
      {double padding = 50}) {
    final cn = nodes.where((n) => cluster.nodeIds.contains(n.id)).toList();
    if (cn.isEmpty) return Rect.zero;

    double minX = cn.map((n) => n.x - n.radius).reduce(min) - padding;
    double maxX = cn.map((n) => n.x + n.radius).reduce(max) + padding;
    double minY = cn.map((n) => n.y - n.radius).reduce(min) - padding;
    double maxY = cn.map((n) => n.y + n.radius).reduce(max) + padding;

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// BFS 최단 거리 계산 (무방향 그래프)
  static int _bfsDistance(
      String from, String to, List<LayoutEdge> edges) {
    if (from == to) return 0;
    final visited = <String>{from};
    final queue = <(String, int)>[(from, 0)];

    while (queue.isNotEmpty) {
      final (current, dist) = queue.removeAt(0);
      for (final e in edges) {
        String? neighbor;
        if (e.sourceId == current) neighbor = e.targetId;
        if (e.targetId == current) neighbor = e.sourceId;
        if (neighbor == null || visited.contains(neighbor)) continue;
        if (neighbor == to) return dist + 1;
        visited.add(neighbor);
        queue.add((neighbor, dist + 1));
      }
    }
    return 999999; // 연결 없음 (고립 노드)
  }
}
