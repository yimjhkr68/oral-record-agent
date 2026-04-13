import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/record_api.dart';
import '../models/oral_record.dart';

final recordApiProvider = Provider<RecordApi>((ref) {
  return RecordApi(ref.read(apiClientProvider));
});

// 기록 목록 상태
class RecordListState {
  final List<OralRecord> records;
  final bool loading;
  final String? error;

  const RecordListState({
    this.records = const [],
    this.loading = false,
    this.error,
  });

  RecordListState copyWith({
    List<OralRecord>? records,
    bool? loading,
    String? error,
  }) =>
      RecordListState(
        records: records ?? this.records,
        loading: loading ?? this.loading,
        error: error,
      );
}

class RecordListNotifier extends StateNotifier<RecordListState> {
  final RecordApi _api;

  RecordListNotifier(this._api) : super(const RecordListState()) {
    load();
  }

  Future<void> load({
    String q = '',
    String sourceType = '',
    String source = '',
  }) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final records = await _api.list(
        q: q,
        sourceType: sourceType,
        source: source,
      );
      state = state.copyWith(records: records, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<OralRecord?> createText({
    required String title,
    required String content,
    String note = '',
  }) async {
    try {
      final record = await _api.createText(
          title: title, content: content, note: note);
      await load();
      return record;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<OralRecord?> createFileFromBytes({
    required List<int> bytes,
    required String fileName,
    String note = '',
    String source = 'manual',
  }) async {
    try {
      final record = await _api.createFileFromBytes(
        bytes: bytes,
        fileName: fileName,
        note: note,
        source: source,
      );
      await load();
      return record;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<bool> delete(String id) async {
    try {
      await _api.delete(id);
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<OralRecord?> update(String id,
      {String? title, String? note}) async {
    try {
      final record = await _api.update(id, title: title, note: note);
      await load();
      return record;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }
}

final recordListProvider =
    StateNotifierProvider<RecordListNotifier, RecordListState>((ref) {
  return RecordListNotifier(ref.read(recordApiProvider));
});
