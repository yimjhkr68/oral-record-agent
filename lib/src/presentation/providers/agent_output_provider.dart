// lib/src/presentation/providers/agent_output_provider.dart
// 에이전트 산출물 StateNotifier + Hive Box<String> 'agent_outputs' 저장

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../../../agents/core/agent_output.dart';

const _kBoxName = 'agent_outputs';
const _kMaxEntries = 500;

class AgentOutputNotifier extends StateNotifier<List<AgentOutput>> {
  AgentOutputNotifier() : super([]) {
    _load();
  }

  void _load() {
    if (!Hive.isBoxOpen(_kBoxName)) return;
    final box = Hive.box<String>(_kBoxName);
    final entries = box.values
        .map((json) {
          try {
            return AgentOutput.fromJsonString(json);
          } catch (_) {
            return null;
          }
        })
        .whereType<AgentOutput>()
        .toList()
      ..sort((a, b) => b.executedAt.compareTo(a.executedAt));
    state = entries;
  }

  Future<void> addOutput(AgentOutput output) async {
    final newList = [output, ...state];
    if (newList.length > _kMaxEntries) {
      newList.removeRange(_kMaxEntries, newList.length);
    }
    state = newList;
    if (Hive.isBoxOpen(_kBoxName)) {
      await Hive.box<String>(_kBoxName).put(output.id, output.toJsonString());
    }
  }

  Future<void> deleteOutput(String id) async {
    state = state.where((o) => o.id != id).toList();
    if (Hive.isBoxOpen(_kBoxName)) {
      await Hive.box<String>(_kBoxName).delete(id);
    }
  }

  Future<void> clearAll() async {
    state = [];
    if (Hive.isBoxOpen(_kBoxName)) {
      await Hive.box<String>(_kBoxName).clear();
    }
  }

  Future<void> refreshFileStatus() async {
    final updated = <AgentOutput>[];
    for (final o in state) {
      await o.refreshExists();
      updated.add(o);
    }
    state = List.from(updated);
    // 갱신된 상태를 Hive에 저장
    if (Hive.isBoxOpen(_kBoxName)) {
      final box = Hive.box<String>(_kBoxName);
      for (final o in updated) {
        await box.put(o.id, o.toJsonString());
      }
    }
  }
}

final agentOutputProvider =
    StateNotifierProvider<AgentOutputNotifier, List<AgentOutput>>(
  (_) => AgentOutputNotifier(),
);
