import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/triple_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../services/rdf_api_service.dart';
import 'triple_step1_extract.dart';
import 'triple_step2_review.dart';
import 'triple_step3_list.dart';

class TripleScreen extends ConsumerStatefulWidget {
  const TripleScreen({super.key});

  @override
  ConsumerState<TripleScreen> createState() => _TripleScreenState();
}

class _TripleScreenState extends ConsumerState<TripleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  // 프로그래밍 방식 탭 전환 중 플래그 — _onTabChanged가 provider step을 되돌리지 않도록
  bool _programmaticChange = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    // addListener 제거: animateTo 호출 시 notifyListeners()가 즉시 발동해
    // indexIsChanging 체크 타이밍 레이스로 setStep(oldIndex)가 호출되는 버그 방지.
    // 사용자 탭 클릭은 TabBar.onTap에서 처리.
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // provider step 변경 → 탭 자동 이동
    ref.listen(tripleWorkProvider.select((s) => s.currentStep), (prev, step) {
      if (_tabCtrl.index != step) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _tabCtrl.index != step) {
            _programmaticChange = true;
            _tabCtrl.animateTo(step);
            // 애니메이션 완료 후 플래그 해제
            Future.delayed(const Duration(milliseconds: 400), () {
              _programmaticChange = false;
            });
          }
        });
      }
    });

    final pending =
        ref.watch(tripleWorkProvider.select((s) => s.pendingTriples.length));

    return Scaffold(
      body: Column(
        children: [
          // ── 탭바 ─────────────────────────────────────────────────────────
          Container(
            color: AppColors.surface,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TabBar(
                        controller: _tabCtrl,
                        onTap: (index) {
                          if (!_programmaticChange) {
                            ref.read(tripleWorkProvider.notifier).setStep(index);
                          }
                        },
                        tabs: [
                          const Tab(text: 'Step 1  추출 설정'),
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Step 2  검토'),
                                if (pending > 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text('$pending',
                                        style: AppTypography.badge.copyWith(
                                            color: Colors.white)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Tab(text: 'Step 3  저장된 트리플'),
                        ],
                      ),
                    ),
                    _RdfExportButton(api: ref.read(rdfApiProvider)),
                    const SizedBox(width: 8),
                  ],
                ),
                const Divider(height: 1, thickness: 1,
                    color: AppColors.border),
              ],
            ),
          ),
          // ── 탭 본문 ───────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                TripleStep1Extract(),
                TripleStep2Review(),
                TripleStep3List(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RdfExportButton extends StatelessWidget {
  final RdfApiService api;
  const _RdfExportButton({required this.api});

  static const _formats = [
    ('turtle', 'Turtle (.ttl)'),
    ('json-ld', 'JSON-LD (.jsonld)'),
    ('xml', 'OWL/XML (.owl)'),
  ];

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'RDF 내보내기',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.download_outlined, size: 14,
                color: AppColors.secondary),
            const SizedBox(width: 4),
            const Text('RDF ▼',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
      itemBuilder: (_) => _formats
          .map((f) => PopupMenuItem(
                value: f.$1,
                child: Text(f.$2, style: const TextStyle(fontSize: 12)),
              ))
          .toList(),
      onSelected: (fmt) => api.exportAndSave(
        context: context,
        endpoint: '/rdf/export/triples',
        format: fmt,
        prefix: 'triples',
      ),
    );
  }
}
