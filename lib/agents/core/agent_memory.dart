// lib/agents/core/agent_memory.dart
// 에이전트의 단기 기억 및 대화 컨텍스트 관리

import 'agent_intent.dart';
import 'agent_result.dart';

/// Claude API에 전달할 메시지 형식
class AgentMessage {
  final String role;    // 'user' | 'assistant'
  final String content;
  final DateTime timestamp;

  AgentMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toApiMap() => {
        'role': role,
        'content': content,
      };
}

/// 완료된 태스크 로그 (재시도·오류 패턴 파악용)
class TaskLog {
  final AgentIntent intent;
  final AgentResult result;
  final DateTime completedAt;

  const TaskLog({
    required this.intent,
    required this.result,
    required this.completedAt,
  });
}

/// 에이전트 단기 메모리
/// - 현재 세션의 대화 히스토리 보관
/// - Claude API 컨텍스트 윈도우 관리
/// - 최근 태스크 로그 유지
class AgentMemory {
  // 대화 히스토리 (Claude API context로 전달)
  final List<AgentMessage> _conversationHistory = [];

  // 최근 완료 태스크 로그 (최대 20개 유지)
  final List<TaskLog> _recentLogs = [];

  // 현재 진행 중인 태스크 컨텍스트
  AgentIntent? _currentIntent;

  static const int _maxHistoryLength = 20; // 토큰 절약을 위해 제한
  static const int _maxLogCount = 20;

  // ─── 대화 히스토리 ──────────────────────────────────

  void addUserMessage(String content) {
    _conversationHistory.add(AgentMessage(role: 'user', content: content));
    _trimHistory();
  }

  void addAssistantMessage(String content) {
    _conversationHistory.add(AgentMessage(role: 'assistant', content: content));
    _trimHistory();
  }

  /// Claude API에 전달할 messages 배열 반환
  List<Map<String, dynamic>> buildApiMessages(String userPrompt) {
    final messages = _conversationHistory
        .map((m) => m.toApiMap())
        .toList();
    messages.add({'role': 'user', 'content': userPrompt});
    return messages;
  }

  void _trimHistory() {
    if (_conversationHistory.length > _maxHistoryLength) {
      // 앞에서 2개씩 제거 (user+assistant 쌍)
      _conversationHistory.removeRange(0, 2);
    }
  }

  // ─── 태스크 컨텍스트 ─────────────────────────────────

  void setCurrentIntent(AgentIntent intent) {
    _currentIntent = intent;
  }

  void clearCurrentIntent() {
    _currentIntent = null;
  }

  AgentIntent? get currentIntent => _currentIntent;

  // ─── 태스크 로그 ──────────────────────────────────────

  void logTask(AgentIntent intent, AgentResult result) {
    _recentLogs.add(TaskLog(
      intent: intent,
      result: result,
      completedAt: DateTime.now(),
    ));
    if (_recentLogs.length > _maxLogCount) {
      _recentLogs.removeAt(0);
    }
  }

  List<TaskLog> get recentLogs => List.unmodifiable(_recentLogs);

  /// 특정 Intent 타입의 최근 성공률 계산 (에이전트 학습 힌트)
  double successRate(IntentType type) {
    final relevant = _recentLogs.where((l) => l.intent.type == type).toList();
    if (relevant.isEmpty) return 1.0;
    final successes = relevant.where((l) => l.result.isSuccess).length;
    return successes / relevant.length;
  }

  // ─── 세션 초기화 ──────────────────────────────────────

  void clearSession() {
    _conversationHistory.clear();
    _currentIntent = null;
    // recentLogs는 유지 (세션 간 학습용)
  }

  int get historyLength => _conversationHistory.length;
}
