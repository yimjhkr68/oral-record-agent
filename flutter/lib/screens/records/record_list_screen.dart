import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/oral_record.dart';
import '../../providers/record_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/empty_state.dart';
import 'record_detail_screen.dart';

class RecordListScreen extends ConsumerStatefulWidget {
  const RecordListScreen({super.key});

  @override
  ConsumerState<RecordListScreen> createState() => _RecordListScreenState();
}

class _RecordListScreenState extends ConsumerState<RecordListScreen> {
  final _searchCtrl = TextEditingController();
  String _sourceTypeFilter = ''; // '' | 'file' | 'text'
  String _sourceFilter = '';     // '' | 'manual' | 'ontology' | 'triple'

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _reload() {
    ref.read(recordListProvider.notifier).load(
          q: _searchCtrl.text.trim(),
          sourceType: _sourceTypeFilter,
          source: _sourceFilter,
        );
  }

  // ── 파일 업로드 ──────────────────────────────────────────────────────────────

  Future<void> _uploadFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['txt', 'pdf', 'docx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    int uploaded = 0;
    int failed = 0;
    for (final pf in result.files) {
      try {
        final bytes = pf.bytes ?? File(pf.path!).readAsBytesSync();
        await ref.read(recordListProvider.notifier).createFileFromBytes(
              bytes: bytes,
              fileName: pf.name,
              source: 'manual',
            );
        uploaded++;
      } catch (_) {
        failed++;
      }
    }

    if (!mounted) return;
    final msg = failed == 0
        ? '$uploaded개 기록 등록 완료'
        : '$uploaded개 등록 완료 ($failed개 실패)';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── 파일 다운로드 ────────────────────────────────────────────────────────────

  Future<void> _downloadFile(OralRecord record) async {
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: '파일 저장',
      fileName: record.fileName.isNotEmpty
          ? record.fileName
          : '${record.title}.${record.fileExt}',
    );
    if (savePath == null) return;

    try {
      final bytes =
          await ref.read(recordApiProvider).downloadFile(record.id);
      await File(savePath).writeAsBytes(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 완료: $savePath')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('다운로드 실패: $e')),
      );
    }
  }

  // ── 내용 보기 다이얼로그 ─────────────────────────────────────────────────────

  void _showContent(OralRecord record) async {
    // 상세 내용 로드 (목록에는 200자 preview만 있음)
    OralRecord full = record;
    if (record.content == null) {
      try {
        full = await ref.read(recordApiProvider).get(record.id);
      } catch (_) {}
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Expanded(
            child: Text(full.title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15)),
          ),
          if (full.hasFile)
            IconButton(
              icon: const Icon(Icons.download_outlined, size: 18),
              tooltip: '파일 다운로드',
              onPressed: () {
                Navigator.of(ctx).pop();
                _downloadFile(full);
              },
            ),
        ]),
        content: SizedBox(
          width: 600,
          height: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                _SourceBadge(source: full.source),
                const SizedBox(width: 8),
                Text('${_fmtCount(full.charCount)}자',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
                const SizedBox(width: 8),
                Text(
                    full.createdAt.length >= 16
                        ? full.createdAt.substring(0, 16)
                        : full.createdAt,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
              ]),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Expanded(
                child: Scrollbar(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      full.content ?? full.contentPreview ?? '',
                      style:
                          const TextStyle(fontSize: 13, height: 1.7),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('구술기록'),
        actions: [
          // 파일 등록 버튼
          TextButton.icon(
            icon: const Icon(Icons.upload_file, size: 16),
            label: const Text('파일 등록'),
            onPressed: _uploadFiles,
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
            onPressed: _reload,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.edit_note),
        label: const Text('텍스트 입력'),
        onPressed: () => _showCreateDialog(context),
      ),
      body: Column(
        children: [
          // ── 검색 + 필터 ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
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
                              _reload();
                            },
                          )
                        : null,
                  ),
                  onSubmitted: (_) => _reload(),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ]),
          ),

          // ── 필터 칩 행 ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Row(children: [
              // 타입 필터
              _FilterChip(
                label: '전체',
                selected: _sourceTypeFilter.isEmpty,
                onTap: () {
                  setState(() => _sourceTypeFilter = '');
                  _reload();
                },
              ),
              const SizedBox(width: 4),
              _FilterChip(
                label: '파일',
                selected: _sourceTypeFilter == 'file',
                onTap: () {
                  setState(() => _sourceTypeFilter = 'file');
                  _reload();
                },
              ),
              const SizedBox(width: 4),
              _FilterChip(
                label: '텍스트',
                selected: _sourceTypeFilter == 'text',
                onTap: () {
                  setState(() => _sourceTypeFilter = 'text');
                  _reload();
                },
              ),
              const SizedBox(width: 12),
              const Text('|',
                  style: TextStyle(color: AppColors.border, fontSize: 16)),
              const SizedBox(width: 12),
              // 출처 필터
              _FilterChip(
                label: '전체출처',
                selected: _sourceFilter.isEmpty,
                onTap: () {
                  setState(() => _sourceFilter = '');
                  _reload();
                },
              ),
              const SizedBox(width: 4),
              _FilterChip(
                label: '수동',
                selected: _sourceFilter == 'manual',
                color: AppColors.textMuted,
                onTap: () {
                  setState(() => _sourceFilter = 'manual');
                  _reload();
                },
              ),
              const SizedBox(width: 4),
              _FilterChip(
                label: '온톨로지',
                selected: _sourceFilter == 'ontology',
                color: AppColors.primary,
                onTap: () {
                  setState(() => _sourceFilter = 'ontology');
                  _reload();
                },
              ),
              const SizedBox(width: 4),
              _FilterChip(
                label: '트리플',
                selected: _sourceFilter == 'triple',
                color: AppColors.secondary,
                onTap: () {
                  setState(() => _sourceFilter = 'triple');
                  _reload();
                },
              ),
            ]),
          ),

          // ── 상태 표시 ────────────────────────────────────────────────────
          if (state.loading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
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
                ? _EmptyView(
                    onUpload: _uploadFiles,
                    onAdd: () => _showCreateDialog(context),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: state.records.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) => _RecordCard(
                      record: state.records[i],
                      onView: () => _showContent(state.records[i]),
                      onDownload: state.records[i].hasFile
                          ? () => _downloadFile(state.records[i])
                          : null,
                      onDetail: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProviderScope(
                            child: RecordDetailScreen(
                                recordId: state.records[i].id),
                          ),
                        ),
                      ),
                    ),
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

// ── 필터 칩 ───────────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.5)
                : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? color : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

// ── 출처 배지 ─────────────────────────────────────────────────────────────────

class _SourceBadge extends StatelessWidget {
  final String source;
  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (source) {
      'ontology' => ('온톨로지', AppColors.primary),
      'triple' => ('트리플', AppColors.secondary),
      _ => ('수동', AppColors.textMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

// ── 기록 카드 ─────────────────────────────────────────────────────────────────

class _RecordCard extends ConsumerWidget {
  final OralRecord record;
  final VoidCallback onView;
  final VoidCallback? onDownload;
  final VoidCallback onDetail;

  const _RecordCard({
    required this.record,
    required this.onView,
    required this.onDetail,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      onTap: onDetail,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(children: [
        // 파일 타입 아이콘
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: _iconColor.withValues(alpha: 0.25)),
          ),
          child: Icon(_fileIcon, size: 18, color: _iconColor),
        ),
        const SizedBox(width: 12),

        // 제목 + 메타데이터
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(record.title,
                  style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Row(children: [
                _SourceBadge(source: record.source),
                const SizedBox(width: 6),
                Text('${_fmtCount(record.charCount)}자',
                    style: AppTypography.caption),
                const SizedBox(width: 6),
                Text(record.dateLabel, style: AppTypography.caption),
              ]),
            ],
          ),
        ),

        // 액션 버튼
        Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            icon: const Icon(Icons.visibility_outlined, size: 17),
            tooltip: '내용 보기',
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            onPressed: onView,
          ),
          if (onDownload != null) ...[
            const SizedBox(width: 2),
            IconButton(
              icon: const Icon(Icons.download_outlined, size: 17),
              tooltip: '파일 다운로드',
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              onPressed: onDownload,
            ),
          ],
          const SizedBox(width: 2),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 17, color: AppColors.textMuted),
            tooltip: '삭제',
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ]),
      ]),
    );
  }

  IconData get _fileIcon {
    switch (record.fileExt.toLowerCase()) {
      case 'docx':
        return Icons.description_outlined;
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'txt':
        return Icons.text_snippet_outlined;
      default:
        return record.isFile
            ? Icons.insert_drive_file_outlined
            : Icons.article_outlined;
    }
  }

  Color get _iconColor {
    switch (record.fileExt.toLowerCase()) {
      case 'docx':
        return Colors.blue;
      case 'pdf':
        return Colors.red;
      case 'txt':
        return AppColors.success;
      default:
        return record.isFile ? AppColors.secondary : AppColors.primary;
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('기록 삭제'),
        content: Text('"${record.title}"을 삭제하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('취소')),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(recordListProvider.notifier).delete(record.id);
            },
            child: const Text('삭제',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

// ── 빈 화면 ──────────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final VoidCallback onUpload;
  final VoidCallback onAdd;
  const _EmptyView({required this.onUpload, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.library_books_outlined,
      title: '등록된 구술기록이 없습니다',
      description: '텍스트를 입력하거나 파일을 불러와\n첫 번째 구술기록을 등록하세요.',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.upload_file, size: 16),
            label: const Text('파일 등록'),
            onPressed: onUpload,
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.edit_note, size: 16),
            label: const Text('텍스트 입력'),
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

// ── 유틸 ──────────────────────────────────────────────────────────────────────

String _fmtCount(int n) {
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
  return n.toString();
}
