import 'package:flutter/material.dart';
import '../../models/ontology.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// 클래스 또는 속성 하나의 표준 매핑 카드.
/// 추천 후보 라디오 선택 + confidence 바, 직접 입력, 확정/확정 취소 기능.
class MappingCard extends StatefulWidget {
  final MappingItem item;

  /// (tag, confirmed) — 저장/적용/확정 시 호출
  final void Function(String tag, bool confirmed) onSave;

  const MappingCard({required this.item, required this.onSave, super.key});

  @override
  State<MappingCard> createState() => _MappingCardState();
}

class _MappingCardState extends State<MappingCard> {
  late TextEditingController _customCtrl;
  late bool _confirmed;
  late String _currentTag;
  bool _expanded = false;

  // 라디오 선택값: suggestion URI 또는 'custom'
  String? _selectedUri;

  @override
  void initState() {
    super.initState();
    _currentTag = widget.item.currentTag;
    _confirmed  = widget.item.isConfirmed;
    _customCtrl = TextEditingController();
    _initSelectedUri();
  }

  @override
  void didUpdateWidget(MappingCard old) {
    super.didUpdateWidget(old);
    if (old.item != widget.item) {
      _currentTag = widget.item.currentTag;
      _confirmed  = widget.item.isConfirmed;
      _initSelectedUri();
    }
  }

  void _initSelectedUri() {
    if (_currentTag.isEmpty) {
      _selectedUri = null;
    } else {
      final match = widget.item.suggestions
          .where((s) => s.uri == _currentTag)
          .firstOrNull;
      if (match != null) {
        _selectedUri = match.uri;
      } else {
        _selectedUri = 'custom';
        _customCtrl.text = _currentTag;
      }
    }
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  Color get _bgColor {
    if (_confirmed) return Colors.green.withValues(alpha: 0.07);
    if (_currentTag.isNotEmpty) return Colors.amber.withValues(alpha: 0.06);
    return Colors.transparent;
  }

  Color _parseColor(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  Color _confidenceColor(double c) {
    if (c >= 0.9) return AppColors.success;
    if (c >= 0.7) return Colors.orange;
    return AppColors.textMuted;
  }

  void _selectSuggestion(String uri) {
    setState(() {
      _selectedUri = uri;
      _currentTag  = uri;
      _confirmed   = false;
    });
    widget.onSave(uri, false);
  }

  void _applyCustom() {
    final tag = _customCtrl.text.trim();
    if (tag.isEmpty) return;
    setState(() {
      _selectedUri = 'custom';
      _currentTag  = tag;
      _confirmed   = false;
    });
    widget.onSave(tag, false);
  }

  void _confirm() {
    setState(() => _confirmed = true);
    widget.onSave(_currentTag, true);
  }

  void _unconfirm() {
    setState(() => _confirmed = false);
    widget.onSave(_currentTag, false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      color: _bgColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 헤더 행 ─────────────────────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  // 클래스 색상 dot
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _parseColor(widget.item.color),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 이름 + 한국어 레이블
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.item.name}'
                          '${widget.item.labelKo.isNotEmpty ? "  (${widget.item.labelKo})" : ""}',
                          style: AppTypography.body
                              .copyWith(fontWeight: FontWeight.w500),
                        ),
                        if (_currentTag.isNotEmpty)
                          Text(
                            _currentTag,
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: _confirmed
                                  ? Colors.green.shade700
                                  : Colors.orange.shade700,
                            ),
                          )
                        else
                          Text('매핑 없음',
                              style: AppTypography.caption.copyWith(
                                  color: AppColors.textMuted)),
                      ],
                    ),
                  ),

                  // 상태 아이콘
                  if (_confirmed)
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 18)
                  else if (_currentTag.isNotEmpty)
                    Icon(Icons.pending,
                        color: Colors.orange.shade600, size: 18),

                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),

          // ── 펼침: 추천 라디오 + 직접입력 + 확정 ────────────────────────
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 추천 후보 목록 — 라디오 버튼 + confidence 바
                  if (widget.item.suggestions.isNotEmpty) ...[
                    Text('추천 매핑',
                        style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    ...widget.item.suggestions.map((s) => _SuggestionRow(
                          suggestion: s,
                          isSelected: _selectedUri == s.uri,
                          confidenceColor: _confidenceColor(s.confidence),
                          onSelect: () => _selectSuggestion(s.uri),
                        )),
                    const SizedBox(height: 6),
                  ],

                  // 직접 입력 라디오 옵션
                  InkWell(
                    onTap: () => setState(() => _selectedUri = 'custom'),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: _selectedUri == 'custom'
                            ? AppColors.primaryFaint
                            : AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _selectedUri == 'custom'
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                      child: Row(children: [
                        _RadioDot(selected: _selectedUri == 'custom'),
                        const SizedBox(width: 8),
                        Text('직접 입력',
                            style: AppTypography.body
                                .copyWith(fontSize: 12)),
                      ]),
                    ),
                  ),

                  // 직접 입력 필드 (custom 선택 시)
                  if (_selectedUri == 'custom') ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _customCtrl,
                          style: const TextStyle(
                              fontSize: 12, fontFamily: 'monospace'),
                          decoration: const InputDecoration(
                            hintText: '예: cidoc:E21_Person',
                            isDense: true,
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                          ),
                          onSubmitted: (_) => _applyCustom(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _applyCustom,
                        style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12)),
                        child: const Text('적용'),
                      ),
                    ]),
                  ],

                  const SizedBox(height: 10),

                  // 확정 / 확정 취소 버튼
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    if (_confirmed)
                      OutlinedButton(
                        onPressed: _unconfirm,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                        ),
                        child: const Text('확정 취소',
                            style: TextStyle(fontSize: 12)),
                      )
                    else
                      ElevatedButton(
                        onPressed: (_currentTag.isNotEmpty &&
                                _selectedUri != null &&
                                (_selectedUri != 'custom' ||
                                    _customCtrl.text.isNotEmpty))
                            ? _confirm
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                        ),
                        child: const Text('확정',
                            style: TextStyle(fontSize: 12)),
                      ),
                  ]),
                ],
              ),
            ),

          const Divider(height: 1),
        ],
      ),
    );
  }
}

// ── 라디오 원형 인디케이터 ────────────────────────────────────────────────────

class _RadioDot extends StatelessWidget {
  final bool selected;
  const _RadioDot({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
          width: selected ? 2.0 : 1.5,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
              ),
            )
          : null,
    );
  }
}

// ── 추천 후보 행 (라디오 + URI + confidence 바) ───────────────────────────────

class _SuggestionRow extends StatelessWidget {
  final MappingSuggestion suggestion;
  final bool isSelected;
  final Color confidenceColor;
  final VoidCallback onSelect;

  const _SuggestionRow({
    required this.suggestion,
    required this.isSelected,
    required this.confidenceColor,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryFaint
                : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(children: [
            // 라디오 인디케이터
            _RadioDot(selected: isSelected),
            const SizedBox(width: 8),

            // URI + 레이블
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.uri,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    suggestion.label,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),

            // Confidence % + 바
            if (suggestion.confidence > 0)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${(suggestion.confidence * 100).round()}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: confidenceColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  SizedBox(
                    width: 48,
                    height: 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: suggestion.confidence,
                        backgroundColor: AppColors.border,
                        valueColor:
                            AlwaysStoppedAnimation(confidenceColor),
                      ),
                    ),
                  ),
                ],
              ),
          ]),
        ),
      ),
    );
  }
}
