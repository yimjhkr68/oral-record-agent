import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/triple_provider.dart';
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

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabCtrl.indexIsChanging) return;
    // 탭 직접 클릭 시 provider step도 동기화
    ref.read(tripleWorkProvider.notifier).setStep(_tabCtrl.index);
  }

  @override
  void dispose() {
    _tabCtrl.removeListener(_onTabChanged);
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // provider step 변경 → 탭 자동 이동 (Step 1→2: 추출 완료 후, Step 2→3: 확정 저장 후)
    // addPostFrameCallback: build 도중 animateTo 호출 방지 (블랙스크린 버그 수정)
    ref.listen(tripleWorkProvider.select((s) => s.currentStep), (_, step) {
      if (_tabCtrl.index != step) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _tabCtrl.index != step) {
            _tabCtrl.animateTo(step);
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
          Material(
            color: Theme.of(context).colorScheme.surface,
            elevation: 1,
            child: TabBar(
              controller: _tabCtrl,
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
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('$pending',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11)),
                        ),
                      ],
                    ],
                  ),
                ),
                const Tab(text: 'Step 3  저장된 트리플'),
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
