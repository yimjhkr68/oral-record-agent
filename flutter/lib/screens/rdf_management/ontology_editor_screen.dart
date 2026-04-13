import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../services/rdf_api_service.dart';

class OntologyEditorScreen extends ConsumerStatefulWidget {
  const OntologyEditorScreen({super.key});
  @override
  ConsumerState<OntologyEditorScreen> createState() =>
      _OntologyEditorScreenState();
}

class _OntologyEditorScreenState extends ConsumerState<OntologyEditorScreen> {
  List<Map<String, dynamic>> _classes = [];
  Map<String, dynamic>? _selected;
  bool _loading = false;
  String? _error;
  String? _message;
  bool _turtleExpanded = false;
  String _turtleText = '';
  Map<String, dynamic>? _version;

  // 편집 폼
  final _labelKoCtrl = TextEditingController();
  final _labelEnCtrl = TextEditingController();
  final _parentCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _turtleCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _labelKoCtrl.dispose();
    _labelEnCtrl.dispose();
    _parentCtrl.dispose();
    _descCtrl.dispose();
    _turtleCtrl.dispose();
    super.dispose();
  }

  RdfApiService get _api => ref.read(rdfApiProvider);

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final r = await Future.wait([
        _api.ontologyClasses(),
        _api.ontologyVersion(),
        _api.ontologyGetTurtle(),
      ]);
      _classes = r[0] as List<Map<String, dynamic>>;
      _version = r[1] as Map<String, dynamic>;
      final turtleData = r[2] as Map<String, dynamic>;
      _turtleText = turtleData['turtle'] as String? ?? '';
      _turtleCtrl.text = _turtleText;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectClass(Map<String, dynamic> cls) {
    setState(() {
      _selected = cls;
      _labelKoCtrl.text = cls['label_ko'] ?? '';
      _labelEnCtrl.text = cls['label_en'] ?? '';
      _parentCtrl.text =
          (cls['parents'] as List? ?? []).join(', ');
      _descCtrl.text = cls['description'] ?? '';
      _error = null;
      _message = null;
    });
  }

  Future<void> _saveClass() async {
    if (_selected == null) return;
    if (_labelKoCtrl.text.trim().isEmpty) {
      setState(() => _error = '한국어 레이블은 필수입니다');
      return;
    }
    setState(() { _loading = true; _error = null; _message = null; });
    try {
      final local = _selected!['local'] as String;
      final parents = _parentCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      await _api.ontologyUpdateClass(local, {
        'label_ko': _labelKoCtrl.text.trim(),
        'label_en': _labelEnCtrl.text.trim(),
        'parent_uris': parents,
        'equiv_uris': [],
        'description': _descCtrl.text.trim(),
      });
      _message = '저장 완료';
      await _loadAll();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deprecateClass() async {
    if (_selected == null) return;
    final local = _selected!['local'] as String;
    final ok = await _confirm('Deprecated 처리', '$local 클래스를 Deprecated 처리합니다. 계속하시겠습니까?');
    if (!ok) return;
    setState(() { _loading = true; _error = null; });
    try {
      await _api.ontologyDeprecateClass(local);
      _selected = null;
      _message = 'Deprecated 처리 완료 (MAJOR 버전 증가)';
      await _loadAll();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _validateTurtle() async {
    setState(() { _loading = true; _error = null; _message = null; });
    try {
      final r = await _api.ontologyValidateTurtle(_turtleCtrl.text);
      if (r['valid'] == true) {
        _message = '검증 통과 — ${r['triple_count']} 트리플';
      } else {
        _error = 'Turtle 오류: ${r['error']}';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _applyTurtle() async {
    final ok = await _confirm('Turtle 적용', '현재 Turtle 텍스트를 그래프에 반영합니다. 계속하시겠습니까?');
    if (!ok) return;
    setState(() { _loading = true; _error = null; _message = null; });
    try {
      final r = await _api.ontologyApplyTurtle(_turtleCtrl.text);
      _message = '적용 완료 — ${r['triple_count']} 트리플 (PATCH 버전 증가)';
      await _loadAll();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _confirm(String title, String msg) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title, style: AppTypography.heading2),
        content: Text(msg, style: AppTypography.body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('확인', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return r ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            // 버전 + 메시지 바
            Container(
              color: AppColors.surfaceElevated,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 12, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    '버전: ${_version?['version'] ?? '-'}',
                    style: AppTypography.caption,
                  ),
                  const SizedBox(width: 16),
                  Text('클래스 ${_classes.length}개',
                      style: AppTypography.caption),
                  const Spacer(),
                  if (_message != null)
                    Text(_message!,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.success)),
                  if (_error != null)
                    Text(_error!,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.error)),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    icon: const Icon(Icons.refresh, size: 14),
                    label: const Text('새로고침'),
                    onPressed: _loadAll,
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.secondary,
                        textStyle: AppTypography.caption),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),

            // 좌우 분할
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 좌측: 클래스 목록 ──────────────────────────────────
                  SizedBox(
                    width: 260,
                    child: Column(
                      children: [
                        Container(
                          color: AppColors.surface,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Row(children: [
                            Text('클래스 목록',
                                style: AppTypography.heading2),
                          ]),
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _classes.length,
                            itemBuilder: (_, i) {
                              final cls = _classes[i];
                              final isSelected =
                                  _selected?['uri'] == cls['uri'];
                              final isDeprecated =
                                  cls['deprecated'] == true;
                              return ListTile(
                                dense: true,
                                selected: isSelected,
                                selectedTileColor: AppColors.primaryFaint,
                                leading: Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: isDeprecated
                                      ? AppColors.textMuted
                                      : AppColors.secondary,
                                ),
                                title: Text(
                                  cls['local'] ?? '',
                                  style: AppTypography.body.copyWith(
                                    fontSize: 12,
                                    decoration: isDeprecated
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: isDeprecated
                                        ? AppColors.textMuted
                                        : null,
                                  ),
                                ),
                                subtitle: cls['label_ko'] != null &&
                                        cls['label_ko'] != ''
                                    ? Text(cls['label_ko'],
                                        style: AppTypography.caption)
                                    : null,
                                onTap: () => _selectClass(cls),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const VerticalDivider(width: 1, color: AppColors.border),

                  // ── 우측: 편집 패널 ────────────────────────────────────
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: _selected == null
                                ? Center(
                                    child: Text('클래스를 선택하세요',
                                        style: AppTypography.body))
                                : _EditPanel(
                                    selected: _selected!,
                                    labelKoCtrl: _labelKoCtrl,
                                    labelEnCtrl: _labelEnCtrl,
                                    parentCtrl: _parentCtrl,
                                    descCtrl: _descCtrl,
                                    onSave: _saveClass,
                                    onDeprecate: _deprecateClass,
                                  ),
                          ),
                        ),

                        // ── 하단: Turtle 직접 편집 ──────────────────────
                        const Divider(height: 1, color: AppColors.border),
                        Container(
                          color: AppColors.surface,
                          child: Column(
                            children: [
                              ListTile(
                                dense: true,
                                leading: const Icon(Icons.code,
                                    size: 14, color: AppColors.textMuted),
                                title: Text('Turtle 직접 편집 (고급)',
                                    style: AppTypography.caption),
                                trailing: Icon(
                                  _turtleExpanded
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  size: 16,
                                ),
                                onTap: () => setState(
                                    () => _turtleExpanded = !_turtleExpanded),
                              ),
                              if (_turtleExpanded) ...[
                                const Divider(height: 1, color: AppColors.border),
                                SizedBox(
                                  height: 200,
                                  child: TextField(
                                    controller: _turtleCtrl,
                                    style: AppTypography.mono,
                                    maxLines: null,
                                    expands: true,
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.all(12),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.check, size: 14),
                                        label: const Text('Turtle 검증'),
                                        onPressed: _validateTurtle,
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.secondary,
                                          textStyle: AppTypography.caption,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.upload, size: 14),
                                        label: const Text('Turtle 적용'),
                                        onPressed: _applyTurtle,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.secondary,
                                          foregroundColor: Colors.white,
                                          textStyle: AppTypography.caption,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_loading)
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

class _EditPanel extends StatelessWidget {
  final Map<String, dynamic> selected;
  final TextEditingController labelKoCtrl;
  final TextEditingController labelEnCtrl;
  final TextEditingController parentCtrl;
  final TextEditingController descCtrl;
  final VoidCallback onSave;
  final VoidCallback onDeprecate;

  const _EditPanel({
    required this.selected,
    required this.labelKoCtrl,
    required this.labelEnCtrl,
    required this.parentCtrl,
    required this.descCtrl,
    required this.onSave,
    required this.onDeprecate,
  });

  InputDecoration _deco(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 11),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        isDense: true,
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Text('선택: ${selected['local']}',
                style: AppTypography.heading2),
          ),
          if (selected['deprecated'] == true)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('Deprecated',
                  style: AppTypography.badge.copyWith(color: AppColors.textMuted)),
            ),
        ]),
        const SizedBox(height: 4),
        Text(selected['uri'] ?? '',
            style: AppTypography.mono.copyWith(fontSize: 10)),
        const SizedBox(height: 16),
        TextField(
          controller: labelKoCtrl,
          decoration: _deco('레이블 (한국어) *'),
          style: AppTypography.body,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: labelEnCtrl,
          decoration: _deco('레이블 (English)'),
          style: AppTypography.body,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: parentCtrl,
          decoration: _deco('상위 클래스 URI (쉼표 구분)'),
          style: AppTypography.mono.copyWith(fontSize: 11),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: descCtrl,
          decoration: _deco('설명'),
          style: AppTypography.body,
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.save, size: 14),
              label: const Text('저장 (PATCH)'),
              onPressed: onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                textStyle: AppTypography.caption,
              ),
            ),
            const SizedBox(width: 8),
            if (selected['deprecated'] != true)
              OutlinedButton.icon(
                icon: const Icon(Icons.remove_circle_outline, size: 14),
                label: const Text('Deprecated'),
                onPressed: onDeprecate,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  textStyle: AppTypography.caption,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if ((selected['props_domain'] as List? ?? []).isNotEmpty ||
            (selected['props_range'] as List? ?? []).isNotEmpty) ...[
          Text('관련 속성', style: AppTypography.caption),
          const SizedBox(height: 4),
          ...(selected['props_domain'] as List? ?? []).map((p) => Text(
                '→ $p (domain)',
                style: AppTypography.mono.copyWith(fontSize: 10),
              )),
          ...(selected['props_range'] as List? ?? []).map((p) => Text(
                '← $p (range)',
                style: AppTypography.mono.copyWith(fontSize: 10),
              )),
        ],
      ],
    );
  }
}
