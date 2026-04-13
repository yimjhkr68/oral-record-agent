// 파일 목적: Record Repository 구현 (데이터 액세스 계층)

import 'package:oral_record_agent/src/data/models/record.dart';
import 'package:oral_record_agent/src/data/models/narrator.dart';
import 'package:oral_record_agent/src/data/models/search_filters.dart';
import 'package:oral_record_agent/src/data/services/display_id_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

abstract class RecordRepository {
  /// 기록 생성
  Future<String> createRecord(Record record);

  /// 기록 조회 (ID)
  Future<Record?> getRecord(String id);

  /// 기록 목록 조회 (필터 + 페이징)
  Future<List<Record>> searchRecords(SearchFilters filters);

  /// 기록 업데이트
  Future<void> updateRecord(String id, Record record);

  /// 기록 삭제
  Future<void> deleteRecord(String id);

  /// 전체 기록 수
  Future<int> getTotalRecordCount();

  /// 최근 N개 기록 조회
  Future<List<Record>> getRecentRecords(int limit);

  /// 파일 해시로 기존 기록 조회 (중복 감지)
  Future<Record?> findByFileHash(String hash);
}

class HiveRecordRepository implements RecordRepository {
  final Box<Record> _recordBox;
  final Box<Narrator>? _narratorBox;

  HiveRecordRepository(this._recordBox, [this._narratorBox]);

  @override
  Future<String> createRecord(Record record) async {
    try {
      final recordToSave = record.displayId == null
          ? record.copyWith(displayId: _generateDisplayId(record.createdAt))
          : record;
      await _recordBox.put(recordToSave.id, recordToSave);
      return recordToSave.id;
    } catch (e) {
      throw Exception('Failed to create record: $e');
    }
  }

  String _generateDisplayId(DateTime date) {
    final existingIds = _recordBox.values
        .map((r) => r.displayId)
        .whereType<String>()
        .toList();
    return DisplayIdService.generateRecordId(date, existingIds);
  }

  @override
  Future<Record?> getRecord(String id) async {
    try {
      return _recordBox.get(id);
    } catch (e) {
      throw Exception('Failed to get record: $e');
    }
  }

  @override
  Future<List<Record>> searchRecords(SearchFilters filters) async {
    try {
      var results = _recordBox.values.toList();

      // 구술자 필터
      if (filters.narratorId != null) {
        results =
            results.where((r) => r.narratorId == filters.narratorId).toList();
      }

      // 날짜 범위 필터
      if (filters.startDate != null) {
        results = results
            .where((r) => r.createdAt.isAfter(filters.startDate!))
            .toList();
      }
      if (filters.endDate != null) {
        results = results
            .where((r) => r.createdAt.isBefore(filters.endDate!))
            .toList();
      }

      // 주제 필터
      if (filters.mainCategory != null) {
        results = results
            .where((r) => r.mainCategory == filters.mainCategory)
            .toList();
      }

      // 텍스트 검색 (제목, displayId, 구술자 이름)
      if (filters.query != null && filters.query!.isNotEmpty) {
        final q = filters.query!.toLowerCase();
        results = results.where((r) {
          if (r.title.toLowerCase().contains(q)) return true;
          if (r.displayId != null && r.displayId!.toLowerCase().contains(q)) return true;
          // 구술자 이름으로도 검색
          final narrator = _narratorBox?.get(r.narratorId);
          if (narrator != null && narrator.name.toLowerCase().contains(q)) return true;
          return false;
        }).toList();
      }

      // 날짜 내림차순 정렬 (최신 기록 먼저)
      results.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // 페이징
      final offset = filters.offset;
      final limit = filters.limit;
      return results.skip(offset).take(limit).toList();
    } catch (e) {
      throw Exception('Failed to search records: $e');
    }
  }

  @override
  Future<void> updateRecord(String id, Record record) async {
    try {
      await _recordBox.put(id, record);
    } catch (e) {
      throw Exception('Failed to update record: $e');
    }
  }

  @override
  Future<void> deleteRecord(String id) async {
    try {
      await _recordBox.delete(id);
    } catch (e) {
      throw Exception('Failed to delete record: $e');
    }
  }

  @override
  Future<int> getTotalRecordCount() async {
    try {
      return _recordBox.length;
    } catch (e) {
      throw Exception('Failed to get record count: $e');
    }
  }

  @override
  Future<List<Record>> getRecentRecords(int limit) async {
    try {
      final records = _recordBox.values.toList();
      records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return records.take(limit).toList();
    } catch (e) {
      throw Exception('Failed to get recent records: $e');
    }
  }

  @override
  Future<Record?> findByFileHash(String hash) async {
    return _recordBox.values
        .where((r) => r.fileHash == hash)
        .firstOrNull;
  }
}
