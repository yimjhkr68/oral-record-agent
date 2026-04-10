import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/published_ontology.dart';
import '../../providers/published_ontology_provider.dart';

class PublishedOntologyScreen extends ConsumerWidget {
  const PublishedOntologyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(publishedOntologyProvider);

    if (state.isLoading && state.ontologies.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Row(
      children: [
        // ── 좌측: 온톨로지 목록 ───────────────────────────────────────────────
        SizedBox(
          width: 260,
          child: Column(
            children: [
              _Header(state: state),
              if (state.error != null)
                _ErrorBanner(message: state.error!),
              Expanded(child: _OntologyList(state: state)),
            ],
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        // ── 우측: 클래스 목록 ─────────────────────────────────────────────────
        Expanded(
          child: state.selected == null
              ? const _EmptyDetail()
              : _ClassDetail(onto: state.selected!),
        ),
      ],
    );
  }
}

// ── 헤더 ─────────────────────────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  final PublishedOntologyState state;
  const _Header({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          const Text('공표 온톨로지',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            tooltip: '새로고침',
            onPressed: () =>
                ref.read(publishedOntologyProvider.notifier).load(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.add, size: 20),
            tooltip: '온톨로지 추가',
            onPressed: () => _showCreateDialog(context, ref),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => _OntologyCreateDialog(
        onSave: (id, name, prefix, ns, desc, ver) async {
          final ok = await ref
              .read(publishedOntologyProvider.notifier)
              .createOntology(
                id: id,
                name: name,
                prefix: prefix,
                namespaceUri: ns,
                description: desc,
                version: ver,
              );
          if (ok && context.mounted) Navigator.pop(context);
        },
      ),
    );
  }
}

// ── 온톨로지 목록 ─────────────────────────────────────────────────────────────

class _OntologyList extends ConsumerWidget {
  final PublishedOntologyState state;
  const _OntologyList({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(publishedOntologyProvider.notifier);
    final ontos = state.ontologies;

    if (ontos.isEmpty) {
      return const Center(
        child: Text('공표 온톨로지가 없습니다.',
            style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      itemCount: ontos.length,
      itemBuilder: (ctx, i) {
        final o = ontos[i];
        final isSelected = state.selected?.id == o.id;
        return ListTile(
          selected: isSelected,
          selectedTileColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          title: Row(children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .secondaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(o.prefix,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context)
                          .colorScheme
                          .onSecondaryContainer)),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(o.name,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
          subtitle: Text('${o.classes.length}개 클래스',
              style: const TextStyle(fontSize: 11)),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
            tooltip: '삭제',
            onPressed: () =>
                _confirmDelete(context, ref, notifier, o),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          onTap: () => notifier.select(o),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref,
      PublishedOntologyNotifier notifier, PublishedOntology o) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('온톨로지 삭제'),
        content: Text('"${o.name}"을(를) 삭제합니다.\n포함된 클래스도 모두 삭제됩니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(dialogCtx);
              notifier.deleteOntology(o.id);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

// ── 클래스 상세 패널 ──────────────────────────────────────────────────────────

class _ClassDetail extends ConsumerWidget {
  final PublishedOntology onto;
  const _ClassDetail({required this.onto});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(publishedOntologyProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(onto.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      '${onto.prefix}: ${onto.namespaceUri}'
                      '${onto.version.isNotEmpty ? '  v${onto.version}' : ''}',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey),
                    ),
                    if (onto.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(onto.description,
                          style: const TextStyle(fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('클래스 추가'),
                style: ElevatedButton.styleFrom(
                    visualDensity: VisualDensity.compact),
                onPressed: () =>
                    _showAddClassDialog(context, ref, notifier),
              ),
            ],
          ),
        ),

        // 클래스 목록
        Expanded(
          child: onto.classes.isEmpty
              ? const Center(
                  child: Text('클래스가 없습니다. 추가 버튼으로 클래스를 등록하세요.',
                      style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: onto.classes.length,
                  itemBuilder: (ctx, i) => _ClassCard(
                    cls: onto.classes[i],
                    ontoId: onto.id,
                    notifier: notifier,
                  ),
                ),
        ),
      ],
    );
  }

  void _showAddClassDialog(BuildContext context, WidgetRef ref,
      PublishedOntologyNotifier notifier) {
    showDialog(
      context: context,
      builder: (_) => _ClassEditDialog(
        title: '클래스 추가',
        prefix: onto.prefix,
        namespaceUri: onto.namespaceUri,
        onSave: (curie, uri, label, labelKo, desc) async {
          final ok = await notifier.addClass(
            onto.id,
            curie: curie,
            uri: uri,
            label: label,
            labelKo: labelKo,
            description: desc,
          );
          if (ok && context.mounted) Navigator.pop(context);
        },
      ),
    );
  }
}

// ── 클래스 카드 ───────────────────────────────────────────────────────────────

class _ClassCard extends ConsumerWidget {
  final PublishedClass cls;
  final String ontoId;
  final PublishedOntologyNotifier notifier;

  const _ClassCard({
    required this.cls,
    required this.ontoId,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CURIE 뱃지
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(cls.curie,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer)),
            ),
            const SizedBox(width: 10),
            // 레이블 + 설명
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(cls.label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    if (cls.labelKo.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text('(${cls.labelKo})',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ],
                  ]),
                  if (cls.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(cls.description,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ),
                ],
              ),
            ),
            // 수정/삭제
            Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 16),
                tooltip: '수정',
                onPressed: () =>
                    _showEditDialog(context, ref),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 16, color: Colors.red),
                tooltip: '삭제',
                onPressed: () =>
                    _confirmDelete(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => _ClassEditDialog(
        title: '클래스 수정',
        initialCurie: cls.curie,
        initialUri: cls.uri,
        initialLabel: cls.label,
        initialLabelKo: cls.labelKo,
        initialDescription: cls.description,
        onSave: (curie, uri, label, labelKo, desc) async {
          final ok = await notifier.updateClass(
            ontoId, cls.id,
            curie: curie, uri: uri, label: label,
            labelKo: labelKo, description: desc,
          );
          if (ok && context.mounted) Navigator.pop(context);
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('클래스 삭제'),
        content: Text('"${cls.curie}"를 삭제합니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(dialogCtx);
              notifier.deleteClass(ontoId, cls.id);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

// ── 다이얼로그: 온톨로지 생성 ────────────────────────────────────────────────

class _OntologyCreateDialog extends StatefulWidget {
  final Future<void> Function(String id, String name, String prefix,
      String ns, String desc, String ver) onSave;
  const _OntologyCreateDialog({required this.onSave});

  @override
  State<_OntologyCreateDialog> createState() => _OntologyCreateDialogState();
}

class _OntologyCreateDialogState extends State<_OntologyCreateDialog> {
  final _idCtrl    = TextEditingController();
  final _nameCtrl  = TextEditingController();
  final _pfxCtrl   = TextEditingController();
  final _nsCtrl    = TextEditingController();
  final _descCtrl  = TextEditingController();
  final _verCtrl   = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _idCtrl.dispose(); _nameCtrl.dispose(); _pfxCtrl.dispose();
    _nsCtrl.dispose(); _descCtrl.dispose(); _verCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('공표 온톨로지 추가'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _field(_idCtrl,   'ID (slug)', 'e.g. my-ontology'),
          _field(_nameCtrl, '이름', 'e.g. My Ontology'),
          _field(_pfxCtrl,  'Prefix', 'e.g. mo'),
          _field(_nsCtrl,   'Namespace URI', 'e.g. http://example.org/mo/'),
          _field(_verCtrl,  '버전 (선택)', 'e.g. 1.0'),
          _field(_descCtrl, '설명 (선택)', '', maxLines: 2),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('취소')),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('추가'),
        ),
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      String hint, {int maxLines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: ctrl,
          maxLines: maxLines,
          decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              border: const OutlineInputBorder(),
              isDense: true),
        ),
      );

  Future<void> _submit() async {
    if (_idCtrl.text.trim().isEmpty || _nameCtrl.text.trim().isEmpty ||
        _pfxCtrl.text.trim().isEmpty || _nsCtrl.text.trim().isEmpty) { return; }
    setState(() => _saving = true);
    await widget.onSave(
      _idCtrl.text.trim(), _nameCtrl.text.trim(), _pfxCtrl.text.trim(),
      _nsCtrl.text.trim(), _descCtrl.text.trim(), _verCtrl.text.trim(),
    );
    if (mounted) setState(() => _saving = false);
  }
}

// ── 다이얼로그: 클래스 추가/수정 ─────────────────────────────────────────────

class _ClassEditDialog extends StatefulWidget {
  final String title;
  final String prefix;
  final String namespaceUri;
  final String? initialCurie;
  final String? initialUri;
  final String? initialLabel;
  final String? initialLabelKo;
  final String? initialDescription;
  final Future<void> Function(
      String curie, String uri, String label, String labelKo, String desc) onSave;

  const _ClassEditDialog({
    required this.title,
    this.prefix = '',
    this.namespaceUri = '',
    this.initialCurie,
    this.initialUri,
    this.initialLabel,
    this.initialLabelKo,
    this.initialDescription,
    required this.onSave,
  });

  @override
  State<_ClassEditDialog> createState() => _ClassEditDialogState();
}

class _ClassEditDialogState extends State<_ClassEditDialog> {
  late final TextEditingController _curieCtrl;
  late final TextEditingController _uriCtrl;
  late final TextEditingController _labelCtrl;
  late final TextEditingController _labelKoCtrl;
  late final TextEditingController _descCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _curieCtrl   = TextEditingController(text: widget.initialCurie ?? '');
    _uriCtrl     = TextEditingController(text: widget.initialUri ?? '');
    _labelCtrl   = TextEditingController(text: widget.initialLabel ?? '');
    _labelKoCtrl = TextEditingController(text: widget.initialLabelKo ?? '');
    _descCtrl    = TextEditingController(text: widget.initialDescription ?? '');

    // 새 클래스: prefix 미리 채움
    if (widget.initialCurie == null && widget.prefix.isNotEmpty) {
      _curieCtrl.text = '${widget.prefix}:';
    }
    if (widget.initialUri == null && widget.namespaceUri.isNotEmpty) {
      _uriCtrl.text = widget.namespaceUri;
    }
  }

  @override
  void dispose() {
    _curieCtrl.dispose(); _uriCtrl.dispose(); _labelCtrl.dispose();
    _labelKoCtrl.dispose(); _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _field(_curieCtrl,   'CURIE', 'e.g. crm:E21_Person'),
          _field(_uriCtrl,     'URI', 'e.g. http://...'),
          _field(_labelCtrl,   '레이블 (영문)', 'e.g. Person'),
          _field(_labelKoCtrl, '레이블 (한국어)', '예: 인물'),
          _field(_descCtrl,    '설명', '', maxLines: 3),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('취소')),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('저장'),
        ),
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      String hint, {int maxLines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: ctrl,
          maxLines: maxLines,
          decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              border: const OutlineInputBorder(),
              isDense: true),
        ),
      );

  Future<void> _submit() async {
    if (_curieCtrl.text.trim().isEmpty || _uriCtrl.text.trim().isEmpty ||
        _labelCtrl.text.trim().isEmpty) { return; }
    setState(() => _saving = true);
    await widget.onSave(
      _curieCtrl.text.trim(), _uriCtrl.text.trim(), _labelCtrl.text.trim(),
      _labelKoCtrl.text.trim(), _descCtrl.text.trim(),
    );
    if (mounted) setState(() => _saving = false);
  }
}

// ── 보조 위젯 ─────────────────────────────────────────────────────────────────

class _EmptyDetail extends StatelessWidget {
  const _EmptyDetail();

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.library_books_outlined, size: 56, color: Colors.grey),
          SizedBox(height: 12),
          Text('온톨로지를 선택하면 클래스 목록이 표시됩니다.',
              style: TextStyle(color: Colors.grey)),
        ]),
      );
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          border: Border.all(color: Colors.red.shade200),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(message,
            style: const TextStyle(fontSize: 12, color: Colors.red)),
      );
}
