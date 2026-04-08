import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/ontology.dart';
import '../../models/triple.dart';
import '../../providers/ontology_provider.dart';
import '../../providers/triple_provider.dart';

class TripleStep1Extract extends ConsumerStatefulWidget {
  const TripleStep1Extract({super.key});

  @override
  ConsumerState<TripleStep1Extract> createState() => _TripleStep1ExtractState();
}

class _TripleStep1ExtractState extends ConsumerState<TripleStep1Extract> {
  final _textCtrl    = TextEditingController();
  final _sourceCtrl  = TextEditingController();

  @override
  void dispose() {
    _textCtrl.dispose();
    _sourceCtrl.dispose();
    super.dispose();
  }

  void _addRecord() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    final id = _sourceCtrl.text.trim().isEmpty
        ? '구술기록-${DateTime.now().millisecondsSinceEpoch ~/ 1000}'
        : _sourceCtrl.text.trim();
    ref.read(tripleWorkProvider.notifier)
        .addSourceRecord(SourceRecord(id: id, content: text));
    _textCtrl.clear();
    _sourceCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final state     = ref.watch(tripleWorkProvider);
    final versions  = ref.watch(ontologyProvider).versions;
    final confirmed = versions
        .where((v) => v.status == OntologyStatus.confirmed)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 온톨로지 선택 ─────────────────────────────────────────────────
          _SectionTitle('1. 온톨로지 버전 선택 (Confirmed)'),
          const SizedBox(height: 8),
          if (confirmed.isEmpty)
            _WarningBox('Confirmed 온톨로지가 없습니다. 온톨로지 탭에서 먼저 확정해 주세요.')
          else
            InputDecorator(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
              child: DropdownButton<String>(
                value: state.selectedVersionId,
                isExpanded: true,
                underline: const SizedBox(),
                hint: const Text('버전 선택'),
                items: confirmed
                    .map((v) => DropdownMenuItem(
                          value: v.versionId,
                          child: Text(v.versionId),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    ref.read(tripleWorkProvider.notifier).setVersion(v);
                  }
                },
              ),
            ),

          const SizedBox(height: 24),

          // ── 구술기록 입력 ─────────────────────────────────────────────────
          _SectionTitle('2. 구술기록 추가 (텍스트 입력)'),
          const SizedBox(height: 8),
          TextField(
            controller: _sourceCtrl,
            decoration: const InputDecoration(
              labelText: '레코드 ID (비워두면 자동 생성)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _textCtrl,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: '구술 텍스트 붙여넣기',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('목록에 추가'),
              onPressed: _addRecord,
            ),
          ),

          const SizedBox(height: 20),

          // ── 선택된 구술기록 목록 ──────────────────────────────────────────
          if (state.sourceRecords.isNotEmpty) ...[
            _SectionTitle('선택된 구술기록 (${state.sourceRecords.length}개)'),
            const SizedBox(height: 8),
            ...state.sourceRecords.asMap().entries.map(
              (e) => _SourceCard(
                index: e.key,
                record: e.value,
                onRemove: () => ref
                    .read(tripleWorkProvider.notifier)
                    .removeSourceRecord(e.key),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // ── 진행 상황 ────────────────────────────────────────────────────
          if (state.isExtracting) ...[
            const SizedBox(height: 12),
            Text(
              '처리 중 (${state.extractProgress + 1}/${state.extractTotal}): '
              '${state.extractStatus}',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: state.extractTotal > 0
                  ? state.extractProgress / state.extractTotal
                  : null,
            ),
            const SizedBox(height: 4),
            const Text(
              'AI 분석 중입니다. 잠시 기다려주세요... (레코드당 최대 2분)',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],

          // ── 에러 ─────────────────────────────────────────────────────────
          if (state.error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(state.error!,
                      style:
                          const TextStyle(color: Colors.red, fontSize: 12)),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 28),

          // ── 트리플 생성 버튼 ──────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: state.isExtracting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(state.isExtracting
                  ? 'AI 추출 중...'
                  : '트리플 생성 (${state.sourceRecords.length}개 레코드)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: state.canExtract
                  ? () => ref.read(tripleWorkProvider.notifier).extractAll()
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 보조 위젯 ─────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: Theme.of(context).colorScheme.primary));
}

class _WarningBox extends StatelessWidget {
  final String message;
  const _WarningBox(this.message);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          border:
              Border.all(color: Colors.orange.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          const Icon(Icons.warning_amber_outlined,
              color: Colors.orange, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
        ]),
      );
}

class _SourceCard extends StatelessWidget {
  final int index;
  final SourceRecord record;
  final VoidCallback onRemove;
  const _SourceCard(
      {required this.index,
      required this.record,
      required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final preview = record.content.length > 120
        ? '${record.content.substring(0, 120)}…'
        : record.content;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
              child: Text('${index + 1}',
                  style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.primary)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(record.id,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(preview,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: onRemove,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
