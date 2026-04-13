// lib/src/presentation/widgets/prompt_enhance_card.dart
// 프롬프트 개선 결과 카드 UI — 편집 + 재개선 지원

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../../../agents/core/prompt_enhancer.dart';

class PromptEnhanceCard extends StatefulWidget {
  final EnhancedPrompt enhanced;
  final bool isReEnhancing;
  final VoidCallback onUseEnhanced;
  final VoidCallback onUseOriginal;
  final VoidCallback onCancel;
  final Future<void> Function(String editedText) onReEnhance;

  const PromptEnhanceCard({
    super.key,
    required this.enhanced,
    required this.onUseEnhanced,
    required this.onUseOriginal,
    required this.onCancel,
    required this.onReEnhance,
    this.isReEnhancing = false,
  });

  @override
  State<PromptEnhanceCard> createState() => _PromptEnhanceCardState();
}

class _PromptEnhanceCardState extends State<PromptEnhanceCard> {
  bool _isEditing = false;
  late final TextEditingController _editController;
  int _reEnhanceCount = 0;
  static const int _maxReEnhance = 3;

  @override
  void initState() {
    super.initState();
    _editController =
        TextEditingController(text: widget.enhanced.enhanced);
  }

  @override
  void didUpdateWidget(PromptEnhanceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 재개선 결과가 도착하면 → 편집 모드 종료 + 텍스트 업데이트
    if (oldWidget.enhanced.enhanced != widget.enhanced.enhanced) {
      _editController.text = widget.enhanced.enhanced;
      setState(() => _isEditing = false);
    }
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  void _startEditing() {
    _editController.text = widget.enhanced.enhanced;
    setState(() => _isEditing = true);
  }

  void _cancelEditing() => setState(() => _isEditing = false);

  Future<void> _reEnhance() async {
    final text = _editController.text.trim();
    if (text.isEmpty) return;
    setState(() => _reEnhanceCount++);
    await widget.onReEnhance(text);
  }

  @override
  Widget build(BuildContext context) {
    final canReEnhance = _reEnhanceCount < _maxReEnhance;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.primaryLight.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 헤더 ─────────────────────────────────────
          _Header(
            isEditing: _isEditing,
            reEnhanceCount: _reEnhanceCount,
            maxReEnhance: _maxReEnhance,
            onCancel: widget.onCancel,
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 원본 (항상 표시)
                _PromptBlock(
                  label: '원본',
                  text: widget.enhanced.original,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(height: 8),

                // 편집 모드 / 개선안 표시 분기
                if (_isEditing) ...[
                  _EditSection(
                    controller: _editController,
                    isLoading: widget.isReEnhancing,
                    canReEnhance: canReEnhance,
                    reEnhanceCount: _reEnhanceCount,
                    maxReEnhance: _maxReEnhance,
                    onReEnhance: _reEnhance,
                    onCancel: _cancelEditing,
                  ),
                ] else ...[
                  // 개선안 표시
                  _PromptBlock(
                    label: _reEnhanceCount > 0 ? '재개선 $_reEnhanceCount' : '개선',
                    text: widget.enhanced.enhanced,
                    color: AppTheme.primaryLight,
                    highlight: true,
                  ),
                  if (widget.enhanced.reason.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline,
                            size: 11, color: AppTheme.textDisabled),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.enhanced.reason,
                            style: const TextStyle(
                              color: AppTheme.textDisabled,
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  // 메인 버튼: 개선된 프롬프트로 실행
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: widget.onUseEnhanced,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      child: const Text('개선된 프롬프트로 실행'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // 보조 버튼: 편집 + 원본 실행
                  Row(
                    children: [
                      if (canReEnhance)
                        OutlinedButton.icon(
                          onPressed: _startEditing,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 7),
                            textStyle: const TextStyle(fontSize: 11),
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 13),
                          label: const Text('편집'),
                        ),
                      if (canReEnhance) const SizedBox(width: 6),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: widget.onUseOriginal,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 7),
                            textStyle: const TextStyle(fontSize: 11),
                          ),
                          child: const Text('원본 실행'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 헤더 ─────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final bool isEditing;
  final int reEnhanceCount;
  final int maxReEnhance;
  final VoidCallback onCancel;

  const _Header({
    required this.isEditing,
    required this.reEnhanceCount,
    required this.maxReEnhance,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final title = isEditing
        ? '프롬프트 편집'
        : reEnhanceCount > 0
            ? 'AI가 프롬프트를 재개선했어요'
            : 'AI가 프롬프트를 개선했어요';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight.withValues(alpha: 0.1),
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(10)),
      ),
      child: Row(
        children: [
          Icon(
            isEditing ? Icons.edit_outlined : Icons.auto_fix_high,
            size: 15,
            color: AppTheme.primaryLight,
          ),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.primaryLight,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (reEnhanceCount > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                '$reEnhanceCount/$maxReEnhance',
                style: const TextStyle(
                  color: AppTheme.primaryLight,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const Spacer(),
          InkWell(
            onTap: onCancel,
            borderRadius: BorderRadius.circular(4),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.close,
                  size: 14, color: AppTheme.textDisabled),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 편집 섹션 ─────────────────────────────────────────────

class _EditSection extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final bool canReEnhance;
  final int reEnhanceCount;
  final int maxReEnhance;
  final VoidCallback onReEnhance;
  final VoidCallback onCancel;

  const _EditSection({
    required this.controller,
    required this.isLoading,
    required this.canReEnhance,
    required this.reEnhanceCount,
    required this.maxReEnhance,
    required this.onReEnhance,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 편집 라벨
        Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text(
                '편집',
                style: TextStyle(
                  color: AppTheme.primaryLight,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        // 텍스트 필드
        TextField(
          controller: controller,
          enabled: !isLoading,
          maxLines: null,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 12,
            height: 1.5,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            filled: true,
            fillColor: AppTheme.primaryLight.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                color: AppTheme.primaryLight.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                color: AppTheme.primaryLight.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppTheme.primaryLight),
            ),
            hintText: '프롬프트를 수정하세요...',
            hintStyle: const TextStyle(
              color: AppTheme.textDisabled,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // 편집 버튼들
        Row(
          children: [
            if (isLoading) ...[
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              const Text(
                '재개선 중...',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11),
              ),
            ] else if (canReEnhance) ...[
              Expanded(
                child: FilledButton.icon(
                  onPressed: onReEnhance,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                  icon: const Icon(Icons.auto_fix_high, size: 13),
                  label: Text(
                      '다시 개선해줘 (${reEnhanceCount + 1}/$maxReEnhance)'),
                ),
              ),
            ] else ...[
              Expanded(
                child: Text(
                  '최대 재개선 횟수($maxReEnhance회)에 도달했습니다.',
                  style: const TextStyle(
                      color: AppTheme.textDisabled, fontSize: 11),
                ),
              ),
            ],
            const SizedBox(width: 6),
            OutlinedButton(
              onPressed: isLoading ? null : onCancel,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 7),
                textStyle: const TextStyle(fontSize: 11),
              ),
              child: const Text('취소'),
            ),
          ],
        ),
      ],
    );
  }
}

// ── 프롬프트 텍스트 블록 ──────────────────────────────────

class _PromptBlock extends StatelessWidget {
  final String label;
  final String text;
  final Color color;
  final bool highlight;

  const _PromptBlock({
    required this.label,
    required this.text,
    required this.color,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          margin: const EdgeInsets.only(top: 1, right: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: highlight
                  ? AppTheme.textPrimary
                  : AppTheme.textSecondary,
              fontSize: 12,
              height: 1.4,
              fontWeight:
                  highlight ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}
