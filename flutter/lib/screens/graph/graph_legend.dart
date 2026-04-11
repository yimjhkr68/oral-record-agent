import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/graph_provider.dart';
import '../../services/graph_color_settings.dart';

/// 하단 범례 — 탭으로 접기/펼치기 + 색상 점 클릭으로 색상 변경
class GraphLegend extends ConsumerStatefulWidget {
  const GraphLegend({super.key});

  @override
  ConsumerState<GraphLegend> createState() => _GraphLegendState();
}

class _GraphLegendState extends ConsumerState<GraphLegend> {
  bool _expanded = false;

  /// 그래프에 실제 등장하는 클래스 타입 집합
  Set<String> get _usedTypes {
    final nodes = ref.read(graphProvider).nodes;
    return nodes.map((n) => n.type).toSet();
  }

  Future<void> _editColor(String className) async {
    final current = GraphColorSettings.colorFor(className);
    Color picked = current;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$className 색상 변경'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: current,
            onColorChanged: (c) => picked = c,
            pickerAreaHeightPercent: 0.6,
            enableAlpha: false,
            labelTypes: const [],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await GraphColorSettings.resetColor(className);
              // dialog 자신의 ctx 사용 — outer context 사용 시 graph screen이 팝됨
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const Text('기본값으로'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('적용'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await GraphColorSettings.setColor(className, picked);
      if (!mounted) return;
      // 그래프 강제 갱신
      ref.read(graphProvider.notifier).applyColorSettings();
      setState(() {}); // 범례 색상 갱신
    }
  }

  @override
  Widget build(BuildContext context) {
    // 실제 사용 중인 클래스만 표시 — 중요도순 정렬 (Narrator 계열 우선)
    const priorityOrder = [
      'Narrator', 'OralNarrator', 'OralHistoryNarrator',
      'Victim', 'Survivor', 'SurvivorFamily', 'Witness',
      'Person', 'Interviewer',
      'HistoricalEvent', 'HistoricalMassacreEvent', 'TraumaticEvent', 'Event',
      'OralHistoryRecord', 'NarrativeSession',
      'Place', 'Location', 'AdministrativeRegion',
      'Organization', 'Community',
      'Time', 'Date', 'HistoricalPeriod',
      'Emotion', 'Trauma', 'TraumaticExperience',
      'HistoricalActor', 'MilitaryUnit', 'Perpetrator',
      'Topic', 'Policy', 'Object', 'Collection', 'Document',
    ];
    final used = _usedTypes;
    final allEntries = GraphColorSettings.currentColors.entries
        .where((e) => used.isEmpty || used.contains(e.key))
        .toList();
    allEntries.sort((a, b) {
      final ia = priorityOrder.indexOf(a.key);
      final ib = priorityOrder.indexOf(b.key);
      if (ia == -1 && ib == -1) return a.key.compareTo(b.key);
      if (ia == -1) return 1;
      if (ib == -1) return -1;
      return ia.compareTo(ib);
    });
    final entries = allEntries;

    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: _expanded
              ? _expandedView(entries)
              : _collapsedView(entries),
        ),
      ),
    );
  }

  Widget _expandedView(List<MapEntry<String, Color>> entries) {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: entries.map((e) {
        final isCustom = GraphColorSettings.customizedClasses.contains(e.key);
        return GestureDetector(
          onTap: () {
            _editColor(e.key);
          },
          child: Tooltip(
            message: '탭하여 색상 변경',
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _dot(e.value, border: isCustom),
              const SizedBox(width: 4),
              Text(e.key,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: isCustom
                        ? FontWeight.bold
                        : FontWeight.normal,
                  )),
            ]),
          ),
        );
      }).toList(),
    );
  }

  Widget _collapsedView(List<MapEntry<String, Color>> entries) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      ...entries.take(5).map((e) => Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _dot(e.value),
          )),
      const Text('범례 ▸',
          style: TextStyle(color: Colors.white70, fontSize: 10)),
    ]);
  }

  Widget _dot(Color color, {bool border = false}) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: border
              ? Border.all(color: Colors.white, width: 1.5)
              : null,
        ),
      );
}
