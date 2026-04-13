import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ontology_provider.dart';
import '../../theme/app_colors.dart';
import 'ontology_working_tab.dart';
import 'ontology_standard_tab.dart';
import 'ontology_confirmed_tab.dart';

// ── 온톨로지 관리 화면 — 3탭 구조 ──────────────────────────────────────────────
//
//  [작업 중]  Draft 버전 목록 + 종합
//  [표준화]   standard_tag 있는 Draft + 표준 태그 편집
//  [확정]     Confirmed(활성) + Archived 섹션

class OntologyListScreen extends ConsumerStatefulWidget {
  const OntologyListScreen({super.key});

  @override
  ConsumerState<OntologyListScreen> createState() => _OntologyListScreenState();
}

class _OntologyListScreenState extends ConsumerState<OntologyListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      // 탭 전환 시 선택된 버전 초기화
      if (_tabCtrl.indexIsChanging) {
        ref.read(ontologyProvider.notifier).clearSelection();
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TabBar(
                  controller: _tabCtrl,
                  tabs: const [
                    Tab(text: '작업 중'),
                    Tab(text: '표준화'),
                    Tab(text: '확정'),
                  ],
                ),
                const Divider(height: 1, thickness: 1, color: AppColors.border),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                OntologyWorkingTab(),
                OntologyStandardTab(),
                OntologyConfirmedTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
