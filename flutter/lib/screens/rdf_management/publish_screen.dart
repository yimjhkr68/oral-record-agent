import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../services/rdf_api_service.dart';

class PublishScreen extends ConsumerStatefulWidget {
  const PublishScreen({super.key});
  @override
  ConsumerState<PublishScreen> createState() => _PublishScreenState();
}

class _PublishScreenState extends ConsumerState<PublishScreen> {
  // Step 1 — 온톨로지 정보 폼
  final _nameCtrl = TextEditingController(text: 'oral-history-ontology');
  final _versionCtrl = TextEditingController(text: '1.0.0');
  final _uriCtrl = TextEditingController(
      text: 'https://yimjhkr68.github.io/oral-history-ontology/core#');
  final _licenseCtrl = TextEditingController(text: 'CC BY 4.0');
  final _descCtrl = TextEditingController(text: '구술기록 온톨로지 공표 패키지');
  final _authorCtrl = TextEditingController(text: 'Oral Record Agent Team');
  final _outputCtrl = TextEditingController(text: 'data/rdf/published');

  // Step 2 — 포함 파일
  final Map<String, bool> _files = {
    'turtle': true,
    'json_ld': true,
    'owl_xml': true,
    'readme': true,
    'changelog': true,
  };
  static const _fileLabels = {
    'turtle': 'Turtle (.ttl)',
    'json_ld': 'JSON-LD (.jsonld)',
    'owl_xml': 'OWL/XML (.owl)',
    'readme': 'README.md',
    'changelog': 'CHANGELOG.md',
  };

  bool _loading = false;
  String? _error;
  String? _readmePreview;
  Map<String, dynamic>? _packageResult;
  List<dynamic> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _versionCtrl.dispose();
    _uriCtrl.dispose();
    _licenseCtrl.dispose();
    _descCtrl.dispose();
    _authorCtrl.dispose();
    _outputCtrl.dispose();
    super.dispose();
  }

  RdfApiService get _api => ref.read(rdfApiProvider);

  Future<void> _loadHistory() async {
    try {
      final r = await _api.publishHistory();
      if (mounted) setState(() => _history = r);
    } catch (_) {}
  }

  Map<String, dynamic> _buildPayload() => {
        'name': _nameCtrl.text.trim(),
        'version': _versionCtrl.text.trim(),
        'namespace_uri': _uriCtrl.text.trim(),
        'license': _licenseCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'author': _authorCtrl.text.trim(),
        'output_path': _outputCtrl.text.trim(),
        'include_files': _files,
      };

  Future<void> _createPackage() async {
    setState(() { _loading = true; _error = null; _packageResult = null; _readmePreview = null; });
    try {
      _packageResult = await _api.publishPackage(_buildPayload());
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadPreview() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await _api.publishPreview();
      _readmePreview = r['readme'] as String? ?? '(미리보기 없음)';
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runPublish() async {
    final ok = await _confirmDialog();
    if (!ok) return;
    setState(() { _loading = true; _error = null; });
    try {
      final r = await _api.publishRun(_buildPayload());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('공표 완료: v${r['version'] ?? '-'} → ${r['path'] ?? '-'}'),
          backgroundColor: AppColors.success,
        ));
        await _loadHistory();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _confirmDialog() async {
    final r = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('공표 실행', style: AppTypography.heading2),
        content: Text(
          '온톨로지 v${_versionCtrl.text}를 공표합니다.\n'
          '이 작업은 되돌리기 어렵습니다. 계속하시겠습니까?',
          style: AppTypography.body,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('취소')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('공표', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    return r ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Step 1: 온톨로지 정보 ────────────────────────────────────
              _StepHeader(1, '온톨로지 정보 입력'),
              const SizedBox(height: 10),
              _FormGrid(children: [
                _LabeledField('이름', _nameCtrl),
                _LabeledField('버전', _versionCtrl),
                _LabeledField('네임스페이스 URI', _uriCtrl),
                _LabeledField('라이선스', _licenseCtrl),
              ]),
              const SizedBox(height: 8),
              _LabeledField('설명', _descCtrl, maxLines: 2),
              const SizedBox(height: 8),
              _LabeledField('저자', _authorCtrl),

              const SizedBox(height: 20),
              const Divider(color: AppColors.border),

              // ── Step 2: 포함 파일 ────────────────────────────────────────
              _StepHeader(2, '포함 파일 선택'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _files.entries.map((e) {
                  return FilterChip(
                    label: Text(_fileLabels[e.key] ?? e.key,
                        style: AppTypography.caption),
                    selected: e.value,
                    onSelected: (v) =>
                        setState(() => _files[e.key] = v),
                    selectedColor: AppColors.primaryFaint,
                    checkmarkColor: AppColors.primary,
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),
              const Divider(color: AppColors.border),

              // ── Step 3: README 미리보기 ─────────────────────────────────
              _StepHeader(3, 'README 미리보기'),
              const SizedBox(height: 10),
              Row(children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.preview, size: 14),
                  label: const Text('README 미리보기'),
                  onPressed: _loadPreview,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    textStyle: AppTypography.caption,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                ),
              ]),
              if (_readmePreview != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: SelectableText(
                    _readmePreview!,
                    style: AppTypography.mono.copyWith(fontSize: 11),
                  ),
                ),
              ],

              const SizedBox(height: 20),
              const Divider(color: AppColors.border),

              // ── Step 4: 출력 경로 + 실행 ────────────────────────────────
              _StepHeader(4, '출력 경로 및 패키지 생성'),
              const SizedBox(height: 10),
              _LabeledField('출력 경로', _outputCtrl),
              const SizedBox(height: 10),
              Row(children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.inventory_2_outlined, size: 14),
                  label: const Text('패키지 생성'),
                  onPressed: _createPackage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                    textStyle: AppTypography.caption,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.publish, size: 14),
                  label: const Text('공표 실행'),
                  onPressed: _runPublish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    textStyle: AppTypography.caption,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                ),
              ]),

              if (_error != null) ...[
                const SizedBox(height: 10),
                _ErrorBanner(_error!),
              ],

              if (_packageResult != null) ...[
                const SizedBox(height: 10),
                _PackageResult(_packageResult!),
              ],

              const SizedBox(height: 20),
              const Divider(color: AppColors.border),

              // ── Step 5: 공표 이력 ────────────────────────────────────────
              _StepHeader(5, '공표 이력'),
              const SizedBox(height: 10),
              if (_history.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('공표 이력 없음', style: AppTypography.body),
                  ),
                )
              else
                _HistoryTable(_history),

              const SizedBox(height: 40),
            ],
          ),
        ),
        if (_loading) const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

// ── 내부 위젯 ─────────────────────────────────────────────────────────────────

class _StepHeader extends StatelessWidget {
  final int number;
  final String title;
  const _StepHeader(this.number, this.title);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: AppColors.secondary,
          borderRadius: BorderRadius.circular(11),
        ),
        alignment: Alignment.center,
        child: Text('$number',
            style: AppTypography.badge.copyWith(color: Colors.white)),
      ),
      const SizedBox(width: 8),
      Text('Step $number. $title', style: AppTypography.heading2),
    ]);
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLines;
  const _LabeledField(this.label, this.controller, {this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: AppTypography.body.copyWith(fontSize: 12),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTypography.caption,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
      ),
    );
  }
}

class _FormGrid extends StatelessWidget {
  final List<Widget> children;
  const _FormGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    // 2-column grid using paired rows
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      rows.add(Row(
        children: [
          Expanded(child: children[i]),
          if (i + 1 < children.length) ...[
            const SizedBox(width: 12),
            Expanded(child: children[i + 1]),
          ],
        ],
      ));
      if (i + 2 < children.length) rows.add(const SizedBox(height: 8));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }
}

class _PackageResult extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PackageResult(this.data);

  @override
  Widget build(BuildContext context) {
    final files = (data['files'] as List? ?? []).cast<String>();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border:
            Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.check_circle, size: 14, color: AppColors.success),
            const SizedBox(width: 6),
            Text('패키지 생성 완료',
                style:
                    AppTypography.body.copyWith(color: AppColors.success)),
          ]),
          if (data['path'] != null) ...[
            const SizedBox(height: 4),
            Text('경로: ${data['path']}',
                style: AppTypography.mono.copyWith(fontSize: 11)),
          ],
          if (files.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: files.map((f) {
                final name = f.split('/').last.split('\\').last;
                return Chip(
                  label: Text(name, style: AppTypography.caption),
                  backgroundColor: AppColors.surfaceElevated,
                  side: const BorderSide(color: AppColors.border),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryTable extends StatelessWidget {
  final List<dynamic> history;
  const _HistoryTable(this.history);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          // 헤더
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
            ),
            child: Row(children: [
              _HCell('버전', flex: 1),
              _HCell('공표일', flex: 2),
              _HCell('경로', flex: 4),
              _HCell('파일수', flex: 1),
            ]),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          // 행
          ...history.reversed.take(10).map((e) {
            final row = e as Map? ?? {};
            final path = (row['path'] as String? ?? '-');
            final shortPath = path.length > 40
                ? '...${path.substring(path.length - 37)}'
                : path;
            final publishedAt =
                (row['published_at'] as String? ?? '-').length >= 10
                    ? (row['published_at'] as String).substring(0, 10)
                    : '-';
            final fileCount = (row['files'] as List?)?.length ?? 0;
            return Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                child: Row(children: [
                  _DCell(row['version']?.toString() ?? '-', flex: 1),
                  _DCell(publishedAt, flex: 2),
                  _DCell(shortPath, flex: 4),
                  _DCell('$fileCount', flex: 1),
                ]),
              ),
              const Divider(height: 1, color: AppColors.border),
            ]);
          }),
        ],
      ),
    );
  }
}

class _HCell extends StatelessWidget {
  final String text;
  final int flex;
  const _HCell(this.text, {this.flex = 1});
  @override
  Widget build(BuildContext context) => Expanded(
        flex: flex,
        child: Text(text,
            style: AppTypography.caption
                .copyWith(fontWeight: FontWeight.w600)),
      );
}

class _DCell extends StatelessWidget {
  final String text;
  final int flex;
  const _DCell(this.text, {this.flex = 1});
  @override
  Widget build(BuildContext context) => Expanded(
        flex: flex,
        child: Text(text,
            style: AppTypography.mono.copyWith(fontSize: 11),
            overflow: TextOverflow.ellipsis),
      );
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border:
              Border.all(color: AppColors.error.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline, size: 14, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style:
                      AppTypography.body.copyWith(color: AppColors.error))),
        ]),
      );
}
