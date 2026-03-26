// 파일 목적: 통합 검색 화면 (기록/구술자/면담자 전체 검색)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/record.dart';
import '../../data/models/narrator.dart';
import '../../data/models/interviewer.dart';
import '../../data/models/interview_session.dart';
import '../../data/models/search_filters.dart';
import '../providers/master_data_provider.dart';
import '../providers/record_provider.dart';

const _mainCategories = [
  '정치사건',
  '경제정책',
  '문화콘텐츠',
  '개인사',
  '사회운동',
  '교육',
  '종교',
  '기타',
];

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late TabController _tabController;
  Timer? _debounce;

  // 검색 상태
  String _query = '';
  String _targetChip = '전체'; // 전체/기록/구술자/면담자
  bool _filtersExpanded = false;

  // 고급 필터
  DateTime? _startDate;
  DateTime? _endDate;
  String? _fileFormat; // 전체/음성/영상/문서/텍스트
  String? _filterNarratorId;
  String? _filterInterviewerId;
  String? _filterMainCategory;
  bool _includePrivate = true;

  // 최근/즐겨찾기 검색어
  final List<String> _recentSearches = [];
  final List<String> _savedSearches = [];

  // 검색 결과
  List<Record> _recordResults = [];
  List<Narrator> _narratorResults = [];
  List<Interviewer> _interviewerResults = [];
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    // suffixIcon(clear) 갱신을 위해 항상 setState
    setState(() {});

    _debounce?.cancel();
    if (value.trim().length < 2) {
      if (_hasSearched) {
        setState(() {
          _query = '';
          _hasSearched = false;
          _recordResults = [];
          _narratorResults = [];
          _interviewerResults = [];
        });
      }
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _runSearch(value);
    });
  }

  void _runSearch(String query) {
    if (query.trim().length < 2) {
      setState(() {
        _query = '';
        _hasSearched = false;
        _recordResults = [];
        _narratorResults = [];
        _interviewerResults = [];
      });
      return;
    }

    final trimmed = query.trim();
    setState(() {
      _query = trimmed;
      _recentSearches.remove(trimmed);
      _recentSearches.insert(0, trimmed);
      if (_recentSearches.length > 5) _recentSearches.removeLast();
    });

    _performSearch(trimmed);
  }

  void _performSearch(String query) {
    final q = query.toLowerCase();

    // 지도 데이터 로드
    final narratorMap =
        ref.read(narratorMapProvider).valueOrNull ?? {};
    final interviewerMap =
        ref.read(interviewerMapProvider).valueOrNull ?? {};
    final sessionMap =
        ref.read(sessionMapProvider).valueOrNull ?? {};

    // 기록 검색
    List<Record> records = [];
    if (_targetChip == '전체' || _targetChip == '기록') {
      final allRecords =
          ref.read(recordListProvider(SearchFilters(limit: 999999))).valueOrNull ?? [];
      final matched = allRecords.where((r) {
        if (!_includePrivate && r.visibility == 'private') return false;
        if (_filterNarratorId != null && r.narratorId != _filterNarratorId) {
          return false;
        }
        if (_filterMainCategory != null &&
            r.mainCategory != _filterMainCategory) {
          return false;
        }
        if (_startDate != null && r.createdAt.isBefore(_startDate!)) {
          return false;
        }
        if (_endDate != null && r.createdAt.isAfter(_endDate!)) return false;
        if (_fileFormat != null && _fileFormat != '전체') {
          final fmt = _fileFormat!;
          if (fmt == '음성' &&
              !(r.mimeType?.contains('audio') == true ||
                  r.inputType == 'audio')) { return false; }
          if (fmt == '영상' &&
              !(r.mimeType?.contains('video') == true ||
                  r.inputType == 'video')) { return false; }
          if (fmt == '문서' &&
              !(r.mimeType?.contains('pdf') == true ||
                  r.mimeType?.contains('word') == true ||
                  r.inputType == 'document')) { return false; }
          if (fmt == '텍스트' && r.inputType != 'text') { return false; }
        }

        // 세션 및 면담자 정보
        final session = sessionMap[r.sessionId];
        final narrator = narratorMap[r.narratorId];
        final interviewer = session != null
            ? interviewerMap[session.interviewerId]
            : null;

        // 전체 content 검색
        if (r.title.toLowerCase().contains(q)) return true;
        if (r.displayId?.toLowerCase().contains(q) == true) return true;
        if (r.content.toLowerCase().contains(q)) return true;
        if (r.summary?.toLowerCase().contains(q) == true) return true;
        if (r.mainCategory.toLowerCase().contains(q)) return true;
        if (r.subCategory?.toLowerCase().contains(q) == true) return true;
        if (r.keywordTags.any((t) => t.toLowerCase().contains(q))) return true;
        if (r.tags.any((t) => t.toLowerCase().contains(q))) return true;
        if (r.originalFileName?.toLowerCase().contains(q) == true) return true;
        if (narrator?.name.toLowerCase().contains(q) == true) return true;
        if (interviewer?.name.toLowerCase().contains(q) == true) return true;
        if (interviewer?.affiliation?.toLowerCase().contains(q) == true) return true;
        if (session?.location?.toLowerCase().contains(q) == true) return true;
        if (session?.notes?.toLowerCase().contains(q) == true) return true;
        final dateStr =
            '${session?.interviewDate.year ?? ''}-${(session?.interviewDate.month ?? 0).toString().padLeft(2, '0')}-${(session?.interviewDate.day ?? 0).toString().padLeft(2, '0')}';
        if (dateStr.contains(q)) return true;
        return false;
      }).toList();

      // 정렬: 제목 매칭 우선, 그 다음 최신순
      matched.sort((a, b) {
        final aTitle = a.title.toLowerCase().contains(q);
        final bTitle = b.title.toLowerCase().contains(q);
        if (aTitle && !bTitle) return -1;
        if (!aTitle && bTitle) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });
      records = matched;
    }

    // 구술자 검색
    List<Narrator> narrators = [];
    if (_targetChip == '전체' || _targetChip == '구술자') {
      final allNarrators =
          ref.read(narratorListProvider).valueOrNull ?? [];
      narrators = allNarrators.where((n) {
        return n.name.toLowerCase().contains(q) ||
            (n.jobTitle?.toLowerCase().contains(q) == true) ||
            (n.currentJobTitle?.toLowerCase().contains(q) == true) ||
            (n.affiliation?.toLowerCase().contains(q) == true);
      }).toList();
    }

    // 면담자 검색
    List<Interviewer> interviewers = [];
    if (_targetChip == '전체' || _targetChip == '면담자') {
      final allInterviewers =
          ref.read(interviewerListProvider).valueOrNull ?? [];
      interviewers = allInterviewers.where((iv) {
        return iv.name.toLowerCase().contains(q) ||
            (iv.jobTitle?.toLowerCase().contains(q) == true) ||
            (iv.affiliation?.toLowerCase().contains(q) == true) ||
            (iv.specialization?.toLowerCase().contains(q) == true);
      }).toList();
    }

    setState(() {
      _recordResults = records;
      _narratorResults = narrators;
      _interviewerResults = interviewers;
      _hasSearched = true;
    });
  }

  /// 기록에서 매칭 출처 레이블 반환
  String _findMatchSource(Record r, String q,
      {Narrator? narrator,
      Interviewer? interviewer,
      InterviewSession? session}) {
    if (r.title.toLowerCase().contains(q)) return '제목';
    if (r.displayId?.toLowerCase().contains(q) == true) return '기록 ID';
    if (r.content.toLowerCase().contains(q)) return '전사 내용';
    if (r.summary?.toLowerCase().contains(q) == true) return '요약';
    if (r.mainCategory.toLowerCase().contains(q)) return '주제 분류';
    if (r.subCategory?.toLowerCase().contains(q) == true) return '소분류';
    if (r.keywordTags.any((t) => t.toLowerCase().contains(q))) return '키워드 태그';
    if (r.tags.any((t) => t.toLowerCase().contains(q))) return '태그';
    if (r.originalFileName?.toLowerCase().contains(q) == true) return '파일명';
    if (narrator?.name.toLowerCase().contains(q) == true) return '구술자';
    if (interviewer?.name.toLowerCase().contains(q) == true) return '면담자';
    if (interviewer?.affiliation?.toLowerCase().contains(q) == true) return '면담자 소속';
    if (session?.location?.toLowerCase().contains(q) == true) return '면담 장소';
    if (session?.notes?.toLowerCase().contains(q) == true) return '면담 노트';
    return '';
  }

  /// 텍스트에서 쿼리 주변 최대 60자 스니펫 반환
  String _getSnippet(String text, String query) {
    final lower = text.toLowerCase();
    final idx = lower.indexOf(query.toLowerCase());
    if (idx == -1) return '';
    final start = (idx - 20).clamp(0, text.length);
    final end = (idx + query.length + 40).clamp(0, text.length);
    final prefix = start > 0 ? '...' : '';
    final suffix = end < text.length ? '...' : '';
    return '$prefix${text.substring(start, end)}$suffix';
  }

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startDate ?? now)
          : (_endDate ?? now),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Widget _buildHighlightedText(String text, String query,
      {TextStyle? style, int maxLines = 1}) {
    if (query.isEmpty) {
      return Text(text,
          style: style,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis);
    }
    final lower = text.toLowerCase();
    final q = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;
    int idx;
    while ((idx = lower.indexOf(q, start)) != -1) {
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx), style: style));
      }
      spans.add(TextSpan(
        text: text.substring(idx, idx + q.length),
        style: (style ?? const TextStyle()).copyWith(
          backgroundColor: Colors.yellow[300],
          fontWeight: FontWeight.bold,
        ),
      ));
      start = idx + q.length;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: style));
    }
    return RichText(
      text: TextSpan(
        style: style ?? DefaultTextStyle.of(context).style,
        children: spans,
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    final narrators = ref.watch(narratorListProvider).valueOrNull ?? [];
    final interviewers = ref.watch(interviewerListProvider).valueOrNull ?? [];
    // 검색에 필요한 프로바이더 사전 로드 (ref.read로 읽을 때 데이터 보장)
    ref.watch(recordListProvider(SearchFilters(limit: 999999)));
    ref.watch(narratorMapProvider);
    ref.watch(interviewerMapProvider);
    ref.watch(sessionMapProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('검색'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_outline),
            tooltip: '즐겨찾기에 저장',
            onPressed: _query.isEmpty
                ? null
                : () {
                    setState(() {
                      if (!_savedSearches.contains(_query)) {
                        _savedSearches.insert(0, _query);
                      }
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('"$_query" 즐겨찾기에 추가됨')),
                    );
                  },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── 검색 바 ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '검색어를 입력하세요 (2자 이상)',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 8),
                      isDense: true,
                    ),
                    onChanged: _onSearchChanged,
                    onSubmitted: _runSearch,
                    textInputAction: TextInputAction.search,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _runSearch(_searchController.text),
                  child: const Text('검색'),
                ),
              ],
            ),
          ),

          // ── 대상 칩 ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['전체', '기록', '구술자', '면담자'].map((label) {
                  final selected = _targetChip == label;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(label),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _targetChip = label);
                        if (_hasSearched && _query.isNotEmpty) {
                          _performSearch(_query);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // ── 고급 필터 (접을 수 있음) ──────────────────────
          InkWell(
            onTap: () =>
                setState(() => _filtersExpanded = !_filtersExpanded),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    '상세 필터',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  Icon(
                    _filtersExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: Theme.of(context).primaryColor,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (_filtersExpanded)
            Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 기간
                  Row(
                    children: [
                      const Text('기간: ', style: TextStyle(fontSize: 13)),
                      TextButton(
                        onPressed: () => _pickDate(true),
                        child: Text(
                          _startDate == null
                              ? '시작일'
                              : '${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const Text('~'),
                      TextButton(
                        onPressed: () => _pickDate(false),
                        child: Text(
                          _endDate == null
                              ? '종료일'
                              : '${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      if (_startDate != null || _endDate != null)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () => setState(() {
                            _startDate = null;
                            _endDate = null;
                          }),
                        ),
                    ],
                  ),
                  // 파일 형식
                  Row(
                    children: [
                      const Text('파일 형식: ', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 8),
                      DropdownButton<String?>(
                        value: _fileFormat,
                        isDense: true,
                        hint: const Text('전체', style: TextStyle(fontSize: 13)),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('전체')),
                          ...['음성', '영상', '문서', '텍스트']
                              .map((f) => DropdownMenuItem(value: f, child: Text(f))),
                        ],
                        onChanged: (v) => setState(() => _fileFormat = v),
                      ),
                    ],
                  ),
                  // 구술자
                  Row(
                    children: [
                      const Text('구술자: ', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 8),
                      DropdownButton<String?>(
                        value: _filterNarratorId,
                        isDense: true,
                        hint: const Text('전체', style: TextStyle(fontSize: 13)),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('전체')),
                          ...narrators.map((n) => DropdownMenuItem(
                              value: n.id, child: Text(n.name))),
                        ],
                        onChanged: (v) =>
                            setState(() => _filterNarratorId = v),
                      ),
                    ],
                  ),
                  // 면담자
                  Row(
                    children: [
                      const Text('면담자: ', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 8),
                      DropdownButton<String?>(
                        value: _filterInterviewerId,
                        isDense: true,
                        hint: const Text('전체', style: TextStyle(fontSize: 13)),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('전체')),
                          ...interviewers.map((iv) => DropdownMenuItem(
                              value: iv.id, child: Text(iv.name))),
                        ],
                        onChanged: (v) =>
                            setState(() => _filterInterviewerId = v),
                      ),
                    ],
                  ),
                  // 주제
                  Row(
                    children: [
                      const Text('주제: ', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 8),
                      DropdownButton<String?>(
                        value: _filterMainCategory,
                        isDense: true,
                        hint: const Text('전체', style: TextStyle(fontSize: 13)),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('전체')),
                          ..._mainCategories.map((c) =>
                              DropdownMenuItem(value: c, child: Text(c))),
                        ],
                        onChanged: (v) =>
                            setState(() => _filterMainCategory = v),
                      ),
                    ],
                  ),
                  // 비공개 포함
                  Row(
                    children: [
                      const Text('비공개 포함: ',
                          style: TextStyle(fontSize: 13)),
                      Switch(
                        value: _includePrivate,
                        onChanged: (v) =>
                            setState(() => _includePrivate = v),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          const Divider(height: 1),

          // ── 검색 결과 or 최근/즐겨찾기 ───────────────────
          Expanded(
            child: _hasSearched
                ? _buildResultsView()
                : _buildEmptyStateView(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateView() {
    if (_savedSearches.isEmpty && _recentSearches.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text('검색어를 입력하세요 (2자 이상)',
                style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_savedSearches.isNotEmpty) ...[
          const Text('즐겨찾기 검색',
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: _savedSearches.map((s) {
              return InputChip(
                avatar: const Icon(Icons.bookmark, size: 14),
                label: Text(s),
                onPressed: () {
                  _searchController.text = s;
                  _runSearch(s);
                },
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () =>
                    setState(() => _savedSearches.remove(s)),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
        if (_recentSearches.isNotEmpty) ...[
          const Text('최근 검색',
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: _recentSearches.map((s) {
              return InputChip(
                avatar: const Icon(Icons.history, size: 14),
                label: Text(s),
                onPressed: () {
                  _searchController.text = s;
                  _runSearch(s);
                },
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () =>
                    setState(() => _recentSearches.remove(s)),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildResultsView() {
    final total = _recordResults.length +
        _narratorResults.length +
        _interviewerResults.length;

    if (total == 0) {
      return const Center(
        child: Text('검색 결과가 없습니다',
            style: TextStyle(color: Colors.grey, fontSize: 16)),
      );
    }

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: '기록(${_recordResults.length})'),
            Tab(text: '구술자(${_narratorResults.length})'),
            Tab(text: '면담자(${_interviewerResults.length})'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildRecordsList(),
              _buildNarratorsList(),
              _buildInterviewersList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecordsList() {
    if (_recordResults.isEmpty) {
      return const Center(child: Text('검색 결과가 없습니다'));
    }

    final narratorMap =
        ref.read(narratorMapProvider).valueOrNull ?? {};
    final interviewerMap =
        ref.read(interviewerMapProvider).valueOrNull ?? {};
    final sessionMap =
        ref.read(sessionMapProvider).valueOrNull ?? {};

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _recordResults.length,
      itemBuilder: (context, i) {
        final r = _recordResults[i];
        final session = sessionMap[r.sessionId];
        final narrator = narratorMap[r.narratorId];
        final interviewer = session != null
            ? interviewerMap[session.interviewerId]
            : null;

        final matchSource = _findMatchSource(r, _query.toLowerCase(),
            narrator: narrator,
            interviewer: interviewer,
            session: session);

        // 전사 내용 스니펫
        String? snippet;
        if (matchSource == '전사 내용') {
          snippet = _getSnippet(r.content, _query);
        } else if (matchSource == '요약' && r.summary != null) {
          snippet = _getSnippet(r.summary!, _query);
        } else if (matchSource == '면담 노트' && session?.notes != null) {
          snippet = _getSnippet(session!.notes!, _query);
        }

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 3),
          child: ListTile(
            title: _buildHighlightedText(r.title, _query),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (r.displayId != null)
                  Text(r.displayId!,
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.blueGrey,
                          fontFamily: 'monospace')),
                Text(
                  '${r.mainCategory} · ${r.createdAt.year}-${r.createdAt.month.toString().padLeft(2, '0')}-${r.createdAt.day.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 12),
                ),
                if (matchSource.isNotEmpty && matchSource != '제목' && matchSource != '기록 ID')
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$matchSource에서 발견됨',
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                          ),
                        ),
                        if (snippet != null && snippet.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildHighlightedText(
                              snippet,
                              _query,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.black54),
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
            trailing: Icon(
              r.visibility == 'private' ? Icons.lock : Icons.lock_open,
              size: 16,
              color: Colors.grey,
            ),
            onTap: () => context.push('/records/detail/${r.id}'),
          ),
        );
      },
    );
  }

  Widget _buildNarratorsList() {
    if (_narratorResults.isEmpty) {
      return const Center(child: Text('검색 결과가 없습니다'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _narratorResults.length,
      itemBuilder: (context, i) {
        final n = _narratorResults[i];
        final subtitle = [
          if (n.jobTitle != null) n.jobTitle!,
          if (n.affiliation != null) n.affiliation!,
        ].join(' · ');
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 3),
          child: ListTile(
            leading: CircleAvatar(
              child: Text(n.name.isNotEmpty ? n.name[0] : '?'),
            ),
            title: _buildHighlightedText(n.name, _query),
            subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/people/narrator/${n.id}'),
          ),
        );
      },
    );
  }

  Widget _buildInterviewersList() {
    if (_interviewerResults.isEmpty) {
      return const Center(child: Text('검색 결과가 없습니다'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _interviewerResults.length,
      itemBuilder: (context, i) {
        final iv = _interviewerResults[i];
        final subtitle = [
          if (iv.jobTitle != null) iv.jobTitle!,
          if (iv.affiliation != null) iv.affiliation!,
        ].join(' · ');
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 3),
          child: ListTile(
            leading: CircleAvatar(
              child: Text(iv.name.isNotEmpty ? iv.name[0] : '?'),
            ),
            title: _buildHighlightedText(iv.name, _query),
            subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/people/interviewer/${iv.id}'),
          ),
        );
      },
    );
  }
}
