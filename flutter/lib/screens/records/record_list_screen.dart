import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/oral_record.dart';
import '../../providers/record_provider.dart';
import 'record_detail_screen.dart';

class RecordListScreen extends ConsumerStatefulWidget {
  const RecordListScreen({super.key});

  @override
  ConsumerState<RecordListScreen> createState() => _RecordListScreenState();
}

class _RecordListScreenState extends ConsumerState<RecordListScreen> {
  final _searchCtrl = TextEditingController();
  String _sourceFilter = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _search() {
    ref.read(recordListProvider.notifier).load(
          q: _searchCtrl.text.trim(),
          sourceType: _sourceFilter,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('구술기록'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
            onPressed: () => ref.read(recordListProvider.notifier).load(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('텍스트 입력'),
        onPressed: () => _showCreateDialog(context),
      ),
      body: Column(
        children: [
          // ── 검색 + 필터 ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: '제목 또는 내용 검색',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    border: const OutlineInputBorder(),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchCtrl.clear();
                              _search();
                            },
                          )
                        : null,
                  ),
                  onSubmitted: (_) => _search(),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _sourceFilter,
                isDense: true,
                items: const [
                  DropdownMenuItem(value: '', child: Text('전체')),
                  DropdownMenuItem(value: 'text', child: Text('텍스트')),
                  DropdownMenuItem(value: 'file', child: Text('파일')),
                ],
                onChanged: (v) {
                  setState(() => _sourceFilter = v ?? '');
                  _search();
                },
              ),
            ]),
          ),

          // ── 상태 표시 ────────────────────────────────────────────────────
          if (state.loading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: LinearProgressIndicator(),
            ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(state.error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
            ),

          // ── 목록 ─────────────────────────────────────────────────────────
          Expanded(
            child: state.records.isEmpty && !state.loading
                ? _EmptyView(onAdd: () => _showCreateDialog(context))
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: state.records.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) =>
                        _RecordCard(record: state.records[i]),
                  ),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _CreateTextDialog(),
    );
  }
}

// ── 기록 카드 ─────────────────────────────────────────────────────────────────

class _RecordCard extends ConsumerWidget {
  final OralRecord record;
  const _RecordCard({required this.record});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProviderScope(
                child: RecordDetailScreen(recordId: record.id),
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            // 타입 아이콘
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: record.isFile
                    ? Colors.blue.shade50
                    : Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                record.isFile ? Icons.description : Icons.text_snippet,
                size: 18,
                color:
                    record.isFile ? Colors.blue.shade700 : Colors.green.shade700,
              ),
            ),
            const SizedBox(width: 12),
            // 제목 + 미리보기
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(record.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  if (record.contentPreview != null)
                    Text(record.contentPreview!,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 날짜 + 글자수
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(record.dateLabel,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.grey)),
                Text('${_fmt(record.charCount)}자',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.grey)),
              ],
            ),
            // 삭제 버튼
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              color: Colors.grey,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              onPressed: () => _confirmDelete(context, ref),
            ),
          ]),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('기록 삭제'),
        content: Text('"${record.title}"을 삭제하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(recordListProvider.notifier).delete(record.id);
            },
            child:
                const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }
}

// ── 빈 화면 ──────────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyView({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.library_books_outlined,
              size: 56, color: Colors.grey),
          const SizedBox(height: 12),
          const Text('등록된 구술기록이 없습니다',
              style: TextStyle(fontSize: 15, color: Colors.grey)),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('첫 기록 등록'),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

// ── 텍스트 입력 다이얼로그 ────────────────────────────────────────────────────

class _CreateTextDialog extends ConsumerStatefulWidget {
  const _CreateTextDialog();

  @override
  ConsumerState<_CreateTextDialog> createState() => _CreateTextDialogState();
}

class _CreateTextDialogState extends ConsumerState<_CreateTextDialog> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (title.isEmpty || content.isEmpty) {
      setState(() => _error = '제목과 내용을 입력해 주세요.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final record = await ref.read(recordListProvider.notifier).createText(
          title: title,
          content: content,
          note: _noteCtrl.text.trim(),
        );
    if (!mounted) return;
    if (record != null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${record.title}" 등록 완료')),
      );
    } else {
      setState(() {
        _saving = false;
        _error = '저장 실패';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('구술기록 텍스트 입력'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: '제목 *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _contentCtrl,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: '구술 텍스트 *',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _noteCtrl,
                decoration: const InputDecoration(
                  labelText: '메모 (선택)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
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
