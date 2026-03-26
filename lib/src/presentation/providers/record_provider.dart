// 파일 목적: 기록 관련 Riverpod Providers
// RecordRepository를 통한 데이터 제공 및 상태 관리

import 'package:riverpod/riverpod.dart';
import '../../data/models/record.dart';
import '../../data/models/search_filters.dart';
import '../../data/repositories/repository_provider.dart';
import '../../data/services/display_id_service.dart';

/// 기록 목록 Provider (필터 적용, 앱 생명주기 동안 캐시 유지)
final recordListProvider =
    FutureProvider.family<List<Record>, SearchFilters>(
  (ref, SearchFilters filters) async {
    final repository = await ref.watch(recordRepositoryProvider.future);
    return repository.searchRecords(filters);
  },
);

/// 기록 상세 정보 Provider
final recordDetailProvider = FutureProvider.family<Record, String>(
  (ref, String recordId) async {
    final repository = await ref.watch(recordRepositoryProvider.future);
    final record = await repository.getRecord(recordId);
    if (record == null) throw Exception('Record not found: $recordId');
    return record;
  },
);

/// 최근 기록 N건 Provider (홈 화면용)
/// 저장 완료 후 ref.invalidate(recentRecordsProvider)로 갱신 필요
final recentRecordsProvider = FutureProvider<List<Record>>(
  (ref) async {
    final repository = await ref.watch(recordRepositoryProvider.future);
    return repository.getRecentRecords(10);
  },
);

/// 기록 폼 상태 관리 (저장 / 삭제)
class RecordFormNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  RecordFormNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> saveRecord(Record record) async {
    state = const AsyncValue.loading();
    try {
      final repo = await _ref.read(recordRepositoryProvider.future);
      // displayId가 없으면 새로 생성
      Record toSave = record;
      if (record.displayId == null) {
        final all = await repo.searchRecords(SearchFilters(limit: 100000));
        final existingIds = all
            .where((r) => r.displayId != null)
            .map((r) => r.displayId!)
            .toList();
        final newDisplayId = DisplayIdService.generateRecordId(
            record.createdAt, existingIds);
        toSave = record.copyWith(displayId: newDisplayId);
      }
      await repo.createRecord(toSave);
      _invalidateLists();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// 기록 삭제: Hive 텍스트 데이터 + FileStorage 파일 바이트 모두 삭제
  Future<void> deleteRecord(String recordId) async {
    state = const AsyncValue.loading();
    try {
      final repo = await _ref.read(recordRepositoryProvider.future);
      await repo.deleteRecord(recordId);

      final fileStorage = _ref.read(fileStorageProvider);
      await fileStorage.deleteFile(recordId);

      _invalidateLists();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _invalidateLists() {
    _ref.invalidate(recentRecordsProvider);
    _ref.invalidate(recordListProvider);
  }
}

final recordFormProvider =
    StateNotifierProvider<RecordFormNotifier, AsyncValue<void>>(
  (ref) => RecordFormNotifier(ref),
);
