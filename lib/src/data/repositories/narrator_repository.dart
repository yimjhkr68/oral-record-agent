// 파일 목적: Narrator Repository 구현

import 'package:oral_record_agent/src/data/models/narrator.dart';
import 'package:hive_flutter/hive_flutter.dart';

abstract class NarratorRepository {
  Future<String> createNarrator(Narrator narrator);
  Future<Narrator?> getNarrator(String id);
  Future<List<Narrator>> getAllNarrators();
  Future<void> updateNarrator(String id, Narrator narrator);
  Future<void> deleteNarrator(String id);
  Future<int> getTotalNarratorCount();
}

class HiveNarratorRepository implements NarratorRepository {
  final Box<Narrator> _narratorBox;

  HiveNarratorRepository(this._narratorBox);

  @override
  Future<String> createNarrator(Narrator narrator) async {
    try {
      await _narratorBox.put(narrator.id, narrator);
      return narrator.id;
    } catch (e) {
      throw Exception('Failed to create narrator: $e');
    }
  }

  @override
  Future<Narrator?> getNarrator(String id) async {
    try {
      return _narratorBox.get(id);
    } catch (e) {
      throw Exception('Failed to get narrator: $e');
    }
  }

  @override
  Future<List<Narrator>> getAllNarrators() async {
    try {
      return _narratorBox.values.toList();
    } catch (e) {
      throw Exception('Failed to get all narrators: $e');
    }
  }

  @override
  Future<void> updateNarrator(String id, Narrator narrator) async {
    try {
      await _narratorBox.put(id, narrator);
    } catch (e) {
      throw Exception('Failed to update narrator: $e');
    }
  }

  @override
  Future<void> deleteNarrator(String id) async {
    try {
      await _narratorBox.delete(id);
    } catch (e) {
      throw Exception('Failed to delete narrator: $e');
    }
  }

  @override
  Future<int> getTotalNarratorCount() async {
    try {
      return _narratorBox.length;
    } catch (e) {
      throw Exception('Failed to get narrator count: $e');
    }
  }
}
