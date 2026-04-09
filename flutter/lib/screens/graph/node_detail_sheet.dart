import 'package:flutter/material.dart';
import '../../models/triple.dart';
import '../../widgets/graph/graph_node_model.dart';
import '../../widgets/graph/graph_painter.dart';

/// 노드 탭 시 BottomSheet 표시
void showNodeDetailSheet(
  BuildContext context, {
  required String nodeId,
  required LayoutNode nodeData,
  required List<Triple> rawTriples,
}) {
  final connected =
      rawTriples.where((t) => t.subject == nodeId || t.object == nodeId).toList();
  final outgoing = connected.where((t) => t.subject == nodeId).toList();
  final incoming = connected.where((t) => t.object == nodeId).toList();
  final color = graphClassColors[nodeData.type] ?? Colors.blueGrey;

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.25,
      maxChildSize: 0.75,
      expand: false,
      builder: (_, scroll) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 드래그 핸들
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color,
                child: Text(
                  nodeId[0].toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nodeId,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(nodeData.type,
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
          // 트리플 목록
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.all(12),
              children: [
                if (outgoing.isNotEmpty) ...[
                  const _SectionHeader('나가는 관계'),
                  ...outgoing.map((t) => _TripleRow(t, nodeId)),
                ],
                if (incoming.isNotEmpty) ...[
                  const _SectionHeader('들어오는 관계'),
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

// ── 내부 위젯 ─────────────────────────────────────────────────────────────────

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
        child: Text('$label $value', style: const TextStyle(fontSize: 11)),
      );
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

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
              style:
                  DefaultTextStyle.of(context).style.copyWith(fontSize: 12),
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
