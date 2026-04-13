// test/agents/core/multi_step_task_test.dart
// MultiStepTask, TaskStep 단위 테스트

import 'package:flutter_test/flutter_test.dart';
import 'package:oral_record_agent/agents/core/agent_intent.dart';
import 'package:oral_record_agent/agents/core/multi_step_task.dart';

AgentIntent _stubIntent([String label = 'test']) => AgentIntent(
      type: IntentType.analyzeRecord,
      rawInput: label,
      params: {'query': label},
      confidence: 0.9,
    );

List<TaskStep> _steps(int n) =>
    List.generate(n, (i) => TaskStep(intent: _stubIntent('step $i')));

void main() {
  // ── TaskStep ──────────────────────────────────────────

  group('TaskStep', () {
    test('초기 상태는 pending', () {
      final step = TaskStep(intent: _stubIntent());
      expect(step.status, StepStatus.pending);
      expect(step.result, isNull);
    });

    test('dependsOn 기본값은 빈 리스트', () {
      final step = TaskStep(intent: _stubIntent());
      expect(step.dependsOn, isEmpty);
    });

    test('statusLabel 반환 확인', () {
      final step = TaskStep(intent: _stubIntent());
      expect(step.status.label, '대기');
      step.status = StepStatus.running;
      expect(step.status.label, '실행 중');
      step.status = StepStatus.done;
      expect(step.status.label, '완료');
      step.status = StepStatus.failed;
      expect(step.status.label, '실패');
      step.status = StepStatus.skipped;
      expect(step.status.label, '건너뜀');
    });
  });

  // ── MultiStepTask 생성 ────────────────────────────────

  group('MultiStepTask 생성', () {
    test('id 자동 생성', () {
      final a = MultiStepTask(title: 'A', steps: []);
      final b = MultiStepTask(title: 'B', steps: []);
      expect(a.id, isNotEmpty);
      expect(a.id, isNot(equals(b.id)));
    });

    test('createdAt 자동 설정', () {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      final task = MultiStepTask(title: 'T', steps: []);
      expect(task.createdAt.isAfter(before), isTrue);
    });
  });

  // ── 진행률 계산 ───────────────────────────────────────

  group('progressPercent', () {
    test('빈 steps → 0.0', () {
      final task = MultiStepTask(title: 'empty', steps: []);
      expect(task.progressPercent, 0.0);
    });

    test('2/5 완료 → 0.4', () {
      final steps = _steps(5);
      final task = MultiStepTask(title: 'T', steps: steps);
      steps[0].status = StepStatus.done;
      steps[1].status = StepStatus.done;
      expect(task.completedCount, 2);
      expect(task.progressPercent, closeTo(0.4, 0.001));
    });

    test('전체 완료 → 1.0', () {
      final steps = _steps(3);
      final task = MultiStepTask(title: 'T', steps: steps);
      for (final s in steps) { s.status = StepStatus.done; }
      expect(task.progressPercent, 1.0);
    });

    test('failed 단계는 completedCount에 포함 안 됨', () {
      final steps = _steps(4);
      final task = MultiStepTask(title: 'T', steps: steps);
      steps[0].status = StepStatus.done;
      steps[1].status = StepStatus.failed;
      expect(task.completedCount, 1);
      expect(task.progressPercent, closeTo(0.25, 0.001));
    });
  });

  // ── isCompleted ───────────────────────────────────────

  group('isCompleted', () {
    test('모든 단계 done → true', () {
      final steps = _steps(3);
      for (final s in steps) { s.status = StepStatus.done; }
      final task = MultiStepTask(title: 'T', steps: steps);
      expect(task.isCompleted, isTrue);
    });

    test('pending 단계 남아 있으면 false', () {
      final steps = _steps(3);
      steps[0].status = StepStatus.done;
      steps[1].status = StepStatus.done;
      // steps[2] remains pending
      final task = MultiStepTask(title: 'T', steps: steps);
      expect(task.isCompleted, isFalse);
    });

    test('running 단계 있으면 false', () {
      final steps = _steps(2);
      steps[0].status = StepStatus.done;
      steps[1].status = StepStatus.running;
      final task = MultiStepTask(title: 'T', steps: steps);
      expect(task.isCompleted, isFalse);
    });

    test('done+failed+skipped 혼합 → true', () {
      final steps = _steps(3);
      steps[0].status = StepStatus.done;
      steps[1].status = StepStatus.failed;
      steps[2].status = StepStatus.skipped;
      final task = MultiStepTask(title: 'T', steps: steps);
      expect(task.isCompleted, isTrue);
    });

    test('빈 steps → false', () {
      final task = MultiStepTask(title: 'empty', steps: []);
      expect(task.isCompleted, isFalse);
    });
  });

  // ── hasFailed / failedSteps ───────────────────────────

  group('hasFailed', () {
    test('failed 단계 있으면 true', () {
      final steps = _steps(3);
      steps[1].status = StepStatus.failed;
      final task = MultiStepTask(title: 'T', steps: steps);
      expect(task.hasFailed, isTrue);
      expect(task.failedSteps.length, 1);
    });

    test('모두 done이면 false', () {
      final steps = _steps(3);
      for (final s in steps) { s.status = StepStatus.done; }
      final task = MultiStepTask(title: 'T', steps: steps);
      expect(task.hasFailed, isFalse);
      expect(task.failedSteps, isEmpty);
    });
  });

  // ── cancel() ─────────────────────────────────────────

  group('cancel()', () {
    test('pending/running → skipped, done 유지', () {
      final steps = _steps(4);
      final task = MultiStepTask(title: 'T', steps: steps);
      steps[0].status = StepStatus.done;
      steps[1].status = StepStatus.running;
      // steps[2], steps[3] remain pending

      task.cancel();

      expect(task.isCancelled, isTrue);
      expect(steps[0].status, StepStatus.done);    // 변경 없음
      expect(steps[1].status, StepStatus.skipped); // running → skipped
      expect(steps[2].status, StepStatus.skipped); // pending → skipped
      expect(steps[3].status, StepStatus.skipped); // pending → skipped
    });

    test('cancel 후 completedAt 설정됨', () {
      final task = MultiStepTask(title: 'T', steps: _steps(2));
      expect(task.completedAt, isNull);
      task.cancel();
      expect(task.completedAt, isNotNull);
    });

    test('cancel 후 isCancelled = true', () {
      final task = MultiStepTask(title: 'T', steps: _steps(2));
      expect(task.isCancelled, isFalse);
      task.cancel();
      expect(task.isCancelled, isTrue);
    });

    test('stopOnFirstFailure 시뮬레이션: failed 이후 pending → skipped', () {
      final steps = _steps(5);
      final task = MultiStepTask(title: 'T', steps: steps);
      steps[0].status = StepStatus.done;
      steps[1].status = StepStatus.failed;
      // 이후 단계 수동 skipped (AgentCore의 stopOnFirstFailure 동작)
      steps[2].status = StepStatus.skipped;
      steps[3].status = StepStatus.skipped;
      steps[4].status = StepStatus.skipped;

      expect(task.hasFailed, isTrue);
      expect(task.failedSteps.length, 1);
      expect(task.isCompleted, isTrue);
    });
  });

  // ── elapsed ──────────────────────────────────────────

  group('elapsed', () {
    test('completedAt 설정 후 elapsed 계산', () {
      final created = DateTime.now().subtract(const Duration(seconds: 5));
      final completed = created.add(const Duration(seconds: 3));
      final task = MultiStepTask(
        title: 'T',
        steps: [],
        createdAt: created,
      );
      task.completedAt = completed;
      expect(task.elapsed.inSeconds, 3);
    });
  });
}
