import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/ontology.dart';
import '../../providers/ontology_provider.dart';
import '../../providers/triple_provider.dart';
import '../../api/api_client.dart';
import '../../services/export_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/empty_state.dart';
import 'ontology_working_tab.dart'; // OntologyStatusBadge

// ── [확정] 탭 — Confirmed(활성) + Archived 섹션 구분 ─────────────────────────────

class OntologyConfirmedTab extends ConsumerStatefulWidget {
  const OntologyConfirmedTab({super.key});

  @override
  ConsumerState<OntologyConfirmedTab> createState() =>
      _OntologyConfirmedTabState();
}

class _OntologyConfirmedTabState extends ConsumerState<OntologyConfirmedTab> {
  final Set<String> _selected = {};

  void _toggleSelect(String id) => setState(() {
        if (_selected.contains(id)) {
          _selected.remove(id);
        } else {
          _selected.add(id);
        }
      });

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ontologyProvider);
    final confirmed = state.versions
        .where((v) => v.status == OntologyStatus.confirmed)
        .toList();
    final archived = state.versions
        .where((v) => v.status == OntologyStatus.archived)
        .toList();

    final validIds = {...confirmed, ...archived}.map((v) => v.versionId).toSet();
    _selected.removeWhere((id) => !validIds.contains(id));

    return Row(
      children: [
        // ── 좌측: 확정/아카이브 목록 ─────────────────────────────────────
        SizedBox(
          width: 280,
          child: Column(
            children: [
              _ConfirmedListHeader(
                confirmedCount: confirmed.length,
                archivedCount: archived.length,
                selected: _selected,
                onExport: _selected.isEmpty
                    ? null
                    : () => ExportService.exportOntologies(
                          apiClient: ref.read(apiClientProvider),
                          versionIds: _selected.toList(),
                          context: context,
                        ),
                onClearSelect: () => setState(() => _selected.clear()),
              ),
              Expanded(
                child: (confirmed.isEmpty && archived.isEmpty)
                    ? const _EmptyConfirmedView()
                    : _ConfirmedVersionList(
                        confirmed: confirmed,
                        archived: archived,
                        selected: _selected,
                        onToggle: _toggleSelect,
                      ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        // ── 우측: 확정 상세 패널 ──────────────────────────────────────────
        const Expanded(child: _ConfirmedDetailPanel()),
      ],
    );
  }
}

// ── 목록 헤더 ─────────────────────────────────────────────────────────────────

class _ConfirmedListHeader extends ConsumerWidget {
  final int confirmedCount;
  final int archivedCount;
  final Set<String> selected;
  final VoidCallback? onExport;
  final VoidCallback onClearSelect;
  const _ConfirmedListHeader({
    required this.confirmedCount,
    required this.archivedCount,
    required this.selected,
    required this.onExport,
    required this.onClearSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
            child: Row(
              children: [
                Text('활성 $confirmedCount · 아카이브 $archivedCount',
                    style: AppTypography.heading2),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: () =>
                      ref.read(ontologyProvider.notifier).loadVersions(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: '새로고침',
                ),
              ],
            ),
          ),
          if (selected.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryFaint,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Text('${selected.length}개 선택됨',
                      style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.download_outlined, size: 18,
                        color: AppColors.primary),
                    tooltip: '내보내기',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onExport,
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16,
                        color: AppColors.textMuted),
                    tooltip: '선택 해제',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onClearSelect,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── 빈 상태 ───────────────────────────────────────────────────────────────────

class _EmptyConfirmedView extends StatelessWidget {
  const _EmptyConfirmedView();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.check_circle_outline,
      title: '확정된 버전이 없습니다',
      description: '[작업 중] 탭의 Draft를 확정하면\n여기에 표시됩니다.',
    );
  }
}

// ── 버전 목록 (활성 + 아카이브 섹션) ──────────────────────────────────────────

class _ConfirmedVersionList extends ConsumerWidget {
  final List<OntologyVersion> confirmed;
  final List<OntologyVersion> archived;
  final Set<String> selected;
  final void Function(String) onToggle;
  const _ConfirmedVersionList({
    required this.confirmed,
    required this.archived,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailSelected = ref.watch(ontologyProvider).selectedVersion;
    final notifier = ref.read(ontologyProvider.notifier);

    return ListView(
      children: [
        if (confirmed.isNotEmpty) ...[
          _SectionHeader(
            icon: Icons.circle,
            iconColor: AppColors.confirmed,
            label: '활성 (${confirmed.length})',
          ),
          ...confirmed.map((v) => _VersionTile(
                version: v,
                isDetailSelected:
                    detailSelected?.versionId == v.versionId,
                inExport: selected.contains(v.versionId),
                onTap: () => notifier.selectVersion(v),
                onToggle: () => onToggle(v.versionId),
              )),
        ],
        if (confirmed.isNotEmpty && archived.isNotEmpty)
          const Divider(height: 1, color: AppColors.border),
        if (archived.isNotEmpty) ...[
          _SectionHeader(
            icon: Icons.circle_outlined,
            iconColor: AppColors.archived,
            label: '아카이브 (${archived.length})',
          ),
          ...archived.map((v) => _VersionTile(
                version: v,
                isDetailSelected:
                    detailSelected?.versionId == v.versionId,
                inExport: selected.contains(v.versionId),
                onTap: () => notifier.selectVersion(v),
                onToggle: () => onToggle(v.versionId),
              )),
        ],
      ],
    );
  }
}

// ── 섹션 헤더 ─────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  const _SectionHeader(
      {required this.icon, required this.iconColor, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Row(
        children: [
          Icon(icon, size: 10, color: iconColor),
          const SizedBox(width: 6),
          Text(label,
              style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ── 버전 타일 ─────────────────────────────────────────────────────────────────

class _VersionTile extends StatelessWidget {
  final OntologyVersion version;
  final bool isDetailSelected;
  final bool inExport;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  const _VersionTile({
    required this.version,
    required this.isDetailSelected,
    required this.inExport,
    required this.onTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isDetailSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : null,
          border: Border(
            left: BorderSide(
              color: isDetailSelected
                  ? AppColors.primary
                  : Colors.transparent,
              width: 3,
            ),
            bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: inExport,
                onChanged: (_) => onToggle(),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(version.versionId,
                      style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary),
                      overflow: TextOverflow.ellipsis),
                  Text(
                      '클래스 ${version.classes.length}개 · 속성 ${version.predicates.length}개',
                      style: AppTypography.caption),
                ],
              ),
            ),
            OntologyStatusBadge(status: version.status),
          ],
        ),
      ),
    );
  }
}

// ── 확정 상세 패널 ────────────────────────────────────────────────────────────

class _ConfirmedDetailPanel extends ConsumerWidget {
  const _ConfirmedDetailPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(ontologyProvider).selectedVersion;
    if (selected == null) {
      return const EmptyState(
        icon: Icons.check_circle_outline,
        title: '버전을 선택하세요',
        description: '좌측에서 확정 버전을 선택하면\n상세 내용이 표시됩니다.',
      );
    }
    return _ConfirmedDetail(version: selected);
  }
}

// ── 확정 상세 뷰 (StatefulWidget) ──────────────────────────────────────────────

class _ConfirmedDetail extends ConsumerStatefulWidget {
  final OntologyVersion version;
  const _ConfirmedDetail({required this.version});

  @override
  ConsumerState<_ConfirmedDetail> createState() => _ConfirmedDetailState();
}

class _ConfirmedDetailState extends ConsumerState<_ConfirmedDetail>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _isEditingName = false;
  late final TextEditingController _nameCtrl;
  bool _reportExpanded = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _nameCtrl = TextEditingController(text: widget.version.versionId);
  }

  @override
  void didUpdateWidget(_ConfirmedDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.version.versionId != widget.version.versionId) {
      _isEditingName = false;
      _nameCtrl.text = widget.version.versionId;
      _reportExpanded = false;
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  OntologyVersion get v =>
      ref.watch(ontologyProvider).selectedVersion ?? widget.version;

  bool get isConfirmed => v.status == OntologyStatus.confirmed;
  bool get isArchived  => v.status == OntologyStatus.archived;

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
      _snack(ref.read(ontologyProvider).error ?? '이름 변경 실패', isError: true);
    }
  }

  Future<void> _deleteVersion() async {
    int tripleCount = 0;
    try {
      final triples = await ref
          .read(tripleApiProvider)
          .listTriples(version: v.versionId, status: 'active');
      tripleCount = triples.length;
    } catch (_) {}

    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('온톨로지 삭제'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('"${v.versionId}"을 영구 삭제하시겠습니까?'),
            const SizedBox(height: 8),
            if (tripleCount > 0)
              Text(
                '⚠ 이 버전을 참조하는 트리플이 $tripleCount개 있습니다.\n'
                '트리플은 삭제되지 않지만 온톨로지 정보를 잃습니다.',
                style: const TextStyle(color: Colors.orange, fontSize: 13),
              ),
            const SizedBox(height: 4),
            const Text('이 작업은 되돌릴 수 없습니다.',
                style: TextStyle(color: Colors.red, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final success = await ref
        .read(ontologyProvider.notifier)
        .deleteVersion(v.versionId, force: true);
    if (!mounted) return;
    if (success) {
      messenger.showSnackBar(
          const SnackBar(content: Text('온톨로지가 삭제되었습니다.')));
    } else {
      _snack(ref.read(ontologyProvider).error ?? '삭제 실패', isError: true);
    }
  }

  Future<void> _archiveVersion() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('아카이브'),
        content: Text('"${v.versionId}"을 아카이브하시겠습니까?\n아카이브된 버전은 읽기 전용으로 유지됩니다.'),
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
    if (ok != true || !mounted) return;
    final success =
        await ref.read(ontologyProvider.notifier).archiveVersion(v.versionId);
    if (!success && mounted) {
      _snack(ref.read(ontologyProvider).error ?? '아카이브 실패', isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = v.confirmedAt != null && v.confirmedAt!.length >= 10
        ? v.confirmedAt!.substring(0, 10)
        : (v.confirmedAt ?? '—');
    final createdStr = v.createdAt.length >= 10
        ? v.createdAt.substring(0, 10)
        : v.createdAt;

    return Column(
      children: [
        // ── 헤더 ──────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              OntologyStatusBadge(status: v.status),
              const SizedBox(width: 10),
              if (_isEditingName && isConfirmed)
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _nameCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    ),
                    style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary),
                    onSubmitted: (_) => _saveName(),
                  ),
                )
              else
                Flexible(
                  child: Text(v.versionId,
                      style: AppTypography.heading2,
                      overflow: TextOverflow.ellipsis),
                ),
              if (isConfirmed) ...[
                IconButton(
                  icon: Icon(
                      _isEditingName ? Icons.check : Icons.edit_outlined,
                      size: 16,
                      color: AppColors.textSecondary),
                  tooltip: _isEditingName ? '저장' : '이름 변경',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _isEditingName
                      ? _saveName
                      : () => setState(() {
                            _nameCtrl.text = v.versionId;
                            _isEditingName = true;
                          }),
                ),
              ],
              const Spacer(),
              if (isConfirmed) ...[
                OutlinedButton(
                  onPressed: _archiveVersion,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.archived,
                    side: BorderSide(color: AppColors.archived),
                  ),
                  child: const Text('아카이브'),
                ),
                const SizedBox(width: 8),
              ],
              OutlinedButton(
                onPressed: _deleteVersion,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
                child: const Text('삭제'),
              ),
              if (isArchived) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.archived.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.archived.withValues(alpha: 0.3)),
                  ),
                  child: Text('읽기 전용',
                      style: AppTypography.badge.copyWith(color: AppColors.archived)),
                ),
              ],
            ],
          ),
        ),

        // ── 메타 정보 ──────────────────────────────────────────────────────
        Container(
          color: AppColors.surfaceElevated,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(children: [
            _Meta('생성일', createdStr),
            const SizedBox(width: 20),
            if (v.confirmedAt != null) ...[
              _Meta('확정일', dateStr),
              const SizedBox(width: 20),
            ],
            _Meta('클래스', '${v.classes.length}개'),
            const SizedBox(width: 20),
            _Meta('속성', '${v.predicates.length}개'),
          ]),
        ),
        const Divider(height: 1, color: AppColors.border),

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
              _ClassesReadOnly(version: v),
              _PredicatesReadOnly(version: v),
            ],
          ),
        ),

        // ── 종합 원칙 리포트 ─────────────────────────────────────────────
        if (v.description.isNotEmpty) ...[
          const Divider(height: 1, color: AppColors.border),
          InkWell(
            onTap: () =>
                setState(() => _reportExpanded = !_reportExpanded),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.summarize_outlined,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text('종합 원칙 리포트',
                      style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Icon(
                    _reportExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (_reportExpanded)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(6),
              ),
              child: SelectableText(
                v.description,
                style: AppTypography.body,
              ),
            ),
        ],
      ],
    );
  }
}

// ── 메타 레이블 ───────────────────────────────────────────────────────────────

class _Meta extends StatelessWidget {
  final String label;
  final String value;
  const _Meta(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('$label: ', style: AppTypography.caption),
      Text(value,
          style: AppTypography.caption.copyWith(
              color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
    ]);
  }
}

// ── 클래스 읽기 전용 탭 ───────────────────────────────────────────────────────

class _ClassesReadOnly extends StatelessWidget {
  final OntologyVersion version;
  const _ClassesReadOnly({required this.version});

  @override
  Widget build(BuildContext context) {
    if (version.classes.isEmpty) {
      return Center(
          child: Text('클래스 없음', style: AppTypography.caption));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: version.classes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final cls = version.classes[i];
        return AppCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _parseColor(cls.color),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(cls.name,
                      style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                  if (cls.labelKo.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text('(${cls.labelKo})',
                        style: AppTypography.caption),
                  ],
                  if (cls.standardTag.isNotEmpty) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: AppColors.secondary.withValues(alpha: 0.3)),
                      ),
                      child: Text(cls.standardTag,
                          style: AppTypography.badge.copyWith(
                              color: AppColors.secondary,
                              fontFamily: 'monospace')),
                    ),
                  ],
                ],
              ),
              if (cls.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(cls.description, style: AppTypography.caption),
              ],
            ],
          ),
        );
      },
    );
  }

  Color _parseColor(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return AppColors.textMuted;
    }
  }
}

// ── 속성 읽기 전용 탭 ─────────────────────────────────────────────────────────

class _PredicatesReadOnly extends StatelessWidget {
  final OntologyVersion version;
  const _PredicatesReadOnly({required this.version});

  @override
  Widget build(BuildContext context) {
    if (version.predicates.isEmpty) {
      return Center(
          child: Text('속성 없음', style: AppTypography.caption));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: version.predicates.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final p = version.predicates[i];
        return AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary)),
                    if (p.domain.isNotEmpty || p.range.isNotEmpty)
                      Text(
                        '${p.domain.join(', ')} → ${p.range.join(', ')}',
                        style: AppTypography.caption,
                      ),
                  ],
                ),
              ),
              if (p.standardTag.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Text(p.standardTag,
                      style: AppTypography.badge.copyWith(
                          color: AppColors.primary,
                          fontFamily: 'monospace')),
                ),
            ],
          ),
        );
      },
    );
  }
}
