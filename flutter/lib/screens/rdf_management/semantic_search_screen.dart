import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../services/rdf_api_service.dart';

class SemanticSearchScreen extends ConsumerStatefulWidget {
  const SemanticSearchScreen({super.key});
  @override
  ConsumerState<SemanticSearchScreen> createState() =>
      _SemanticSearchScreenState();
}

class _SemanticSearchScreenState extends ConsumerState<SemanticSearchScreen> {
  final _queryCtrl = TextEditingController();
  final _sparqlCtrl = TextEditingController();
  bool _sparqlMode = false;
  bool _sparqlExpanded = false;
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _searchResult;
  Map<String, dynamic>? _reasonStatus;
  Map<String, dynamic> _templates = {};

  @override
  void initState() {
    super.initState();
    _loadTemplatesAndStatus();
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    _sparqlCtrl.dispose();
    super.dispose();
  }

  RdfApiService get _api => ref.read(rdfApiProvider);

  Future<void> _loadTemplatesAndStatus() async {
    try {
      final r = await Future.wait([
        _api.searchTemplates(),
        _api.searchReasonStatus(),
      ]);
      if (mounted) {
        setState(() {
          _templates = r[0] as Map<String, dynamic>;
          _reasonStatus = r[1] as Map<String, dynamic>;
        });
      }
    } catch (_) {}
  }

  Future<void> _search() async {
    final q = _sparqlMode ? _sparqlCtrl.text.trim() : _queryCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() { _loading = true; _error = null; _searchResult = null; });
    try {
      _searchResult = await _api.searchQuery(
          q, _sparqlMode ? 'sparql' : 'natural', 20);
      if (_searchResult?['sparql'] != null && !_sparqlMode) {
        _sparqlCtrl.text = _searchResult!['sparql'] as String;
        _sparqlExpanded = true;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runReasoner() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await _api.searchReason();
      _reasonStatus = await _api.searchReasonStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('추론 완료: ${r['status']} '
              '(신규 트리플: ${r['new_triples'] ?? '-'})'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyTemplate(String name) {
    final t = _templates[name] as Map? ?? {};
    final sparql = t['sparql'] as String? ?? '';
    setState(() {
      _sparqlCtrl.text = sparql;
      _sparqlMode = true;
      _sparqlExpanded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final results = (_searchResult?['results'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final count = _searchResult?['count'] ?? 0;
    final explanation = _searchResult?['explanation'] as String?;
    final available = _reasonStatus?['reasoner_available'] == true;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 검색 입력 ─────────────────────────────────────────────
              Text('추론 검색', style: AppTypography.heading2),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _sparqlMode ? _sparqlCtrl : _queryCtrl,
                      decoration: InputDecoration(
                        hintText: _sparqlMode
                            ? 'SELECT ?s ?p ?o WHERE { ... }'
                            : '구술자 목록 조회, 제주4.3 관련 기록...',
                        hintStyle: AppTypography.caption,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        isDense: true,
                        prefixIcon: Icon(
                          _sparqlMode ? Icons.code : Icons.search,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                      ),
                      style: _sparqlMode
                          ? AppTypography.mono
                          : AppTypography.body,
                      maxLines: _sparqlMode ? 3 : 1,
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.search, size: 14),
                    label: const Text('검색'),
                    onPressed: _search,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      textStyle: AppTypography.caption,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 모드 토글
              Row(
                children: [
                  FilterChip(
                    label: Text('자연어', style: AppTypography.caption),
                    selected: !_sparqlMode,
                    onSelected: (_) => setState(() => _sparqlMode = false),
                    selectedColor: AppColors.primaryFaint,
                    checkmarkColor: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text('SPARQL 직접', style: AppTypography.caption),
                    selected: _sparqlMode,
                    onSelected: (_) => setState(() => _sparqlMode = true),
                    selectedColor: AppColors.secondaryFaint,
                    checkmarkColor: AppColors.secondary,
                  ),
                ],
              ),

              if (_error != null) ...[
                const SizedBox(height: 8),
                _Banner(_error!, AppColors.error),
              ],

              // ── 생성된 SPARQL ─────────────────────────────────────────
              if (_sparqlCtrl.text.isNotEmpty && !_sparqlMode) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () =>
                      setState(() => _sparqlExpanded = !_sparqlExpanded),
                  child: Row(children: [
                    const Icon(Icons.code, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Text('생성된 SPARQL', style: AppTypography.caption),
                    if (explanation != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(explanation,
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.secondary),
                              overflow: TextOverflow.ellipsis)),
                    ],
                    const Spacer(),
                    Icon(
                      _sparqlExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 16,
                    ),
                  ]),
                ),
                if (_sparqlExpanded) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: SelectableText(
                      _sparqlCtrl.text,
                      style: AppTypography.mono,
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 16),

              // ── 결과 ─────────────────────────────────────────────────
              if (_searchResult != null) ...[
                Row(children: [
                  Text('검색 결과 ($count건)',
                      style: AppTypography.heading2),
                  if (_searchResult?['message'] != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(
                      _searchResult!['message'] as String,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.warning),
                      overflow: TextOverflow.ellipsis,
                    )),
                  ],
                ]),
                const SizedBox(height: 8),
                if (results.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('결과 없음', style: AppTypography.body),
                    ),
                  )
                else
                  ...results.map((row) => _ResultCard(row)),
              ],

              const SizedBox(height: 20),

              // ── 쿼리 템플릿 ───────────────────────────────────────────
              if (_templates.isNotEmpty) ...[
                Text('쿼리 템플릿', style: AppTypography.heading2),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _templates.entries.map((e) {
                    final desc = (e.value as Map?)?['description'] as String? ?? '';
                    return ActionChip(
                      label: Text(e.key, style: AppTypography.caption),
                      tooltip: desc,
                      avatar: const Icon(Icons.bolt, size: 12),
                      onPressed: () => _applyTemplate(e.key),
                      backgroundColor: AppColors.surfaceElevated,
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 20),
              const Divider(color: AppColors.border),

              // ── 추론 엔진 ─────────────────────────────────────────────
              Row(children: [
                Text('추론 엔진', style: AppTypography.heading2),
                const SizedBox(width: 12),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: available ? AppColors.success : AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  available ? '실행 가능 (owlready2)' : '미설치 (owlready2)',
                  style: AppTypography.caption.copyWith(
                    color: available ? AppColors.success : AppColors.textMuted,
                  ),
                ),
                const Spacer(),
                if (_reasonStatus?['last_run'] != null)
                  Text(
                    '마지막: ${(_reasonStatus!['last_run'] as Map?)?['run_at']?.toString().substring(0, 10) ?? '-'}',
                    style: AppTypography.caption,
                  ),
              ]),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow, size: 14),
                    label: const Text('추론 실행 (HermiT)'),
                    onPressed: available ? _runReasoner : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      textStyle: AppTypography.caption,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_reasonStatus?['last_run'] != null)
                    Text(
                      '신규 트리플: ${(_reasonStatus!['last_run'] as Map?)?['new_triples'] ?? 0}개',
                      style: AppTypography.caption,
                    ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
        if (_loading) const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  final Map<String, dynamic> row;
  const _ResultCard(this.row);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        children: row.entries.map((e) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${e.key}: ',
                style: AppTypography.caption
                    .copyWith(color: AppColors.secondary)),
            Text(
              e.value?.toString() ?? '',
              style: AppTypography.mono.copyWith(fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        )).toList(),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String message;
  final Color color;
  const _Banner(this.message, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          Icon(Icons.info_outline, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: AppTypography.body.copyWith(color: color))),
        ]),
      );
}
