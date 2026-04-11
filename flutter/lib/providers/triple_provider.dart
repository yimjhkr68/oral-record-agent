import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/triple_api.dart';
import '../models/triple.dart';

/// 현재 역할: 'viewer' | 'admin'
final roleProvider = StateProvider<String>((ref) => 'admin');

final tripleApiProvider = Provider<TripleApi>((ref) {
  final role = ref.watch(roleProvider);
  return TripleApi(ref.read(apiClientProvider), role: role);
});

// ── 기존 저장된 트리플 목록 ────────────────────────────────────────────────────
final tripleQueryProvider         = StateProvider<String>((ref) => '');
final tripleStatusProvider        = StateProvider<String>((ref) => 'active');
final tripleVersionFilterProvider = StateProvider<String?>((ref) => null);
final tripleSubjectTypeProvider   = StateProvider<String>((ref) => '');

final tripleListProvider = FutureProvider.autoDispose<List<Triple>>((ref) async {
  final q          = ref.watch(tripleQueryProvider);
  final status     = ref.watch(tripleStatusProvider);
  final version    = ref.watch(tripleVersionFilterProvider);
  final subjType   = ref.watch(tripleSubjectTypeProvider);
  return ref.read(tripleApiProvider).listTriples(
      q: q, status: status, version: version, subjectType: subjType);
});

/// 범주별 카운트 — Map<typeName, count>
final categoryCountProvider =
    FutureProvider.autoDispose<Map<String, int>>((ref) async {
  final version = ref.watch(tripleVersionFilterProvider);
  final status  = ref.watch(tripleStatusProvider);
  return ref.read(tripleApiProvider).getCategories(
      version: version, status: status);
});

// ── 트리플 작업 상태 (Step 1/2) ───────────────────────────────────────────────

class TripleWorkState {
  final String? selectedVersionId;
  final List<SourceRecord> sourceRecords;
  final List<PendingTriple> pendingTriples;
  final bool isExtracting;
  final int extractProgress;   // 처리 완료된 레코드 수
  final int extractTotal;
  final String extractStatus;  // 현재 처리 중인 레코드 ID
  final String? error;
  final int currentStep;       // 0=Step1, 1=Step2, 2=Step3
  // Step 2 검토 카운터
  final int editedCount;       // updatePending 호출 횟수
  final int deletedCount;      // removePending 호출 횟수
  final int addedCount;        // addPending 호출 횟수 (수동 추가)

  const TripleWorkState({
    this.selectedVersionId,
    this.sourceRecords = const [],
    this.pendingTriples = const [],
    this.isExtracting = false,
    this.extractProgress = 0,
    this.extractTotal = 0,
    this.extractStatus = '',
    this.error,
    this.currentStep = 0,
    this.editedCount = 0,
    this.deletedCount = 0,
    this.addedCount = 0,
  });

  bool get canExtract =>
      selectedVersionId != null && sourceRecords.isNotEmpty && !isExtracting;

  TripleWorkState copyWith({
    String? selectedVersionId,
    bool clearVersion = false,
    List<SourceRecord>? sourceRecords,
    List<PendingTriple>? pendingTriples,
    bool? isExtracting,
    int? extractProgress,
    int? extractTotal,
    String? extractStatus,
    String? error,
    bool clearError = false,
    int? currentStep,
    int? editedCount,
    int? deletedCount,
    int? addedCount,
    bool resetCounters = false,
  }) =>
      TripleWorkState(
        selectedVersionId:
            clearVersion ? null : (selectedVersionId ?? this.selectedVersionId),
        sourceRecords: sourceRecords ?? this.sourceRecords,
        pendingTriples: pendingTriples ?? this.pendingTriples,
        isExtracting: isExtracting ?? this.isExtracting,
        extractProgress: extractProgress ?? this.extractProgress,
        extractTotal: extractTotal ?? this.extractTotal,
        extractStatus: extractStatus ?? this.extractStatus,
        error: clearError ? null : (error ?? this.error),
        currentStep: currentStep ?? this.currentStep,
        editedCount:  resetCounters ? 0 : (editedCount  ?? this.editedCount),
        deletedCount: resetCounters ? 0 : (deletedCount ?? this.deletedCount),
        addedCount:   resetCounters ? 0 : (addedCount   ?? this.addedCount),
      );
}

class TripleWorkNotifier extends StateNotifier<TripleWorkState> {
  final TripleApi _api;
  TripleWorkNotifier(this._api) : super(const TripleWorkState());

  void setVersion(String versionId) =>
      state = state.copyWith(selectedVersionId: versionId);

  void addSourceRecord(SourceRecord record) => state = state.copyWith(
        sourceRecords: [...state.sourceRecords, record],
      );

  void removeSourceRecord(int index) {
    final list = List<SourceRecord>.from(state.sourceRecords);
    list.removeAt(index);
    state = state.copyWith(sourceRecords: list);
  }

  void clearSourceRecords() =>
      state = state.copyWith(sourceRecords: []);

  void setStep(int step) => state = state.copyWith(currentStep: step);

  // ── Step 1 → AI 추출 ────────────────────────────────────────────────────────
  Future<void> extractAll() async {
    if (!state.canExtract) return;
    final records = state.sourceRecords;
    state = state.copyWith(
      isExtracting: true,
      extractProgress: 0,
      extractTotal: records.length,
      extractStatus: '',
      pendingTriples: [],
      clearError: true,
      resetCounters: true,
    );

    final allPending = <PendingTriple>[];
    final errors = <String>[];

    for (int i = 0; i < records.length; i++) {
      final rec = records[i];
      state = state.copyWith(
        extractProgress: i,
        extractStatus: rec.id,
      );
      try {
        final result = await _api.extractTriples(
          rec.content,
          state.selectedVersionId!,
          sourceRecordId: rec.id,
        );
        final rawList = result['triples'] as List? ?? [];
        for (final t in rawList) {
          allPending.add(PendingTriple.fromJson(t as Map<String, dynamic>));
        }
      } on DioException catch (e) {
        if (e.type == DioExceptionType.receiveTimeout) {
          errors.add('${rec.id}: AI 응답 지연');
        } else {
          errors.add('${rec.id}: ${e.message}');
        }
      } catch (e) {
        errors.add('${rec.id}: $e');
      }
    }

    state = state.copyWith(
      isExtracting: false,
      extractProgress: records.length,
      extractStatus: '',
      pendingTriples: allPending,
      currentStep: 1, // Step 2로 자동 이동
      error: errors.isNotEmpty ? errors.join('\n') : null,
    );
  }

  // ── Step 2 — pending 편집 ───────────────────────────────────────────────────
  void updatePending(int index, PendingTriple updated) {
    final list = List<PendingTriple>.from(state.pendingTriples);
    list[index] = updated;
    state = state.copyWith(
        pendingTriples: list,
        editedCount: state.editedCount + 1);
  }

  void removePending(int index) {
    final list = List<PendingTriple>.from(state.pendingTriples);
    list.removeAt(index);
    state = state.copyWith(
        pendingTriples: list,
        deletedCount: state.deletedCount + 1);
  }

  void addPending(PendingTriple t) => state = state.copyWith(
        pendingTriples: [...state.pendingTriples, t],
        addedCount: state.addedCount + 1,
      );

  // ── Step 2 → 확정 저장 ─────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> bulkConfirm() async {
    if (state.pendingTriples.isEmpty) return null;
    state = state.copyWith(isExtracting: true, clearError: true);
    try {
      final result = await _api.bulkConfirm(
        state.pendingTriples.map((t) => t.toJson()).toList(),
      );
      state = state.copyWith(
        isExtracting: false,
        pendingTriples: [],
        sourceRecords: [],
      );
      Future.microtask(() {
        state = state.copyWith(currentStep: 2);
      });
      return result;
    } on DioException catch (e) {
      state = state.copyWith(
        isExtracting: false,
        error: e.type == DioExceptionType.receiveTimeout
            ? 'AI 응답이 지연되고 있습니다. 다시 시도해주세요.'
            : e.message ?? e.toString(),
      );
      return null;
    } catch (e) {
      state = state.copyWith(isExtracting: false, error: e.toString());
      return null;
    }
  }

  void clearError() => state = state.copyWith(clearError: true);

  void reset() => state = const TripleWorkState();
}

final tripleWorkProvider =
    StateNotifierProvider<TripleWorkNotifier, TripleWorkState>((ref) {
  return TripleWorkNotifier(ref.read(tripleApiProvider));
});
