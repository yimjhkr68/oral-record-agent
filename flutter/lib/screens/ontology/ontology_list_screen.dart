import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'ontology_working_tab.dart';
import 'ontology_standard_tab.dart';
import 'ontology_confirmed_tab.dart';

// ── 온톨로지 관리 화면 — 3탭 구조 ──────────────────────────────────────────────
//
//  [작업 중]  Draft 버전 목록 + 종합
//  [표준화]   standard_tag 있는 Draft + 표준 태그 편집
//  [확정]     Confirmed(활성) + Archived 섹션

class OntologyListScreen extends StatelessWidget {
  const OntologyListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: Column(
          children: [
            Container(
              color: AppColors.surface,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TabBar(
                    tabs: [
                      Tab(text: '작업 중'),
                      Tab(text: '표준화'),
                      Tab(text: '확정'),
                    ],
                  ),
                  Divider(height: 1, thickness: 1, color: AppColors.border),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                physics: NeverScrollableScrollPhysics(),
                children: [
                  OntologyWorkingTab(),
                  OntologyStandardTab(),
                  OntologyConfirmedTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
