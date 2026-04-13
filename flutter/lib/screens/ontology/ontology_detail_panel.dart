import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/api_client.dart';
import '../../models/ontology.dart';
import '../../models/published_ontology.dart';
import '../../providers/ontology_provider.dart';
import '../../providers/published_ontology_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/empty_state.dart';

class OntologyDetailPanel extends ConsumerWidget {
  const OntologyDetailPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ontologyProvider);

    if (state.isLoading && state.selectedVersion == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.selectedVersion == null) {
      return const EmptyState(
        icon: Icons.account_tree_outlined,
        title: '버전을 선택하세요',
        description: '좌측 목록에서 온톨로지 버전을 선택하면\n상세 내용이 표시됩니다.',
      );
    }

    return _VersionDetail(version: state.selectedVersion!);
  }
}

// ── 버전 상세 뷰 ─────────────────────────────────────────────────────────────

class _VersionDetail extends ConsumerStatefulWidget {
  final OntologyVersion version;
  const _VersionDetail({required this.version});

  @override
  ConsumerState<_VersionDetail> createState() => _VersionDetailState();
}

class _VersionDetailState extends ConsumerState<_VersionDetail>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  // ── 이름 편집 상태 ───────────────────────────────────────────────────────────
  bool _isEditingName = false;
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _nameCtrl = TextEditingController(text: widget.version.versionId);
  }

  @override
  void didUpdateWidget(_VersionDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 외부에서 버전이 바뀌면 편집 중인 이름도 초기화
    if (oldWidget.version.versionId != widget.version.versionId) {
      _isEditingName = false;
      _nameCtrl.text = widget.version.versionId;
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  OntologyVersion get v => ref.watch(ontologyProvider).selectedVersion ?? widget.version;

  void _startEditName() {
    setState(() {
      _nameCtrl.text = v.versionId;
      _isEditingName = true;
    });
  }

  Future<void> _saveName() async {
    final newId = _nameCtrl.text.trim();
    if (newId.isEmpty || newId == v.versionId) {
      setState(() => _isEditingName = false);
      return;
    }
    setState(() => _isEditingName = false);
    final result = await ref
        .read(ontologyProvider.notifier)
        .renameVersion(v.versionId, newId);
    if (result == null && mounted) {
      _snack(context, ref.read(ontologyProvider).error ?? '이름 변경 실패',
          isError: true);
    }
  }

  Future<void> _downloadJson() async {
    final versionId = v.versionId;
    final messenger = ScaffoldMessenger.of(context);
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'JSON 저장',
      fileName: '$versionId.json',
      allowedExtensions: ['json'],
      type: FileType.custom,
    );
    if (savePath == null) return;

    try {
      final client = ref.read(apiClientProvider);
      final res = await client.get('/api/ontologies/$versionId/download');
      final content = const JsonEncoder.withIndent('  ').convert(res.data);
      await File(savePath).writeAsString(content, encoding: utf8);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('저장됨: $savePath')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
              content: Text('다운로드 실패: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDraft = v.status == OntologyStatus.draft;
    final isConfirmed = v.status == OntologyStatus.confirmed;

    return Column(
      children: [
        // ── 헤더 ──────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border))),
          child: Row(
            children: [
              _StatusBadge(status: v.status),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 이름 표시 / 인라인 편집 ──────────────────────────
                    Row(
                      children: [
                        if (_isEditingName)
                          SizedBox(
                            width: 200,
                            child: TextField(
                              controller: _nameCtrl,
                              autofocus: true,
                              decoration: const InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                              ),
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold),
                              onSubmitted: (_) => _saveName(),
                            ),
                          )
                        else
                          Flexible(
                            child: Text(v.versionId,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15),
                                overflow: TextOverflow.ellipsis),
                          ),
                        IconButton(
                          icon: Icon(
                              _isEditingName
                                  ? Icons.check
                                  : Icons.edit_outlined,
                              size: 16),
                          tooltip: _isEditingName ? '저장' : '이름 변경',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: _isEditingName
                              ? _saveName
                              : _startEditName,
                        ),
                      ],
                    ),
                    if (v.description.isNotEmpty)
                      Text(v.description,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              // 액션 버튼
              IconButton(
                icon: const Icon(Icons.download_outlined),
                tooltip: 'JSON 다운로드',
                onPressed: _downloadJson,
              ),
              if (isDraft) ...[
                OutlinedButton(
                  onPressed: () => _confirmVersion(context, ref),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF388E3C),
                    side: const BorderSide(color: Color(0xFF388E3C)),
                  ),
                  child: const Text('확정하기'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _deleteVersion(context, ref),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  child: const Text('삭제'),
                ),
              ],
              if (isConfirmed)
                OutlinedButton(
                  onPressed: () => _archiveVersion(context, ref),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey,
                    side: const BorderSide(color: Colors.grey),
                  ),
                  child: const Text('아카이브'),
                ),
              if (!isDraft)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Chip(
                    label: const Text('읽기 전용',
                        style: TextStyle(fontSize: 11)),
                    backgroundColor:
                        Colors.grey.withValues(alpha: 0.15),
                    side: BorderSide.none,
                  ),
                ),
            ],
          ),
        ),

        // ── 메타 정보 ──────────────────────────────────────────────────────
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(children: [
            _Meta('생성일', v.createdAt.length >= 10
                ? v.createdAt.substring(0, 10) : v.createdAt),
            if (v.confirmedAt != null) ...[
              const SizedBox(width: 20),
              _Meta('확정일', v.confirmedAt!.length >= 10
                  ? v.confirmedAt!.substring(0, 10) : v.confirmedAt!),
            ],
            const SizedBox(width: 20),
            _Meta('클래스', '${v.classes.length}개'),
            const SizedBox(width: 20),
            _Meta('속성', '${v.predicates.length}개'),
          ]),
        ),
        const Divider(height: 1),

        // ── 탭 ────────────────────────────────────────────────────────────
        TabBar(
          controller: _tabCtrl,
          tabs: [
            Tab(text: '클래스 (${v.classes.length})'),
            Tab(text: '속성 (${v.predicates.length})'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _ClassesTab(version: v, isDraft: isDraft),
              _PredicatesTab(version: v, isDraft: isDraft),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmVersion(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('온톨로지 확정'),
        content: Text('"${v.versionId}"을 확정하시겠습니까?\n확정 후에는 수정 및 삭제가 불가능합니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF388E3C),
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('확정'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final success =
        await ref.read(ontologyProvider.notifier).confirmVersion(v.versionId);
    if (!success && context.mounted) {
      _snack(context, ref.read(ontologyProvider).error ?? '확정 실패',
          isError: true);
    }
  }

  Future<void> _archiveVersion(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('아카이브'),
        content: Text('"${v.versionId}"을 아카이브하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('아카이브'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final success =
        await ref.read(ontologyProvider.notifier).archiveVersion(v.versionId);
    if (!success && context.mounted) {
      _snack(context, ref.read(ontologyProvider).error ?? '아카이브 실패',
          isError: true);
    }
  }

  Future<void> _deleteVersion(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Draft 삭제'),
        content: Text('"${v.versionId}"을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await ref.read(ontologyProvider.notifier).deleteDraft(v.versionId);
  }

  void _snack(BuildContext context, String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : null,
    ));
  }
}

// ── 클래스 탭 ─────────────────────────────────────────────────────────────────

class _ClassesTab extends ConsumerWidget {
  final OntologyVersion version;
  final bool isDraft;
  const _ClassesTab({required this.version, required this.isDraft});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        ...version.classes.asMap().entries.map((e) => _ClassCard(
              cls: e.value,
              index: e.key,
              isDraft: isDraft,
              version: version,
            )),
        if (isDraft)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('클래스 추가'),
              onPressed: () => _showAddDialog(context, ref),
            ),
          ),
      ],
    );
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final cls = await showDialog<OntologyClass>(
      context: context,
      builder: (ctx) => const _ClassEditDialog(),
    );
    if (cls == null || !context.mounted) return;
    final updated = [...version.classes, cls];
    await ref.read(ontologyProvider.notifier).updateDraft(
          version.versionId,
          classes: updated,
          predicates: version.predicates,
        );
  }
}

class _ClassCard extends ConsumerWidget {
  final OntologyClass cls;
  final int index;
  final bool isDraft;
  final OntologyVersion version;
  const _ClassCard(
      {required this.cls,
      required this.index,
      required this.isDraft,
      required this.version});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _parseColor(cls.color);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        elevated: true,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(cls.name,
                  style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(width: 6),
              Text('(${cls.labelKo})',
                  style: AppTypography.caption),
              const Spacer(),
              if (isDraft) ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 15,
                      color: AppColors.textMuted),
                  onPressed: () => _editDialog(context, ref),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: '수정',
                ),
                const SizedBox(width: 2),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 15, color: AppColors.error),
                  onPressed: () => _delete(ref),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: '삭제',
                ),
              ],
            ]),
            if (cls.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(cls.description, style: AppTypography.body),
            ],
            if (cls.examples.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: cls.examples
                    .map((e) => Chip(
                          label: Text(e,
                              style: const TextStyle(fontSize: 11)),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ))
                    .toList(),
              ),
            ],
            // 매핑 칩은 확정/아카이브 탭(isDraft=false)에서만 표시
            if (!isDraft && cls.standardTag.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: cls.standardTag.split('·').map((tag) => Chip(
                      label: Text(tag.trim(),
                          style: const TextStyle(fontSize: 10)),
                      backgroundColor: Colors.blue.withValues(alpha: 0.08),
                      side: BorderSide(
                          color: Colors.blue.withValues(alpha: 0.25)),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    )).toList(),
              ),
            ],
            if (!isDraft && cls.mappings.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: cls.mappings.map((m) => Tooltip(
                      message:
                          '${m.isPrimary ? "주" : "부"} 매핑 · 신뢰도 ${(m.confidence * 100).round()}%',
                      child: Chip(
                        label: Text(m.curie,
                            style: const TextStyle(fontSize: 10)),
                        backgroundColor: m.isPrimary
                            ? Colors.indigo.withValues(alpha: 0.10)
                            : Colors.purple.withValues(alpha: 0.08),
                        avatar: m.isPrimary
                            ? const Icon(Icons.star,
                                size: 10, color: Colors.indigo)
                            : null,
                        side: BorderSide(
                          color: m.isPrimary
                              ? Colors.indigo.withValues(alpha: 0.3)
                              : Colors.purple.withValues(alpha: 0.2),
                        ),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                    )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _editDialog(BuildContext context, WidgetRef ref) async {
    final updated = await showDialog<OntologyClass>(
      context: context,
      builder: (ctx) => _ClassEditDialog(initial: cls),
    );
    if (updated == null || !context.mounted) return;
    final classes = [...version.classes];
    classes[index] = updated;
    await ref.read(ontologyProvider.notifier).updateDraft(
          version.versionId,
          classes: classes,
          predicates: version.predicates,
        );
  }

  Future<void> _delete(WidgetRef ref) async {
    final classes = [...version.classes]..removeAt(index);
    await ref.read(ontologyProvider.notifier).updateDraft(
          version.versionId,
          classes: classes,
          predicates: version.predicates,
        );
  }
}

// ── 속성 탭 ───────────────────────────────────────────────────────────────────

class _PredicatesTab extends ConsumerWidget {
  final OntologyVersion version;
  final bool isDraft;
  const _PredicatesTab({required this.version, required this.isDraft});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        ...version.predicates.asMap().entries.map((e) => _PredicateCard(
              pred: e.value,
              index: e.key,
              isDraft: isDraft,
              version: version,
            )),
        if (isDraft)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('속성 추가'),
              onPressed: () => _showAddDialog(context, ref),
            ),
          ),
      ],
    );
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final pred = await showDialog<OntologyPredicate>(
      context: context,
      builder: (ctx) => _PredicateEditDialog(
          availableClasses: version.classes.map((c) => c.name).toList()),
    );
    if (pred == null || !context.mounted) return;
    final updated = [...version.predicates, pred];
    await ref.read(ontologyProvider.notifier).updateDraft(
          version.versionId,
          classes: version.classes,
          predicates: updated,
        );
  }
}

class _PredicateCard extends ConsumerWidget {
  final OntologyPredicate pred;
  final int index;
  final bool isDraft;
  final OntologyVersion version;
  const _PredicateCard(
      {required this.pred,
      required this.index,
      required this.isDraft,
      required this.version});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        elevated: true,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.link, size: 15,
                  color: AppColors.secondary),
              const SizedBox(width: 6),
              Text(pred.name,
                  style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(width: 8),
              if (pred.domain.isNotEmpty || pred.range.isNotEmpty)
                Flexible(
                  child: Text(
                    '${pred.domain.join(', ')} → ${pred.range.join(', ')}',
                    style: AppTypography.caption.copyWith(
                        color: AppColors.secondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const Spacer(),
              if (isDraft) ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 15,
                      color: AppColors.textMuted),
                  onPressed: () => _editDialog(context, ref),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 2),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 15, color: AppColors.error),
                  onPressed: () => _delete(ref),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ]),
            if (pred.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(pred.description, style: AppTypography.body),
            ],
            // 매핑 칩은 확정/아카이브 탭(isDraft=false)에서만 표시
            if (!isDraft && pred.standardTag.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: pred.standardTag.split('·').map((tag) => Chip(
                      label: Text(tag.trim(),
                          style: const TextStyle(fontSize: 10)),
                      backgroundColor: Colors.teal.withValues(alpha: 0.08),
                      side: BorderSide(
                          color: Colors.teal.withValues(alpha: 0.25)),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _editDialog(BuildContext context, WidgetRef ref) async {
    final updated = await showDialog<OntologyPredicate>(
      context: context,
      builder: (ctx) => _PredicateEditDialog(
        initial: pred,
        availableClasses: version.classes.map((c) => c.name).toList(),
      ),
    );
    if (updated == null || !context.mounted) return;
    final preds = [...version.predicates];
    preds[index] = updated;
    await ref.read(ontologyProvider.notifier).updateDraft(
          version.versionId,
          classes: version.classes,
          predicates: preds,
        );
  }

  Future<void> _delete(WidgetRef ref) async {
    final preds = [...version.predicates]..removeAt(index);
    await ref.read(ontologyProvider.notifier).updateDraft(
          version.versionId,
          classes: version.classes,
          predicates: preds,
        );
  }
}

// ── 클래스 편집 다이얼로그 ────────────────────────────────────────────────────

class _ClassEditDialog extends ConsumerStatefulWidget {
  final OntologyClass? initial;
  const _ClassEditDialog({this.initial});

  @override
  ConsumerState<_ClassEditDialog> createState() => _ClassEditDialogState();
}

class _ClassEditDialogState extends ConsumerState<_ClassEditDialog> {
  final _nameCtrl = TextEditingController();
  final _labelCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _exCtrl = TextEditingController();
  String _color = '#4A90D9';
  List<String> _examples = [];
  List<ClassMapping> _mappings = [];
  String? _pendingMappingKey; // "ontologyId:::curie"

  static const _colorOptions = [
    '#4A90D9', '#E74C3C', '#2ECC71', '#F39C12', '#9B59B6',
    '#1ABC9C', '#E67E22', '#3498DB', '#D35400', '#27AE60',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      final c = widget.initial!;
      _nameCtrl.text = c.name;
      _labelCtrl.text = c.labelKo;
      _descCtrl.text = c.description;
      _color = c.color;
      _examples = List.from(c.examples);
      _mappings = List.from(c.mappings);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _labelCtrl.dispose();
    _descCtrl.dispose();
    _exCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? '클래스 추가' : '클래스 수정'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 색상 선택
              const Text('색상', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: _colorOptions.map((c) {
                  final col = _parseColor(c);
                  return GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: col,
                        shape: BoxShape.circle,
                        border: _color == c
                            ? Border.all(color: Colors.black, width: 2)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: '클래스명 (영문)',
                      hintText: 'Person',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _labelCtrl,
                    decoration: const InputDecoration(
                      labelText: '한국어 레이블',
                      hintText: '인물',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              TextField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: '설명',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              // 예시 입력
              const Text('예시', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _exCtrl,
                    decoration: const InputDecoration(
                      hintText: '예시 추가 후 엔터',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (v) {
                      if (v.trim().isNotEmpty) {
                        setState(() {
                          _examples.add(v.trim());
                          _exCtrl.clear();
                        });
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    if (_exCtrl.text.trim().isNotEmpty) {
                      setState(() {
                        _examples.add(_exCtrl.text.trim());
                        _exCtrl.clear();
                      });
                    }
                  },
                ),
              ]),
              if (_examples.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _examples.asMap().entries.map((e) => Chip(
                        label: Text(e.value,
                            style: const TextStyle(fontSize: 11)),
                        onDeleted: () =>
                            setState(() => _examples.removeAt(e.key)),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      )).toList(),
                ),
              ],
              const SizedBox(height: 14),
              // ── 공표 온톨로지 매핑 ────────────────────────────────────────
              const Text('공표 온톨로지 매핑',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              ..._mappings.asMap().entries.map((e) {
                final i = e.key;
                final m = e.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    Tooltip(
                      message: m.isPrimary ? '주 매핑 (클릭하여 부로 전환)' : '부 매핑 (클릭하여 주로 전환)',
                      child: IconButton(
                        icon: Icon(
                          m.isPrimary ? Icons.star : Icons.star_border,
                          size: 16,
                          color: m.isPrimary ? Colors.indigo : Colors.grey,
                        ),
                        onPressed: () => setState(
                            () => _mappings[i] = m.copyWith(isPrimary: !m.isPrimary)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${m.curie}  (${m.ontologyId})',
                        style: TextStyle(
                          fontSize: 12,
                          color: m.isPrimary ? Colors.indigo : Colors.purple,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 14, color: Colors.red),
                      onPressed: () => setState(() => _mappings.removeAt(i)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ]),
                );
              }),
              // 새 매핑 추가
              Builder(builder: (ctx) {
                final pubState = ref.watch(publishedOntologyProvider);
                final allClasses = [
                  for (final o in pubState.ontologies)
                    for (final c in o.classes)
                      (key: '${o.id}:::${c.curie}', curie: c.curie, label: c.label, ontologyId: o.id),
                ];
                final available = allClasses
                    .where((item) => !_mappings.any((m) => m.curie == item.curie))
                    .toList();
                return Row(children: [
                  Expanded(
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      child: DropdownButton<String>(
                        value: _pendingMappingKey,
                        hint: const Text('공표 클래스 선택',
                            style: TextStyle(fontSize: 12)),
                        items: available
                            .map((item) => DropdownMenuItem<String>(
                                  value: item.key,
                                  child: Text(
                                    '${item.curie}  ${item.label}',
                                    style: const TextStyle(fontSize: 11),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _pendingMappingKey = v),
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: Icon(
                      Icons.add_circle_outline,
                      color: _pendingMappingKey != null
                          ? Colors.indigo
                          : Colors.grey,
                    ),
                    onPressed: _pendingMappingKey == null
                        ? null
                        : () {
                            final parts = _pendingMappingKey!.split(':::');
                            setState(() {
                              _mappings.add(ClassMapping(
                                curie: parts[1],
                                ontologyId: parts[0],
                                isPrimary: _mappings.isEmpty,
                              ));
                              _pendingMappingKey = null;
                            });
                          },
                    tooltip: '매핑 추가',
                  ),
                ]);
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소')),
        ElevatedButton(
          onPressed: () {
            if (_nameCtrl.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              OntologyClass(
                name: _nameCtrl.text.trim(),
                labelKo: _labelCtrl.text.trim(),
                color: _color,
                description: _descCtrl.text.trim(),
                examples: _examples,
                mappings: _mappings,
              ),
            );
          },
          child: const Text('저장'),
        ),
      ],
    );
  }
}

// ── 속성 편집 다이얼로그 ──────────────────────────────────────────────────────

class _PredicateEditDialog extends StatefulWidget {
  final OntologyPredicate? initial;
  final List<String> availableClasses;
  const _PredicateEditDialog(
      {this.initial, required this.availableClasses});

  @override
  State<_PredicateEditDialog> createState() => _PredicateEditDialogState();
}

class _PredicateEditDialogState extends State<_PredicateEditDialog> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  List<String> _domain = [];
  List<String> _range = [];

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      final p = widget.initial!;
      _nameCtrl.text = p.name;
      _descCtrl.text = p.description;
      _domain = List.from(p.domain);
      _range = List.from(p.range);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? '속성 추가' : '속성 수정'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: '속성명',
                  hintText: '태어난곳',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: '설명',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              _ClassMultiSelect(
                label: '도메인 (주어 클래스)',
                availableClasses: widget.availableClasses,
                selected: _domain,
                onChanged: (v) => setState(() => _domain = v),
              ),
              const SizedBox(height: 10),
              _ClassMultiSelect(
                label: '범위 (목적어 클래스)',
                availableClasses: widget.availableClasses,
                selected: _range,
                onChanged: (v) => setState(() => _range = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소')),
        ElevatedButton(
          onPressed: () {
            if (_nameCtrl.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              OntologyPredicate(
                name: _nameCtrl.text.trim(),
                domain: _domain,
                range: _range,
                description: _descCtrl.text.trim(),
              ),
            );
          },
          child: const Text('저장'),
        ),
      ],
    );
  }
}

class _ClassMultiSelect extends StatelessWidget {
  final String label;
  final List<String> availableClasses;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  const _ClassMultiSelect(
      {required this.label,
      required this.availableClasses,
      required this.selected,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: availableClasses.map((cls) {
            final isSelected = selected.contains(cls);
            return FilterChip(
              label: Text(cls, style: const TextStyle(fontSize: 12)),
              selected: isSelected,
              onSelected: (v) {
                final updated = List<String>.from(selected);
                if (v) {
                  updated.add(cls);
                } else {
                  updated.remove(cls);
                }
                onChanged(updated);
              },
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── 공통 위젯 ─────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final OntologyStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      OntologyStatus.draft     => ('Draft',     AppColors.draft),
      OntologyStatus.confirmed => ('Confirmed', AppColors.confirmed),
      OntologyStatus.archived  => ('Archived',  AppColors.archived),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: AppTypography.badge.copyWith(color: color)),
    );
  }
}

class _Meta extends StatelessWidget {
  final String label;
  final String value;
  const _Meta(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppTypography.caption),
      Text(value,
          style: AppTypography.body.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary)),
    ]);
  }
}

Color _parseColor(String hex) {
  final h = hex.replaceFirst('#', '');
  if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
  return const Color(0xFF888888);
}
