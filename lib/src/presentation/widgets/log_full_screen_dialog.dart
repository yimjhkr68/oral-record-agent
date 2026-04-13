// lib/src/presentation/widgets/log_full_screen_dialog.dart
// 에이전트 로그 전체화면 보기 다이얼로그

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/agent_state_provider.dart';
import '../theme/app_theme.dart';

class LogFullScreenDialog extends ConsumerStatefulWidget {
  const LogFullScreenDialog({super.key});

  @override
  ConsumerState<LogFullScreenDialog> createState() =>
      _LogFullScreenDialogState();
}

class _LogFullScreenDialogState
    extends ConsumerState<LogFullScreenDialog> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(agentLogProvider);
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = screenSize.width < 950 ? screenSize.width - 32 : 900.0;

    return Dialog(
      backgroundColor: AppTheme.background,
      insetPadding: EdgeInsets.symmetric(
        horizontal: ((screenSize.width - dialogWidth) / 2).clamp(8.0, double.infinity),
        vertical: screenSize.height * 0.05,
      ),
      child: SizedBox(
        width: dialogWidth,
        height: screenSize.height * 0.9,
        child: Column(
          children: [
            _DialogHeader(logs: logs),
            const Divider(height: 1, color: AppTheme.border),
            Expanded(
              child: logs.isEmpty
                  ? const Center(
                      child: Text('로그 없음',
                          style: TextStyle(
                              color: AppTheme.textDisabled, fontSize: 13)),
                    )
                  : Row(
                      children: [
                        SizedBox(
                          width: 280,
                          child: _TimelinePanel(
                            logs: logs,
                            selectedIndex: _selectedIndex,
                            onSelect: (i) =>
                                setState(() => _selectedIndex = i),
                          ),
                        ),
                        const VerticalDivider(
                            width: 1, color: AppTheme.border),
                        Expanded(
                          child: _selectedIndex != null
                              ? _DetailPanel(entry: logs[_selectedIndex!])
                              : const Center(
                                  child: Text('항목을 선택하세요',
                                      style: TextStyle(
                                          color: AppTheme.textDisabled,
                                          fontSize: 13)),
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
}

// ── 헤더 ─────────────────────────────────────────────────

class _DialogHeader extends StatelessWidget {
  final List<AgentLogEntry> logs;
  const _DialogHeader({required this.logs});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.list_alt_outlined,
              size: 16, color: AppTheme.primaryLight),
          const SizedBox(width: 8),
          Text(
            '에이전트 로그 (${logs.length}건)',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (logs.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                final all = logs
                    .map((e) =>
                        '[${_fmtTime(e.timestamp)}] ${e.step}: ${e.detail}')
                    .join('\n');
                Clipboard.setData(ClipboardData(text: all));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('로그를 클립보드에 복사했습니다'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.copy_outlined, size: 13),
              label: const Text('전체 복사', style: TextStyle(fontSize: 11)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }

  static String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';
}

// ── 타임라인 패널 ─────────────────────────────────────────

class _TimelinePanel extends StatelessWidget {
  final List<AgentLogEntry> logs;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;

  const _TimelinePanel({
    required this.logs,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: logs.length,
      itemBuilder: (ctx, i) {
        final entry = logs[i];
        final isSelected = selectedIndex == i;
        final isLast = i == logs.length - 1;

        return InkWell(
          onTap: () => onSelect(i),
          child: Container(
            color: isSelected
                ? AppTheme.primaryLight.withValues(alpha: 0.08)
                : null,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 세로선 + 원형 점
                SizedBox(
                  width: 18,
                  child: Column(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: entry.isError
                              ? AppTheme.error
                              : isSelected
                                  ? AppTheme.primaryLight
                                  : AppTheme.textDisabled,
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 1,
                          height: 30,
                          color: AppTheme.border,
                          margin: const EdgeInsets.symmetric(vertical: 2),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.step,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? AppTheme.primaryLight
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                            Text(
                              _fmtTime(entry.timestamp),
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.textDisabled),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          entry.detail,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: entry.isError
                                ? AppTheme.error
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';
}

// ── 상세 패널 ─────────────────────────────────────────────

class _DetailPanel extends StatelessWidget {
  final AgentLogEntry entry;
  const _DetailPanel({required this.entry});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                entry.step,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryLight,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _fmtTime(entry.timestamp),
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textDisabled),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: SelectableText(
              entry.detail,
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color:
                    entry.isError ? AppTheme.error : AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: entry.detail));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('복사했습니다'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              icon: const Icon(Icons.copy_outlined, size: 13),
              label: const Text('복사', style: TextStyle(fontSize: 11)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';
}
