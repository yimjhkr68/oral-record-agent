import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/history.dart';
import '../../providers/history_provider.dart';

class OntologyHistoryTab extends ConsumerStatefulWidget {
  const OntologyHistoryTab({super.key});

  @override
  ConsumerState<OntologyHistoryTab> createState() => _OntologyHistoryTabState();
}

class _OntologyHistoryTabState extends ConsumerState<OntologyHistoryTab> {
  bool _selectMode = false;
  final Set<String> _selectedIds = {};

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _deleteBulk() async {
    final ids = List<String>.from(_selectedIds);
    _exitSelectMode();
    await ref.read(ontologyEventProvider.notifier).deleteBulk(ids);
  }

  Future<void> _deleteSingle(String id) async {
    await ref.read(ontologyEventProvider.notifier).deleteSingle(id);
  }

  Future<void> _clearAll(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('온톨로지 이력 전체 삭제'),
        content: const Text('모든 온톨로지 이력을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('전체 삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(ontologyEventProvider.notifier).clearAll();
  }

  @override
  Widget build(BuildContext context) {
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

    return Column(
      children: [
        // ── 액션 바 ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              TextButton.icon(
                icon: Icon(
                    _selectMode ? Icons.close : Icons.checklist,
                    size: 16),
                label: Text(
                    _selectMode ? '취소' : '선택 삭제',
                    style: const TextStyle(fontSize: 12)),
                onPressed: () {
                  if (_selectMode) {
                    _exitSelectMode();
                  } else {
                    setState(() => _selectMode = true);
                  }
                },
              ),
              if (_selectMode && _selectedIds.isNotEmpty) ...[
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6)),
                  icon: const Icon(Icons.delete, size: 16, color: Colors.white),
                  label: Text('${_selectedIds.length}개 삭제',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12)),
                  onPressed: _deleteBulk,
                ),
              ],
              if (!_selectMode) ...[
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.delete_sweep,
                      color: Colors.red, size: 16),
                  label: const Text('전체 삭제',
                      style: TextStyle(color: Colors.red, fontSize: 12)),
                  onPressed: state.events.isEmpty
                      ? null
                      : () => _clearAll(context),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        // ── 목록 ────────────────────────────────────────────────────────────
        if (state.events.isEmpty)
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_edu, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('온톨로지 이력이 없습니다',
                      style: TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: state.events.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 48),
              itemBuilder: (_, i) {
                final event = state.events[i];
                return _EventTile(
                  event: event,
                  selectMode: _selectMode,
                  selected: _selectedIds.contains(event.id),
                  onToggle: () => _toggleSelect(event.id),
                  onDelete: () => _deleteSingle(event.id),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _EventTile extends StatelessWidget {
  final OntologyEvent event;
  final bool selectMode;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _EventTile({
    required this.event,
    required this.selectMode,
    required this.selected,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      onTap: selectMode ? onToggle : null,
      leading: selectMode
          ? Checkbox(
              value: selected,
              onChanged: (_) => onToggle(),
            )
          : _EventIcon(eventType: event.eventType),
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
      trailing: selectMode
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(event.dateLabel,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.grey)),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 16, color: Colors.red),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: '삭제',
                  onPressed: onDelete,
                ),
              ],
            ),
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
