// lib/agents/core/agent_result.dart
// 에이전트 실행 결과 및 상태 데이터 모델

/// 에이전트 작업의 최종 상태
enum AgentStatus {
  success,             // 완료, 저장됨
  pendingReview,       // 완료됐지만 사람의 검토 필요
  needsClarification,  // 의도 불명확 → 사용자에게 질문
  partialSuccess,      // 일부 단계만 성공
  duplicateDetected,   // 중복 파일 감지 → OCR/전사 건너뜀
  failed,              // 실패
}

/// 개별 툴 실행 결과
class ToolCallResult {
  final String toolName;
  final bool success;
  final dynamic output;          // 툴 실행 결과값
  final String? errorMessage;
  final Duration executionTime;

  const ToolCallResult({
    required this.toolName,
    required this.success,
    this.output,
    this.errorMessage,
    this.executionTime = Duration.zero,
  });

  @override
  String toString() => success
      ? 'ToolCallResult($toolName: 성공, ${executionTime.inMilliseconds}ms)'
      : 'ToolCallResult($toolName: 실패 - $errorMessage)';
}

/// 에이전트 전체 실행의 최종 결과
class AgentResult {
  final AgentStatus status;
  final List<ToolCallResult> toolCallResults; // 각 단계 실행 결과
  final String? savedRecordId;               // 저장된 기록 ID (등록 성공 시)
  final String? summary;                     // 사용자에게 보여줄 요약
  final String? clarificationQuestion;       // 사용자에게 되물을 질문
  final String? reviewContent;               // 검토 요청 내용
  final String? errorMessage;
  final Duration totalTime;

  const AgentResult({
    required this.status,
    this.toolCallResults = const [],
    this.savedRecordId,
    this.summary,
    this.clarificationQuestion,
    this.reviewContent,
    this.errorMessage,
    this.totalTime = Duration.zero,
  });

  bool get isSuccess => status == AgentStatus.success;
  bool get needsHumanAction =>
      status == AgentStatus.pendingReview ||
      status == AgentStatus.needsClarification;

  /// 성공 결과 팩토리
  factory AgentResult.success({
    required List<ToolCallResult> toolCallResults,
    String? savedRecordId,
    String? summary,
    Duration totalTime = Duration.zero,
  }) =>
      AgentResult(
        status: AgentStatus.success,
        toolCallResults: toolCallResults,
        savedRecordId: savedRecordId,
        summary: summary,
        totalTime: totalTime,
      );

  /// 검토 요청 결과 팩토리
  factory AgentResult.pendingReview({
    required List<ToolCallResult> toolCallResults,
    required String reviewContent,
    String? summary,
  }) =>
      AgentResult(
        status: AgentStatus.pendingReview,
        toolCallResults: toolCallResults,
        reviewContent: reviewContent,
        summary: summary,
      );

  /// 사용자 확인 요청 결과 팩토리
  factory AgentResult.clarify(String question) => AgentResult(
        status: AgentStatus.needsClarification,
        clarificationQuestion: question,
      );

  /// 실패 결과 팩토리
  factory AgentResult.failed(String error, {List<ToolCallResult> completed = const []}) =>
      AgentResult(
        status: AgentStatus.failed,
        toolCallResults: completed,
        errorMessage: error,
      );

  @override
  String toString() => 'AgentResult(status: $status, '
      'steps: ${toolCallResults.length}, '
      'time: ${totalTime.inMilliseconds}ms)';
}
