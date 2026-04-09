import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oral_record_agent/widgets/graph/force_layout.dart';
import 'package:oral_record_agent/widgets/graph/graph_node_model.dart';

void main() {
  group('ForceLayout', () {
    test('initPositions — 모든 노드가 캔버스 안에 배치됨', () {
      final nodes = List.generate(
        6,
        (i) => LayoutNode(id: 'n$i', type: 'Person', degree: 1),
      );
      final layout = ForceLayout(
        nodes: nodes,
        edges: [],
        canvasSize: const Size(800, 600),
      );
      layout.initPositions();

      for (final n in nodes) {
        expect(n.x, greaterThan(0));
        expect(n.y, greaterThan(0));
        expect(n.x, lessThan(800));
        expect(n.y, lessThan(600));
      }
    });

    test('tick — 100틱 이내 수렴 (연결된 노드 4개)', () {
      final nodes = [
        LayoutNode(id: 'A', type: 'Person', degree: 2),
        LayoutNode(id: 'B', type: 'Place',  degree: 1),
        LayoutNode(id: 'C', type: 'Event',  degree: 2),
        LayoutNode(id: 'D', type: 'Person', degree: 1),
      ];
      final edges = [
        LayoutEdge(sourceId: 'A', targetId: 'B', predicate: '출생지'),
        LayoutEdge(sourceId: 'A', targetId: 'C', predicate: '참여'),
        LayoutEdge(sourceId: 'C', targetId: 'D', predicate: '관련'),
      ];
      final layout = ForceLayout(
        nodes: nodes,
        edges: edges,
        canvasSize: const Size(1200, 900),
      );
      layout.initPositions();

      bool converged = false;
      for (int i = 0; i < 100; i++) {
        converged = layout.tick();
        if (converged) break;
      }
      expect(converged, isTrue, reason: '100틱 내 수렴해야 함');
    });

    test('tick — 노드 없을 때 즉시 수렴', () {
      final layout = ForceLayout(
        nodes: [],
        edges: [],
        canvasSize: const Size(800, 600),
      );
      layout.initPositions();
      expect(layout.tick(), isTrue);
    });

    test('pinned 노드는 위치가 변하지 않음', () {
      final fixed = LayoutNode(id: 'F', type: 'Place', degree: 0,
          x: 400, y: 300);
      fixed.pinned = true;
      final other = LayoutNode(id: 'O', type: 'Person', degree: 1,
          x: 410, y: 310);
      final layout = ForceLayout(
        nodes: [fixed, other],
        edges: [],
        canvasSize: const Size(800, 600),
      );

      layout.tick();

      expect(fixed.x, equals(400));
      expect(fixed.y, equals(300));
    });
  });
}
