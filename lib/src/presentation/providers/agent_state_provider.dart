// lib/src/presentation/providers/agent_state_provider.dart
// AgentCore 실행 상태를 Riverpod StateNotifier로 관리
//
// 사용 예:
//   final state = ref.watch(agentStateProvider);
//   ref.read(agentStateProvider.notifier).handle('interview.mp3 등록해줘');

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../agents/core/agent_core.dart';
import '../../../agents/core/agent_result.dart';
import '../../../agents/core/intent_parser.dart';
import '../../../agents/core/multi_step_task.dart';
import '../../../agents/core/task_planner.dart';
import '../../../agents/tools/tool_registry.dart';
import '../../../agents/tools/tool_services.dart';
import '../../data/repositories/record_repository.dart';
import '../../data/repositories/narrator_repository.dart';
import '../../data/repositories/repository_provider.dart';
import 'settings_provider.dart';

// ─── 로그 항목 ────────────────────────────────────────

class AgentLogEntry {
  final String step;
  final String detail;
  final DateTime timestamp;
  final bool isError;

  AgentLogEntry({
    required this.step,
    required this.detail,
    DateTime? timestamp,
    this.isError = false,
  }) : timestamp = timestamp ?? DateTime.now();
}

// ─── 에이전트 처리 상태 (agent_result.dart의 AgentStatus와 구분) ──

enum AgentProcessStatus { idle, thinking, executing, pendingReview, error }

// ─── 상태 클래스 ──────────────────────────────────────

class AgentState {
  /// 현재 처리 상태
  final AgentProcessStatus status;

  /// "전사 중..." 같은 현재 단계 메시지
  final String? currentTask;

  /// "summarize" 같은 현재 툴 이름
  final String? currentStep;

  /// 완료된 단계 수
  final int stepProgress;

  /// 전체 단계 수
  final int totalSteps;

  /// 실행 로그 (UI에 스트리밍 표시)
  final List<AgentLogEntry> agentLog;

  /// 마지막 실행 결과
  final AgentResult? lastResult;

  /// 사용자 검토 대기 중인 결과
  final AgentResult? pendingReview;

  /// 에러 메시지
  final String? errorMessage;

  /// 현재 진행 중인 멀티스텝 태스크
  final MultiStepTask? currentMultiTask;

  /// 완료된 태스크 히스토리 (최대 10개)
  final List<MultiStepTask> taskHistory;

  const AgentState({
    this.status = AgentProcessStatus.idle,
    this.currentTask,
    this.currentStep,
    this.stepProgress = 0,
    this.totalSteps = 0,
    this.agentLog = const [],
    this.lastResult,
    this.pendingReview,
    this.errorMessage,
    this.currentMultiTask,
    this.taskHistory = const [],
  });

  AgentState copyWith({
    AgentProcessStatus? status,
    String? currentTask,
    String? currentStep,
    int? stepProgress,
    int? totalSteps,
    List<AgentLogEntry>? agentLog,
    AgentResult? lastResult,
    AgentResult? pendingReview,
    String? errorMessage,
    MultiStepTask? currentMultiTask,
    List<MultiStepTask>? taskHistory,
    bool clearPendingReview = false,
    bool clearCurrentTask = false,
    bool clearErrorMessage = false,
    bool clearCurrentMultiTask = false,
  }) {
    return AgentState(
      status: status ?? this.status,
      currentTask: clearCurrentTask ? null : (currentTask ?? this.currentTask),
      currentStep: clearCurrentTask ? null : (currentStep ?? this.currentStep),
      stepProgress: stepProgress ?? this.stepProgress,
      totalSteps: totalSteps ?? this.totalSteps,
      agentLog: agentLog ?? this.agentLog,
      lastResult: lastResult ?? this.lastResult,
      pendingReview: clearPendingReview ? null : (pendingReview ?? this.pendingReview),
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      currentMultiTask: clearCurrentMultiTask ? null : (currentMultiTask ?? this.currentMultiTask),
      taskHistory: taskHistory ?? this.taskHistory,
    );
  }
}

// ─── StateNotifier ────────────────────────────────────

class AgentStateNotifier extends StateNotifier<AgentState> {
  final Ref _ref;

  AgentStateNotifier(this._ref) : super(const AgentState());

  // ── 공개 API ─────────────────────────────────────

  /// 사용자 자연어 입력 처리
  /// IntentParser → AgentCore 순서로 실행
  Future<void> handle(String userInput) async {
    state = state.copyWith(
      status: AgentProcessStatus.thinking,
      clearCurrentTask: true,
      clearErrorMessage: true,
      agentLog: [],
    );

    try {
      // 1단계: IntentParser로 의도 파악
      final settings = _ref.read(settingsProvider);
      final apiKey = settings.apiKey.isEmpty ? null : settings.apiKey;

      final parser = IntentParser(claudeApiKey: apiKey);
      final intent = await parser.parse(userInput);

      _addLog('분석', '의도: ${intent.typeLabel} (${(intent.confidence * 100).toInt()}%)');

      // 2단계: 서비스 주입 (Hive 미초기화 환경에서는 null 처리)
      RecordRepository? recordRepo;
      NarratorRepository? narratorRepo;
      try {
        recordRepo = await _ref.read(recordRepositoryProvider.future);
        narratorRepo = await _ref.read(narratorRepositoryProvider.future);
      } catch (_) {
        // Hive 미초기화 (테스트/미리보기) → null 유지, 스텁 모드로 동작
      }

      // 3단계: AgentCore 실행 (onProgress로 실시간 상태 업데이트)
      // 레포 둘 다 null(Hive 미초기화) → 스텁 레지스트리로 안전하게 폴백
      final ToolRegistry toolRegistry;
      if (recordRepo == null && narratorRepo == null) {
        toolRegistry = ToolRegistry.standard();
      } else {
        final services = ToolServices(
          claudeApiKey: apiKey,
          pythonPath: settings.pythonPath,
          whisperModel: settings.whisperModel,
          transcriptionLanguage: settings.transcriptionLanguage,
          recordRepo: recordRepo,
          narratorRepo: narratorRepo,
        );
        toolRegistry = ToolRegistry.withServices(services);
      }

      final core = AgentCore(
        claudeApiKey: settings.apiKey,
        toolRegistry: toolRegistry,
        onProgress: (step, detail) {
          _addLog(step, detail);
          state = state.copyWith(
            status: AgentProcessStatus.executing,
            currentStep: step,
            currentTask: detail,
          );
        },
      );

      final result = await core.handle(intent);

      // 4단계: 결과 반영
      _applyResult(result);
    } catch (e) {
      _addLog('오류', '$e', isError: true);
      state = state.copyWith(
        status: AgentProcessStatus.error,
        errorMessage: '$e',
        clearCurrentTask: true,
      );
    }
  }

  /// TaskPlanner로 단일/멀티 판단 후 적절한 경로로 실행
  /// 기존 handle()과 달리 멀티스텝도 처리 가능
  Future<void> handleInput(String userInput) async {
    state = state.copyWith(
      status: AgentProcessStatus.thinking,
      clearCurrentTask: true,
      clearErrorMessage: true,
      clearCurrentMultiTask: true,
      agentLog: [],
    );

    try {
      final settings = _ref.read(settingsProvider);
      final apiKey = settings.apiKey.isEmpty ? null : settings.apiKey;

      RecordRepository? recordRepo;
      NarratorRepository? narratorRepo;
      try {
        recordRepo = await _ref.read(recordRepositoryProvider.future);
        narratorRepo = await _ref.read(narratorRepositoryProvider.future);
      } catch (_) {}

      // 1단계: TaskPlanner로 단일/멀티 판단
      final planner = TaskPlanner(claudeApiKey: apiKey, recordRepo: recordRepo);
      final task = await planner.plan(userInput);

      if (task.steps.length > 1) {
        _addLog('분석', '멀티스텝 태스크: ${task.steps.length}개 단계 — ${task.title}');
      } else {
        final intent = task.steps.first.intent;
        _addLog('분석', '의도: ${intent.typeLabel} (${(intent.confidence * 100).toInt()}%)');
      }

      // 2단계: ToolRegistry 구성
      final ToolRegistry toolRegistry;
      if (recordRepo == null && narratorRepo == null) {
        toolRegistry = ToolRegistry.standard();
      } else {
        final services = ToolServices(
          claudeApiKey: apiKey,
          pythonPath: settings.pythonPath,
          whisperModel: settings.whisperModel,
          transcriptionLanguage: settings.transcriptionLanguage,
          recordRepo: recordRepo,
          narratorRepo: narratorRepo,
        );
        toolRegistry = ToolRegistry.withServices(services);
      }

      final core = AgentCore(
        claudeApiKey: settings.apiKey,
        toolRegistry: toolRegistry,
        onProgress: (step, detail) {
          _addLog(step, detail);
          state = state.copyWith(
            status: AgentProcessStatus.executing,
            currentStep: step,
            currentTask: detail,
          );
        },
      );

      if (task.steps.length == 1) {
        // 단일 스텝: 기존 경로 (이미 파싱된 intent 재사용)
        final result = await core.handle(task.steps.first.intent);
        _applyResult(result);
      } else {
        // 멀티스텝 경로
        state = state.copyWith(
          currentMultiTask: task,
          status: AgentProcessStatus.executing,
        );

        await core.handleMultiStep(
          task,
          onStepComplete: (updatedTask) {
            state = state.copyWith(
              currentMultiTask: updatedTask,
              status: AgentProcessStatus.executing,
            );
          },
        );

        final done = task.completedCount;
        final total = task.totalCount;
        final failCount = task.failedSteps.length;
        _addLog('완료',
            '멀티스텝 완료: $done/$total 성공${failCount > 0 ? ', $failCount 실패' : ''}');

        final history = [...state.taskHistory, task];
        final trimmed =
            history.length > 10 ? history.sublist(history.length - 10) : history;

        state = state.copyWith(
          status: task.hasFailed ? AgentProcessStatus.error : AgentProcessStatus.idle,
          taskHistory: trimmed,
          clearCurrentTask: true,
          clearCurrentMultiTask: true,
          errorMessage: task.hasFailed ? '${task.failedSteps.length}개 단계 실패' : null,
        );
      }
    } catch (e) {
      _addLog('오류', '$e', isError: true);
      state = state.copyWith(
        status: AgentProcessStatus.error,
        errorMessage: '$e',
        clearCurrentTask: true,
        clearCurrentMultiTask: true,
      );
    }
  }

  /// 진행 중인 멀티스텝 태스크 취소
  void cancelTask() {
    final task = state.currentMultiTask;
    if (task == null) return;
    task.cancel();
    _addLog('취소', '태스크 취소됨 (${task.completedCount}/${task.totalCount} 완료)');

    final history = [...state.taskHistory, task];
    final trimmed =
        history.length > 10 ? history.sublist(history.length - 10) : history;

    state = state.copyWith(
      status: AgentProcessStatus.idle,
      clearCurrentMultiTask: true,
      clearCurrentTask: true,
      taskHistory: trimmed,
    );
  }

  /// pendingReview 승인 → idle로 전환 (결과 보존)
  void approveReview() {
    if (state.status != AgentProcessStatus.pendingReview) return;
    _addLog('승인', '검토 승인 완료');
    state = state.copyWith(
      status: AgentProcessStatus.idle,
      clearPendingReview: true,
      clearCurrentTask: true,
    );
  }

  /// pendingReview 거부 → idle로 전환, pendingReview null
  void rejectReview() {
    if (state.status != AgentProcessStatus.pendingReview) return;
    _addLog('거부', '검토 거부 — 처리 취소됨');
    state = AgentState(
      agentLog: List.from(state.agentLog),
    );
  }

  /// 로그 초기화
  void clearLog() {
    state = state.copyWith(agentLog: []);
  }

  /// 전체 상태 초기화
  void reset() {
    state = const AgentState();
  }

  // ── 테스트용 직접 상태 주입 ──────────────────────

  @visibleForTesting
  void setStateForTest(AgentState newState) => state = newState;

  // ── 내부 헬퍼 ─────────────────────────────────

  void _addLog(String step, String detail, {bool isError = false}) {
    final entry = AgentLogEntry(step: step, detail: detail, isError: isError);
    state = state.copyWith(agentLog: [...state.agentLog, entry]);
  }

  void _applyResult(AgentResult result) {
    switch (result.status) {
      case AgentStatus.pendingReview:
        _addLog('검토', result.reviewContent ?? '결과를 검토해주세요');
        state = state.copyWith(
          status: AgentProcessStatus.pendingReview,
          pendingReview: result,
          lastResult: result,
          clearCurrentTask: true,
        );
      case AgentStatus.failed:
        _addLog('실패', result.errorMessage ?? '처리 실패', isError: true);
        state = state.copyWith(
          status: AgentProcessStatus.error,
          errorMessage: result.errorMessage,
          lastResult: result,
          clearCurrentTask: true,
        );
      default:
        _addLog('완료', result.summary ?? '처리 완료');
        state = state.copyWith(
          status: AgentProcessStatus.idle,
          lastResult: result,
          clearPendingReview: true,
          clearCurrentTask: true,
          clearErrorMessage: true,
        );
    }
  }
}

// ─── Provider 정의 ────────────────────────────────────

/// 에이전트 상태 Provider
final agentStateProvider =
    StateNotifierProvider<AgentStateNotifier, AgentState>(
  (ref) => AgentStateNotifier(ref),
);

/// 실행 로그만 노출하는 파생 Provider
final agentLogProvider = Provider<List<AgentLogEntry>>(
  (ref) => ref.watch(agentStateProvider).agentLog,
);

/// 검토 대기 여부 bool Provider
final isPendingReviewProvider = Provider<bool>(
  (ref) => ref.watch(agentStateProvider).status == AgentProcessStatus.pendingReview,
);

/// 현재 진행 중인 멀티스텝 태스크 Provider
final currentMultiTaskProvider = Provider<MultiStepTask?>(
  (ref) => ref.watch(agentStateProvider).currentMultiTask,
);
