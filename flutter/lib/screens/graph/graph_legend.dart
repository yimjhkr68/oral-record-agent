import 'package:flutter/material.dart';
import '../../widgets/graph/graph_painter.dart';

/// 하단 범례 — 탭으로 접기/펼치기
class GraphLegend extends StatefulWidget {
  const GraphLegend({super.key});

  @override
  State<GraphLegend> createState() => _GraphLegendState();
}

class _GraphLegendState extends State<GraphLegend> {
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
          child: _expanded ? _expandedView() : _collapsedView(),
        ),
      ),
    );
  }

  Widget _expandedView() {
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: graphClassColors.entries.map((e) {
        return Row(mainAxisSize: MainAxisSize.min, children: [
          _dot(e.value),
          const SizedBox(width: 4),
          Text(e.key,
              style: const TextStyle(color: Colors.white, fontSize: 10)),
        ]);
      }).toList(),
    );
  }

  Widget _collapsedView() {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      ...graphClassColors.entries.take(5).map((e) => Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _dot(e.value),
          )),
      const Text('범례 ▸',
          style: TextStyle(color: Colors.white70, fontSize: 10)),
    ]);
  }

  Widget _dot(Color color) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
