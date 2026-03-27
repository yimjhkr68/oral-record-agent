// lib/agents/core/agent_core.dart  ← v2 (ToolRegistry 연결 버전)
// _mockToolCall 제거, 실제 ToolRegistry 사용

import 'agent_intent.dart';
import 'agent_result.dart';
import 'agent_memory.dart';
import 'multi_step_task.dart';
import '../tools/tool_registry.dart';
import '../tools/tool_interface.dart';

typedef AgentProgressCallback = void Function(String step, String detail);

class AgentCore {
  final String claudeApiKey;
  final ToolRegistry _tools;
  final AgentMemory _memory;
  final AgentProgressCallback? onProgress;

  AgentCore({
    required this.claudeApiKey,
    ToolRegistry? toolRegistry,
    AgentMemory? memory,
    this.onProgress,
  })  : _tools = toolRegistry ?? ToolRegistry.standard(),
        _memory = memory ?? AgentMemory();

  // ─── 공개 API ────────────────────────────────────────

  Future<AgentResult> handle(AgentIntent intent) async {
    final sw = Stopwatch()..start();
    _memory.setCurrentIntent(intent);
    _notify('시작', '${intent.typeLabel} 처리 시작');

    try {
      if (intent.needsClarification) {
        return AgentResult.clarify(
          '요청을 조금 더 구체적으로 알려주실 수 있나요?\n'
          '예: "김철수 선생님 면담 음성 파일 등록해줘"',
        );
      }

      _notify('계획', '처리 계획 수립 중...');
      final plan = _buildDefaultPlan(intent);

      _notify('실행', '${plan.steps.length}개 단계 실행 중...');
      final toolResults = await _execute(plan);

      _notify('검증', '결과 품질 검증 중...');
      final check = _verify(intent, toolResults);

      _notify('완료', '처리 완료');
      final result = await _act(intent, toolResults, check);

      sw.stop();
      final timed = _withTiming(result, sw.elapsed);
      _memory.logTask(intent, timed);
      _memory.clearCurrentIntent();
      return timed;
    } catch (e) {
      sw.stop();
      final err = AgentResult.failed('예기치 않은 오류: $e');
      _memory.logTask(intent, err);
      _memory.clearCurrentIntent();
      return err;
    }
  }

  void clearSession() => _memory.clearSession();
  double getSuccessRate(IntentType type) => _memory.successRate(type);

  /// 멀티스텝 태스크 순차 실행
  ///
  /// [stopOnFirstFailure]: true이면 첫 실패 단계에서 이후 단계 건너뜀
  /// [onStepComplete]: 각 단계 완료(done/failed/skipped) 직후 호출되는 콜백
  Future<MultiStepTask> handleMultiStep(
    MultiStepTask task, {
    bool stopOnFirstFailure = false,
    void Function(MultiStepTask)? onStepComplete,
  }) async {
    for (int i = 0; i < task.steps.length; i++) {
      if (task.isCancelled) break;

      final step = task.steps[i];
      if (step.status != StepStatus.pending) continue;

      // 의존 단계가 아직 완료되지 않았으면 건너뜀
      final depsOk = step.dependsOn.every(
        (depIdx) => task.steps[depIdx].status == StepStatus.done,
      );
      if (!depsOk) {
        step.status = StepStatus.skipped;
        onStepComplete?.call(task);
        continue;
      }

      step.status = StepStatus.running;
      _notify('실행', '[${i + 1}/${task.steps.length}] ${step.intent.typeLabel}');
      onStepComplete?.call(task);

      try {
        final result = await handle(step.intent);
        step.result = result;
        step.status = result.isSuccess ? StepStatus.done : StepStatus.failed;
      } catch (e) {
        step.result = AgentResult.failed('$e');
        step.status = StepStatus.failed;
      }

      onStepComplete?.call(task);

      if (step.status == StepStatus.failed && stopOnFirstFailure) break;

      // 단계 사이 딜레이 (API 호출 폭주 방지)
      if (i < task.steps.length - 1 && !task.isCancelled) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    // 남은 pending 단계 → skipped
    for (final step in task.steps) {
      if (step.status == StepStatus.pending) {
        step.status = StepStatus.skipped;
      }
    }

    task.completedAt ??= DateTime.now();
    return task;
  }

  // ─── [D] Do ──────────────────────────────────────────

  Future<List<ToolCallResult>> _execute(_ExecutionPlan plan) async {
    final results = <ToolCallResult>[];

    for (final step in plan.steps) {
      _notify('실행', '${step.toolName} 실행 중...');

      // 툴이 등록돼 있지 않으면 건너뜀 (optional 단계)
      if (!_tools.has(step.toolName)) {
        if (step.required) {
          // 미지원 파일 형식 전용 에러 메시지
          final errMsg = step.toolName == '_unsupported_type'
              ? '지원하지 않는 파일 형식입니다: .${step.params['ext']}\n'
                '지원 형식: mp3, mp4, wav, m4a, webm, mov, pdf, docx, txt'
              : '등록되지 않은 툴: ${step.toolName}';
          results.add(ToolCallResult(
            toolName: step.toolName,
            success: false,
            errorMessage: errMsg,
          ));
          break;
        }
        continue;
      }

      final toolResult = await _tools.run(step.toolName, step.params);

      results.add(ToolCallResult(
        toolName: step.toolName,
        success: toolResult.success,
        output: toolResult.output,
        errorMessage: toolResult.errorMessage,
        executionTime: toolResult.executionTime,
      ));

      if (!toolResult.success && step.required) break;

      // 성공한 경우 다음 단계로 출력 체이닝
      if (toolResult.success) _chain(step, toolResult, plan);
    }

    return results;
  }

  // ─── [C] Check ───────────────────────────────────────

  _CheckResult _verify(AgentIntent intent, List<ToolCallResult> results) {
    final failed = results.where((r) => !r.success).toList();

    if (failed.isNotEmpty) {
      // 미지원 파일 형식은 사람 검토 불필요 → 즉시 실패
      final unsupported = failed.any((r) => r.toolName == '_unsupported_type');
      final reason = failed
          .map((r) => r.errorMessage ?? '${r.toolName} 실패')
          .join('; ');
      return _CheckResult(
        passed: false,
        reason: reason,
        needsHumanReview: !unsupported,
      );
    }

    if (intent.type == IntentType.registerRecord) {
      // 중복 파일 감지 시 save_record 없어도 정상 (별도 처리)
      final dupDetected = results.any((r) =>
          r.toolName == 'check_duplicate' &&
          (r.output as Map<String, dynamic>?)?['isDuplicate'] == true);
      if (!dupDetected) {
        final hasSave = results.any((r) => r.toolName == 'save_record' && r.success);
        if (!hasSave) {
          return const _CheckResult(
            passed: false,
            reason: '저장 단계가 실행되지 않았습니다',
            needsHumanReview: true,
          );
        }
      }
    }

    return const _CheckResult(passed: true);
  }

  // ─── [A] Act ─────────────────────────────────────────

  Future<AgentResult> _act(
    AgentIntent intent,
    List<ToolCallResult> toolResults,
    _CheckResult check,
  ) async {
    if (!check.passed) {
      if (check.needsHumanReview) {
        return AgentResult.pendingReview(
          toolCallResults: toolResults,
          reviewContent: check.reason ?? '처리 결과를 검토해주세요',
          summary: _summary(intent, toolResults),
        );
      }
      return AgentResult.failed(check.reason ?? '검증 실패', completed: toolResults);
    }

    // 중복 파일 감지 처리
    final dupResult = toolResults
        .where((r) =>
            r.toolName == 'check_duplicate' &&
            (r.output as Map<String, dynamic>?)?['isDuplicate'] == true)
        .firstOrNull;
    if (dupResult != null) {
      return AgentResult(
        status: AgentStatus.duplicateDetected,
        toolCallResults: toolResults,
        summary: dupResult.errorMessage,
        savedRecordId: (dupResult.output as Map<String, dynamic>?)?['existingRecordId'] as String?,
      );
    }

    final saveResult = toolResults
        .where((r) => r.toolName == 'save_record' && r.success)
        .firstOrNull;

    return AgentResult.success(
      toolCallResults: toolResults,
      savedRecordId: saveResult?.output?['recordId'] as String?,
      summary: _summary(intent, toolResults),
    );
  }

  // ─── 헬퍼 ────────────────────────────────────────────

  void _notify(String step, String detail) => onProgress?.call(step, detail);

  void _chain(_PlanStep step, ToolResult result, _ExecutionPlan plan) {
    final out = result.output;
    for (final next in plan.steps) {
      // 전처리 툴(전사/추출) → summarize 로 텍스트 전달
      if ((step.toolName == 'transcribe' ||
              step.toolName == 'extract_pdf' ||
              step.toolName == 'extract_docx' ||
              step.toolName == 'extract_image') &&
          next.toolName == 'summarize') {
        next.params['text'] = out['transcript'];
      }
      // 전처리 툴 → save_record 로 transcript 전달 (기록 본문 보존)
      if ((step.toolName == 'transcribe' ||
              step.toolName == 'extract_pdf' ||
              step.toolName == 'extract_docx' ||
              step.toolName == 'extract_image') &&
          next.toolName == 'save_record') {
        next.params['transcript'] = out['transcript'];
      }
      if (step.toolName == 'summarize') {
        if (next.toolName == 'tag') next.params['text'] = out['summary'];
        if (next.toolName == 'link_person') next.params['text'] = out['summary'];
        if (next.toolName == 'save_record') next.params['summary'] = out['summary'];
      }
      if (step.toolName == 'tag' && next.toolName == 'save_record') {
        next.params['tags'] = out['tags'];
      }
      if (step.toolName == 'link_person' && next.toolName == 'save_record') {
        next.params['narratorId'] =
            (out['linkedPersonIds'] as List?)?.firstOrNull;
      }
      // check_duplicate → save_record: 미리 계산한 해시 전달
      if (step.toolName == 'check_duplicate' && next.toolName == 'save_record') {
        next.params['fileHash'] = out['fileHash'];
      }
    }
  }

  String _summary(AgentIntent intent, List<ToolCallResult> results) {
    final ok = results.where((r) => r.success).length;
    final ms = results.fold<int>(0, (s, r) => s + r.executionTime.inMilliseconds);
    return '${intent.typeLabel} 완료: $ok/${results.length}단계 '
        '(${(ms / 1000).toStringAsFixed(1)}초)';
  }

  AgentResult _withTiming(AgentResult r, Duration elapsed) => AgentResult(
        status: r.status,
        toolCallResults: r.toolCallResults,
        savedRecordId: r.savedRecordId,
        summary: r.summary,
        clarificationQuestion: r.clarificationQuestion,
        reviewContent: r.reviewContent,
        errorMessage: r.errorMessage,
        totalTime: elapsed,
      );

  // ─── 기본 계획 빌더 (Phase 2에서 Claude API 계획으로 교체) ──

  _ExecutionPlan _buildDefaultPlan(AgentIntent intent) {
    switch (intent.type) {
      case IntentType.registerRecord:
        return _planRegister(intent.params);
      case IntentType.searchRecord:
        return _ExecutionPlan([_PlanStep('search', Map.from(intent.params))]);
      case IntentType.generateContent:
        final genParams = Map<String, dynamic>.from(intent.params);
        genParams['docType'] ??= 'report';
        genParams['recordIds'] ??= <String>[];
        return _ExecutionPlan([_PlanStep('generate_doc', genParams)]);
      case IntentType.exportData:
        return _ExecutionPlan([_PlanStep('export', Map.from(intent.params))]);
      case IntentType.analyzeRecord:
        return _ExecutionPlan([
          _PlanStep('search', Map.from(intent.params)),
          _PlanStep('summarize', {}),
        ]);
      default:
        return _ExecutionPlan([]);
    }
  }

  _ExecutionPlan _planRegister(Map<String, dynamic> params) {
    final filePath = params['filePath'] as String? ?? '';
    final preprocessTool = _tools.preprocessToolFor(filePath);
    final steps = <_PlanStep>[];

    // 파일 경로가 있는데 지원하지 않는 형식이면 즉시 실패
    if (filePath.isNotEmpty && preprocessTool == null) {
      final ext = filePath.contains('.') ? filePath.split('.').last.toLowerCase() : '';
      final isText = params.containsKey('text') && (params['text'] as String?)?.isNotEmpty == true;
      // 알 수 없는 확장자(2~5자 알파벳/숫자)이고 텍스트 입력도 없는 경우 → 미지원 형식
      final hasUnknownExt = ext.length >= 2 && ext.length <= 5 &&
          RegExp(r'^[a-z0-9]+$').hasMatch(ext);
      if (hasUnknownExt && !isText) {
        return _ExecutionPlan([
          _PlanStep('_unsupported_type',
              {'ext': ext, 'filePath': filePath},
              required: true),
        ]);
      }
    }

    // 파일이 있으면 중복 체크를 첫 번째 단계로 실행 (required: true → 중복 시 즉시 중단)
    if (filePath.isNotEmpty) {
      steps.add(_PlanStep('check_duplicate', {'filePath': filePath}, required: true));
    }

    if (preprocessTool != null) {
      steps.add(_PlanStep(preprocessTool, {'filePath': filePath}, required: true));
    }

    steps.addAll([
      _PlanStep('summarize', {'text': params['text'] ?? ''}),
      _PlanStep('tag', {}),
      _PlanStep('link_person', {}),
      _PlanStep('save_record', Map.from(params), required: true),
    ]);

    return _ExecutionPlan(steps);
  }
}

// ─── 내부 데이터 클래스 ───────────────────────────────

class _PlanStep {
  final String toolName;
  Map<String, dynamic> params;
  final bool required;

  _PlanStep(this.toolName, this.params, {this.required = false});
}

class _ExecutionPlan {
  final List<_PlanStep> steps;
  _ExecutionPlan(this.steps);
}

class _CheckResult {
  final bool passed;
  final String? reason;
  final bool needsHumanReview;

  const _CheckResult({
    required this.passed,
    this.reason,
    this.needsHumanReview = false,
  });
}
