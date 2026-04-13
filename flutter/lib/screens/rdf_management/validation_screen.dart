import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../services/rdf_api_service.dart';

class ValidationScreen extends ConsumerStatefulWidget {
  const ValidationScreen({super.key});
  @override
  ConsumerState<ValidationScreen> createState() => _ValidationScreenState();
}

class _ValidationScreenState extends ConsumerState<ValidationScreen> {
  Map<String, dynamic>? _results;
  bool _loading = false;
  String? _error;

  static const _checkLabels = {
    'structure':   ('구조 검증', Icons.account_tree_outlined),
    'labels':      ('레이블 검증', Icons.label_outlined),
    'mappings':    ('매핑 검증', Icons.link),
    'duplicates':  ('중복 검증', Icons.filter_none),
    'consistency': ('일관성 검증', Icons.verified_outlined),
  };

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  RdfApiService get _api => ref.read(rdfApiProvider);

  Future<void> _loadResults() async {
    setState(() => _loading = true);
    try {
      _results = await _api.validateResults();
    } catch (_) {
      // 결과 없으면 null 유지
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runValidation() async {
    setState(() { _loading = true; _error = null; });
    try {
      _results = await _api.validateRun();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _results?['summary'] as Map? ?? {};
    final checks = _results?['checks'] as Map? ?? {};
    final readiness = (summary['readiness'] as num?)?.toInt() ?? 0;
    final passed = (summary['passed'] as num?)?.toInt() ?? 0;
    final warnings = (summary['warnings'] as num?)?.toInt() ?? 0;
    final errors = (summary['errors'] as num?)?.toInt() ?? 0;
    final triples = (_results?['triple_count'] as num?)?.toInt() ?? 0;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 실행 버튼 ──────────────────────────────────────────────
              Row(
                children: [
                  Text('온톨로지 품질 검증', style: AppTypography.heading2),
                  const Spacer(),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow, size: 14),
                    label: const Text('전체 검증 실행'),
                    onPressed: _runValidation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      textStyle: AppTypography.caption,
                    ),
                  ),
                ],
              ),

              if (_error != null) ...[
                const SizedBox(height: 8),
                _ErrorBanner(_error!),
              ],

              const SizedBox(height: 16),

              // ── 요약 카드 4개 ──────────────────────────────────────────
              if (_results != null) ...[
                Row(
                  children: [
                    _SummaryCard(
                        label: '통과', value: '$passed',
                        color: AppColors.success,
                        icon: Icons.check_circle_outline),
                    const SizedBox(width: 10),
                    _SummaryCard(
                        label: '경고', value: '$warnings',
                        color: AppColors.warning,
                        icon: Icons.warning_amber_outlined),
                    const SizedBox(width: 10),
                    _SummaryCard(
                        label: '오류', value: '$errors',
                        color: AppColors.error,
                        icon: Icons.error_outline),
                    const SizedBox(width: 10),
                    _SummaryCard(
                        label: '트리플', value: '$triples',
                        color: AppColors.info,
                        icon: Icons.share_outlined),
                  ],
                ),
                const SizedBox(height: 20),

                // ── 항목별 결과 ─────────────────────────────────────────
                Text('검증 항목별 결과', style: AppTypography.heading2),
                const SizedBox(height: 8),
                ..._checkLabels.entries.map((e) {
                  final check = Map<String, dynamic>.from(checks[e.key] as Map? ?? {});
                  return _CheckItem(
                    key: ValueKey(e.key),
                    icon: e.value.$2,
                    label: e.value.$1,
                    check: check,
                  );
                }),

                const SizedBox(height: 20),

                // ── 준비도 ─────────────────────────────────────────────
                Row(children: [
                  Text('공표 준비도', style: AppTypography.heading2),
                  const SizedBox(width: 12),
                  Text('$readiness%',
                      style: AppTypography.heading2.copyWith(
                          color: _readinessColor(readiness))),
                  const SizedBox(width: 12),
                  if (readiness < 80)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.4)),
                      ),
                      child: Text('공표 탭 비활성',
                          style: AppTypography.badge
                              .copyWith(color: AppColors.error)),
                    ),
                ]),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: readiness / 100,
                    minHeight: 12,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        _readinessColor(readiness)),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  readiness == 100
                      ? '공표 가능합니다'
                      : readiness >= 80
                          ? '경고·오류 해결 후 공표 권장'
                          : '오류 수정 필요. 공표 불가',
                  style: AppTypography.caption
                      .copyWith(color: _readinessColor(readiness)),
                ),
              ] else ...[
                const SizedBox(height: 40),
                Center(
                  child: Column(
                    children: [
                      const Icon(Icons.verified_outlined,
                          size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      Text('검증 결과가 없습니다.',
                          style: AppTypography.body),
                      const SizedBox(height: 4),
                      Text('마이그레이션 → 확정 후 검증을 실행하세요.',
                          style: AppTypography.caption),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
        if (_loading) const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  Color _readinessColor(int r) {
    if (r == 100) return AppColors.success;
    if (r >= 80) return AppColors.warning;
    return AppColors.error;
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _SummaryCard(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(value,
                style: AppTypography.heading2.copyWith(color: color)),
            Text(label, style: AppTypography.caption),
          ],
        ),
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Map<String, dynamic> check;
  const _CheckItem(
      {super.key,
      required this.icon,
      required this.label,
      required this.check});

  @override
  Widget build(BuildContext context) {
    final status = check['status'] as String? ?? 'skip';
    final warnings = (check['warnings'] as List? ?? []).cast<String>();
    final errors = (check['errors'] as List? ?? []).cast<String>();

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'pass':
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle;
        break;
      case 'error':
        statusColor = AppColors.error;
        statusIcon = Icons.cancel;
        break;
      case 'warning':
        statusColor = AppColors.warning;
        statusIcon = Icons.warning_amber;
        break;
      default:
        statusColor = AppColors.textMuted;
        statusIcon = Icons.remove_circle_outline;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(statusIcon, size: 16, color: statusColor),
            const SizedBox(width: 8),
            Icon(icon, size: 14, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Text(label, style: AppTypography.body.copyWith(fontSize: 13)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(status,
                  style: AppTypography.badge.copyWith(color: statusColor)),
            ),
            if (check['class_count'] != null) ...[
              const Spacer(),
              Text('${check['class_count']}개 클래스',
                  style: AppTypography.caption),
            ],
            if (check['total'] != null) ...[
              const Spacer(),
              Text('${check['with_ko'] ?? 0}/${check['total']}',
                  style: AppTypography.caption),
            ],
          ]),
          if (warnings.isNotEmpty || errors.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...errors.take(3).map((e) => _IssueRow(e, AppColors.error)),
            ...warnings.take(3).map((w) => _IssueRow(w, AppColors.warning)),
          ],
        ],
      ),
    );
  }
}

class _IssueRow extends StatelessWidget {
  final String text;
  final Color color;
  const _IssueRow(this.text, this.color);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, left: 24),
      child: Text(
        '• $text',
        style: AppTypography.caption.copyWith(color: color),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
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
          border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline, size: 14, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: AppTypography.body.copyWith(color: AppColors.error))),
        ]),
      );
}
