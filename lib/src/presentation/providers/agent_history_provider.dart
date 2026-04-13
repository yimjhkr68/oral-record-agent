// lib/src/presentation/providers/agent_history_provider.dart
// 에이전트 실행 이력 StateNotifier + Hive Box<String> 저장

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../../../agents/core/agent_history.dart';

const _kBoxName = 'agent_history';
const _kMaxEntries = 100;

class AgentHistoryNotifier
    extends StateNotifier<List<AgentHistoryEntry>> {
  AgentHistoryNotifier() : super([]) {
    _load();
  }

  void _load() {
    if (!Hive.isBoxOpen(_kBoxName)) return;
    final box = Hive.box<String>(_kBoxName);
    final entries = box.values
        .map((json) {
          try {
            return AgentHistoryEntry.fromJsonString(json);
          } catch (_) {
            return null;
          }
        })
        .whereType<AgentHistoryEntry>()
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = entries;
  }

  Future<void> addEntry(AgentHistoryEntry entry) async {
    final newList = [entry, ...state];
    if (newList.length > _kMaxEntries) {
      newList.removeRange(_kMaxEntries, newList.length);
    }
    state = newList;
    if (Hive.isBoxOpen(_kBoxName)) {
      await Hive.box<String>(_kBoxName).put(entry.id, entry.toJsonString());
    }
  }

  Future<void> clear() async {
    state = [];
    if (Hive.isBoxOpen(_kBoxName)) {
      await Hive.box<String>(_kBoxName).clear();
    }
  }
}

final agentHistoryProvider =
    StateNotifierProvider<AgentHistoryNotifier, List<AgentHistoryEntry>>(
  (_) => AgentHistoryNotifier(),
);
