// 파일 목적: 통합 검증 엔진 (모든 Phase 체크리스트 통합)

import 'phase1_checklist.dart';
import 'phase2_checklist.dart';
import 'phase3_checklist.dart';
import 'phase4_checklist.dart';

class AutomatedChecklistEngine {
  /// 자율 감시 체크리스트 엔진
  /// 목적: 모든 Phase의 검증 항목을 일괄 관리 및 보고
  /// 생성일: 2024-03-23

  static void printAllChecklistReports() {
    print('\n${'═' * 70}');
    print('구술기록관리 에이전트 - 전체 자율 감시 체크리스트 보고서'.padLeft(50));
    print('생성일: 2024-03-23');
    print('${'═' * 70}\n');

    print(Phase1CheckList.generateReport());
    print('\n');
    print(Phase2CheckList.generateReport());
    print('\n');
    print(Phase3CheckList.generateReport());
    print('\n');
    print(Phase4CheckList.generateReport());

    print('\n${'═' * 70}');
    print('종합 통계'.padLeft(50));
    print('═' * 70);
    print('Phase 1 체크리스트: ${_count(Phase1CheckList.summary)} 항목');
    print('Phase 2 체크리스트: ${_count(Phase2CheckList.summary)} 항목');
    print('Phase 3 체크리스트: ${_count(Phase3CheckList.summary)} 항목');
    print('Phase 4 체크리스트: ${_count(Phase4CheckList.summary)} 항목');
    print('─' * 70);
    final total = _count(Phase1CheckList.summary) +
        _count(Phase2CheckList.summary) +
        _count(Phase3CheckList.summary) +
        _count(Phase4CheckList.summary);
    print('전체 항목: $total 개 ✓');
    print('${'═' * 70}\n');
  }

  static int _count(Map<String, List<String>> summary) =>
      summary.values.fold(0, (sum, items) => sum + items.length);

  static Map<String, int> getPhaseChecklistCounts() {
    return {
      'Phase 1': _count(Phase1CheckList.summary),
      'Phase 2': _count(Phase2CheckList.summary),
      'Phase 3': _count(Phase3CheckList.summary),
      'Phase 4': _count(Phase4CheckList.summary),
    };
  }

  static int getTotalChecklistItems() {
    return getPhaseChecklistCounts().values.reduce((a, b) => a + b);
  }

  static List<String> getPhase1Items() =>
      Phase1CheckList.summary.values.expand((i) => i).toList();

  static List<String> getPhase2Items() =>
      Phase2CheckList.summary.values.expand((i) => i).toList();

  static List<String> getPhase3Items() =>
      Phase3CheckList.summary.values.expand((i) => i).toList();

  static List<String> getPhase4Items() =>
      Phase4CheckList.summary.values.expand((i) => i).toList();
}

/// 사용 예시:
/// ```dart
/// AutomatedChecklistEngine.printAllChecklistReports();
///
/// // 각 Phase별 항목 조회
/// final counts = AutomatedChecklistEngine.getPhaseChecklistCounts();
/// print('Phase 1: ${counts['Phase 1']} 항목');
///
/// // 전체 항목 수
/// final total = AutomatedChecklistEngine.getTotalChecklistItems();
/// print('전체: $total 항목');
/// ```
