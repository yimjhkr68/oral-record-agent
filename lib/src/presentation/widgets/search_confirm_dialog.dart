// lib/src/presentation/widgets/search_confirm_dialog.dart
// 검색 결과를 보여주고 진행할 기록을 선택하는 다이얼로그

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/agent_state_provider.dart';
import '../theme/app_theme.dart';

class SearchConfirmDialog extends ConsumerStatefulWidget {
  final SearchConfirmData data;
  const SearchConfirmDialog({super.key, required this.data});

  @override
  ConsumerState<SearchConfirmDialog> createState() =>
      _SearchConfirmDialogState();
}

class _SearchConfirmDialogState extends ConsumerState<SearchConfirmDialog> {
  late List<SearchResultRecord> _records;

  @override
  void initState() {
    super.initState();
    // 로컬 복사본 (체크박스 상태 변경용)
    _records = widget.data.records
        .map((r) => SearchResultRecord(
              recordId: r.recordId,
              title: r.title,
              narratorName: r.narratorName,
              date: r.date,
              summaryPreview: r.summaryPreview,
              relevanceScore: r.relevanceScore,
              isSelected: r.isSelected,
            ))
        .toList();
  }

  List<String> get _selectedIds =>
      _records.where((r) => r.isSelected).map((r) => r.recordId).toList();

  String get _actionLabel {
    switch (widget.data.nextAction) {
      case 'analyze':
        return '분석';
      case 'generate_book':
        return '생애사 책 생성';
      case 'generate_summary':
        return '요약집 생성';
      default:
        return '보고서 생성';
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedIds.length;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.search, size: 18, color: AppTheme.primaryLight),
          const SizedBox(width: 8),
          Text(
            '관련 기록을 찾았어요 (${_records.length}건)',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 쿼리 표시
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.format_quote,
                      size: 14, color: AppTheme.textDisabled),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.data.enhancedPrompt.isNotEmpty
                          ? widget.data.enhancedPrompt
                          : widget.data.originalPrompt,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // 전체 선택/해제 헤더
            Row(
              children: [
                Checkbox(
                  value: selectedCount == _records.length,
                  tristate: selectedCount > 0 &&
                      selectedCount < _records.length,
                  onChanged: (v) => setState(() {
                    for (final r in _records) {
                      r.isSelected = v ?? false;
                    }
                  }),
                  visualDensity: VisualDensity.compact,
                ),
                Text(
                  '전체 선택 ($selectedCount/${_records.length})',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary),
                ),
              ],
            ),
            const Divider(height: 8),

            // 기록 목록
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 340),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _records.length,
                itemBuilder: (context, i) =>
                    _RecordItem(
                  record: _records[i],
                  onToggle: () => setState(() {
                    _records[i].isSelected = !_records[i].isSelected;
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            ref.read(agentStateProvider.notifier).rejectSearch();
          },
          child: const Text('취소'),
        ),
        FilledButton.icon(
          onPressed: selectedCount == 0
              ? null
              : () {
                  Navigator.of(context).pop();
                  ref
                      .read(agentStateProvider.notifier)
                      .confirmSearch(_selectedIds);
                },
          icon: const Icon(Icons.play_arrow_rounded, size: 16),
          label: Text(
            '$selectedCount개 기록으로 $_actionLabel',
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }
}

// ── 기록 항목 ────────────────────────────────────────

class _RecordItem extends StatelessWidget {
  final SearchResultRecord record;
  final VoidCallback onToggle;

  const _RecordItem({required this.record, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final score = record.relevanceScore;
    final scoreColor = score >= 0.7
        ? Colors.green.shade600
        : score >= 0.5
            ? Colors.orange.shade600
            : AppTheme.textDisabled;

    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: record.isSelected,
              onChanged: (_) => onToggle(),
              visualDensity: VisualDensity.compact,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 제목 + 관련도 바
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          record.title,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 관련도 % 표시
                      Text(
                        '${(score * 100).toInt()}%',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: scoreColor),
                      ),
                    ],
                  ),
                  // 관련도 바
                  const SizedBox(height: 2),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: score,
                      minHeight: 3,
                      backgroundColor: AppTheme.border,
                      valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                    ),
                  ),
                  const SizedBox(height: 3),
                  // 구술자 | 날짜
                  Row(
                    children: [
                      if (record.narratorName.isNotEmpty) ...[
                        const Icon(Icons.person_outline,
                            size: 11, color: AppTheme.textDisabled),
                        const SizedBox(width: 2),
                        Text(record.narratorName,
                            style: const TextStyle(
                                fontSize: 10, color: AppTheme.textDisabled)),
                        const SizedBox(width: 8),
                      ],
                      if (record.date.isNotEmpty)
                        Text(
                          _formatDate(record.date),
                          style: const TextStyle(
                              fontSize: 10, color: AppTheme.textDisabled),
                        ),
                    ],
                  ),
                  // 요약 미리보기
                  if (record.summaryPreview.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        record.summaryPreview.length > 80
                            ? '${record.summaryPreview.substring(0, 80)}…'
                            : record.summaryPreview,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary),
                        maxLines: 2,
                      ),
                    ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}
