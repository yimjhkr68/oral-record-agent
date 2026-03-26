// test/agents/core/task_planner_test.dart
// TaskPlanner 단위 테스트

import 'package:flutter_test/flutter_test.dart';
import 'package:oral_record_agent/agents/core/agent_intent.dart';
import 'package:oral_record_agent/agents/core/multi_step_task.dart';
import 'package:oral_record_agent/agents/core/task_planner.dart';

void main() {
  late TaskPlanner planner;

  setUp(() {
    // recordRepo = null → 스텁 모드 (Hive 불필요)
    planner = TaskPlanner();
  });

  // ── 단일 스텝 감지 ────────────────────────────────────

  group('단일 스텝 (isMultiStep = false)', () {
    test('"interview.mp3 등록해줘" → steps 1개', () async {
      final task = await planner.plan('interview.mp3 등록해줘');
      expect(task.steps.length, 1);
      expect(task.steps.first.intent.type, IntentType.registerRecord);
    });

    test('"전체 기록 CSV로 내보내줘" → steps 1개 (내보내줘는 actionKeyword 아님)', () async {
      final task = await planner.plan('전체 기록 CSV로 내보내줘');
      // '전체'는 multiKeyword, but '내보내줘' ≠ actionKeyword → single
      expect(task.steps.length, 1);
    });

    test('"기록 검색해줘" → steps 1개', () async {
      final task = await planner.plan('기록 검색해줘');
      expect(task.steps.length, 1);
    });

    test('단일 태스크는 intent.typeLabel이 title', () async {
      final task = await planner.plan('interview.mp3 등록해줘');
      expect(task.title, isNotEmpty);
    });
  });

  // ── 멀티스텝 감지 ─────────────────────────────────────

  group('멀티스텝 (isMultiStep = true)', () {
    test('"이번 달 기록 전부 정리해줘" → steps > 1', () async {
      final task = await planner.plan('이번 달 기록 전부 정리해줘');
      expect(task.steps.length, greaterThan(1));
    });

    test('"올해 기록 전체 분석해줘" → steps > 1', () async {
      final task = await planner.plan('올해 기록 전체 분석해줘');
      expect(task.steps.length, greaterThan(1));
    });

    test('"모든 파일 일괄 처리해줘" → steps > 1', () async {
      final task = await planner.plan('모든 파일 일괄 처리해줘');
      expect(task.steps.length, greaterThan(1));
    });

    test('"지난달 기록 전부 정리해줘" → steps > 1', () async {
      final task = await planner.plan('지난달 기록 전부 정리해줘');
      expect(task.steps.length, greaterThan(1));
    });

    test('스텁 모드에서 멀티스텝 → steps = 3 (샘플 고정)', () async {
      final task = await planner.plan('이번 달 기록 전부 정리해줘');
      expect(task.steps.length, 3);
    });

    test('멀티스텝 각 단계는 analyzeRecord Intent', () async {
      final task = await planner.plan('이번 달 기록 모두 정리해줘');
      for (final step in task.steps) {
        expect(step.intent.type, IntentType.analyzeRecord);
      }
    });

    test('멀티스텝 태스크 title은 비어 있지 않음', () async {
      final task = await planner.plan('이번 달 기록 전부 정리해줘');
      expect(task.title, isNotEmpty);
    });

    test('멀티스텝 태스크 title에서 "전부" 제거됨', () async {
      final task = await planner.plan('이번 달 기록 전부 정리해줘');
      expect(task.title, isNot(contains('전부')));
    });
  });

  // ── 진행률 계산 (MultiStepTask 통합) ─────────────────

  group('진행률 계산', () {
    test('2/5 완료 → progressPercent ≈ 0.4', () async {
      final task = await planner.plan('이번 달 기록 전부 정리해줘');
      // 스텁 모드 → steps = 3. 1개만 done으로 변경
      task.steps[0].status = StepStatus.done;
      expect(task.progressPercent, closeTo(1 / 3, 0.001));
    });

    test('전체 done → progressPercent = 1.0', () async {
      final task = await planner.plan('이번 달 기록 전부 정리해줘');
      for (final s in task.steps) {
        s.status = StepStatus.done;
      }
      expect(task.progressPercent, 1.0);
    });
  });

  // ── stopOnFirstFailure 시뮬레이션 ────────────────────

  group('stopOnFirstFailure 동작', () {
    test('첫 실패 후 나머지 skipped → hasFailed=true, isCompleted=true', () async {
      final task = await planner.plan('이번 달 기록 전부 정리해줘');
      // steps = 3
      task.steps[0].status = StepStatus.done;
      task.steps[1].status = StepStatus.failed;
      task.steps[2].status = StepStatus.skipped;

      expect(task.hasFailed, isTrue);
      expect(task.failedSteps.length, 1);
      expect(task.isCompleted, isTrue);
    });
  });

  // ── cancelTask 동작 ───────────────────────────────────

  group('cancelTask', () {
    test('cancel → pending/running → skipped', () async {
      final task = await planner.plan('이번 달 기록 전부 정리해줘');
      // steps = 3, 1개 done 후 cancel
      task.steps[0].status = StepStatus.done;
      task.cancel();

      expect(task.isCancelled, isTrue);
      expect(task.steps[0].status, StepStatus.done);
      expect(task.steps[1].status, StepStatus.skipped);
      expect(task.steps[2].status, StepStatus.skipped);
    });

    test('cancel 후 isCompleted = true', () async {
      final task = await planner.plan('이번 달 기록 전부 정리해줘');
      task.cancel();
      expect(task.isCompleted, isTrue);
    });
  });

  // ── 태스크 ID 고유성 ──────────────────────────────────

  group('태스크 ID', () {
    test('서로 다른 태스크는 다른 ID', () async {
      final a = await planner.plan('이번 달 기록 전부 정리해줘');
      final b = await planner.plan('이번 달 기록 전부 정리해줘');
      expect(a.id, isNot(equals(b.id)));
    });
  });
}
