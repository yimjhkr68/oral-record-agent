// lib/src/presentation/widgets/history_detail_window.dart
// 실행 이력 상세 창 — 프롬프트 3종 + 단계별 로그 + 재실행 버튼

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../agents/core/agent_history.dart';
import '../providers/agent_state_provider.dart';
import '../theme/app_theme.dart';

class HistoryDetailWindow extends ConsumerWidget {
  final AgentHistoryEntry entry;

  const HistoryDetailWindow({super.key, required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promptOriginal = _extractByLogType(HistoryLogType.promptOriginal);
    final promptEnhanced = _extractByLogType(HistoryLogType.promptEnhanced);
    final promptExecuted = _extractByLogType(HistoryLogType.promptExecuted);
    final executedPrompt =
        promptExecuted ?? promptEnhanced ?? promptOriginal ?? entry.inputText;

    final statusColor = switch (entry.status) {
      AgentHistoryStatus.success => Colors.green.shade600,
      AgentHistoryStatus.failed => AppTheme.error,
      AgentHistoryStatus.cancelled => Colors.orange.shade600,
      AgentHistoryStatus.noResults => Colors.grey.shade500,
    };
    final statusLabel = switch (entry.status) {
      AgentHistoryStatus.success => '완료',
      AgentHistoryStatus.failed => '실패',
      AgentHistoryStatus.cancelled => '취소',
      AgentHistoryStatus.noResults => '결과 없음',
    };

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 700,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 헤더 ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              decoration: const BoxDecoration(
                color: Color(0xFF1E2736),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.title,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _formatDateTime(entry.createdAt),
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 11),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54,
                        size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // ── 스크롤 가능 본문 ───────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 프롬프트 섹션
                    if (promptOriginal != null || promptEnhanced != null ||
                        promptExecuted != null) ...[
                      _sectionLabel('프롬프트'),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            if (promptOriginal != null)
                              _PromptRow(
                                  label: '원본', text: promptOriginal),
                            if (promptEnhanced != null) ...[
                              const Divider(height: 1),
                              _PromptRow(
                                  label: '개선', text: promptEnhanced),
                            ],
                            if (promptExecuted != null &&
                                promptExecuted != promptOriginal) ...[
                              const Divider(height: 1),
                              _PromptRow(
                                  label: '실행', text: promptExecuted),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // 단계별 로그
                    _sectionLabel('실행 로그'),
                    const SizedBox(height: 8),
                    ...entry.steps
                        .where((s) => s.logType != 'promptOriginal' &&
                            s.logType != 'promptEnhanced' &&
                            s.logType != 'promptExecuted')
                        .map((s) => _LogCard(item: s)),
                  ],
                ),
              ),
            ),

            // ── 하단 버튼 ──────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                children: [
                  // 전체 복사
                  TextButton.icon(
                    icon: const Icon(Icons.copy_all, size: 15),
                    label: const Text('전체 텍스트 복사'),
                    onPressed: () => _copyAll(context),
                  ),
                  const Spacer(),
                  // 재실행
                  FilledButton.icon(
                    icon: const Icon(Icons.replay, size: 15),
                    label: const Text('이 프롬프트로 재실행'),
                    onPressed: () {
                      ref
                          .read(agentStateProvider.notifier)
                          .requestInputRestore(executedPrompt);
                      Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('닫기'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _extractByLogType(HistoryLogType type) {
    final match = entry.steps
        .where((s) => s.logType == type.name)
        .lastOrNull;
    return match?.detail.isEmpty == false ? match?.detail : null;
  }

  void _copyAll(BuildContext context) {
    final sb = StringBuffer();
    sb.writeln('=== 실행 이력: ${entry.title} ===');
    sb.writeln('시각: ${_formatDateTime(entry.createdAt)}');
    sb.writeln('상태: ${entry.status.name}');
    sb.writeln();
    for (final s in entry.steps) {
      sb.writeln('[${s.step}] ${s.detail}');
    }
    Clipboard.setData(ClipboardData(text: sb.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('전체 텍스트가 복사됐어요'),
          duration: Duration(seconds: 2)),
    );
  }

  String _formatDateTime(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary),
      );
}

class _PromptRow extends StatelessWidget {
  final String label;
  final String text;

  const _PromptRow({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              text,
              style: const TextStyle(fontSize: 13),
              contextMenuBuilder: (ctx, state) =>
                  AdaptiveTextSelectionToolbar.editableText(
                      editableTextState: state),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  final HistoryLogItem item;

  const _LogCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _stepStyle();
    final timeStr =
        '${item.timestamp.hour.toString().padLeft(2, '0')}:'
        '${item.timestamp.minute.toString().padLeft(2, '0')}:'
        '${item.timestamp.second.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: item.isError
              ? AppTheme.error.withValues(alpha: 0.05)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: item.isError
                ? AppTheme.error.withValues(alpha: 0.25)
                : AppTheme.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 5),
                Text(
                  item.step,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color),
                ),
                const SizedBox(width: 6),
                Text(
                  timeStr,
                  style: const TextStyle(
                      fontSize: 10, color: AppTheme.textDisabled),
                ),
                const Spacer(),
                if (item.isError)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '실패',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.error,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            SelectableText(
              item.detail,
              style: TextStyle(
                  fontSize: 12,
                  color: item.isError
                      ? AppTheme.error
                      : AppTheme.textPrimary,
                  height: 1.5),
              contextMenuBuilder: (ctx, state) =>
                  AdaptiveTextSelectionToolbar.editableText(
                      editableTextState: state),
            ),
          ],
        ),
      ),
    );
  }

  (IconData, Color) _stepStyle() {
    if (item.isError) return (Icons.error_outline, AppTheme.error);
    switch (item.logType) {
      case 'searchQuery':
        return (Icons.search, AppTheme.primaryLight);
      case 'searchResult':
        return (Icons.list_alt_outlined, AppTheme.primaryLight);
      case 'searchConfirmed':
        return (Icons.check_circle_outline, Colors.green.shade600);
      case 'agentComplete':
        return (Icons.done_all, Colors.green.shade600);
      case 'toolError':
        return (Icons.error_outline, AppTheme.error);
    }
    switch (item.step) {
      case '완료':
        return (Icons.done_all, Colors.green.shade600);
      case '분석':
        return (Icons.psychology_outlined, AppTheme.primaryLight);
      case '검색':
        return (Icons.search, AppTheme.primaryLight);
      case '선택':
        return (Icons.check_circle_outline, Colors.green.shade600);
      case '실행':
        return (Icons.settings_outlined, AppTheme.primaryLight);
      case '제외':
        return (Icons.remove_circle_outline, Colors.orange.shade700);
      case '안내':
        return (Icons.info_outline, Colors.blue.shade600);
      default:
        return (Icons.info_outline, AppTheme.textSecondary);
    }
  }
}
