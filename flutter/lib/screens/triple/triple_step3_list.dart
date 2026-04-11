import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/ontology.dart';
import '../../models/triple.dart';
import '../../providers/ontology_provider.dart';
import '../../providers/triple_provider.dart';
import '../../api/api_client.dart';
import '../../services/export_service.dart';

// ── 추출 방법 레이블 ────────────────────────────────────────────────────────────
String _methodLabel(String m) => switch (m) {
  'auto_extract' => '자동추출',
  'manual'       => '수동입력',
  'edited'       => '편집됨',
  _              => m,
};

// ── 검색어 하이라이트 ──────────────────────────────────────────────────────────
TextSpan _highlightText(
  String text,
  String query, {
  TextStyle? baseStyle,
  TextStyle? matchStyle,
}) {
  if (query.isEmpty) return TextSpan(text: text, style: baseStyle);
  final lower = text.toLowerCase();
  final lowerQ = query.toLowerCase();
  final spans = <TextSpan>[];
  int start = 0;
  int idx;
  while ((idx = lower.indexOf(lowerQ, start)) != -1) {
    if (idx > start) {
      spans.add(TextSpan(text: text.substring(start, idx), style: baseStyle));
    }
    spans.add(TextSpan(
      text: text.substring(idx, idx + lowerQ.length),
      style: matchStyle ??
          baseStyle?.copyWith(
            backgroundColor: const Color(0xFFFFE082),
            fontWeight: FontWeight.bold,
          ) ??
          const TextStyle(
              backgroundColor: Color(0xFFFFE082),
              fontWeight: FontWeight.bold),
    ));
    start = idx + lowerQ.length;
  }
  if (start < text.length) {
    spans.add(TextSpan(text: text.substring(start), style: baseStyle));
  }
  return TextSpan(children: spans);
}

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

  // ── 로컬 로드 상태 ──────────────────────────────────────────────────────────
  List<Triple> _allTriples = [];      // API 전체 데이터
  List<Triple> _filteredTriples = []; // 클래스 + 검색 클라이언트 필터 결과
  bool _isLoading = false;
  String _error = '';
  String _classFilter = '';    // 빠른 선택 바 클래스 필터
  String _appliedSearch = '';  // [검색] 버튼으로 확정된 검색어

  // 클라이언트 필터
  final Set<String> _selectedTypes = {};
  String _sourceFilter = '';
  bool _showFilters = false;
  final _sourceFilterCtrl = TextEditingController();

  // 다중 선택
  final Set<String> _checkedIds = {};
  bool _isSelecting = false;

  // ── 클라이언트 필터 (클래스 + 검색어 AND) ────────────────────────────────
  List<Triple> _computeFilter([List<Triple>? source]) {
    final data = source ?? _allTriples;
    if (_classFilter.isEmpty && _appliedSearch.isEmpty) return List.of(data);

    // 검색어를 공백으로 분리 → 모든 키워드가 AND 매칭
    final keywords = _appliedSearch.trim().toLowerCase()
        .split(' ')
        .where((k) => k.isNotEmpty)
        .toList();

    return data.where((t) {
      // 클래스 필터: 주어 타입 OR 목적어 타입
      if (_classFilter.isNotEmpty &&
          t.subjectType != _classFilter &&
          t.objectType  != _classFilter) return false;

      // 검색어 필터: 모든 키워드가 어느 필드에든 포함되어야 함
      if (keywords.isNotEmpty) {
        // 특수문자 포함 검색을 위해 RegExp 사용 안 함 — String.contains() 사용
        final fields = [
          t.subject.toLowerCase(),
          t.predicate.toLowerCase(),
          t.object.toLowerCase(),
          t.subjectType.toLowerCase(),
          t.objectType.toLowerCase(),
          t.sourceRecordId.toLowerCase(),
          t.ontologyVersion.toLowerCase(),
          t.note.toLowerCase(),
        ];
        final allMatched = keywords.every(
          (kw) => fields.any((f) => f.contains(kw)),
        );
        if (!allMatched) return false;
      }

      return true;
    }).toList();
  }

  void _applyFilter() {
    setState(() => _filteredTriples = _computeFilter());
  }

  // ── 탭별 필터 ───────────────────────────────────────────────────────────────
  List<Triple> get _activeTriples =>
      _filteredTriples.where((t) => t.status == TripleStatus.active).toList();
  List<Triple> get _archivedTriples =>
      _filteredTriples.where((t) => t.status == TripleStatus.archived).toList();

  // ── 데이터 로드 (API) ───────────────────────────────────────────────────────
  Future<void> _loadTriples() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _error = ''; });

    try {
      final version = ref.read(tripleVersionFilterProvider);
      final params = <String, dynamic>{};
      if (version != null) params['version'] = version;
      // 클래스·검색 필터는 클라이언트에서 처리 — API 에는 보내지 않음

      final response = await ref
          .read(apiClientProvider)
          .get('/api/triples/', params: params);
      if (!mounted) return;

      final data = response.data as Map<String, dynamic>;
      // 서버 형식 양쪽 지원: {total, items} 또는 구형 {nodes, triples}
      final rawItems = (data['items'] as List?)
          ?? (data['triples'] as List?)
          ?? <dynamic>[];

      final triples = rawItems
          .map((t) => Triple.fromJson(t as Map<String, dynamic>))
          .toList();

      setState(() {
        _allTriples      = triples;
        _filteredTriples = _computeFilter(triples); // 현재 필터 즉시 적용
        _isLoading       = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _allTriples      = [];
        _filteredTriples = [];
        _isLoading       = false;
        _error           = e.toString();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() {
      if (_tabCtrl.indexIsChanging) return;
      setState(() => _selected = null);
    });
    // Step3 진입 시 전체 트리플 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadTriples();
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
    final q = _searchCtrl.text.trim();
    ref.read(tripleQueryProvider.notifier).state = q; // 텍스트 하이라이트용
    setState(() => _appliedSearch = q);
    _applyFilter();
  }

  void _clearAllFilters() {
    _searchCtrl.clear();
    _sourceFilterCtrl.clear();
    setState(() {
      _selectedTypes.clear();
      _sourceFilter  = '';
      _classFilter   = '';
      _appliedSearch = '';
    });
    ref.read(tripleQueryProvider.notifier).state = '';
    ref.read(tripleVersionFilterProvider.notifier).state = null;
    _loadTriples(); // 버전 필터 리셋 시 API 재로드
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
    return _selectedTypes.isNotEmpty || _sourceFilter.isNotEmpty
        || version != null || _classFilter.isNotEmpty
        || _appliedSearch.isNotEmpty;
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
    await _loadTriples();
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
    await _loadTriples();
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

  // ── 타입 칩 (카운트 배지 포함) ────────────────────────────────────────────────
  Widget _buildTypeChips({required Map<String, int> counts}) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: _classColors.keys.map((type) {
        final sel   = _selectedTypes.contains(type);
        final count = counts[type];
        return FilterChip(
          label: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(type,
                style: TextStyle(
                    fontSize: 10,
                    color: sel ? Colors.white : null)),
            if (count != null && count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: sel
                      ? Colors.white.withValues(alpha: 0.3)
                      : _colorForType(type).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$count',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: sel
                            ? Colors.white
                            : _colorForType(type))),
              ),
            ],
          ]),
          selected: sel,
          backgroundColor: Colors.white,
          selectedColor: _colorForType(type),
          checkmarkColor: Colors.white,
          side: BorderSide(
              color: _colorForType(type).withValues(alpha: 0.5)),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          labelPadding: const EdgeInsets.symmetric(horizontal: 6),
          onSelected: (v) => setState(() {
            v ? _selectedTypes.add(type) : _selectedTypes.remove(type);
          }),
        );
      }).toList(),
    );
  }

  // ── 수동 추가 다이얼로그 ───────────────────────────────────────────────────────
  Future<void> _showAddTripleDialog(
      BuildContext ctx, List<OntologyVersion> versions) async {
    final created = await showDialog<bool>(
      context: ctx,
      builder: (_) => _AddTripleDialog(versions: versions),
    );
    if (created == true) {
      _loadTriples();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('트리플이 추가되었습니다.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery  = ref.watch(tripleQueryProvider);
    final selVersion   = ref.watch(tripleVersionFilterProvider);
    final allVersions  = ref.watch(ontologyProvider).versions
        .where((v) => v.status == OntologyStatus.confirmed)
        .toList();
    final hasFilter = _hasActiveFilters;
    final role    = ref.watch(roleProvider);
    final isAdmin = role == 'admin';

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
                          setState(() => _appliedSearch = '');
                          _applyFilter();
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
          // 검색 버튼
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: _search,
            child: const Text('검색', style: TextStyle(fontSize: 13)),
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
          // 관리자 모드 토글
          Tooltip(
            message: isAdmin ? '관리자 모드 해제' : '관리자 모드',
            child: IconButton(
              icon: Icon(
                isAdmin
                    ? Icons.admin_panel_settings
                    : Icons.admin_panel_settings_outlined,
                color: isAdmin ? Colors.deepOrange : Colors.grey,
                size: 20,
              ),
              onPressed: () =>
                  ref.read(roleProvider.notifier).state =
                      isAdmin ? 'viewer' : 'admin',
            ),
          ),
          // 트리플 수동 추가 (관리자 전용)
          if (isAdmin)
            Tooltip(
              message: '트리플 수동 추가',
              child: IconButton(
                icon: const Icon(Icons.add_circle_outline,
                    size: 20, color: Colors.green),
                onPressed: () =>
                    _showAddTripleDialog(context, allVersions),
              ),
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
                  onChanged: (v) {
                    ref.read(tripleVersionFilterProvider.notifier).state = v;
                    _loadTriples(); // 버전은 서버 필터 — API 재로드
                  },
                ),
              ),
              const SizedBox(height: 10),

              // 클래스 타입 칩 (카운트 배지 포함)
              Text('클래스 타입',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600)),
              const SizedBox(height: 6),
              ref.watch(categoryCountProvider).when(
                loading: () => const SizedBox(
                    height: 28,
                    child: Center(
                        child: LinearProgressIndicator())),
                error: (_, __) => _buildTypeChips(counts: {}),
                data: (counts) => _buildTypeChips(counts: counts),
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

      // ── 범주 빠른 선택 바 (서버 필터) ───────────────────────────
      ref.watch(categoryCountProvider).maybeWhen(
        data: (counts) {
          if (counts.isEmpty) return const SizedBox.shrink();
          final sorted = counts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          return Container(
            height: 36,
            color: Colors.grey.shade50,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              itemCount: sorted.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final type  = sorted[i].key;
                final count = sorted[i].value;
                final sel   = _classFilter == type;
                final color = _colorForType(type);
                return GestureDetector(
                  onTap: () {
                    final newFilter = sel ? '' : type;
                    setState(() => _classFilter = newFilter);
                    _applyFilter(); // API 호출 없이 클라이언트 필터
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: sel
                          ? color.withValues(alpha: 0.15)
                          : Colors.white,
                      border: Border.all(
                          color: sel
                              ? color
                              : color.withValues(alpha: 0.35),
                          width: sel ? 1.5 : 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(
                              color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 4),
                        Text(type,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: sel
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: sel ? color : Colors.grey.shade700)),
                        const SizedBox(width: 3),
                        Text('$count',
                            style: TextStyle(
                                fontSize: 9,
                                color: sel ? color : Colors.grey)),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
        orElse: () => const SizedBox.shrink(),
      ),

      // ── 내보내기 버튼 바 ──────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
        child: Row(
          children: [
            // 전체 내보내기 (현재 탭 status + 버전 필터 기준)
            OutlinedButton.icon(
              icon: const Icon(Icons.download_outlined, size: 14),
              label: const Text('전체 내보내기',
                  style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => ExportService.exportTriples(
                apiClient: ref.read(apiClientProvider),
                context: context,
                statusFilter: _tabCtrl.index == 0 ? 'active' : 'archived',
                ontologyVersion: ref.read(tripleVersionFilterProvider),
              ),
            ),
            // 선택 내보내기 (다중 선택 모드 + 선택 항목 있을 때)
            if (_isSelecting && _checkedIds.isNotEmpty) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.download_outlined, size: 14),
                label: Text('선택 내보내기 (${_checkedIds.length}개)',
                    style: const TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  visualDensity: VisualDensity.compact,
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  side: BorderSide(
                      color: Theme.of(context).colorScheme.primary),
                ),
                onPressed: () async {
                  final selectedItems = _allTriples
                      .where((t) => _checkedIds.contains(t.id))
                      .toList();
                  final messenger = ScaffoldMessenger.of(context);

                  final savePath = await FilePicker.platform.saveFile(
                    dialogTitle: '선택 트리플 내보내기 (${selectedItems.length}개)',
                    fileName:
                        'triples_selected_${selectedItems.length}_'
                        '${DateTime.now().millisecondsSinceEpoch}.json',
                    allowedExtensions: ['json'],
                    type: FileType.custom,
                  );
                  if (savePath == null || !mounted) return;

                  final exportData = jsonEncode({
                    'export_type': 'triples',
                    'exported_at': DateTime.now().toIso8601String(),
                    'total': selectedItems.length,
                    'items': selectedItems.map((t) => {
                      'id': t.id,
                      'subject': t.subject,
                      'subject_type': t.subjectType,
                      'predicate': t.predicate,
                      'object': t.object,
                      'object_type': t.objectType,
                      'ontology_version': t.ontologyVersion,
                      'source_record_id': t.sourceRecordId,
                      'confidence': t.confidence,
                      'status': t.status.name,
                      'created_at': t.createdAt,
                      'created_by': t.createdBy,
                      'note': t.note,
                    }).toList(),
                  });

                  await File(savePath).writeAsString(exportData,
                      encoding: utf8);

                  if (!mounted) return;
                  messenger.showSnackBar(SnackBar(
                    content: Text(
                        '저장 완료: ${selectedItems.length}개 트리플'),
                  ));
                },
              ),
            ],
          ],
        ),
      ),

      TabBar(
        controller: _tabCtrl,
        tabs: const [Tab(text: '활성'), Tab(text: '아카이브')],
      ),

      // ── 목록 + 상세 패널 ─────────────────────────────────────────
      Expanded(
        child: Builder(builder: (context) {
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_error.isNotEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('오류: $_error',
                    style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _loadTriples,
                  child: const Text('다시 시도'),
                ),
              ]),
            );
          }

          // 현재 탭에 맞는 트리플 (Flutter 에서 status 분리)
          final tabTriples =
              _tabCtrl.index == 0 ? _activeTriples : _archivedTriples;
          final filtered = _applyFilters(tabTriples);

          if (tabTriples.isEmpty) {
            return Center(
              child: Text(
                _tabCtrl.index == 0
                    ? '활성 트리플이 없습니다.'
                    : '아카이브된 트리플이 없습니다.',
                style: const TextStyle(color: Colors.grey),
              ),
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
                      ? '총 ${tabTriples.length}개  →  ${filtered.length}개 표시'
                      : '총 ${tabTriples.length}개',
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
                              isAdmin: isAdmin,
                              searchQuery: searchQuery,
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
                              onArchive: () async {
                                await ref
                                    .read(tripleApiProvider)
                                    .archiveTriple(t.id);
                                await _loadTriples();
                                if (mounted) setState(() => _selected = null);
                              },
                              onDelete: () async {
                                await ref
                                    .read(tripleApiProvider)
                                    .deleteTriple(t.id);
                                await _loadTriples();
                                if (mounted) setState(() => _selected = null);
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
                            isAdmin: isAdmin,
                            onClose: () =>
                                setState(() => _selected = null),
                            onRefresh: () => _loadTriples(),
                            onArchive: (id) async {
                              await ref
                                  .read(tripleApiProvider)
                                  .archiveTriple(id);
                              await _loadTriples();
                              if (mounted) setState(() => _selected = null);
                            },
                            onDelete: (id) async {
                              await ref
                                  .read(tripleApiProvider)
                                  .deleteTriple(id);
                              await _loadTriples();
                              if (mounted) setState(() => _selected = null);
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
        }),
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
  final bool isAdmin;
  final String searchQuery;
  final VoidCallback onTap;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;

  const _TripleRow({
    required this.triple,
    required this.selected,
    required this.onTap,
    this.checkMode = false,
    this.checked = false,
    this.isAdmin = false,
    this.searchQuery = '',
    this.onArchive,
    this.onDelete,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
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
                      RichText(
                        overflow: TextOverflow.ellipsis,
                        text: _highlightText(
                          t.subject,
                          searchQuery,
                          baseStyle: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 술어
                Expanded(
                  flex: 2,
                  child: Center(
                    child: RichText(
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      text: _highlightText(
                        t.predicate,
                        searchQuery,
                        baseStyle: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
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
                      RichText(
                        overflow: TextOverflow.ellipsis,
                        text: _highlightText(
                          t.object,
                          searchQuery,
                          baseStyle: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 신뢰도
                SizedBox(
                  width: 36,
                  child: Text(
                    t.confidence.toStringAsFixed(1),
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.right,
                  ),
                ),
                // 관리자 팝업 메뉴
                if (isAdmin && !checkMode)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 16,
                        color: Colors.grey),
                    padding: EdgeInsets.zero,
                    itemBuilder: (_) => [
                      if (t.status == TripleStatus.active)
                        const PopupMenuItem(
                            value: 'archive',
                            child: Text('아카이브', style: TextStyle(fontSize: 13))),
                      const PopupMenuItem(
                          value: 'delete',
                          child: Text('삭제',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.red))),
                    ],
                    onSelected: (v) {
                      if (v == 'archive') onArchive?.call();
                      if (v == 'delete') onDelete?.call();
                    },
                  ),
              ]),
              // 메타데이터 행
              const SizedBox(height: 4),
              Row(children: [
                Text(
                  t.createdAt.length >= 10
                      ? t.createdAt.substring(0, 10)
                      : t.createdAt,
                  style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(width: 6),
                Text('· ${t.createdBy}',
                    style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(width: 6),
                Text('· ${_methodLabel(t.extractionMethod)}',
                    style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
                if (t.sourceRecordId.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '· ${t.sourceRecordId}',
                      style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ]),
            ],
          ),
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
  final bool isAdmin;
  final VoidCallback? onRefresh;
  const _DetailPanel({
    required this.triple,
    required this.onClose,
    required this.onArchive,
    required this.onDelete,
    this.isAdmin = false,
    this.onRefresh,
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
                _MetaRow('생성자', t.createdBy),
                _MetaRow('추출방법', _methodLabel(t.extractionMethod)),
                if (t.updatedAt != null) ...[
                  _MetaRow('수정일', t.updatedAt!.length >= 10
                      ? t.updatedAt!.substring(0, 10)
                      : t.updatedAt),
                  _MetaRow('수정자', t.updatedBy ?? '—'),
                ],
                const SizedBox(height: 20),

                // 액션 (관리자 전용)
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
                                  updatedBy: 'admin',
                                );
                            widget.onRefresh?.call();
                            setState(() => _editing = false);
                          },
                          child: const Text('저장'),
                        );
                      }),
                    ),
                  ]),
                ] else if (widget.isAdmin && isActive) ...[
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
                ] else if (widget.isAdmin && !isActive) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline,
                          size: 16, color: Colors.red),
                      label: const Text('영구 삭제',
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

// ── 트리플 수동 추가 다이얼로그 ───────────────────────────────────────────────────

class _AddTripleDialog extends ConsumerStatefulWidget {
  final List<OntologyVersion> versions;
  const _AddTripleDialog({required this.versions});

  @override
  ConsumerState<_AddTripleDialog> createState() => _AddTripleDialogState();
}

class _AddTripleDialogState extends ConsumerState<_AddTripleDialog> {
  final _subjectCtrl     = TextEditingController();
  final _predicateCtrl   = TextEditingController();
  final _objectCtrl      = TextEditingController();
  String? _subjectType;
  String? _objectType;
  String? _selectedVersion;
  double _confidence = 1.0;
  bool _saving = false;
  String? _error;

  static const _classOptions = [
    'Person', 'Place', 'Event', 'Time', 'Organization',
    'Object', 'Topic', 'NarrativeSession', 'Community',
    'Policy', 'Emotion', 'Collection',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.versions.isNotEmpty) {
      _selectedVersion = widget.versions.first.versionId;
    }
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _predicateCtrl.dispose();
    _objectCtrl.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _subjectCtrl.text.trim().isNotEmpty &&
      _predicateCtrl.text.trim().isNotEmpty &&
      _objectCtrl.text.trim().isNotEmpty &&
      _subjectType != null &&
      _objectType != null &&
      _selectedVersion != null;

  Future<void> _save() async {
    if (!_isValid) return;
    setState(() { _saving = true; _error = null; });
    try {
      await ref.read(tripleApiProvider).createTriple(
        subject: _subjectCtrl.text.trim(),
        subjectType: _subjectType!,
        predicate: _predicateCtrl.text.trim(),
        object: _objectCtrl.text.trim(),
        objectType: _objectType!,
        ontologyVersion: _selectedVersion!,
        confidence: _confidence,
        createdBy: 'admin',
        extractionMethod: 'manual',
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() { _saving = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('트리플 수동 추가'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 온톨로지 버전
              const Text('온톨로지 버전',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: _selectedVersion,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(), isDense: true),
                items: widget.versions
                    .map((v) => DropdownMenuItem(
                          value: v.versionId,
                          child: Text(v.versionId,
                              style: const TextStyle(fontSize: 12)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedVersion = v),
              ),
              const SizedBox(height: 12),

              // 주어
              const Text('주어',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _subjectType,
                    decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        hintText: '타입'),
                    items: _classOptions
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c,
                                  style: const TextStyle(fontSize: 12)),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _subjectType = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _subjectCtrl,
                    decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        hintText: '주어 값'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ]),
              const SizedBox(height: 12),

              // 술어
              const Text('술어',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextField(
                controller: _predicateCtrl,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    hintText: '관계 술어'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),

              // 목적어
              const Text('목적어',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _objectType,
                    decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        hintText: '타입'),
                    items: _classOptions
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c,
                                  style: const TextStyle(fontSize: 12)),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _objectType = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _objectCtrl,
                    decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        hintText: '목적어 값'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ]),
              const SizedBox(height: 12),

              // 신뢰도
              Row(children: [
                const Text('신뢰도',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Text(_confidence.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 12)),
              ]),
              Slider(
                value: _confidence,
                min: 0, max: 1, divisions: 10,
                onChanged: (v) => setState(() => _confidence = v),
              ),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!,
                      style: const TextStyle(color: Colors.red, fontSize: 12)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: (_saving || !_isValid) ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('추가'),
        ),
      ],
    );
  }
}
