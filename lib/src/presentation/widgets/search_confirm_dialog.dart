// lib/src/presentation/widgets/search_confirm_dialog.dart
// 검색 결과를 보여주고 진행할 기록을 선택하는 다이얼로그
// 검색 결과 0건 시: 3가지 선택지 표시 + 기록 직접 선택 패널

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
  // 검색 결과 있는 경우용
  late List<SearchResultRecord> _records;

  // 직접 선택 패널용
  bool _showPicker = false;
  late List<SearchResultRecord> _allRecords;
  final TextEditingController _pickerSearch = TextEditingController();
  String _pickerQuery = '';

  @override
  void initState() {
    super.initState();
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
    _allRecords = widget.data.allRecords
        .map((r) => SearchResultRecord(
              recordId: r.recordId,
              title: r.title,
              narratorName: r.narratorName,
              date: r.date,
              summaryPreview: r.summaryPreview,
              relevanceScore: 0.0,
              isSelected: false,
            ))
        .toList();
  }

  @override
  void dispose() {
    _pickerSearch.dispose();
    super.dispose();
  }

  List<String> get _selectedIds =>
      _records.where((r) => r.isSelected).map((r) => r.recordId).toList();

  List<String> get _pickerSelectedIds =>
      _allRecords.where((r) => r.isSelected).map((r) => r.recordId).toList();

  List<SearchResultRecord> get _filteredAll {
    if (_pickerQuery.isEmpty) return _allRecords;
    final q = _pickerQuery.toLowerCase();
    return _allRecords
        .where((r) =>
            r.title.toLowerCase().contains(q) ||
            r.narratorName.toLowerCase().contains(q))
        .toList();
  }

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
    if (!widget.data.hasResults) {
      return _showPicker ? _buildPickerDialog() : _buildNoResultsDialog();
    }
    return _buildNormalDialog();
  }

  // ── 결과 없음 다이얼로그 ─────────────────────────────

  Widget _buildNoResultsDialog() {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.search_off, size: 18, color: Colors.orange.shade600),
          const SizedBox(width: 8),
          const Text(
            '관련 기록을 찾지 못했어요',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 검색어 표시
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
            const SizedBox(height: 6),
            Text(
              'AI 의미 검색 결과: 0건',
              style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
            ),
            const SizedBox(height: 16),
            const Text(
              '어떻게 진행할까요?',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 10),

            // 선택지 1: 기록 직접 선택
            if (_allRecords.isNotEmpty)
              _OptionCard(
                icon: Icons.folder_open_outlined,
                iconColor: AppTheme.primaryLight,
                title: '기록 직접 선택',
                subtitle: '전체 기록 목록에서 포함할 기록을 직접 선택합니다',
                onTap: () => setState(() => _showPicker = true),
              ),
            if (_allRecords.isNotEmpty) const SizedBox(height: 8),

            // 선택지 2: 기록 없이 실행
            _OptionCard(
              icon: Icons.play_circle_outline,
              iconColor: Colors.green.shade600,
              title: '기록 없이 최대한 실행',
              subtitle: '등록된 기록 없이 프롬프트 내용만으로 최대한 처리합니다',
              onTap: () {
                Navigator.of(context).pop();
                ref.read(agentStateProvider.notifier).executeWithoutRecords();
              },
            ),
            const SizedBox(height: 8),

            // 선택지 3: 취소
            _OptionCard(
              icon: Icons.close,
              iconColor: AppTheme.textDisabled,
              title: '취소',
              subtitle: '처리를 중단합니다',
              onTap: () {
                Navigator.of(context).pop();
                ref.read(agentStateProvider.notifier).rejectSearch();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── 기록 직접 선택 패널 ──────────────────────────────

  Widget _buildPickerDialog() {
    final filtered = _filteredAll;
    final selectedCount = _pickerSelectedIds.length;

    return AlertDialog(
      title: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => setState(() => _showPicker = false),
            tooltip: '뒤로',
          ),
          const SizedBox(width: 8),
          const Text(
            '기록 직접 선택',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 검색창
            TextField(
              controller: _pickerSearch,
              decoration: const InputDecoration(
                hintText: '제목 / 구술자로 검색...',
                prefixIcon: Icon(Icons.search, size: 18),
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _pickerQuery = v),
            ),
            const SizedBox(height: 8),

            // 카운터 행
            Row(
              children: [
                Text(
                  '전체 ${_allRecords.length}건',
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary),
                ),
                const Spacer(),
                Text(
                  '선택됨: $selectedCount건',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selectedCount > 0
                        ? AppTheme.primaryLight
                        : AppTheme.textDisabled,
                  ),
                ),
              ],
            ),
            const Divider(height: 8),

            // 기록 목록
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('검색 결과 없음',
                          style: TextStyle(color: AppTheme.textDisabled)),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final r = filtered[i];
                        return _PickerItem(
                          record: r,
                          onToggle: () => setState(() {
                            // allRecords의 실제 항목 토글
                            final idx = _allRecords
                                .indexWhere((x) => x.recordId == r.recordId);
                            if (idx >= 0) {
                              _allRecords[idx].isSelected =
                                  !_allRecords[idx].isSelected;
                            }
                          }),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() => _showPicker = false),
          child: const Text('뒤로'),
        ),
        FilledButton.icon(
          onPressed: selectedCount == 0
              ? null
              : () {
                  Navigator.of(context).pop();
                  ref
                      .read(agentStateProvider.notifier)
                      .confirmSearch(_pickerSelectedIds);
                },
          icon: const Icon(Icons.play_arrow_rounded, size: 16),
          label: Text('$selectedCount건 선택하여 $_actionLabel'),
        ),
      ],
    );
  }

  // ── 일반 검색 결과 다이얼로그 ────────────────────────

  Widget _buildNormalDialog() {
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
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
            Row(
              children: [
                Checkbox(
                  value: selectedCount == _records.length,
                  tristate:
                      selectedCount > 0 && selectedCount < _records.length,
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
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 340),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _records.length,
                itemBuilder: (context, i) => _RecordItem(
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

// ── 선택지 카드 ──────────────────────────────────────

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 16, color: AppTheme.textDisabled),
          ],
        ),
      ),
    );
  }
}

// ── 직접 선택 패널 기록 항목 ─────────────────────────

class _PickerItem extends StatelessWidget {
  final SearchResultRecord record;
  final VoidCallback onToggle;

  const _PickerItem({required this.record, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
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
                  Text(record.title,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
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
                        Text(_formatDate(record.date),
                            style: const TextStyle(
                                fontSize: 10, color: AppTheme.textDisabled)),
                    ],
                  ),
                  if (record.summaryPreview.isNotEmpty)
                    Text(
                      record.summaryPreview.length > 60
                          ? '${record.summaryPreview.substring(0, 60)}…'
                          : record.summaryPreview,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary),
                      maxLines: 1,
                    ),
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

// ── 기존 검색 결과 기록 항목 ─────────────────────────

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
                      Text(
                        '${(score * 100).toInt()}%',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: scoreColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: score,
                      minHeight: 3,
                      backgroundColor: AppTheme.border,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(scoreColor),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (record.narratorName.isNotEmpty) ...[
                        const Icon(Icons.person_outline,
                            size: 11, color: AppTheme.textDisabled),
                        const SizedBox(width: 2),
                        Text(record.narratorName,
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.textDisabled)),
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
