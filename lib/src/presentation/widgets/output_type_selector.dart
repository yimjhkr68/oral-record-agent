// lib/src/presentation/widgets/output_type_selector.dart
// 산출물 유형 체크박스 그리드 선택 위젯

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ─── 데이터 모델 ────────────────────────────────────────

class OutputTypeOption {
  final String id;           // 'novel', 'report', 'essay' 등
  final String label;        // "단편소설"
  final String description;  // "기록 기반 창작 픽션"
  final bool isAiRecommended;

  const OutputTypeOption({
    required this.id,
    required this.label,
    required this.description,
    this.isAiRecommended = false,
  });

  OutputTypeOption copyWith({bool? isAiRecommended}) => OutputTypeOption(
        id: id,
        label: label,
        description: description,
        isAiRecommended: isAiRecommended ?? this.isAiRecommended,
      );
}

const List<OutputTypeOption> kOutputTypeOptions = [
  OutputTypeOption(id: 'novel',        label: '단편소설',      description: '기록 기반 창작 픽션'),
  OutputTypeOption(id: 'report',       label: '분석 보고서',   description: '주제별 심층 분석'),
  OutputTypeOption(id: 'essay',        label: '에세이',        description: '대중 교양 문체'),
  OutputTypeOption(id: 'academic',     label: '학술 논문',     description: '서론·분석·결론 구조'),
  OutputTypeOption(id: 'life_history', label: '생애사 책',     description: '구술자 중심 서사'),
  OutputTypeOption(id: 'column',       label: '칼럼',          description: '시사·문화 관점'),
  OutputTypeOption(id: 'poem',         label: '시',            description: '시적 재해석'),
  OutputTypeOption(id: 'play',         label: '희곡·시나리오', description: '대화 중심 구성'),
  OutputTypeOption(id: 'education',    label: '교육 자료',     description: '학습용 구성'),
];

/// outputType ID → 표시 라벨 반환 (로그 표시용)
String outputTypeLabel(String id) {
  return kOutputTypeOptions
      .firstWhere((o) => o.id == id,
          orElse: () => OutputTypeOption(id: '', label: id, description: ''))
      .label;
}

// ─── OutputTypeSelector 위젯 ────────────────────────────

class OutputTypeSelector extends StatefulWidget {
  /// AI 추천 유형 ID (기본 선택됨)
  final String? aiRecommendedId;

  /// 선택 변경 콜백 (선택된 ID 목록)
  final ValueChanged<List<String>> onChanged;

  const OutputTypeSelector({
    super.key,
    this.aiRecommendedId,
    required this.onChanged,
  });

  @override
  State<OutputTypeSelector> createState() => _OutputTypeSelectorState();
}

class _OutputTypeSelectorState extends State<OutputTypeSelector> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    // AI 추천 유형 또는 'report' 기본 선택
    final initial = widget.aiRecommendedId ?? 'report';
    _selected = {initial};
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        if (_selected.length > 1) _selected.remove(id); // 최소 1개 유지
      } else {
        _selected.add(id);
      }
    });
    widget.onChanged(_selected.toList());
  }

  @override
  Widget build(BuildContext context) {
    final options = kOutputTypeOptions.map((o) => o.copyWith(
          isAiRecommended: o.id == widget.aiRecommendedId,
        )).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 3열 그리드
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 2.8,
          ),
          itemCount: options.length,
          itemBuilder: (context, i) {
            final option = options[i];
            final isSelected = _selected.contains(option.id);
            return _OutputTypeChip(
              option: option,
              isSelected: isSelected,
              onTap: () => _toggle(option.id),
            );
          },
        ),
        const SizedBox(height: 8),
        // 하단 카운트
        Row(
          children: [
            const Icon(Icons.check_circle_outline,
                size: 14, color: AppTheme.primaryLight),
            const SizedBox(width: 4),
            Text(
              '${_selected.length}종 생성 예정',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryLight,
              ),
            ),
            if (_selected.length > 1) ...[
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _selected
                      .map((id) => outputTypeLabel(id))
                      .join(' · '),
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ─── 개별 체크박스 칩 ────────────────────────────────────

class _OutputTypeChip extends StatelessWidget {
  final OutputTypeOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _OutputTypeChip({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const selectedColor = AppTheme.primaryLight;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedColor.withValues(alpha: 0.08)
              : Colors.transparent,
          border: Border.all(
            color: isSelected ? selectedColor : AppTheme.border,
            width: isSelected ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            // 체크 / AI 뱃지
            if (isSelected)
              Icon(Icons.check_circle_rounded,
                  size: 14, color: selectedColor)
            else if (option.isAiRecommended)
              Icon(Icons.auto_awesome,
                  size: 14, color: Colors.purple.shade400)
            else
              const Icon(Icons.radio_button_unchecked,
                  size: 14, color: AppTheme.border),
            const SizedBox(width: 5),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          option.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? selectedColor
                                : AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (option.isAiRecommended && !isSelected) ...[
                        const SizedBox(width: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 3, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            'AI',
                            style: TextStyle(
                                fontSize: 8,
                                color: Colors.purple.shade400,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    option.description,
                    style: const TextStyle(
                        fontSize: 9, color: AppTheme.textDisabled),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
