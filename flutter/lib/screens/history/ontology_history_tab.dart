import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/history.dart';
import '../../providers/history_provider.dart';

class OntologyHistoryTab extends ConsumerWidget {
  const OntologyHistoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ontologyEventProvider);

    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return Center(
        child: Text(state.error!,
            style: const TextStyle(color: Colors.red, fontSize: 13)),
      );
    }
    if (state.events.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_edu, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('온톨로지 이력이 없습니다',
                style: TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: state.events.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 48),
      itemBuilder: (_, i) => _EventTile(event: state.events[i]),
    );
  }
}

class _EventTile extends StatelessWidget {
  final OntologyEvent event;
  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: _EventIcon(eventType: event.eventType),
      title: Row(children: [
        Text(event.versionId,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(width: 8),
        _EventChip(eventType: event.eventType),
      ]),
      subtitle: event.detail.isNotEmpty
          ? Text(event.detail,
              style: const TextStyle(fontSize: 11, color: Colors.grey))
          : null,
      trailing: Text(event.dateLabel,
          style: const TextStyle(fontSize: 11, color: Colors.grey)),
    );
  }
}

class _EventIcon extends StatelessWidget {
  final String eventType;
  const _EventIcon({required this.eventType});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (eventType) {
      'confirmed' => (Icons.check_circle, Colors.green),
      'created'   => (Icons.add_circle_outline, Colors.blue),
      'updated'   => (Icons.edit, Colors.orange),
      'deleted'   => (Icons.delete_outline, Colors.red),
      'archived'  => (Icons.archive_outlined, Colors.grey),
      'generated' => (Icons.auto_awesome, Colors.purple),
      'merged'    => (Icons.merge, Colors.teal),
      _           => (Icons.circle_outlined, Colors.grey),
    };
    return Icon(icon, color: color, size: 20);
  }
}

class _EventChip extends StatelessWidget {
  final String eventType;
  const _EventChip({required this.eventType});

  @override
  Widget build(BuildContext context) {
    final label = switch (eventType) {
      'confirmed' => '확정',
      'created'   => '생성',
      'updated'   => '수정',
      'deleted'   => '삭제',
      'archived'  => '아카이브',
      'generated' => 'AI 생성',
      'merged'    => '병합',
      _           => eventType,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 10, color: Colors.grey)),
    );
  }
}
