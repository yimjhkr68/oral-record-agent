// lib/src/presentation/providers/agent_state_provider.dart
// AgentCore 실행 상태를 Riverpod StateNotifier로 관리
//
// 사용 예:
//   final state = ref.watch(agentStateProvider);
//   ref.read(agentStateProvider.notifier).handle('interview.mp3 등록해줘');

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../agents/core/agent_core.dart';
import '../../../agents/core/agent_intent.dart';
import '../../../agents/core/agent_result.dart';
import '../../../agents/core/intent_parser.dart';
import '../../../agents/core/multi_step_task.dart';
import '../../../agents/core/task_planner.dart';
import '../../../agents/tools/tool_registry.dart';
import '../../../agents/tools/tool_services.dart';
import '../../../agents/tools/tool_interface.dart';
import '../../data/repositories/record_repository.dart';
import '../../data/repositories/narrator_repository.dart';
import '../../data/repositories/repository_provider.dart';
import 'settings_provider.dart';
import 'record_provider.dart';
import 'agent_history_provider.dart';
import '../../../agents/core/agent_history.dart';
import 'agent_output_provider.dart';
import '../../../agents/core/agent_output.dart';
import 'auth_provider.dart';
import '../../../agents/core/prompt_enhancer.dart';

// ─── 로그 항목 ────────────────────────────────────────

class AgentLogEntry {
  final String step;
  final String detail;
  final DateTime timestamp;
  final bool isError;
  /// HistoryLogType.name 문자열 (nullable — 기존 로그 호환)
  final String? logType;
  /// 산출물 폴더 경로 — non-null이면 "폴더 열기" 버튼 표시
  final String? folderPath;

  AgentLogEntry({
    required this.step,
    required this.detail,
    DateTime? timestamp,
    this.isError = false,
    this.logType,
    this.folderPath,
  }) : timestamp = timestamp ?? DateTime.now();
}

// ─── 에이전트 처리 상태 (agent_result.dart의 AgentStatus와 구분) ──

enum AgentProcessStatus {
  idle,
  enhancingPrompt,      // PromptEnhancer API 호출 중
  waitingPromptChoice,  // PromptEnhanceCard 표시 중, 사용자 선택 대기
  thinking,
  executing,
  pendingReview,
  pendingSearchConfirm, // 검색 결과 컨펌 대기
  pendingDuplicate,     // 중복 파일 감지 다이얼로그 대기
  error,
}

// ─── 중복 파일 감지 처리 선택 ────────────────────────
enum DuplicateResolution {
  cancel,         // 등록 중단
  forceRegister,  // 새 기록으로 강제 등록
  updateExisting, // 기존 기록 파일 교체 + 재처리
}

// ─── 중복 파일 정보 ─────────────────────────────────
class DuplicateFileInfo {
  final String existingRecordId;
  final String existingTitle;
  final String? existingDisplayId;
  final String? existingDate;
  final String fileHash;
  final String filePath; // 원본 파일 경로 (재처리용)

  const DuplicateFileInfo({
    required this.existingRecordId,
    required this.existingTitle,
    this.existingDisplayId,
    this.existingDate,
    required this.fileHash,
    required this.filePath,
  });
}

// ─── 검색 결과 컨펌 데이터 ─────────────────────────────

class SearchResultRecord {
  final String recordId;
  final String title;
  final String narratorName;
  final String date;
  final String summaryPreview;
  final double relevanceScore;
  bool isSelected;

  SearchResultRecord({
    required this.recordId,
    required this.title,
    required this.narratorName,
    required this.date,
    required this.summaryPreview,
    required this.relevanceScore,
    bool? isSelected,
  }) : isSelected = isSelected ?? relevanceScore >= 0.7;
}

class SearchConfirmData {
  final String originalPrompt;
  final String enhancedPrompt;
  final List<SearchResultRecord> records;
  /// 'analyze' | 'generate_report' | 'generate_book' | 'generate_summary'
  final String nextAction;
  /// 사용자가 명시한 분석 방법론/관점 (예: "비교문화적 관점")
  final String? requirements;

  const SearchConfirmData({
    required this.originalPrompt,
    required this.enhancedPrompt,
    required this.records,
    required this.nextAction,
    this.requirements,
  });
}

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

  /// 검색 결과 컨펌 대기 중인 데이터
  final SearchConfirmData? pendingSearchResult;

  /// 프롬프트 개선 결과 대기 중인 데이터 (waitingPromptChoice 상태)
  final EnhancedPrompt? pendingEnhancedPrompt;

  /// 에러 메시지
  final String? errorMessage;

  /// 현재 진행 중인 멀티스텝 태스크
  final MultiStepTask? currentMultiTask;

  /// 완료된 태스크 히스토리 (최대 10개)
  final List<MultiStepTask> taskHistory;

  /// 중복 파일 감지 정보 (pendingDuplicate 상태일 때)
  final DuplicateFileInfo? pendingDuplicateInfo;

  const AgentState({
    this.status = AgentProcessStatus.idle,
    this.currentTask,
    this.currentStep,
    this.stepProgress = 0,
    this.totalSteps = 0,
    this.agentLog = const [],
    this.lastResult,
    this.pendingReview,
    this.pendingSearchResult,
    this.pendingEnhancedPrompt,
    this.errorMessage,
    this.currentMultiTask,
    this.taskHistory = const [],
    this.pendingDuplicateInfo,
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
    SearchConfirmData? pendingSearchResult,
    EnhancedPrompt? pendingEnhancedPrompt,
    String? errorMessage,
    MultiStepTask? currentMultiTask,
    List<MultiStepTask>? taskHistory,
    DuplicateFileInfo? pendingDuplicateInfo,
    bool clearPendingReview = false,
    bool clearPendingSearch = false,
    bool clearPendingEnhance = false,
    bool clearPendingDuplicate = false,
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
      pendingSearchResult: clearPendingSearch ? null : (pendingSearchResult ?? this.pendingSearchResult),
      pendingEnhancedPrompt: clearPendingEnhance ? null : (pendingEnhancedPrompt ?? this.pendingEnhancedPrompt),
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      currentMultiTask: clearCurrentMultiTask ? null : (currentMultiTask ?? this.currentMultiTask),
      taskHistory: taskHistory ?? this.taskHistory,
      pendingDuplicateInfo: clearPendingDuplicate ? null : (pendingDuplicateInfo ?? this.pendingDuplicateInfo),
    );
  }
}

// ─── StateNotifier ────────────────────────────────────

class AgentStateNotifier extends StateNotifier<AgentState> {
  final Ref _ref;

  /// 현재 처리 중인 원본 입력 (산출물 기록용)
  String _lastInput = '';
  /// 개선된 프롬프트 (산출물 기록용, 없으면 원본과 동일)
  String _lastEnhancedPrompt = '';

  AgentStateNotifier(this._ref) : super(const AgentState());

  /// SmartSearch 결과 후 confirmSearch() 에서 사용할 저장 상태
  ToolRegistry? _pendingToolRegistry;
  RecordRepository? _pendingRecordRepo;

  // ── 공개 API ─────────────────────────────────────

  /// 프롬프트 컨텍스트 저장 (PromptEnhancer 결과 전달용)
  void setPromptContext(String original, String enhanced) {
    _lastInput = original;
    _lastEnhancedPrompt = enhanced;
  }

  /// 사용자 자연어 입력 처리
  /// IntentParser → AgentCore 순서로 실행
  Future<void> handle(String userInput) async {
    _lastInput = userInput;
    _lastEnhancedPrompt = userInput;
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
      _saveHistory(userInput, result);
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
  /// generateContent/analyzeRecord → PromptEnhancer 선처리 후 waitingPromptChoice
  Future<void> handleInput(String userInput) async {
    _lastInput = userInput;
    _lastEnhancedPrompt = userInput;

    // 로그 초기화 (PromptEnhancer 결과도 여기서부터 기록)
    state = state.copyWith(
      clearCurrentTask: true,
      clearErrorMessage: true,
      clearCurrentMultiTask: true,
      clearPendingDuplicate: true,
      agentLog: [],
    );

    // 1단계: PromptEnhancer (generateContent/analyzeRecord 키워드 감지)
    if (PromptEnhancer.shouldEnhance(userInput)) {
      state = state.copyWith(status: AgentProcessStatus.enhancingPrompt);
      _addLog('✨', '프롬프트 분석 중...');

      final settings = _ref.read(settingsProvider);
      final apiKey = settings.apiKey.isEmpty ? null : settings.apiKey;

      try {
        final enhanced =
            await PromptEnhancer(apiKey: apiKey).enhance(userInput);

        // 원본 로그 (항상 기록)
        _addLog('원본', userInput, logType: HistoryLogType.promptOriginal.name);

        if (enhanced.isImproved) {
          // 개선안 로그
          _addLog('개선', enhanced.enhanced,
              logType: HistoryLogType.promptEnhanced.name);
          // PromptEnhanceCard 표시 → 사용자 선택 대기
          state = state.copyWith(
            status: AgentProcessStatus.waitingPromptChoice,
            pendingEnhancedPrompt: enhanced,
          );
          return;
        }
      } catch (_) {
        // 개선 실패 → 원본으로 진행
      }
    }

    // 2단계: PromptEnhancer 불필요하거나 개선 안 됨 → 바로 실행
    await _executeInput(userInput);
  }

  /// PromptEnhanceCard에서 사용자 선택 처리
  Future<void> confirmEnhancedPrompt(bool useEnhanced) async {
    final pending = state.pendingEnhancedPrompt;
    if (pending == null) return;

    final promptToUse = useEnhanced ? pending.enhanced : pending.original;
    if (useEnhanced) _lastEnhancedPrompt = pending.enhanced;

    // [실행] 로그
    _addLog('실행', promptToUse, logType: HistoryLogType.promptExecuted.name);

    state = state.copyWith(
      status: AgentProcessStatus.thinking,
      clearPendingEnhance: true,
    );

    await _executeInput(promptToUse);
  }

  /// PromptEnhanceCard 취소
  void rejectEnhancedPrompt() {
    _addLog('취소', '프롬프트 개선 취소');
    state = state.copyWith(
      status: AgentProcessStatus.idle,
      clearPendingEnhance: true,
      clearCurrentTask: true,
    );
  }

  /// 편집된 텍스트로 재개선 요청 (최대 3회)
  Future<void> reEnhancePrompt(String editedText) async {
    final pending = state.pendingEnhancedPrompt;
    if (pending == null) return;

    state = state.copyWith(status: AgentProcessStatus.enhancingPrompt);

    final settings = _ref.read(settingsProvider);
    final apiKey = settings.apiKey.isEmpty ? null : settings.apiKey;

    try {
      final result =
          await PromptEnhancer(apiKey: apiKey).enhance(editedText);

      // API가 isImproved: false 반환 → 편집 텍스트 자체를 사용
      final newEnhanced = result.isImproved ? result.enhanced : editedText;
      final newReason = result.isImproved
          ? result.reason
          : '편집한 프롬프트를 그대로 사용합니다.';

      _addLog('재개선', newEnhanced,
          logType: HistoryLogType.promptEnhanced.name);

      state = state.copyWith(
        status: AgentProcessStatus.waitingPromptChoice,
        pendingEnhancedPrompt: EnhancedPrompt(
          original: pending.original, // 원본은 보존
          enhanced: newEnhanced,
          reason: newReason,
          isImproved: true,
        ),
      );
    } catch (_) {
      // 실패 → 편집 텍스트 그대로 유지
      state = state.copyWith(
        status: AgentProcessStatus.waitingPromptChoice,
        pendingEnhancedPrompt: EnhancedPrompt(
          original: pending.original,
          enhanced: editedText,
          reason: '재개선 실패 — 편집된 프롬프트를 사용합니다.',
          isImproved: true,
        ),
      );
    }
  }

  /// 실제 실행 진입점 (PromptEnhancer 이후 또는 직접 진입)
  Future<void> _executeInput(String userInput) async {
    state = state.copyWith(
      status: AgentProcessStatus.thinking,
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
        final intent = task.steps.first.intent;

        // analyzeRecord / generateContent → SmartSearch 선처리
        if (intent.type == IntentType.analyzeRecord ||
            intent.type == IntentType.generateContent) {
          final intercepted = await _runSmartSearchIntercept(
            userInput: userInput,
            intent: intent,
            toolRegistry: toolRegistry,
            recordRepo: recordRepo,
          );
          if (intercepted) return; // 컨펌 대기 중 or 결과 없음 → 여기서 종료
        }

        // 단일 스텝: 기존 경로 (이미 파싱된 intent 재사용)
        final result = await core.handle(intent);
        _applyResult(result);
        _saveHistory(userInput, result);
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
        // 멀티스텝에서 저장 성공이 있으면 목록 갱신
        final hasSave = task.steps.any(
          (s) => s.status == StepStatus.done && s.result?.savedRecordId != null,
        );
        if (hasSave) _invalidateRecordProviders();
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

  /// 검색 결과 컨펌 → 선택된 기록으로 다음 단계 실행
  Future<void> confirmSearch(List<String> selectedRecordIds) async {
    final pending = state.pendingSearchResult;
    if (pending == null) return;

    final selectedTitles = pending.records
        .where((r) => selectedRecordIds.contains(r.recordId))
        .map((r) => r.title)
        .join(', ');

    state = state.copyWith(
      status: AgentProcessStatus.executing,
      clearPendingSearch: true,
    );
    _addLog('선택', '선택된 기록: $selectedTitles',
        logType: HistoryLogType.searchConfirmed.name);

    try {
      final toolRegistry = _pendingToolRegistry;
      if (toolRegistry == null) {
        _addLog('오류', '도구 레지스트리 없음', isError: true);
        state = state.copyWith(
            status: AgentProcessStatus.error, errorMessage: '내부 오류');
        return;
      }

      // 선택된 기록 텍스트 결합
      final combinedText = await _buildCombinedText(selectedRecordIds);

      if (pending.nextAction == 'analyze') {
        _addLog('실행', 'summarize 실행 중...',
            logType: HistoryLogType.toolStart.name);
        final result = await toolRegistry.run('summarize', {
          'text': combinedText.isEmpty ? '(내용 없음)' : combinedText,
          'summaryType': 'detailed',
        });
        if (result.success) {
          final summary = result.output['summary'] as String? ?? '분석 완료';
          _addLog('완료', summary, logType: HistoryLogType.agentComplete.name);
          state = state.copyWith(
              status: AgentProcessStatus.idle, clearCurrentTask: true);
        } else {
          _addLog('오류', result.errorMessage ?? '분석 실패',
              isError: true, logType: HistoryLogType.toolError.name);
          state = state.copyWith(
              status: AgentProcessStatus.error,
              errorMessage: result.errorMessage);
        }
      } else {
        // generate_report / generate_book / generate_summary
        final docType = pending.nextAction.startsWith('generate_')
            ? pending.nextAction.substring('generate_'.length)
            : 'report';
        _addLog('실행', 'generate_doc ($docType) 실행 중...',
            logType: HistoryLogType.toolStart.name);
        final result = await toolRegistry.run('generate_doc', {
          'docType': docType,
          'recordIds': selectedRecordIds,
          'title': '구술기록 ${_docTypeLabel(docType)}',
          if (pending.requirements != null) 'requirements': pending.requirements!,
        });
        if (result.success) {
          _addFileCompletionLog(result.output);
          _saveOutputIfPresentFromResult(result);
          state = state.copyWith(
              status: AgentProcessStatus.idle, clearCurrentTask: true);
        } else {
          _addLog('오류', result.errorMessage ?? '생성 실패',
              isError: true, logType: HistoryLogType.toolError.name);
          state = state.copyWith(
              status: AgentProcessStatus.error,
              errorMessage: result.errorMessage);
        }
      }

      _saveHistory(
        pending.originalPrompt,
        AgentResult.success(toolCallResults: [], summary: '완료'),
      );
    } catch (e) {
      _addLog('오류', '$e', isError: true);
      state = state.copyWith(
          status: AgentProcessStatus.error,
          clearCurrentTask: true,
          errorMessage: '$e');
    }
  }

  /// 검색 결과 거부 → idle로 전환
  void rejectSearch() {
    _addLog('취소', '검색 결과 거부 — 새 입력을 기다립니다');
    state = state.copyWith(
      status: AgentProcessStatus.idle,
      clearPendingSearch: true,
      clearCurrentTask: true,
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

  /// SmartSearch 선처리 — true면 컨펌 대기 또는 결과 없음으로 종료
  Future<bool> _runSmartSearchIntercept({
    required String userInput,
    required AgentIntent intent,
    required ToolRegistry toolRegistry,
    required RecordRepository? recordRepo,
  }) async {
    _addLog('검색', '관련 기록 검색 중...',
        logType: HistoryLogType.searchQuery.name);
    state = state.copyWith(
        status: AgentProcessStatus.executing, currentTask: '기록 검색 중...');

    final searchResult = await toolRegistry.run('smart_search', {
      'query': userInput,
      'maxResults': 10,
    });

    if (!searchResult.success) {
      _addLog('오류', '검색 실패: ${searchResult.errorMessage}',
          isError: true, logType: HistoryLogType.toolError.name);
      state = state.copyWith(
          status: AgentProcessStatus.error,
          errorMessage: searchResult.errorMessage);
      return true;
    }

    final records = (searchResult.output['records'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final hasResults = searchResult.output['hasResults'] as bool? ?? false;
    final strategy =
        searchResult.output['searchStrategy'] as String? ?? '';
    final total = searchResult.output['totalFound'] as int? ?? 0;

    _addLog('검색', '$total건 발견 ($strategy)',
        logType: HistoryLogType.searchResult.name);

    if (!hasResults) {
      _addLog(
        '검색',
        '[검색 실패] "${intent.params['query'] ?? userInput}"에 해당하는 기록을 찾지 못했어요.\n'
        '힌트: 구술자 이름, 날짜, 주제어로 다시 시도해보세요.',
        logType: HistoryLogType.searchResult.name,
      );
      _saveHistory(userInput, AgentResult.failed('검색 결과 없음'));
      state = state.copyWith(
          status: AgentProcessStatus.idle, clearCurrentTask: true);
      return true;
    }

    final resultRecords = records.map((m) {
      return SearchResultRecord(
        recordId: m['recordId'] as String? ?? '',
        title: m['title'] as String? ?? '',
        narratorName: m['narratorName'] as String? ?? '',
        date: m['date'] as String? ?? '',
        summaryPreview: m['summaryPreview'] as String? ?? '',
        relevanceScore: (m['relevanceScore'] as num?)?.toDouble() ?? 0.5,
      );
    }).toList();

    final docType = intent.params['docType'] as String? ?? 'report';
    final nextAction = intent.type == IntentType.analyzeRecord
        ? 'analyze'
        : 'generate_$docType';

    _pendingToolRegistry = toolRegistry;
    _pendingRecordRepo = recordRepo;

    state = state.copyWith(
      status: AgentProcessStatus.pendingSearchConfirm,
      clearCurrentTask: true,
      pendingSearchResult: SearchConfirmData(
        originalPrompt: _lastInput,
        enhancedPrompt: _lastEnhancedPrompt,
        records: resultRecords,
        nextAction: nextAction,
        requirements: intent.params['requirements'] as String?,
      ),
    );
    return true;
  }

  /// 선택된 기록들의 transcript + summary 결합
  Future<String> _buildCombinedText(List<String> recordIds) async {
    final repo = _pendingRecordRepo;
    if (repo == null) return '';
    final parts = <String>[];
    for (final id in recordIds) {
      try {
        final record = await repo.getRecord(id);
        if (record == null) continue;
        parts.add('=== ${record.title} ===');
        if (record.content.isNotEmpty) parts.add(record.content);
        if (record.summary?.isNotEmpty == true) {
          parts.add('[요약] ${record.summary}');
        }
      } catch (_) {}
    }
    return parts.join('\n\n');
  }

  /// ToolResult 직접 전달 버전 산출물 기록
  void _saveOutputIfPresentFromResult(ToolResult result) {
    final filePath = result.output['filePath'] as String?;
    if (filePath == null || filePath.isEmpty) return;
    final outputTypeKey = result.output['outputType'] as String? ?? 'report';
    final username =
        _ref.read(authProvider).currentUser?.username ?? 'anonymous';
    final output = AgentOutput.create(
      userAccount: username,
      userPrompt: _lastInput,
      enhancedPrompt: _lastEnhancedPrompt,
      outputTypeKey: outputTypeKey,
      filePath: filePath,
    );
    _ref.read(agentOutputProvider.notifier).addOutput(output).ignore();
    _lastInput = '';
    _lastEnhancedPrompt = '';
  }

  String _docTypeLabel(String docType) {
    switch (docType) {
      case 'book': return '생애사 책';
      case 'summary': return '요약집';
      default: return '보고서';
    }
  }

  /// 파일 생성 완료 로그 — 파일명/경로/크기 + 폴더 열기 버튼
  void _addFileCompletionLog(Map<String, dynamic> output) {
    final filePath = output['filePath'] as String? ?? '';
    if (filePath.isEmpty) return;
    final fileName = output['fileName'] as String? ??
        filePath.split(Platform.pathSeparator).last;
    final fileSizeKb = output['fileSizeKb'] as int? ?? 0;
    final folderPath = output['outputsDir'] as String? ??
        filePath.substring(0, filePath.lastIndexOf(Platform.pathSeparator));
    final sizeLabel = fileSizeKb > 0 ? '$fileSizeKb KB' : '-';

    _addLog(
      '완료',
      '파일이 생성되었습니다\n\n📄 $fileName\n📁 $folderPath\n💾 $sizeLabel',
      logType: HistoryLogType.agentComplete.name,
      folderPath: folderPath,
    );
  }

  /// 산출물 파일 자동 기록 (filePath 출력이 있는 경우)
  void _saveOutputIfPresent(AgentResult result) {
    final filePath = result.toolCallResults
        .where((r) => r.success && r.output != null)
        .map((r) => r.output!['filePath'] as String?)
        .firstWhere((p) => p != null && p.isNotEmpty, orElse: () => null);
    if (filePath == null) return;

    final outputTypeKey = result.toolCallResults
            .where((r) => r.success && r.output?['outputType'] != null)
            .map((r) => r.output!['outputType'] as String)
            .firstOrNull ??
        'report';

    final username =
        _ref.read(authProvider).currentUser?.username ?? 'anonymous';

    final output = AgentOutput.create(
      userAccount: username,
      userPrompt: _lastInput,
      enhancedPrompt: _lastEnhancedPrompt,
      outputTypeKey: outputTypeKey,
      filePath: filePath,
    );

    _ref.read(agentOutputProvider.notifier).addOutput(output).ignore();
    _lastInput = '';
    _lastEnhancedPrompt = '';
  }

  /// 에이전트 이력 저장 (비동기, 오류 무시)
  void _saveHistory(String inputText, AgentResult result) {
    final status = result.isSuccess
        ? AgentHistoryStatus.success
        : AgentHistoryStatus.failed;
    final steps = state.agentLog
        .map((l) => HistoryLogItem(
              step: l.step,
              detail: l.detail,
              isError: l.isError,
              timestamp: l.timestamp,
              logType: l.logType,
            ))
        .toList();
    final entry = AgentHistoryEntry.create(
      inputText: inputText,
      status: status,
      steps: steps,
      savedRecordId: result.savedRecordId,
    );
    _ref.read(agentHistoryProvider.notifier).addEntry(entry).ignore();
  }

  /// 기록 저장 후 목록/최근기록 Provider 강제 갱신
  void _invalidateRecordProviders() {
    _ref.invalidate(recordListProvider);
    _ref.invalidate(recentRecordsProvider);
    debugPrint('[Agent] recordListProvider 갱신 완료');
  }

  void _addLog(String step, String detail,
      {bool isError = false, String? logType, String? folderPath}) {
    final entry = AgentLogEntry(
        step: step,
        detail: detail,
        isError: isError,
        logType: logType,
        folderPath: folderPath);
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
      case AgentStatus.duplicateDetected:
        final dupStep = result.toolCallResults
            .where((tr) => tr.toolName == 'check_duplicate')
            .firstOrNull;
        final out = (dupStep?.output as Map<String, dynamic>?) ?? {};
        _addLog('중복 감지',
            '${out['existingTitle'] ?? ''}은 이미 등록된 파일이에요.\nOCR/전사를 건너뛰고 중단했습니다.');
        state = state.copyWith(
          status: AgentProcessStatus.pendingDuplicate,
          pendingDuplicateInfo: DuplicateFileInfo(
            existingRecordId: out['existingRecordId'] as String? ?? '',
            existingTitle: out['existingTitle'] as String? ?? '',
            existingDisplayId: out['existingDisplayId'] as String?,
            existingDate: out['existingDate'] as String?,
            fileHash: out['fileHash'] as String? ?? '',
            filePath: out['filePath'] as String? ?? '',
          ),
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
        // 파일 산출물 완료 로그 자동 추가
        for (final tr in result.toolCallResults) {
          if (tr.success &&
              (tr.toolName == 'generate_doc' || tr.toolName == 'export')) {
            _addFileCompletionLog(tr.output);
          }
        }
        state = state.copyWith(
          status: AgentProcessStatus.idle,
          lastResult: result,
          clearPendingReview: true,
          clearCurrentTask: true,
          clearErrorMessage: true,
        );
        // 기록 저장이 포함된 경우 목록 Provider 갱신
        if (result.savedRecordId != null) {
          _invalidateRecordProviders();
        }
        // 파일 산출물이 있으면 자동 기록
        _saveOutputIfPresent(result);
    }
  }

  /// 중복 파일 다이얼로그 닫기 → idle 상태로 복귀
  void dismissDuplicate() {
    state = state.copyWith(
      status: AgentProcessStatus.idle,
      clearPendingDuplicate: true,
    );
  }

  /// 중복 파일 감지 후 사용자 선택 처리
  Future<void> resolveDuplicate(
    DuplicateResolution resolution,
    String originalFilePath,
    String existingRecordId,
  ) async {
    state = state.copyWith(
      status: AgentProcessStatus.executing,
      clearPendingDuplicate: true,
    );

    switch (resolution) {
      case DuplicateResolution.cancel:
        _addLog('취소', '등록 중단 — 이미 등록된 파일입니다');
        state = state.copyWith(
          status: AgentProcessStatus.idle,
          clearCurrentTask: true,
        );

      case DuplicateResolution.forceRegister:
        _addLog('강제 등록', '중복 체크 건너뜀 — 새 기록으로 등록 시작');
        await _executeWithoutDuplicateCheck(originalFilePath);

      case DuplicateResolution.updateExisting:
        _addLog('업데이트', '기존 기록($existingRecordId) 재처리 시작');
        await _updateExistingRecord(originalFilePath, existingRecordId);
    }
  }

  /// skipDuplicateCheck: true 로 파이프라인 재실행 (강제 등록)
  Future<void> _executeWithoutDuplicateCheck(String filePath) async {
    final intent = AgentIntent(
      type: IntentType.registerRecord,
      rawInput: '$filePath 등록해줘',
      params: {
        'filePath': filePath,
        'skipDuplicateCheck': true,
      },
    );
    await _runCoreWithIntent(intent);
  }

  /// updateRecordId 파라미터로 기존 기록 재처리 (OCR/전사 → 요약/태그 재생성)
  Future<void> _updateExistingRecord(
      String filePath, String existingRecordId) async {
    final intent = AgentIntent(
      type: IntentType.registerRecord,
      rawInput: '$filePath 업데이트해줘',
      params: {
        'filePath': filePath,
        'skipDuplicateCheck': true,
        'updateRecordId': existingRecordId,
      },
    );
    await _runCoreWithIntent(intent);
  }

  /// AgentIntent를 직접 받아 AgentCore 실행 (중복 처리 경로 공통 헬퍼)
  Future<void> _runCoreWithIntent(AgentIntent intent) async {
    try {
      final settings = _ref.read(settingsProvider);
      final apiKey = settings.apiKey.isEmpty ? null : settings.apiKey;

      RecordRepository? recordRepo;
      NarratorRepository? narratorRepo;
      try {
        recordRepo = await _ref.read(recordRepositoryProvider.future);
        narratorRepo = await _ref.read(narratorRepositoryProvider.future);
      } catch (_) {}

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
      _applyResult(result);
      _saveHistory(intent.rawInput, result);
    } catch (e) {
      _addLog('오류', '$e', isError: true);
      state = state.copyWith(
        status: AgentProcessStatus.error,
        errorMessage: '$e',
        clearCurrentTask: true,
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
