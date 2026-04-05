// lib/src/presentation/screens/outputs_screen.dart
// 에이전트 산출물 목록 화면

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/agent_output_provider.dart';
import '../theme/app_theme.dart';
import '../../../agents/core/agent_output.dart';

class OutputsScreen extends ConsumerStatefulWidget {
  const OutputsScreen({super.key});

  @override
  ConsumerState<OutputsScreen> createState() => _OutputsScreenState();
}

class _OutputsScreenState extends ConsumerState<OutputsScreen> {
  OutputType? _filter; // null = 전체

  @override
  void initState() {
    super.initState();
    // 화면 진입 시 파일 존재 여부 갱신
    Future.microtask(
        () => ref.read(agentOutputProvider.notifier).refreshFileStatus());
  }

  @override
  Widget build(BuildContext context) {
    final outputs = ref.watch(agentOutputProvider);
    final filtered = _filter == null
        ? outputs
        : outputs.where((o) => o.type == _filter).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: const Text('산출물', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: '파일 상태 갱신',
            onPressed: () =>
                ref.read(agentOutputProvider.notifier).refreshFileStatus(),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, size: 20),
            tooltip: '전체 삭제',
            onPressed: outputs.isEmpty ? null : _confirmClear,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: _FilterBar(
            current: _filter,
            onChanged: (t) => setState(() => _filter = t),
          ),
        ),
      ),
      body: filtered.isEmpty
          ? _EmptyState(hasFilter: _filter != null)
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: filtered.length,
              itemBuilder: (context, i) => _OutputTile(
                output: filtered[i],
                onDelete: () =>
                    ref.read(agentOutputProvider.notifier).deleteOutput(filtered[i].id),
              ),
            ),
    );
  }

  void _confirmClear() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('전체 삭제'),
        content: const Text('모든 산출물 기록을 삭제합니다.\n실제 파일은 삭제되지 않습니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('삭제')),
        ],
      ),
    ).then((ok) {
      if (ok == true) ref.read(agentOutputProvider.notifier).clearAll();
    });
  }
}

// ── 필터 탭 바 ─────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final OutputType? current;
  final ValueChanged<OutputType?> onChanged;

  const _FilterBar({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = <(OutputType?, String)>[
      (null, '전체'),
      (OutputType.report, '보고서'),
      (OutputType.book, '생애사 책'),
      (OutputType.summary, '요약집'),
      (OutputType.exportCsv, 'CSV'),
      (OutputType.exportJson, 'JSON'),
    ];

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: items.map((item) {
          final (type, label) = item;
          final selected = current == type;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: Text(label, style: const TextStyle(fontSize: 11)),
              selected: selected,
              onSelected: (_) => onChanged(type),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── 항목 타일 ─────────────────────────────────────────

class _OutputTile extends StatelessWidget {
  final AgentOutput output;
  final VoidCallback onDelete;

  const _OutputTile({required this.output, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final type = output.type;
    final (icon, color) = _typeStyle(type);
    final sizeLabel = _sizeLabel(output.fileSizeBytes);
    final dateLabel = _dateLabel(output.executedAt);
    final promptPreview = output.enhancedPrompt.isNotEmpty
        ? output.enhancedPrompt
        : output.userPrompt;
    final preview = promptPreview.length > 40
        ? '${promptPreview.substring(0, 40)}…'
        : promptPreview;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppTheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showDetail(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // 타입 아이콘
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              // 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            output.fileName,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!output.fileExists)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.warning_amber,
                                size: 14, color: Colors.orange),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      preview,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(dateLabel,
                            style: const TextStyle(
                                fontSize: 10, color: AppTheme.textDisabled)),
                        const SizedBox(width: 8),
                        if (output.userAccount.isNotEmpty) ...[
                          Text(output.userAccount,
                              style: const TextStyle(
                                  fontSize: 10, color: AppTheme.textDisabled)),
                          const SizedBox(width: 8),
                        ],
                        Text(sizeLabel,
                            style: const TextStyle(
                                fontSize: 10, color: AppTheme.textDisabled)),
                      ],
                    ),
                  ],
                ),
              ),
              // 버튼
              const SizedBox(width: 6),
              _ActionButtons(output: output, onDelete: onDelete),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _OutputDetailDialog(output: output),
    );
  }

  (IconData, Color) _typeStyle(OutputType type) {
    switch (type) {
      case OutputType.report:
        return (Icons.description_outlined, AppTheme.primaryLight);
      case OutputType.book:
        return (Icons.menu_book_outlined, Colors.purple.shade400);
      case OutputType.summary:
        return (Icons.summarize_outlined, Colors.teal.shade400);
      case OutputType.exportCsv:
        return (Icons.table_chart_outlined, Colors.green.shade500);
      case OutputType.exportJson:
        return (Icons.data_object, Colors.orange.shade500);
    }
  }

  String _sizeLabel(int bytes) {
    if (bytes == 0) return '-';
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ── 액션 버튼 ─────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  final AgentOutput output;
  final VoidCallback onDelete;

  const _ActionButtons({required this.output, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.open_in_new, size: 16),
          tooltip: '파일 열기',
          visualDensity: VisualDensity.compact,
          onPressed: output.fileExists ? () => _openFile(output.filePath) : null,
        ),
        IconButton(
          icon: const Icon(Icons.folder_open_outlined, size: 16),
          tooltip: '폴더 열기',
          visualDensity: VisualDensity.compact,
          onPressed: () => _openFolder(output.filePath),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 16),
          tooltip: '기록 삭제',
          visualDensity: VisualDensity.compact,
          color: AppTheme.error,
          onPressed: onDelete,
        ),
      ],
    );
  }

  Future<void> _openFile(String path) async {
    final uri = Uri.file(path);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openFolder(String path) async {
    final dir = File(path).parent.path;
    final uri = Uri.file(dir);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}

// ── 상세 다이얼로그 ─────────────────────────────────────

class _OutputDetailDialog extends StatelessWidget {
  final AgentOutput output;
  const _OutputDetailDialog({required this.output});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.info_outline, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(output.fileName,
                style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow('유형', output.type.label),
            _DetailRow('계정', output.userAccount.isEmpty ? '-' : output.userAccount),
            _DetailRow('생성일시', _fullDate(output.executedAt)),
            _DetailRow('파일 경로', output.filePath),
            _DetailRow('파일 상태', output.fileExists ? '존재' : '파일 없음'),
            const Divider(height: 16),
            const Text('원본 프롬프트',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(output.userPrompt,
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            if (output.enhancedPrompt.isNotEmpty &&
                output.enhancedPrompt != output.userPrompt) ...[
              const SizedBox(height: 8),
              const Text('개선된 프롬프트',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(output.enhancedPrompt,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('닫기'),
        ),
      ],
    );
  }

  String _fullDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }
}

// ── 빈 상태 ──────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasFilter;
  const _EmptyState({required this.hasFilter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.folder_open_outlined,
              size: 48, color: AppTheme.textDisabled),
          const SizedBox(height: 12),
          Text(
            hasFilter ? '해당 유형의 산출물이 없습니다' : '아직 산출물이 없습니다',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.textDisabled),
          ),
          const SizedBox(height: 4),
          Text(
            '에이전트가 문서를 생성하면 여기에 표시됩니다',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.textDisabled),
          ),
        ],
      ),
    );
  }
}
