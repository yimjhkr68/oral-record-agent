// lib/agents/core/agent_history.dart
// 에이전트 실행 이력 모델 (Hive Box<String> JSON 직렬화 방식)

import 'dart:convert';

enum AgentHistoryStatus { success, failed, cancelled, noResults }

/// 로그 항목 유형 — AgentLogEntry.logType 및 HistoryLogItem.logType과 공유
enum HistoryLogType {
  promptOriginal,   // 사용자 원본 프롬프트
  promptEnhanced,   // AI 개선 프롬프트
  promptExecuted,   // 실제 실행된 프롬프트
  searchQuery,      // 검색어
  searchResult,     // 검색 결과 요약
  searchConfirmed,  // 사용자가 선택한 기록 목록
  toolStart,
  toolSuccess,
  toolError,
  agentPlan,
  agentComplete,
}

class HistoryLogItem {
  final String step;
  final String detail;
  final bool isError;
  final DateTime timestamp;
  final String? logType; // HistoryLogType.name

  const HistoryLogItem({
    required this.step,
    required this.detail,
    this.isError = false,
    required this.timestamp,
    this.logType,
  });

  Map<String, dynamic> toMap() => {
        'step': step,
        'detail': detail,
        'isError': isError,
        'ts': timestamp.millisecondsSinceEpoch,
        if (logType != null) 'logType': logType,
      };

  factory HistoryLogItem.fromMap(Map<String, dynamic> m) => HistoryLogItem(
        step: m['step'] as String? ?? '',
        detail: m['detail'] as String? ?? '',
        isError: m['isError'] as bool? ?? false,
        timestamp: DateTime.fromMillisecondsSinceEpoch(m['ts'] as int? ?? 0),
        logType: m['logType'] as String?,
      );
}

class AgentHistoryEntry {
  final String id;
  final String title;
  final String inputText;
  final AgentHistoryStatus status;
  final DateTime createdAt;
  final List<HistoryLogItem> steps;
  final String? savedRecordId;

  const AgentHistoryEntry({
    required this.id,
    required this.title,
    required this.inputText,
    required this.status,
    required this.createdAt,
    required this.steps,
    this.savedRecordId,
  });

  factory AgentHistoryEntry.create({
    required String inputText,
    required AgentHistoryStatus status,
    required List<HistoryLogItem> steps,
    String? savedRecordId,
  }) {
    final now = DateTime.now();
    final title =
        inputText.length > 30 ? '${inputText.substring(0, 30)}...' : inputText;
    return AgentHistoryEntry(
      id: '${now.millisecondsSinceEpoch}',
      title: title,
      inputText: inputText,
      status: status,
      createdAt: now,
      steps: steps,
      savedRecordId: savedRecordId,
    );
  }

  String toJsonString() => jsonEncode({
        'id': id,
        'title': title,
        'inputText': inputText,
        'status': status.index,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'steps': steps.map((s) => s.toMap()).toList(),
        'savedRecordId': savedRecordId,
      });

  factory AgentHistoryEntry.fromJsonString(String jsonStr) {
    final m = jsonDecode(jsonStr) as Map<String, dynamic>;
    final rawSteps = m['steps'] as List? ?? [];
    return AgentHistoryEntry(
      id: m['id'] as String,
      title: m['title'] as String,
      inputText: m['inputText'] as String,
      status: AgentHistoryStatus.values[m['status'] as int? ?? 0],
      createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
      steps: rawSteps
          .map((s) => HistoryLogItem.fromMap(s as Map<String, dynamic>))
          .toList(),
      savedRecordId: m['savedRecordId'] as String?,
    );
  }
}
