import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/oral_record.dart';
import '../../providers/record_provider.dart';

class RecordDetailScreen extends ConsumerStatefulWidget {
  final String recordId;
  const RecordDetailScreen({super.key, required this.recordId});

  @override
  ConsumerState<RecordDetailScreen> createState() => _RecordDetailScreenState();
}

class _RecordDetailScreenState extends ConsumerState<RecordDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  OralRecord? _record;
  List<Map<String, dynamic>> _usage = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(recordApiProvider);
      final record = await api.get(widget.recordId);
      final usage = await api.getUsage(widget.recordId);
      setState(() {
        _record = record;
        _usage = usage;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_record?.title ?? '기록 상세'),
        actions: [
          if (_record != null) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: '수정',
              onPressed: () => _showEditDialog(context),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '삭제',
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: '내용'),
            Tab(text: '트리플 생성 이력'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: const TextStyle(color: Colors.red)))
              : _record == null
                  ? const Center(child: Text('기록을 찾을 수 없습니다'))
                  : Column(children: [
                      // 메타 정보
                      _MetaBar(record: _record!),
                      const Divider(height: 1),
                      // 탭 콘텐츠
                      Expanded(
                        child: TabBarView(
                          controller: _tabCtrl,
                          children: [
                            _ContentTab(content: _record!.content ?? ''),
                            _UsageTab(usage: _usage),
                          ],
                        ),
                      ),
                    ]),
    );
  }

  void _showEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _EditDialog(
        record: _record!,
        onSaved: (title, note) async {
          await ref.read(recordListProvider.notifier).update(
                _record!.id,
                title: title,
                note: note,
              );
          await _load();
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('기록 삭제'),
        content: Text('"${_record!.title}"을 삭제하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final ok = await ref
                  .read(recordListProvider.notifier)
                  .delete(_record!.id);
              if (ok && mounted) Navigator.pop(context);
            },
            child: const Text('삭제',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ── 메타 바 ──────────────────────────────────────────────────────────────────

class _MetaBar extends StatelessWidget {
  final OralRecord record;
  const _MetaBar({required this.record});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        Icon(
          record.isFile ? Icons.description : Icons.text_snippet,
          size: 16,
          color: Colors.grey,
        ),
        const SizedBox(width: 6),
        Text(
          record.isFile ? '파일 · ${record.fileName}' : '텍스트 입력',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(width: 12),
        Text(record.dateLabel,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(width: 12),
        Text('${record.charCount}자',
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        if (record.note.isNotEmpty) ...[
          const SizedBox(width: 12),
          Expanded(
            child: Text('메모: ${record.note}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ]),
    );
  }
}

// ── 내용 탭 ──────────────────────────────────────────────────────────────────

class _ContentTab extends StatelessWidget {
  final String content;
  const _ContentTab({required this.content});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        content.isEmpty ? '(내용 없음)' : content,
        style: const TextStyle(fontSize: 14, height: 1.6),
      ),
    );
  }
}

// ── 사용 이력 탭 ─────────────────────────────────────────────────────────────

class _UsageTab extends StatelessWidget {
  final List<Map<String, dynamic>> usage;
  const _UsageTab({required this.usage});

  @override
  Widget build(BuildContext context) {
    if (usage.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 40, color: Colors.grey),
            SizedBox(height: 8),
            Text('트리플 생성 이력이 없습니다',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: usage.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final s = usage[i];
        final status = s['status'] ?? '';
        final date = (s['created_at'] as String? ?? '').substring(0, 10);
        return ListTile(
          dense: true,
          leading: Icon(
            status == 'completed' ? Icons.check_circle : Icons.circle_outlined,
            color: status == 'completed' ? Colors.green : Colors.grey,
            size: 18,
          ),
          title: Text(s['ontology_version_id'] ?? '',
              style: const TextStyle(fontSize: 13)),
          subtitle: Text(
            '추출 ${s['extracted_count'] ?? 0}개 → 확정 ${s['confirmed_count'] ?? 0}개',
            style: const TextStyle(fontSize: 11),
          ),
          trailing: Text(date,
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        );
      },
    );
  }
}

// ── 수정 다이얼로그 ───────────────────────────────────────────────────────────

class _EditDialog extends StatefulWidget {
  final OralRecord record;
  final Future<void> Function(String title, String note) onSaved;
  const _EditDialog({required this.record, required this.onSaved});

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late TextEditingController _titleCtrl;
  late TextEditingController _noteCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.record.title);
    _noteCtrl = TextEditingController(text: widget.record.note);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('기록 수정'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                  labelText: '제목', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                  labelText: '메모', border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소')),
        ElevatedButton(
          onPressed: _saving
              ? null
              : () async {
                  setState(() => _saving = true);
                  await widget.onSaved(
                      _titleCtrl.text.trim(), _noteCtrl.text.trim());
                  if (mounted) Navigator.pop(context);
                },
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('저장'),
        ),
      ],
    );
  }
}
