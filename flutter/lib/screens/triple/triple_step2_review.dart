import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/ontology.dart';
import '../../models/published_ontology.dart';
import '../../models/triple.dart';
import '../../providers/ontology_provider.dart';
import '../../providers/triple_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/empty_state.dart';

// ── 클래스별 색상 (그래프 화면과 동일) ──────────────────────────────────────────
const _classColors = <String, Color>{
  'Person':           Color(0xFFf59e0b),
  'Place':            Color(0xFF10b981),
  'Event':            Color(0xFFef4444),
  'Time':             Color(0xFF8b5cf6),
  'Organization':     Color(0xFF3b82f6),
  'Object':           Color(0xFFf97316),
  'Topic':            Color(0xFFec4899),
  'NarrativeSession': Color(0xFF14b8a6),
  'Community':        Color(0xFF06b6d4),
  'Policy':           Color(0xFF7c3aed),
  'Emotion':          Color(0xFFf43f5e),
  'Collection':       Color(0xFF64748b),
};

Color _colorForType(String type) =>
    _classColors[type] ?? const Color(0xFF94a3b8);

class TripleStep2Review extends ConsumerWidget {
  const TripleStep2Review({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state   = ref.watch(tripleWorkProvider);
    final pending = state.pendingTriples;

    if (pending.isEmpty) {
      return EmptyState(
        icon: Icons.rule_outlined,
        title: '검토할 트리플 없음',
        description: 'Step 1에서 트리플을 생성하면\n여기서 검토할 수 있습니다.',
        action: OutlinedButton(
          onPressed: () =>
              ref.read(tripleWorkProvider.notifier).setStep(0),
          child: const Text('Step 1로 이동'),
        ),
      );
    }

    // 통계 요약
    final added   = pending.length;
    final bySource = <String, int>{};
    for (final t in pending) {
      bySource[t.sourceRecordId] =
          (bySource[t.sourceRecordId] ?? 0) + 1;
    }

    return Column(
      children: [
        // ── 상단 요약 바 ──────────────────────────────────────────────────
        Container(
          color: AppColors.surfaceElevated,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            _StatChip(Icons.hub_outlined, '생성 $added개',
                AppColors.primary),
            const SizedBox(width: 6),
            if (state.editedCount > 0) ...[
              _StatChip(Icons.edit_outlined, '수정 ${state.editedCount}개',
                  Colors.orange),
              const SizedBox(width: 6),
            ],
            if (state.deletedCount > 0) ...[
              _StatChip(Icons.delete_outline, '삭제 ${state.deletedCount}개',
                  Colors.red),
              const SizedBox(width: 6),
            ],
            if (state.addedCount > 0)
              _StatChip(Icons.add_circle_outline, '추가 ${state.addedCount}개',
                  Colors.green),
            const Spacer(),
            OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('트리플 추가'),
              style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact),
              onPressed: () => _showAddDialog(context, ref, state),
            ),
          ]),
        ),

        // ── 트리플 목록 ──────────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: pending.length,
            itemBuilder: (ctx, i) => _TripleReviewCard(
              index: i,
              triple: pending[i],
              ontologyVersionId: state.selectedVersionId,
              onUpdate: (updated) => ref
                  .read(tripleWorkProvider.notifier)
                  .updatePending(i, updated),
              onRemove: () =>
                  ref.read(tripleWorkProvider.notifier).removePending(i),
            ),
          ),
        ),

        // ── 하단 확정 버튼 ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: state.isExtracting
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_alt, size: 18),
              label: Text(state.isExtracting
                  ? '저장 중...'
                  : '전체 확정 저장 (${pending.length}개)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: const Color(0xFF2e7d32),
                foregroundColor: Colors.white,
              ),
              onPressed:
                  state.isExtracting ? null : () => _confirmSave(context, ref),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmSave(BuildContext context, WidgetRef ref) async {
    final count =
        ref.read(tripleWorkProvider).pendingTriples.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('확정 저장'),
        content: Text('검토된 트리플 $count개를 그래프 DB에 저장합니다.\n'
            '저장 후에는 편집 화면으로 돌아올 수 없습니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2e7d32),
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('확정'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final result =
        await ref.read(tripleWorkProvider.notifier).bulkConfirm();
    if (!context.mounted) return;
    if (result != null) {
      messenger.showSnackBar(SnackBar(
        content: Text(
            '트리플 ${result['added']}개가 저장됐습니다.'
            '${result['skipped'] > 0 ? ' (중복 ${result['skipped']}개 건너뜀)' : ''}'),
        backgroundColor: const Color(0xFF2e7d32),
      ));
    } else {
      final err = ref.read(tripleWorkProvider).error ?? '저장 실패';
      messenger.showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.red),
      );
    }
  }

  void _showAddDialog(
      BuildContext context, WidgetRef ref, TripleWorkState state) {
    showDialog(
      context: context,
      builder: (_) => _AddTripleDialog(
        versionId: state.selectedVersionId,
        onAdd: (t) => ref.read(tripleWorkProvider.notifier).addPending(t),
      ),
    );
  }
}

// ── 트리플 카드 ───────────────────────────────────────────────────────────────

class _TripleReviewCard extends ConsumerStatefulWidget {
  final int index;
  final PendingTriple triple;
  final String? ontologyVersionId;
  final ValueChanged<PendingTriple> onUpdate;
  final VoidCallback onRemove;

  const _TripleReviewCard({
    required this.index,
    required this.triple,
    required this.ontologyVersionId,
    required this.onUpdate,
    required this.onRemove,
  });

  @override
  ConsumerState<_TripleReviewCard> createState() => _TripleReviewCardState();
}

class _TripleReviewCardState extends ConsumerState<_TripleReviewCard> {
  bool _editing = false;
  late TextEditingController _subjCtrl;
  late TextEditingController _predCtrl;
  late TextEditingController _objCtrl;
  late double _confidence;

  @override
  void initState() {
    super.initState();
    _subjCtrl   = TextEditingController(text: widget.triple.subject);
    _predCtrl   = TextEditingController(text: widget.triple.predicate);
    _objCtrl    = TextEditingController(text: widget.triple.object);
    _confidence = widget.triple.confidence;
  }

  @override
  void dispose() {
    _subjCtrl.dispose();
    _predCtrl.dispose();
    _objCtrl.dispose();
    super.dispose();
  }

  void _save() {
    widget.onUpdate(widget.triple.copyWith(
      predicate:  _predCtrl.text.trim(),
      object:     _objCtrl.text.trim(),
      confidence: _confidence,
    ));
    setState(() => _editing = false);
  }

  // 온톨로지 버전에서 클래스 매핑 조회
  List<ClassMapping> _mappingsFor(String typeName) {
    if (widget.ontologyVersionId == null) return const [];
    final versions = ref.read(ontologyProvider).versions;
    final version = versions.cast<OntologyVersion?>().firstWhere(
      (v) => v?.versionId == widget.ontologyVersionId,
      orElse: () => null,
    );
    return version?.classes
            .cast<OntologyClass?>()
            .firstWhere((c) => c?.name == typeName, orElse: () => null)
            ?.mappings ??
        const [];
  }

  @override
  Widget build(BuildContext context) {
    final t        = widget.triple;
    final subjColor = _colorForType(t.subjectType);
    final objColor  = _colorForType(t.objectType);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        elevated: true,
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 주어 → 술어 → 목적어 ───────────────────────────────────────
            Row(
              children: [
                _TypeBadge(t.subjectType, subjColor,
                    mappings: _mappingsFor(t.subjectType)),
                const SizedBox(width: 6),
                Expanded(
                  child: _editing
                      ? TextField(
                          controller: _subjCtrl,
                          decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder()),
                          style: AppTypography.body,
                          readOnly: true,
                        )
                      : Text(t.subject,
                          style: AppTypography.body.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: _editing
                  ? TextField(
                      controller: _predCtrl,
                      decoration: const InputDecoration(
                          isDense: true,
                          labelText: '술어',
                          border: OutlineInputBorder()),
                      style: AppTypography.body,
                    )
                  : Row(children: [
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_downward,
                          size: 13, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(t.predicate,
                          style: AppTypography.body.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600)),
                    ]),
            ),
            Row(
              children: [
                _TypeBadge(t.objectType, objColor,
                    mappings: _mappingsFor(t.objectType)),
                const SizedBox(width: 6),
                Expanded(
                  child: _editing
                      ? TextField(
                          controller: _objCtrl,
                          decoration: const InputDecoration(
                              isDense: true,
                              labelText: '목적어',
                              border: OutlineInputBorder()),
                          style: AppTypography.body,
                        )
                      : Text(t.object, style: AppTypography.body.copyWith(
                            color: AppColors.textPrimary)),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // ── 신뢰도 슬라이더 ──────────────────────────────────────────────
            Row(children: [
              Text('신뢰도', style: AppTypography.caption),
              Expanded(
                child: Slider(
                  value: _editing ? _confidence : t.confidence,
                  min: 0,
                  max: 1,
                  divisions: 10,
                  onChanged: _editing
                      ? (v) => setState(() => _confidence = v)
                      : null,
                ),
              ),
              Text(
                (_editing ? _confidence : t.confidence)
                    .toStringAsFixed(1),
                style: const TextStyle(fontSize: 11),
              ),
            ]),

            // ── 출처 + 액션 ──────────────────────────────────────────────────
            Row(children: [
              Expanded(
                child: Text('출처: ${t.sourceRecordId}',
                    style: AppTypography.caption,
                    overflow: TextOverflow.ellipsis),
              ),
              if (_editing) ...[
                TextButton(
                    onPressed: () => setState(() => _editing = false),
                    child: const Text('취소')),
                ElevatedButton(
                    onPressed: _save, child: const Text('저장')),
              ] else ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  tooltip: '수정',
                  onPressed: () => setState(() {
                    _editing = true;
                    _confidence = t.confidence;
                    _predCtrl.text = t.predicate;
                    _objCtrl.text  = t.object;
                  }),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 16, color: Colors.red),
                  tooltip: '삭제',
                  onPressed: widget.onRemove,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ]),
          ],
        ),
      ),
    );
  }
}

// ── 트리플 직접 추가 다이얼로그 ───────────────────────────────────────────────

class _AddTripleDialog extends ConsumerStatefulWidget {
  final String? versionId;
  final ValueChanged<PendingTriple> onAdd;
  const _AddTripleDialog({required this.versionId, required this.onAdd});

  @override
  ConsumerState<_AddTripleDialog> createState() => _AddTripleDialogState();
}

class _AddTripleDialogState extends ConsumerState<_AddTripleDialog> {
  final _subjCtrl   = TextEditingController();
  final _objCtrl    = TextEditingController();
  final _noteCtrl   = TextEditingController();
  String? _subjType;
  String? _predicate;
  String? _objType;
  double  _confidence = 1.0;

  @override
  void dispose() {
    _subjCtrl.dispose();
    _objCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 선택된 버전의 클래스/속성 목록
    final versions  = ref.read(ontologyProvider).versions;
    final version   = widget.versionId == null
        ? null
        : versions.cast<OntologyVersion?>().firstWhere(
            (v) => v?.versionId == widget.versionId,
            orElse: () => null);
    final classes    = version?.classes.map((c) => c.name).toList() ?? [];
    final predicates = version?.predicates.map((p) => p.name).toList() ?? [];

    return AlertDialog(
      title: const Text('트리플 직접 추가'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // 주어
          Row(children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _subjCtrl,
                decoration: const InputDecoration(
                    labelText: '주어', border: OutlineInputBorder(),
                    isDense: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _ClassDropdown(
                  label: '타입',
                  classes: classes,
                  value: _subjType,
                  onChanged: (v) => setState(() => _subjType = v)),
            ),
          ]),
          const SizedBox(height: 10),
          // 술어
          _PredicateDropdown(
              predicates: predicates,
              value: _predicate,
              onChanged: (v) => setState(() => _predicate = v)),
          const SizedBox(height: 10),
          // 목적어
          Row(children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _objCtrl,
                decoration: const InputDecoration(
                    labelText: '목적어', border: OutlineInputBorder(),
                    isDense: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _ClassDropdown(
                  label: '타입',
                  classes: classes,
                  value: _objType,
                  onChanged: (v) => setState(() => _objType = v)),
            ),
          ]),
          const SizedBox(height: 10),
          // 신뢰도
          Row(children: [
            const Text('신뢰도', style: TextStyle(fontSize: 12)),
            Expanded(
              child: Slider(
                value: _confidence,
                min: 0, max: 1, divisions: 10,
                onChanged: (v) => setState(() => _confidence = v),
              ),
            ),
            Text(_confidence.toStringAsFixed(1),
                style: const TextStyle(fontSize: 12)),
          ]),
          // 메모
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(
                labelText: '메모 (선택)', border: OutlineInputBorder(),
                isDense: true),
          ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소')),
        ElevatedButton(
          onPressed: () {
            if (_subjCtrl.text.trim().isEmpty ||
                _predicate == null ||
                _objCtrl.text.trim().isEmpty) return;
            widget.onAdd(PendingTriple(
              subject:        _subjCtrl.text.trim(),
              subjectType:    _subjType ?? '',
              predicate:      _predicate!,
              object:         _objCtrl.text.trim(),
              objectType:     _objType ?? '',
              confidence:     _confidence,
              sourceRecordId: '직접입력',
              ontologyVersion: widget.versionId ?? '',
              note:           _noteCtrl.text.trim(),
            ));
            Navigator.pop(context);
          },
          child: const Text('추가'),
        ),
      ],
    );
  }
}

// ── 보조 위젯 ─────────────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final String type;
  final Color color;
  final List<ClassMapping> mappings;
  const _TypeBadge(this.type, this.color, {this.mappings = const []});

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(type.isEmpty ? '??' : type,
            style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        if (mappings.isNotEmpty) ...[
          const SizedBox(width: 3),
          Icon(Icons.link, size: 9, color: color.withValues(alpha: 0.7)),
        ],
      ]),
    );

    if (mappings.isEmpty) return badge;

    final primary = mappings.where((m) => m.isPrimary).toList();
    final secondary = mappings.where((m) => !m.isPrimary).toList();
    final lines = [
      if (primary.isNotEmpty) '주: ${primary.map((m) => m.curie).join(', ')}',
      if (secondary.isNotEmpty) '부: ${secondary.map((m) => m.curie).join(', ')}',
    ];
    return Tooltip(
      message: lines.join('\n'),
      child: badge,
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatChip(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ]);
}

class _ClassDropdown extends StatelessWidget {
  final String label;
  final List<String> classes;
  final String? value;
  final ValueChanged<String?> onChanged;
  const _ClassDropdown(
      {required this.label,
      required this.classes,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) => InputDecorator(
        decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          underline: const SizedBox(),
          hint: const Text('선택', style: TextStyle(fontSize: 12)),
          items: classes
              .map((c) => DropdownMenuItem(
                  value: c,
                  child: Text(c, style: const TextStyle(fontSize: 12))))
              .toList(),
          onChanged: onChanged,
        ),
      );
}

class _PredicateDropdown extends StatelessWidget {
  final List<String> predicates;
  final String? value;
  final ValueChanged<String?> onChanged;
  const _PredicateDropdown(
      {required this.predicates,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) => InputDecorator(
        decoration: const InputDecoration(
            labelText: '술어',
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          underline: const SizedBox(),
          hint: const Text('술어 선택'),
          items: predicates
              .map((p) =>
                  DropdownMenuItem(value: p, child: Text(p)))
              .toList(),
          onChanged: onChanged,
        ),
      );
}
