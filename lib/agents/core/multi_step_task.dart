// lib/agents/core/multi_step_task.dart
// 멀티스텝 태스크 데이터 모델
// 하나의 태스크는 여러 TaskStep으로 구성되며,
// 각 스텝은 AgentIntent 하나에 대응.

import 'package:uuid/uuid.dart';
import 'agent_intent.dart';
import 'agent_result.dart';

// ── 단계 상태 ────────────────────────────────────────────

enum StepStatus { pending, running, done, failed, skipped }

extension StepStatusLabel on StepStatus {
  String get label {
    switch (this) {
      case StepStatus.pending:  return '대기';
      case StepStatus.running:  return '실행 중';
      case StepStatus.done:     return '완료';
      case StepStatus.failed:   return '실패';
      case StepStatus.skipped:  return '건너뜀';
    }
  }
}

// ── 개별 단계 ────────────────────────────────────────────

class TaskStep {
  /// 이 단계에서 실행할 Intent
  final AgentIntent intent;

  /// 실행 완료 후 채워지는 결과
  AgentResult? result;

  /// 현재 실행 상태
  StepStatus status;

  /// 먼저 완료돼야 하는 단계 인덱스 목록 (의존성)
  final List<int> dependsOn;

  TaskStep({
    required this.intent,
    this.result,
    this.status = StepStatus.pending,
    this.dependsOn = const [],
  });
}

// ── 멀티스텝 태스크 ───────────────────────────────────────

class MultiStepTask {
  /// 태스크 고유 ID
  final String id;

  /// 사용자에게 보여줄 태스크 제목
  final String title;

  /// 실행할 단계 목록
  final List<TaskStep> steps;

  /// 태스크 생성 시각
  final DateTime createdAt;

  /// 태스크 완료 시각 (미완료 시 null)
  DateTime? completedAt;

  bool _cancelled = false;

  MultiStepTask({
    String? id,
    required this.title,
    required this.steps,
    DateTime? createdAt,
    this.completedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  // ── 진행 상태 계산 ──────────────────────────────────────

  int get completedCount =>
      steps.where((s) => s.status == StepStatus.done).length;

  int get totalCount => steps.length;

  /// 0.0~1.0 (done 단계 수 / 전체 단계 수)
  double get progressPercent =>
      totalCount == 0 ? 0.0 : completedCount / totalCount;

  /// 모든 단계가 터미널 상태(done/failed/skipped)이면 true
  bool get isCompleted =>
      steps.isNotEmpty &&
      steps.every((s) =>
          s.status != StepStatus.pending && s.status != StepStatus.running);

  bool get hasFailed => steps.any((s) => s.status == StepStatus.failed);

  List<TaskStep> get failedSteps =>
      steps.where((s) => s.status == StepStatus.failed).toList();

  bool get isCancelled => _cancelled;

  /// 취소: 남은 pending/running 단계를 skipped으로 표시
  void cancel() {
    _cancelled = true;
    for (final step in steps) {
      if (step.status == StepStatus.pending ||
          step.status == StepStatus.running) {
        step.status = StepStatus.skipped;
      }
    }
    completedAt ??= DateTime.now();
  }

  /// 경과 시간 (완료 시각 기준, 미완료면 현재 기준)
  Duration get elapsed =>
      (completedAt ?? DateTime.now()).difference(createdAt);
}
