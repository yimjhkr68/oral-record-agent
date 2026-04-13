import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/ontology.dart';
import '../../providers/ontology_provider.dart';
import '../../api/api_client.dart';
import '../../api/ontology_api.dart';
import '../../services/export_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/common/empty_state.dart';
import 'ontology_working_tab.dart'; // OntologyStatusBadge
import 'mapping_card.dart';

// ── [표준화] 탭 ──────────────────────────────────────────────────────────────────

class OntologyStandardTab extends ConsumerStatefulWidget {
  const OntologyStandardTab({super.key});

  @override
  ConsumerState<OntologyStandardTab> createState() =>
      _OntologyStandardTabState();
}

class _OntologyStandardTabState extends ConsumerState<OntologyStandardTab> {
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
    final drafts = state.versions
        .where((v) => v.status == OntologyStatus.draft)
        .toList();

    final validIds = drafts.map((v) => v.versionId).toSet();
    _selected.removeWhere((id) => !validIds.contains(id));

    return Row(
      children: [
        // ── 좌측: Draft 목록 ─────────────────────────────────────────────
        SizedBox(
          width: 280,
          child: Column(
            children: [
              _StandardListHeader(
                count: drafts.length,
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
                child: drafts.isEmpty
                    ? const _EmptyStandardView()
                    : _StandardVersionList(
                        versions: drafts,
                        selected: _selected,
                        onToggle: _toggleSelect,
                      ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        // ── 우측: 매핑 편집 패널 ─────────────────────────────────────────
        const Expanded(child: _MappingDetailPanel()),
      ],
    );
  }
}

// ── 헤더 ──────────────────────────────────────────────────────────────────────

class _StandardListHeader extends ConsumerWidget {
  final int count;
  final Set<String> selected;
  final VoidCallback? onExport;
  final VoidCallback onClearSelect;
  const _StandardListHeader({
    required this.count,
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
                Text('표준화 초안 ($count)', style: AppTypography.heading2),
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
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3)),
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

class _EmptyStandardView extends StatelessWidget {
  const _EmptyStandardView();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.schema_outlined,
      title: 'Draft 온톨로지가 없습니다',
      description: '[작업 중] 탭에서 새 Draft를 생성하거나\nAI로 자동 생성하세요.',
    );
  }
}

// ── 버전 목록 ─────────────────────────────────────────────────────────────────

class _StandardVersionList extends ConsumerWidget {
  final List<OntologyVersion> versions;
  final Set<String> selected;
  final void Function(String) onToggle;
  const _StandardVersionList({
    required this.versions,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailSelected = ref.watch(ontologyProvider).selectedVersion;
    return ListView.builder(
      itemCount: versions.length,
      itemBuilder: (context, i) {
        final v = versions[i];
        final isDetailSelected = detailSelected?.versionId == v.versionId;
        final inExport = selected.contains(v.versionId);
        final taggedCount =
            v.classes.where((c) => c.standardTag.isNotEmpty).length;
        return InkWell(
          onTap: () =>
              ref.read(ontologyProvider.notifier).selectVersion(v),
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
                bottom: BorderSide(
                    color: AppColors.border.withValues(alpha: 0.5)),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: inExport,
                    onChanged: (_) => onToggle(v.versionId),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.versionId,
                          style: AppTypography.body.copyWith(
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary),
                          overflow: TextOverflow.ellipsis),
                      Text('표준 태그 $taggedCount/${v.classes.length}개',
                          style: AppTypography.caption),
                    ],
                  ),
                ),
                const OntologyStatusBadge(status: OntologyStatus.draft),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── 매핑 패널 (선택 없음 / 선택 있음 분기) ────────────────────────────────────────

class _MappingDetailPanel extends ConsumerWidget {
  const _MappingDetailPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ontologyProvider);
    if (state.selectedVersion == null) {
      return const EmptyState(
        icon: Icons.schema_outlined,
        title: '버전을 선택하세요',
        description: '좌측에서 Draft 버전을 선택하면\n매핑 편집기가 표시됩니다.',
      );
    }
    return _MappingEditor(version: state.selectedVersion!);
  }
}

// ── 매핑 에디터 ────────────────────────────────────────────────────────────────

class _MappingEditor extends ConsumerStatefulWidget {
  final OntologyVersion version;
  const _MappingEditor({required this.version});

  @override
  ConsumerState<_MappingEditor> createState() => _MappingEditorState();
}

class _MappingEditorState extends ConsumerState<_MappingEditor>
    with SingleTickerProviderStateMixin {
  bool _isEditingName = false;
  late final TextEditingController _nameCtrl;

  bool _loading = false;
  List<MappingItem> _classItems = [];
  List<MappingItem> _predItems = [];

  late final TabController _innerTab;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.version.versionId);
    _innerTab = TabController(length: 2, vsync: this);
    _loadMappings();
  }

  @override
  void didUpdateWidget(_MappingEditor old) {
    super.didUpdateWidget(old);
    if (old.version.versionId != widget.version.versionId) {
      _isEditingName = false;
      _nameCtrl.text = widget.version.versionId;
      setState(() {
        _classItems = [];
        _predItems = [];
      });
      _loadMappings();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _innerTab.dispose();
    super.dispose();
  }

  OntologyVersion get v =>
      ref.read(ontologyProvider).selectedVersion ?? widget.version;

  OntologyApi get _api => OntologyApi(ref.read(apiClientProvider));

  Future<void> _loadMappings() async {
    setState(() => _loading = true);
    try {
      final result = await _api.getMappings(v.versionId);
      if (mounted) {
        setState(() {
          _classItems = result['classes'] ?? [];
          _predItems = result['predicates'] ?? [];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onSaveClass(String name, String tag, bool confirmed) async {
    setState(() {
      _classItems = _classItems
          .map((item) => item.name == name
              ? item.copyWith(currentTag: tag, isConfirmed: confirmed)
              : item)
          .toList();
    });
    try {
      await _api.saveMappings(v.versionId,
          classes: [
            {'name': name, 'tag': tag, 'confirmed': confirmed}
          ]);
      ref.read(ontologyProvider.notifier).loadVersions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('클래스 매핑 저장 실패: $e'),
              backgroundColor: Colors.orange),
        );
      }
    }
  }

  Future<void> _onSavePred(String name, String tag, bool confirmed) async {
    setState(() {
      _predItems = _predItems
          .map((item) => item.name == name
              ? item.copyWith(currentTag: tag, isConfirmed: confirmed)
              : item)
          .toList();
    });
    try {
      await _api.saveMappings(v.versionId,
          predicates: [
            {'name': name, 'tag': tag, 'confirmed': confirmed}
          ]);
      ref.read(ontologyProvider.notifier).loadVersions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('속성 매핑 저장 실패: $e'),
              backgroundColor: Colors.orange),
        );
      }
    }
  }

  Future<void> _applyAll() async {
    final updated = _classItems.map((item) {
      if (item.suggestions.isNotEmpty) {
        return item.copyWith(
            currentTag: item.suggestions.first.uri, isConfirmed: false);
      }
      return item;
    }).toList();
    setState(() => _classItems = updated);

    final patches = updated
        .where((item) => item.currentTag.isNotEmpty)
        .map((item) => {
              'name': item.name,
              'tag': item.currentTag,
              'confirmed': item.isConfirmed,
            })
        .toList();
    if (patches.isEmpty) return;

    try {
      await _api.saveMappings(v.versionId, classes: patches);
      ref.read(ontologyProvider.notifier).loadVersions();
      if (mounted) _snack('${patches.length}개 클래스에 1순위 추천 매핑 적용 완료');
    } catch (_) {
      if (mounted) _snack('적용 실패', isError: true);
    }
  }

  Future<void> _confirmAll() async {
    final updated = _classItems.map((item) {
      if (item.currentTag.isNotEmpty) return item.copyWith(isConfirmed: true);
      return item;
    }).toList();
    setState(() => _classItems = updated);

    final patches = updated
        .where((item) => item.currentTag.isNotEmpty)
        .map((item) => {
              'name': item.name,
              'tag': item.currentTag,
              'confirmed': true,
            })
        .toList();
    if (patches.isEmpty) return;

    try {
      await _api.saveMappings(v.versionId, classes: patches);
      ref.read(ontologyProvider.notifier).loadVersions();
      if (mounted) _snack('${patches.length}개 클래스 매핑 전체 확정 완료');
    } catch (_) {
      if (mounted) _snack('확정 실패', isError: true);
    }
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
      _snack(ref.read(ontologyProvider).error ?? '이름 변경 실패', isError: true);
    }
  }

  Future<void> _confirmVersion(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('온톨로지 확정'),
        content: Text(
            '"${v.versionId}"을 확정하시겠습니까?\n확정 후에는 수정 및 삭제가 불가능합니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.confirmed,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('확정'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final success = await ref
        .read(ontologyProvider.notifier)
        .confirmVersion(v.versionId);
    if (!context.mounted) return;
    if (success) {
      ref.read(ontologyProvider.notifier).loadVersions();
      _snack('"${v.versionId}" 확정됐습니다. 확정 탭에서 확인하세요.');
    } else {
      _snack(ref.read(ontologyProvider).error ?? '확정 실패', isError: true);
    }
  }

  Future<void> _deleteVersion(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Draft 삭제'),
        content: Text('"${v.versionId}"을 삭제하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await ref.read(ontologyProvider.notifier).deleteDraft(v.versionId);
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : null,
      duration: const Duration(seconds: 2),
    ));
  }

  int get _confirmedClassCount =>
      _classItems.where((item) => item.isConfirmed).length;
  int get _confirmedPredCount =>
      _predItems.where((item) => item.isConfirmed).length;

  @override
  Widget build(BuildContext context) {
    ref.watch(ontologyProvider);
    return Column(
      children: [
        _buildHeader(context),
        _buildActionBar(),
        Material(
          color: Colors.transparent,
          child: TabBar(
            controller: _innerTab,
            labelStyle: AppTypography.body.copyWith(fontWeight: FontWeight.w500),
            unselectedLabelStyle: AppTypography.body,
            tabs: [
              Tab(text: '클래스 매핑  $_confirmedClassCount/${_classItems.length}'),
              Tab(text: '속성 매핑  $_confirmedPredCount/${_predItems.length}'),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _innerTab,
                  children: [
                    _buildMappingList(_classItems,
                        (name, tag, confirmed) =>
                            _onSaveClass(name, tag, confirmed)),
                    _buildMappingList(_predItems,
                        (name, tag, confirmed) =>
                            _onSavePred(name, tag, confirmed)),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const OntologyStatusBadge(status: OntologyStatus.draft),
          const SizedBox(width: 10),
          if (_isEditingName)
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
          const Spacer(),
          OutlinedButton(
            onPressed: () => _confirmVersion(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.confirmed,
              side: const BorderSide(color: AppColors.confirmed),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
            ),
            child: const Text('확정하기', style: TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => _deleteVersion(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
            ),
            child: const Text('삭제', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Text(
            'CIDOC-CRM · FOAF · Dublin Core · Schema.org',
            style: AppTypography.caption,
          ),
          const Spacer(),
          OutlinedButton.icon(
            icon: const Icon(Icons.auto_fix_high, size: 14),
            label: const Text('전체 자동 적용', style: TextStyle(fontSize: 12)),
            onPressed: _loading ? null : _applyAll,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.check_circle_outline, size: 14),
            label: const Text('전체 확정', style: TextStyle(fontSize: 12)),
            onPressed: _loading ? null : _confirmAll,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.confirmed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            tooltip: '매핑 새로고침',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: _loading ? null : _loadMappings,
          ),
        ],
      ),
    );
  }

  Widget _buildMappingList(
    List<MappingItem> items,
    void Function(String name, String tag, bool confirmed) onSave,
  ) {
    if (items.isEmpty) {
      return Center(
        child: Text('항목이 없습니다.', style: AppTypography.caption),
      );
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, i) => MappingCard(
        item: items[i],
        onSave: (tag, confirmed) => onSave(items[i].name, tag, confirmed),
      ),
    );
  }
}
