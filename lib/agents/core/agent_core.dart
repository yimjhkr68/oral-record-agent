// lib/agents/core/agent_core.dart
// 구술기록관리 에이전트의 핵심 두뇌
// 모든 작업 요청이 이곳을 통과한다.

import 'agent_intent.dart';
import 'agent_result.dart';
import 'agent_memory.dart';
// TODO Phase 1 완료 후 아래 import 활성화
// import '../tools/tool_registry.dart';
// import '../../src/services/claude_api_service.dart';

/// 에이전트 실행 중 각 단계 상태를 UI에 전달하는 콜백
typedef AgentProgressCallback = void Function(String step, String detail);

/// ─────────────────────────────────────────────────────
/// AgentCore
///
/// PDCA 런타임 루프를 구현한 에이전트 두뇌.
///
/// 사용 예:
///   final agent = AgentCore(
///     claudeApiKey: apiKey,
///     onProgress: (step, detail) => print('[$step] $detail'),
///   );
///   final result = await agent.handle(
///     AgentIntent(type: IntentType.registerRecord, rawInput: "이 파일 등록해줘",
///                 params: {'filePath': '/path/to/file.mp3'}),
///   );
/// ─────────────────────────────────────────────────────
class AgentCore {
  final String claudeApiKey;
  final AgentMemory _memory;
  final AgentProgressCallback? onProgress;

  // TODO Phase 1 완료 후 활성화
  // final ToolRegistry _tools;
  // final ClaudeApiService _claude;

  AgentCore({
    required this.claudeApiKey,
    AgentMemory? memory,
    this.onProgress,
  }) : _memory = memory ?? AgentMemory();

  // ─── 공개 API ────────────────────────────────────────

  /// 사용자의 의도를 받아 PDCA 루프 실행
  /// Plan → Do → Check → Act
  Future<AgentResult> handle(AgentIntent intent) async {
    final stopwatch = Stopwatch()..start();
    _memory.setCurrentIntent(intent);
    _notify('시작', '${intent.typeLabel} 처리 시작');

    try {
      // 0. 의도가 불명확하면 바로 되묻기
      if (intent.needsClarification) {
        return AgentResult.clarify(
          '요청을 조금 더 구체적으로 알려주실 수 있나요?\n'
          '예: "김철수 선생님 면담 음성 파일 등록해줘"',
        );
      }

      // 1. PLAN: Claude가 실행 계획 수립
      _notify('계획', '처리 계획을 수립하는 중...');
      final plan = await _plan(intent);
      if (plan == null) {
        return AgentResult.failed('계획 수립 실패: Claude API 응답 오류');
      }

      // 2. DO: 계획에 따라 툴 순차 실행
      _notify('실행', '${plan.steps.length}개 단계 실행 중...');
      final toolResults = await _execute(plan);

      // 3. CHECK: 결과 품질 자동 검증
      _notify('검증', '결과 품질 검증 중...');
      final checkResult = _verify(intent, toolResults);

      // 4. ACT: 검증 결과에 따라 저장 or 검토 요청 or 재시도
      _notify('완료', '처리 완료');
      final finalResult = await _act(intent, toolResults, checkResult);

      stopwatch.stop();
      final result = _attachTiming(finalResult, stopwatch.elapsed);
      _memory.logTask(intent, result);
      _memory.clearCurrentIntent();
      return result;

    } catch (e) {
      stopwatch.stop();
      final error = AgentResult.failed('예기치 않은 오류: $e');
      _memory.logTask(intent, error);
      _memory.clearCurrentIntent();
      return error;
    }
  }

  /// 에이전트 대화 히스토리 초기화
  void clearSession() => _memory.clearSession();

  /// 특정 Intent 타입의 최근 성공률 반환 (디버그/UI용)
  double getSuccessRate(IntentType type) => _memory.successRate(type);

  // ─── PDCA 내부 단계 ──────────────────────────────────

  /// [P] Plan: Claude API로 실행 계획 수립
  Future<_ExecutionPlan?> _plan(AgentIntent intent) async {
    // TODO: 실제 Claude API 호출로 교체 (Phase 2)
    // 현재는 Intent 타입별 기본 계획 반환 (Phase 1 임시)
    return _buildDefaultPlan(intent);
  }

  /// [D] Do: 계획의 각 단계를 순서대로 실행
  Future<List<ToolCallResult>> _execute(_ExecutionPlan plan) async {
    final results = <ToolCallResult>[];

    for (final step in plan.steps) {
      _notify('실행', '${step.toolName} 실행 중...');
      final stepTimer = Stopwatch()..start();

      try {
        // TODO: 실제 ToolRegistry 호출로 교체 (Phase 1 후반)
        // final tool = _tools.get(step.toolName);
        // final output = await tool.execute(step.params);
        final output = await _mockToolCall(step.toolName, step.params);
        stepTimer.stop();

        results.add(ToolCallResult(
          toolName: step.toolName,
          success: true,
          output: output,
          executionTime: stepTimer.elapsed,
        ));

        // 이전 단계 출력을 다음 단계 파라미터에 연결
        _chainOutputs(step, output, plan);

      } catch (e) {
        stepTimer.stop();
        results.add(ToolCallResult(
          toolName: step.toolName,
          success: false,
          errorMessage: e.toString(),
          executionTime: stepTimer.elapsed,
        ));

        // 필수 단계 실패 시 즉시 중단
        if (step.required) break;
      }
    }

    return results;
  }

  /// [C] Check: 결과 완전성·품질 자동 검증
  _CheckResult _verify(AgentIntent intent, List<ToolCallResult> results) {
    final failed = results.where((r) => !r.success).toList();
    final succeeded = results.where((r) => r.success).toList();

    // 실패한 필수 단계가 있으면 검토 필요
    if (failed.isNotEmpty) {
      return _CheckResult(
        passed: false,
        reason: '${failed.map((r) => r.toolName).join(', ')} 단계 실패',
        needsHumanReview: true,
      );
    }

    // 등록 의도인데 저장 단계가 없으면 검토 필요
    if (intent.type == IntentType.registerRecord) {
      final hasSave = succeeded.any((r) => r.toolName == 'save_record');
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

  /// [A] Act: 검증 결과에 따라 최종 처리
  Future<AgentResult> _act(
    AgentIntent intent,
    List<ToolCallResult> toolResults,
    _CheckResult check,
  ) async {
    if (!check.passed) {
      // 검토 필요한 경우 사람에게 전달
      if (check.needsHumanReview) {
        return AgentResult.pendingReview(
          toolCallResults: toolResults,
          reviewContent: check.reason ?? '처리 결과를 검토해주세요',
          summary: _buildSummary(intent, toolResults),
        );
      }
      return AgentResult.failed(check.reason ?? '검증 실패', completed: toolResults);
    }

    // 성공: 저장된 기록 ID 추출
    final saveResult = toolResults
        .where((r) => r.toolName == 'save_record' && r.success)
        .firstOrNull;

    return AgentResult.success(
      toolCallResults: toolResults,
      savedRecordId: saveResult?.output?['recordId'] as String?,
      summary: _buildSummary(intent, toolResults),
    );
  }

  // ─── 헬퍼 메서드 ─────────────────────────────────────

  void _notify(String step, String detail) {
    onProgress?.call(step, detail);
  }

  /// 이전 단계 출력을 다음 단계 파라미터로 자동 연결
  void _chainOutputs(
      _PlanStep step, dynamic output, _ExecutionPlan plan) {
    if (output == null) return;
    final outputMap = output is Map ? output : {'result': output};

    for (final next in plan.steps) {
      // transcribe 결과 → summarize 입력으로 자동 연결
      if (step.toolName == 'transcribe' && next.toolName == 'summarize') {
        next.params['text'] = outputMap['transcript'];
      }
      // summarize 결과 → save_record 입력으로 자동 연결
      if (step.toolName == 'summarize' && next.toolName == 'save_record') {
        next.params['summary'] = outputMap['summary'];
      }
      // tag 결과 → save_record 입력으로 자동 연결
      if (step.toolName == 'tag' && next.toolName == 'save_record') {
        next.params['tags'] = outputMap['tags'];
      }
    }
  }

  /// 사용자에게 보여줄 요약 문장 생성
  String _buildSummary(AgentIntent intent, List<ToolCallResult> results) {
    final successCount = results.where((r) => r.success).length;
    final totalMs = results.fold<int>(
        0, (sum, r) => sum + r.executionTime.inMilliseconds);

    return '${intent.typeLabel} 완료: '
        '$successCount/${results.length}단계 성공 '
        '(${(totalMs / 1000).toStringAsFixed(1)}초)';
  }

  /// 타이밍 정보 부착
  AgentResult _attachTiming(AgentResult result, Duration elapsed) {
    return AgentResult(
      status: result.status,
      toolCallResults: result.toolCallResults,
      savedRecordId: result.savedRecordId,
      summary: result.summary,
      clarificationQuestion: result.clarificationQuestion,
      reviewContent: result.reviewContent,
      errorMessage: result.errorMessage,
      totalTime: elapsed,
    );
  }

  // ─── 기본 계획 빌더 (Phase 2에서 Claude API로 교체) ──

  _ExecutionPlan _buildDefaultPlan(AgentIntent intent) {
    switch (intent.type) {
      case IntentType.registerRecord:
        return _planForRegister(intent.params);

      case IntentType.searchRecord:
        return _ExecutionPlan(steps: [
          _PlanStep(toolName: 'search', params: Map.from(intent.params)),
        ]);

      case IntentType.generateContent:
        return _ExecutionPlan(steps: [
          _PlanStep(toolName: 'generate_doc', params: Map.from(intent.params)),
        ]);

      case IntentType.exportData:
        return _ExecutionPlan(steps: [
          _PlanStep(toolName: 'export', params: Map.from(intent.params)),
        ]);

      default:
        return _ExecutionPlan(steps: []);
    }
  }

  /// 파일 등록 계획: 파일 타입에 따라 전사 단계 포함 여부 결정
  _ExecutionPlan _planForRegister(Map<String, dynamic> params) {
    final filePath = params['filePath'] as String? ?? '';
    final ext = filePath.split('.').last.toLowerCase();
    final isMediaFile = ['mp3', 'mp4', 'wav', 'm4a', 'webm', 'mov'].contains(ext);
    final isPdf = ext == 'pdf';
    final isDocx = ext == 'docx';

    final steps = <_PlanStep>[];

    // 1단계: 미디어 → 전사, PDF/DOCX → 텍스트 추출
    if (isMediaFile) {
      steps.add(_PlanStep(
        toolName: 'transcribe',
        params: {'filePath': filePath},
        required: true,
      ));
    } else if (isPdf) {
      steps.add(_PlanStep(
        toolName: 'extract_pdf',
        params: {'filePath': filePath},
        required: true,
      ));
    } else if (isDocx) {
      steps.add(_PlanStep(
        toolName: 'extract_docx',
        params: {'filePath': filePath},
        required: true,
      ));
    }

    // 2단계: AI 요약 (항상 실행)
    steps.add(_PlanStep(
      toolName: 'summarize',
      params: {'text': params['text'] ?? ''},
    ));

    // 3단계: 자동 태그 생성
    steps.add(_PlanStep(
      toolName: 'tag',
      params: {},
    ));

    // 4단계: 인물사전 자동 연결
    steps.add(_PlanStep(
      toolName: 'link_person',
      params: {},
    ));

    // 5단계: DB 저장 (필수)
    steps.add(_PlanStep(
      toolName: 'save_record',
      params: Map.from(params),
      required: true,
    ));

    return _ExecutionPlan(steps: steps);
  }

  // ─── 목 툴 호출 (Phase 1 임시, Phase 1 후반에 실제 툴로 교체) ──

  Future<Map<String, dynamic>> _mockToolCall(
      String toolName, Map<String, dynamic> params) async {
    // 실제 툴 연동 전 개발·테스트용 목 응답
    await Future.delayed(const Duration(milliseconds: 300));

    switch (toolName) {
      case 'transcribe':
        return {
          'transcript': '[목 전사] 안녕하세요. 오늘 면담을 시작하겠습니다...',
          'duration': 3600,
          'language': 'ko',
        };
      case 'extract_pdf':
      case 'extract_docx':
        return {'transcript': '[목 텍스트 추출] 문서 내용...'};
      case 'summarize':
        return {'summary': '[목 요약] 이 기록은 구술자의 생애 초기 경험에 관한 내용입니다.'};
      case 'tag':
        return {'tags': ['생애사', '구술', '면담']};
      case 'link_person':
        return {'personIds': [], 'newPersons': []};
      case 'save_record':
        return {'recordId': 'REC-${DateTime.now().millisecondsSinceEpoch}'};
      case 'search':
        return {'results': [], 'total': 0};
      case 'export':
        return {'filePath': '/exports/export.csv'};
      case 'generate_doc':
        return {'filePath': '/outputs/report.docx'};
      default:
        throw Exception('알 수 없는 툴: $toolName');
    }
  }
}

// ─── 내부 데이터 클래스 ───────────────────────────────

class _PlanStep {
  final String toolName;
  Map<String, dynamic> params; // mutable: chaining으로 업데이트됨
  final bool required;

  _PlanStep({
    required this.toolName,
    required this.params,
    this.required = false,
  });
}

class _ExecutionPlan {
  final List<_PlanStep> steps;
  _ExecutionPlan({required this.steps});
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
