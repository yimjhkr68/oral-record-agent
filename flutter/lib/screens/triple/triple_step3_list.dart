import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/ontology.dart';
import '../../models/triple.dart';
import '../../providers/ontology_provider.dart';
import '../../providers/triple_provider.dart';

// ── 클래스별 색상 ─────────────────────────────────────────────────────────────
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

class TripleStep3List extends ConsumerStatefulWidget {
  const TripleStep3List({super.key});

  @override
  ConsumerState<TripleStep3List> createState() => _TripleStep3ListState();
}

class _TripleStep3ListState extends ConsumerState<TripleStep3List>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  late TabController _tabCtrl;
  Triple? _selected;

  // 클라이언트 필터
  final Set<String> _selectedTypes = {};
  String _sourceFilter = '';
  bool _showFilters = false;
  final _sourceFilterCtrl = TextEditingController();

  // 다중 선택
  final Set<String> _checkedIds = {};
  bool _isSelecting = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() {
      if (_tabCtrl.indexIsChanging) return;
      // addPostFrameCallback: build 완료 후 provider 변경 → 블랙스크린 방지
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(tripleStatusProvider.notifier).state =
            _tabCtrl.index == 0 ? 'active' : 'archived';
        setState(() => _selected = null);
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _sourceFilterCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  void _search() {
    ref.read(tripleQueryProvider.notifier).state =
        _searchCtrl.text.trim();
  }

  void _clearAllFilters() {
    _searchCtrl.clear();
    _sourceFilterCtrl.clear();
    setState(() {
      _selectedTypes.clear();
      _sourceFilter = '';
    });
    ref.read(tripleQueryProvider.notifier).state = '';
    ref.read(tripleVersionFilterProvider.notifier).state = null;
  }

  List<Triple> _applyFilters(List<Triple> triples) {
    return triples.where((t) {
      if (_selectedTypes.isNotEmpty &&
          !_selectedTypes.contains(t.subjectType) &&
          !_selectedTypes.contains(t.objectType)) {
        return false;
      }
      if (_sourceFilter.isNotEmpty &&
          !t.sourceRecordId.toLowerCase().contains(_sourceFilter.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
  }

  bool get _hasActiveFilters {
    final version = ref.read(tripleVersionFilterProvider);
    return _selectedTypes.isNotEmpty || _sourceFilter.isNotEmpty || version != null;
  }

  // ── 다중 선택 액션 ─────────────────────────────────────────────────────────
  Future<void> _archiveSelected() async {
    final ids = Set<String>.from(_checkedIds);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('선택 아카이브'),
        content: Text('선택한 ${ids.length}개 트리플을 아카이브하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('아카이브')),
        ],
      ),
    );
    if (ok != true) return;
    for (final id in ids) {
      try {
        await ref.read(tripleApiProvider).archiveTriple(id);
      } catch (_) {}
    }
    ref.invalidate(tripleListProvider);
    setState(() {
      _checkedIds.clear();
      _isSelecting = false;
      _selected = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${ids.length}개 아카이브됨')),
      );
    }
  }

  Future<void> _deleteSelected() async {
    final ids = Set<String>.from(_checkedIds);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('선택 삭제'),
        content: Text('선택한 ${ids.length}개 트리플을 영구 삭제하시겠습니까?\n되돌릴 수 없습니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    for (final id in ids) {
      try {
        await ref.read(tripleApiProvider).deleteTriple(id);
      } catch (_) {}
    }
    ref.invalidate(tripleListProvider);
    setState(() {
      _checkedIds.clear();
      _isSelecting = false;
      _selected = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${ids.length}개 삭제됨')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final listAsync    = ref.watch(tripleListProvider);
    final searchQuery  = ref.watch(tripleQueryProvider);
    final selVersion   = ref.watch(tripleVersionFilterProvider);
    final allVersions  = ref.watch(ontologyProvider).versions
        .where((v) => v.status == OntologyStatus.confirmed)
        .toList();
    final hasFilter = _hasActiveFilters;

    return Column(children: [
      // ── 검색바 ────────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: '주어 / 술어 / 목적어 검색',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          ref.read(tripleQueryProvider.notifier).state = '';
                          setState(() {});
                        },
                      )
                    : null,
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onSubmitted: (_) => _search(),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 4),
          // 필터 버튼
          Stack(children: [
            IconButton(
              icon: Icon(
                _showFilters ? Icons.filter_list : Icons.filter_list_outlined,
                color: hasFilter
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              tooltip: '필터',
              onPressed: () => setState(() => _showFilters = !_showFilters),
            ),
            if (hasFilter)
              Positioned(
                right: 6, top: 6,
                child: Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ]),
          // 다중 선택 토글 버튼
          IconButton(
            icon: Icon(
              _isSelecting
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
              color: _isSelecting
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            tooltip: _isSelecting ? '선택 모드 해제' : '다중 선택',
            onPressed: () => setState(() {
              _isSelecting = !_isSelecting;
              if (!_isSelecting) {
                _checkedIds.clear();
                _selected = null;
              }
            }),
          ),
        ]),
      ),

      // ── 필터 패널 (토글) ──────────────────────────────────────────
      if (_showFilters)
        Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.04),
            border: Border.all(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 온톨로지 버전 필터
              Text('온톨로지 버전',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600)),
              const SizedBox(height: 6),
              InputDecorator(
                decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                child: DropdownButton<String?>(
                  value: selVersion,
                  isExpanded: true,
                  underline: const SizedBox(),
                  hint: const Text('전체 버전', style: TextStyle(fontSize: 12)),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('전체 버전', style: TextStyle(fontSize: 12))),
                    ...allVersions.map((v) => DropdownMenuItem<String?>(
                          value: v.versionId,
                          child: Text(v.versionId,
                              style: const TextStyle(fontSize: 12)),
                        )),
                  ],
                  onChanged: (v) =>
                      ref.read(tripleVersionFilterProvider.notifier).state = v,
                ),
              ),
              const SizedBox(height: 10),

              // 클래스 타입 칩
              Text('클래스 타입',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: _classColors.keys.map((type) {
                  final sel = _selectedTypes.contains(type);
                  return FilterChip(
                    label: Text(type,
                        style: TextStyle(
                            fontSize: 10,
                            color: sel ? Colors.white : null)),
                    selected: sel,
                    backgroundColor: Colors.white,
                    selectedColor: _colorForType(type),
                    checkmarkColor: Colors.white,
                    side: BorderSide(
                        color: _colorForType(type).withValues(alpha: 0.5)),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    labelPadding:
                        const EdgeInsets.symmetric(horizontal: 6),
                    onSelected: (v) => setState(() {
                      v
                          ? _selectedTypes.add(type)
                          : _selectedTypes.remove(type);
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),

              // 출처 ID 필터
              Text('출처 ID',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600)),
              const SizedBox(height: 6),
              TextField(
                controller: _sourceFilterCtrl,
                decoration: InputDecoration(
                  hintText: '구술기록 ID 일부 입력',
                  isDense: true,
                  border: const OutlineInputBorder(),
                  suffixIcon: _sourceFilter.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 14),
                          onPressed: () {
                            _sourceFilterCtrl.clear();
                            setState(() => _sourceFilter = '');
                          },
                        )
                      : null,
                ),
                onChanged: (v) => setState(() => _sourceFilter = v.trim()),
              ),

              if (hasFilter || searchQuery.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Icon(Icons.clear_all, size: 14),
                    label: const Text('모두 초기화',
                        style: TextStyle(fontSize: 11)),
                    onPressed: _clearAllFilters,
                  ),
                ),
            ],
          ),
        ),

      TabBar(
        controller: _tabCtrl,
        tabs: const [Tab(text: '활성'), Tab(text: '아카이브')],
      ),

      // ── 목록 + 상세 패널 ─────────────────────────────────────────
      Expanded(
        child: listAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('오류: $e', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(tripleListProvider),
                child: const Text('다시 시도'),
              ),
            ]),
          ),
          data: (data) {
            final allTriples = data.triples;
            final filtered   = _applyFilters(allTriples);

            if (allTriples.isEmpty) {
              return const Center(
                child: Text('저장된 트리플이 없습니다.',
                    style: TextStyle(color: Colors.grey)),
              );
            }
            return Column(children: [
              // ── 통계 바 ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 5),
                color: Colors.grey.shade50,
                child: Row(children: [
                  Text(
                    hasFilter
                        ? '총 ${allTriples.length}개  →  ${filtered.length}개 표시'
                        : '총 ${allTriples.length}개',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600),
                  ),
                  if (_isSelecting && filtered.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => setState(() {
                        if (_checkedIds.length == filtered.length) {
                          _checkedIds.clear();
                        } else {
                          _checkedIds
                            ..clear()
                            ..addAll(filtered.map((t) => t.id));
                        }
                      }),
                      child: Text(
                        _checkedIds.length == filtered.length
                            ? '전체 해제'
                            : '전체 선택',
                        style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.primary,
                            decoration: TextDecoration.underline),
                      ),
                    ),
                  ],
                  if (hasFilter) ...[
                    const Spacer(),
                    GestureDetector(
                      onTap: _clearAllFilters,
                      child: Text('필터 초기화',
                          style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.primary,
                              decoration: TextDecoration.underline)),
                    ),
                  ],
                ]),
              ),

              // ── 목록 영역 ────────────────────────────────────────
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          hasFilter
                              ? '필터 조건에 맞는 트리플이 없습니다.'
                              : '검색 결과가 없습니다.',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    : Row(children: [
                        Expanded(
                          flex: (!_isSelecting && _selected != null) ? 3 : 1,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final t = filtered[i];
                              final isSelected = _selected?.id == t.id;
                              final isChecked = _checkedIds.contains(t.id);
                              return _TripleRow(
                                triple: t,
                                selected: !_isSelecting && isSelected,
                                checkMode: _isSelecting,
                                checked: isChecked,
                                onTap: () {
                                  if (_isSelecting) {
                                    setState(() => isChecked
                                        ? _checkedIds.remove(t.id)
                                        : _checkedIds.add(t.id));
                                  } else {
                                    setState(() =>
                                        _selected = isSelected ? null : t);
                                  }
                                },
                              );
                            },
                          ),
                        ),
                        // 상세 패널 — 선택 모드일 때 숨김
                        if (!_isSelecting && _selected != null) ...[
                          const VerticalDivider(width: 1),
                          SizedBox(
                            width: 300,
                            child: _DetailPanel(
                              triple: _selected!,
                              onClose: () =>
                                  setState(() => _selected = null),
                              onArchive: (id) async {
                                await ref
                                    .read(tripleApiProvider)
                                    .archiveTriple(id);
                                ref.invalidate(tripleListProvider);
                                setState(() => _selected = null);
                              },
                              onDelete: (id) async {
                                await ref
                                    .read(tripleApiProvider)
                                    .deleteTriple(id);
                                ref.invalidate(tripleListProvider);
                                setState(() => _selected = null);
                              },
                            ),
                          ),
                        ],
                      ]),
              ),

              // ── 하단 액션 바 (다중 선택 시) ──────────────────────
              if (_isSelecting)
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                        top: BorderSide(color: Colors.grey.shade300)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 4,
                          offset: const Offset(0, -2)),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(children: [
                    Text(
                      _checkedIds.isEmpty
                          ? '트리플을 선택하세요'
                          : '${_checkedIds.length}개 선택됨',
                      style: TextStyle(
                          fontSize: 13,
                          color: _checkedIds.isEmpty
                              ? Colors.grey
                              : Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    if (_checkedIds.isNotEmpty) ...[
                      // 아카이브 버튼 — 활성 탭에서만
                      if (_tabCtrl.index == 0)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.archive_outlined,
                              size: 16),
                          label: const Text('아카이브'),
                          onPressed: _archiveSelected,
                        ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.delete_outline,
                            size: 16),
                        label: const Text('삭제'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white),
                        onPressed: _deleteSelected,
                      ),
                    ],
                  ]),
                ),
            ]);
          },
        ),
      ),
    ]);
  }
}

// ── 트리플 행 ─────────────────────────────────────────────────────────────────

class _TripleRow extends StatelessWidget {
  final Triple triple;
  final bool selected;
  final bool checkMode;
  final bool checked;
  final VoidCallback onTap;

  const _TripleRow({
    required this.triple,
    required this.selected,
    required this.onTap,
    this.checkMode = false,
    this.checked = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = triple;
    final highlight = checkMode ? checked : selected;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: highlight
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: highlight
            ? BorderSide(
                color: Theme.of(context).colorScheme.primary, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(children: [
            // 체크박스 (선택 모드)
            if (checkMode) ...[
              Checkbox(
                value: checked,
                onChanged: (_) => onTap(),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(width: 4),
            ],
            // 주어
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TypeBadge(t.subjectType),
                  const SizedBox(height: 2),
                  Text(t.subject,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            // 술어
            Expanded(
              flex: 2,
              child: Center(
                child: Text(t.predicate,
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis),
              ),
            ),
            // 목적어
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TypeBadge(t.objectType),
                  const SizedBox(height: 2),
                  Text(t.object,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            // 신뢰도
            SizedBox(
              width: 36,
              child: Text(
                t.confidence.toStringAsFixed(1),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                textAlign: TextAlign.right,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── 상세 패널 ─────────────────────────────────────────────────────────────────

class _DetailPanel extends StatefulWidget {
  final Triple triple;
  final VoidCallback onClose;
  final ValueChanged<String> onArchive;
  final ValueChanged<String> onDelete;
  const _DetailPanel({
    required this.triple,
    required this.onClose,
    required this.onArchive,
    required this.onDelete,
  });

  @override
  State<_DetailPanel> createState() => _DetailPanelState();
}

class _DetailPanelState extends State<_DetailPanel> {
  bool _editing = false;
  late TextEditingController _predCtrl;
  late TextEditingController _objCtrl;
  late TextEditingController _noteCtrl;
  late double _confidence;

  @override
  void initState() {
    super.initState();
    _predCtrl   = TextEditingController(text: widget.triple.predicate);
    _objCtrl    = TextEditingController(text: widget.triple.object);
    _noteCtrl   = TextEditingController(text: widget.triple.note);
    _confidence = widget.triple.confidence;
  }

  @override
  void didUpdateWidget(_DetailPanel old) {
    super.didUpdateWidget(old);
    if (old.triple.id != widget.triple.id) {
      _editing       = false;
      _predCtrl.text = widget.triple.predicate;
      _objCtrl.text  = widget.triple.object;
      _noteCtrl.text = widget.triple.note;
      _confidence    = widget.triple.confidence;
    }
  }

  @override
  void dispose() {
    _predCtrl.dispose();
    _objCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t        = widget.triple;
    final isActive = t.status == TripleStatus.active;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          color: Theme.of(context)
              .colorScheme
              .primary
              .withValues(alpha: 0.07),
          child: Row(children: [
            const Text('트리플 상세',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: widget.onClose,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 주어
                _FieldLabel('주어'),
                Row(children: [
                  _TypeBadge(t.subjectType),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(t.subject,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ),
                ]),
                const SizedBox(height: 12),

                // 술어
                _FieldLabel('술어'),
                _editing
                    ? TextField(
                        controller: _predCtrl,
                        decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder()),
                      )
                    : Text(t.predicate,
                        style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context)
                                .colorScheme
                                .primary,
                            fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),

                // 목적어
                _FieldLabel('목적어'),
                _editing
                    ? TextField(
                        controller: _objCtrl,
                        decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder()),
                      )
                    : Row(children: [
                        _TypeBadge(t.objectType),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(t.object,
                                style: const TextStyle(
                                    fontSize: 13))),
                      ]),
                const SizedBox(height: 12),

                // 신뢰도
                _FieldLabel('신뢰도'),
                _editing
                    ? Row(children: [
                        Expanded(
                          child: Slider(
                            value: _confidence,
                            min: 0, max: 1, divisions: 10,
                            onChanged: (v) =>
                                setState(() => _confidence = v),
                          ),
                        ),
                        Text(_confidence.toStringAsFixed(1)),
                      ])
                    : Text(t.confidence.toStringAsFixed(2),
                        style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 12),

                // 메모
                _FieldLabel('메모'),
                _editing
                    ? TextField(
                        controller: _noteCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder()),
                      )
                    : Text(
                        t.note.isEmpty ? '—' : t.note,
                        style: const TextStyle(
                            fontSize: 13, color: Colors.grey),
                      ),
                const SizedBox(height: 12),

                // 메타
                _MetaRow('온톨로지', t.ontologyVersion),
                _MetaRow('출처', t.sourceRecordId.isEmpty ? '—' : t.sourceRecordId),
                _MetaRow('생성일', t.createdAt.length >= 10
                    ? t.createdAt.substring(0, 10)
                    : t.createdAt),
                const SizedBox(height: 20),

                // 액션
                if (_editing) ...[
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            setState(() => _editing = false),
                        child: const Text('취소'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Consumer(builder: (_, ref, __) {
                        return ElevatedButton(
                          onPressed: () async {
                            await ref
                                .read(tripleApiProvider)
                                .updateTriple(
                                  t.id,
                                  predicate: _predCtrl.text.trim(),
                                  object: _objCtrl.text.trim(),
                                  confidence: _confidence,
                                  note: _noteCtrl.text.trim(),
                                );
                            ref.invalidate(tripleListProvider);
                            setState(() => _editing = false);
                          },
                          child: const Text('저장'),
                        );
                      }),
                    ),
                  ]),
                ] else if (isActive) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('수정'),
                      onPressed: () => setState(() => _editing = true),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.archive_outlined,
                          size: 16),
                      label: const Text('아카이브'),
                      onPressed: () =>
                          _confirmArchive(context, t.id),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline,
                          size: 16, color: Colors.red),
                      label: const Text('삭제',
                          style: TextStyle(color: Colors.red)),
                      onPressed: () =>
                          _confirmDelete(context, t.id),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmArchive(
      BuildContext context, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('아카이브'),
        content: const Text('이 트리플을 아카이브하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('아카이브')),
        ],
      ),
    );
    if (ok == true) widget.onArchive(id);
  }

  Future<void> _confirmDelete(
      BuildContext context, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('삭제'),
        content: const Text('이 트리플을 영구 삭제하시겠습니까?\n되돌릴 수 없습니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok == true) widget.onDelete(id);
  }
}

// ── 보조 위젯 ─────────────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge(this.type);

  @override
  Widget build(BuildContext context) {
    final color = _colorForType(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        type.isEmpty ? '??' : type,
        style: TextStyle(
            fontSize: 9,
            color: color,
            fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500)),
      );
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String? value;
  const _MetaRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          SizedBox(
            width: 64,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value ?? '—',
                style: const TextStyle(fontSize: 11),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      );
}
