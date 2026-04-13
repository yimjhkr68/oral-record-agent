import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../services/rdf_api_service.dart';

class MigrationScreen extends ConsumerStatefulWidget {
  const MigrationScreen({super.key});
  @override
  ConsumerState<MigrationScreen> createState() => _MigrationScreenState();
}

class _MigrationScreenState extends ConsumerState<MigrationScreen> {
  Map<String, dynamic>? _status;
  Map<String, dynamic>? _analyzeResult;
  Map<String, dynamic>? _previewResult;
  bool _loading = false;
  String? _error;
  String? _stepMessage;

  // 설정
  String _namespace =
      'https://yimjhkr68.github.io/oral-history-ontology/core#';
  final List<String> _formats = ['turtle', 'json-ld', 'xml'];

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  RdfApiService get _api => ref.read(rdfApiProvider);

  Future<void> _loadStatus() async {
    setState(() => _loading = true);
    try {
      _status = await _api.migrationStatus();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runStep(String label, Future<Map<String, dynamic>> Function() fn) async {
    setState(() { _loading = true; _error = null; _stepMessage = null; });
    try {
      final r = await fn();
      _stepMessage = r.toString();
      await _loadStatus();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sqlite = _status?['sqlite'] as Map? ?? {};
    final rdfConverted = _status?['rdf_converted'] == true;
    final rdfConfirmed = _status?['rdf_confirmed'] == true;
    final backups = (_status?['backup_files'] as List? ?? []);

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 상태 카드 3개 ────────────────────────────────────────────
              Row(
                children: [
                  _StatusCard(
                    title: 'SQLite 현황',
                    icon: Icons.storage,
                    color: AppColors.info,
                    lines: [
                      '온톨로지 Draft: ${sqlite['ontology_drafts'] ?? 0}',
                      '온톨로지 확정: ${sqlite['ontology_confirmed'] ?? 0}',
                      '활성 트리플: ${sqlite['active_triples'] ?? 0}',
                      '구술기록: ${sqlite['records'] ?? 0}',
                    ],
                  ),
                  const SizedBox(width: 12),
                  _StatusCard(
                    title: 'RDF 변환 상태',
                    icon: Icons.sync_alt,
                    color: rdfConverted ? AppColors.success : AppColors.textMuted,
                    lines: [
                      rdfConverted ? '● 변환 완료' : '● 미변환',
                      rdfConfirmed ? '✓ 확정됨' : '미확정',
                      if (_status?['last_migration'] != null)
                        '마지막: ${(_status!['last_migration'] as String).substring(0, 10)}',
                    ],
                  ),
                  const SizedBox(width: 12),
                  _StatusCard(
                    title: '파일 출력 상태',
                    icon: Icons.folder_outlined,
                    color: backups.isNotEmpty ? AppColors.success : AppColors.textMuted,
                    lines: [
                      '백업: ${backups.length}개',
                      if (backups.isNotEmpty)
                        backups.last.toString().split('/').last,
                    ],
                  ),
                ],
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                _ErrorBanner(_error!),
              ],
              if (_stepMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryFaint,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
                  ),
                  child: Text(_stepMessage!, style: AppTypography.mono),
                ),
              ],

              const SizedBox(height: 24),
              const Divider(color: AppColors.border),

              // ── Step 1. 분석 ────────────────────────────────────────────
              _StepHeader(number: 1, title: '데이터 분석'),
              const SizedBox(height: 8),
              Row(
                children: [
                  _ActionButton(
                    icon: Icons.search,
                    label: '현재 DB 구조 분석',
                    onTap: () => _runStep('분석', () async {
                      final r = await _api.migrationAnalyze();
                      setState(() => _analyzeResult = r);
                      return r;
                    }),
                  ),
                ],
              ),
              if (_analyzeResult != null) ...[
                const SizedBox(height: 8),
                _AnalyzeResult(_analyzeResult!),
              ],

              const SizedBox(height: 20),
              const Divider(color: AppColors.border),

              // ── Step 2. 백업 ────────────────────────────────────────────
              _StepHeader(number: 2, title: '백업'),
              const SizedBox(height: 8),
              _ActionButton(
                icon: Icons.save,
                label: 'v4.0 데이터 백업',
                color: AppColors.warning,
                onTap: () => _runStep('백업', _api.migrationBackup),
              ),

              const SizedBox(height: 20),
              const Divider(color: AppColors.border),

              // ── Step 3. 설정 ────────────────────────────────────────────
              _StepHeader(number: 3, title: '변환 설정'),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: _namespace,
                style: AppTypography.mono,
                decoration: _inputDeco('네임스페이스 URI'),
                onChanged: (v) => _namespace = v,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['turtle', 'json-ld', 'xml'].map((f) {
                  final checked = _formats.contains(f);
                  return FilterChip(
                    label: Text(f, style: AppTypography.caption),
                    selected: checked,
                    onSelected: (v) => setState(() {
                      v ? _formats.add(f) : _formats.remove(f);
                    }),
                    selectedColor: AppColors.primaryFaint,
                    checkmarkColor: AppColors.primary,
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),
              const Divider(color: AppColors.border),

              // ── Step 4. 실행 ────────────────────────────────────────────
              _StepHeader(number: 4, title: '변환 실행'),
              const SizedBox(height: 8),
              _ActionButton(
                icon: Icons.play_arrow,
                label: '마이그레이션 실행',
                color: AppColors.secondary,
                onTap: () => _runStep('실행', () =>
                    _api.migrationRun(namespaceUri: _namespace, formats: _formats)),
              ),

              const SizedBox(height: 20),
              const Divider(color: AppColors.border),

              // ── Step 5. 확인 ────────────────────────────────────────────
              _StepHeader(number: 5, title: '결과 확인 및 확정'),
              const SizedBox(height: 8),
              Row(
                children: [
                  _ActionButton(
                    icon: Icons.preview,
                    label: '변환 결과 미리보기',
                    onTap: () async {
                      setState(() { _loading = true; _error = null; });
                      try {
                        _previewResult = await _api.migrationPreview();
                      } catch (e) {
                        _error = e.toString();
                      } finally {
                        if (mounted) setState(() => _loading = false);
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                  _ActionButton(
                    icon: Icons.check_circle_outline,
                    label: '검증 후 확정',
                    color: AppColors.success,
                    onTap: () => _runStep('확정', _api.migrationConfirm),
                  ),
                  const SizedBox(width: 12),
                  _ActionButton(
                    icon: Icons.undo,
                    label: '되돌리기',
                    color: AppColors.error,
                    onTap: () async {
                      final ok = await _confirmDialog(
                          context, '되돌리기', '백업에서 데이터를 복원합니다. 계속하시겠습니까?');
                      if (ok) _runStep('롤백', _api.migrationRollback);
                    },
                  ),
                ],
              ),

              // 미리보기 영역
              if (_previewResult != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text('Turtle 미리보기',
                            style: AppTypography.heading2),
                        const Spacer(),
                        Text(
                          '총 ${_previewResult!['total']}개 트리플',
                          style: AppTypography.caption,
                        ),
                      ]),
                      const SizedBox(height: 8),
                      SelectableText(
                        _previewResult!['turtle_sample'] ?? '',
                        style: AppTypography.mono,
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 40),
            ],
          ),
        ),
        if (_loading)
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  InputDecoration _inputDeco(String label) => InputDecoration(
        labelText: label,
        labelStyle: AppTypography.caption,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
      );

  Future<bool> _confirmDialog(
      BuildContext ctx, String title, String msg) async {
    final r = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: Text(title, style: AppTypography.heading2),
        content: Text(msg, style: AppTypography.body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('취소')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('확인', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    return r ?? false;
  }
}

// ── 공용 위젯 ──────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> lines;
  const _StatusCard(
      {required this.title,
      required this.icon,
      required this.color,
      required this.lines});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(title, style: AppTypography.caption),
            ]),
            const SizedBox(height: 6),
            ...lines.map((l) => Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(l,
                      style: AppTypography.body
                          .copyWith(fontSize: 12)),
                )),
          ],
        ),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  final int number;
  final String title;
  const _StepHeader({required this.number, required this.title});

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

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;
  const _ActionButton(
      {required this.icon,
      required this.label,
      this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return ElevatedButton.icon(
      icon: Icon(icon, size: 14, color: Colors.white),
      label: Text(label,
          style: AppTypography.body.copyWith(color: Colors.white, fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: c,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      onPressed: onTap,
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
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
}

class _AnalyzeResult extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AnalyzeResult(this.data);

  @override
  Widget build(BuildContext context) {
    final tables = data['tables'] as Map? ?? {};
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: tables.entries.map((e) {
          final v = e.value as Map? ?? {};
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${e.key}: ${v['count'] ?? v['total'] ?? '-'}건',
              style: AppTypography.mono,
            ),
          );
        }).toList(),
      ),
    );
  }
}
