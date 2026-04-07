import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/ontology.dart';
import '../../models/triple.dart';
import '../../providers/ontology_provider.dart';
import '../../providers/triple_provider.dart';

class TripleExtractScreen extends ConsumerStatefulWidget {
  const TripleExtractScreen({super.key});

  @override
  ConsumerState<TripleExtractScreen> createState() =>
      _TripleExtractScreenState();
}

class _TripleExtractScreenState extends ConsumerState<TripleExtractScreen> {
  final _contentCtrl = TextEditingController();
  final _sourceIdCtrl = TextEditingController();
  String? _selectedVersionId;
  bool _loading = false;
  Map<String, dynamic>? _result;
  String? _errorMsg;

  @override
  void dispose() {
    _contentCtrl.dispose();
    _sourceIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _extract() async {
    if (_selectedVersionId == null) {
      setState(() => _errorMsg = '온톨로지 버전을 선택하세요.');
      return;
    }
    if (_contentCtrl.text.trim().isEmpty) {
      setState(() => _errorMsg = '구술 자료 텍스트를 입력하세요.');
      return;
    }
    setState(() {
      _loading = true;
      _errorMsg = null;
      _result = null;
    });
    try {
      final result = await ref.read(tripleApiProvider).extractTriples(
            _contentCtrl.text.trim(),
            _selectedVersionId!,
            sourceRecordId: _sourceIdCtrl.text.trim(),
          );
      ref.invalidate(tripleListProvider);
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _errorMsg = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ontologyVersions = ref.watch(ontologyProvider).versions;

    return Scaffold(
      appBar: AppBar(title: const Text('구술자료 → 트리플 AI 추출')),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 입력 패널 ──────────────────────────────────────────────────
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 온톨로지 버전 선택
                  const Text('온톨로지 버전 (Confirmed)',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Builder(builder: (_) {
                    final confirmed = ontologyVersions
                        .where((v) => v.status == OntologyStatus.confirmed)
                        .toList();
                    if (confirmed.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.4)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(children: [
                          Icon(Icons.warning_amber_outlined,
                              color: Colors.orange, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Confirmed 상태의 온톨로지가 없습니다.\n'
                              '먼저 온톨로지를 확정해 주세요.',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ]),
                      );
                    }
                    return InputDecorator(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedVersionId,
                        isExpanded: true,
                        underline: const SizedBox(),
                        hint: const Text('버전 선택'),
                        items: confirmed
                            .map((v) => DropdownMenuItem(
                                  value: v.versionId,
                                  child: Text(
                                    '${v.versionId}  (클래스 ${v.classes.length} · 속성 ${v.predicates.length})',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedVersionId = v),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),

                  // 출처 ID (선택)
                  const Text('출처 레코드 ID (선택)',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _sourceIdCtrl,
                    decoration: const InputDecoration(
                      hintText: '예) oral-2024-001',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 구술 자료 텍스트
                  const Text('구술 자료 텍스트',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _contentCtrl,
                    maxLines: 12,
                    decoration: const InputDecoration(
                      hintText:
                          '구술 자료를 입력하세요.\n예) 김철수는 1950년 서울에서 태어났으며, 부산대학교를 졸업하였다...',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 오류 메시지
                  if (_errorMsg != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        border: Border.all(
                            color: Colors.red.withValues(alpha: 0.4)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_errorMsg!,
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 13)),
                        ),
                      ]),
                    ),

                  // 추출 버튼
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: _loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white),
                            )
                          : const Icon(Icons.auto_awesome, size: 18),
                      label: Text(_loading ? 'AI 추출 중...' : 'AI 추출 시작'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor:
                            Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _loading ? null : _extract,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const VerticalDivider(width: 1),

          // ── 결과 패널 ──────────────────────────────────────────────────
          Expanded(
            flex: 4,
            child: _ResultPanel(result: _result, loading: _loading),
          ),
        ],
      ),
    );
  }
}

// ── 결과 패널 ─────────────────────────────────────────────────────────────────

class _ResultPanel extends StatelessWidget {
  final Map<String, dynamic>? result;
  final bool loading;
  const _ResultPanel({required this.result, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('AI가 트리플을 추출하는 중...',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (result == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_outlined, size: 56, color: Colors.grey),
            SizedBox(height: 12),
            Text('추출 결과가 여기에 표시됩니다.',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final added = result!['added'] ?? 0;
    final skipped = result!['skipped'] ?? 0;
    final triples = (result!['triples'] as List? ?? [])
        .map((t) => Triple.fromJson(t as Map<String, dynamic>))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 요약 헤더
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.green.withValues(alpha: 0.08),
          child: Row(children: [
            const Icon(Icons.check_circle_outline,
                color: Colors.green, size: 18),
            const SizedBox(width: 8),
            Text('추출 완료 — 추가 $added개',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(width: 12),
            if (skipped > 0)
              Text('(중복 건너뜀 $skipped개)',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.grey)),
          ]),
        ),
        const Divider(height: 1),
        // 트리플 목록
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: triples.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (_, i) => _ResultTripleCard(triple: triples[i]),
          ),
        ),
      ],
    );
  }
}

class _ResultTripleCard extends StatelessWidget {
  final Triple triple;
  const _ResultTripleCard({required this.triple});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.green.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _Chip(triple.subject, triple.subjectType),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(triple.predicate,
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600)),
              ),
              _Chip(triple.object, triple.objectType),
            ]),
            const SizedBox(height: 4),
            Text(
              '신뢰도 ${(triple.confidence * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String type;
  const _Chip(this.label, this.type);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600)),
          if (type.isNotEmpty)
            Text(type,
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}
