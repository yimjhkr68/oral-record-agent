// lib/agents/core/agent_history.dart
// 에이전트 실행 이력 모델 (Hive Box<String> JSON 직렬화 방식)

import 'dart:convert';

enum AgentHistoryStatus { success, failed, cancelled }

class HistoryLogItem {
  final String step;
  final String detail;
  final bool isError;
  final DateTime timestamp;

  const HistoryLogItem({
    required this.step,
    required this.detail,
    this.isError = false,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'step': step,
        'detail': detail,
        'isError': isError,
        'ts': timestamp.millisecondsSinceEpoch,
      };

  factory HistoryLogItem.fromMap(Map<String, dynamic> m) => HistoryLogItem(
        step: m['step'] as String? ?? '',
        detail: m['detail'] as String? ?? '',
        isError: m['isError'] as bool? ?? false,
        timestamp:
            DateTime.fromMillisecondsSinceEpoch(m['ts'] as int? ?? 0),
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
