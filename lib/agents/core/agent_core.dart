// lib/agents/core/agent_core.dart  ← v2 (ToolRegistry 연결 버전)
// _mockToolCall 제거, 실제 ToolRegistry 사용

import 'agent_intent.dart';
import 'agent_result.dart';
import 'agent_memory.dart';
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

  // ─── [D] Do ──────────────────────────────────────────

  Future<List<ToolCallResult>> _execute(_ExecutionPlan plan) async {
    final results = <ToolCallResult>[];

    for (final step in plan.steps) {
      _notify('실행', '${step.toolName} 실행 중...');

      // 툴이 등록돼 있지 않으면 건너뜀 (optional 단계)
      if (!_tools.has(step.toolName)) {
        if (step.required) {
          results.add(ToolCallResult(
            toolName: step.toolName,
            success: false,
            errorMessage: '등록되지 않은 툴: ${step.toolName}',
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
      return _CheckResult(
        passed: false,
        reason: '${failed.map((r) => r.toolName).join(', ')} 단계 실패',
        needsHumanReview: true,
      );
    }

    if (intent.type == IntentType.registerRecord) {
      final hasSave = results.any((r) => r.toolName == 'save_record' && r.success);
      if (!hasSave) {
        return const _CheckResult(
          passed: false,
          reason: '저장 단계가 실행되지 않았습니다',
          needsHumanReview: true,
        );
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
      if (step.toolName == 'transcribe' && next.toolName == 'summarize') {
        next.params['text'] = out['transcript'];
      }
      if (step.toolName == 'extract_pdf' && next.toolName == 'summarize') {
        next.params['text'] = out['transcript'];
      }
      if (step.toolName == 'extract_docx' && next.toolName == 'summarize') {
        next.params['text'] = out['transcript'];
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
        return _ExecutionPlan([_PlanStep('generate_doc', Map.from(intent.params))]);
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
