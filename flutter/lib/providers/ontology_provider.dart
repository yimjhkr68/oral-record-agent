import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/ontology_api.dart';
import '../models/ontology.dart';

String _aiErrorMessage(Object e) {
  if (e is DioException && e.type == DioExceptionType.receiveTimeout) {
    return 'AI 응답이 지연되고 있습니다. 다시 시도해주세요.';
  }
  if (e is DioException && e.type == DioExceptionType.connectionTimeout) {
    return '서버에 연결할 수 없습니다. 서버 설정을 확인해주세요.';
  }
  return e.toString();
}

// ── API 프로바이더 ─────────────────────────────────────────────────────────────

final ontologyApiProvider = Provider<OntologyApi>((ref) {
  return OntologyApi(ref.read(apiClientProvider));
});

// ── 상태 모델 ─────────────────────────────────────────────────────────────────

class OntologyState {
  final List<OntologyVersion> versions;
  final OntologyVersion? selectedVersion;
  final Set<String> selectedForMerge; // Draft 종합 선택
  final bool isLoading;
  final String? error;

  const OntologyState({
    this.versions = const [],
    this.selectedVersion,
    this.selectedForMerge = const {},
    this.isLoading = false,
    this.error,
  });

  OntologyState copyWith({
    List<OntologyVersion>? versions,
    OntologyVersion? selectedVersion,
    bool clearSelected = false,
    Set<String>? selectedForMerge,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return OntologyState(
      versions: versions ?? this.versions,
      selectedVersion:
          clearSelected ? null : (selectedVersion ?? this.selectedVersion),
      selectedForMerge: selectedForMerge ?? this.selectedForMerge,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ── StateNotifier ─────────────────────────────────────────────────────────────

class OntologyNotifier extends StateNotifier<OntologyState> {
  final OntologyApi _api;

  OntologyNotifier(this._api) : super(const OntologyState()) {
    loadVersions();
  }

  // ── 목록 로드 ────────────────────────────────────────────────────────────────

  Future<void> loadVersions() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final versions = await _api.listVersions();
      // 최신순 정렬
      versions.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // 선택된 버전 갱신 (목록 새로고침 후 최신 데이터 반영)
      OntologyVersion? updated;
      if (state.selectedVersion != null) {
        updated = versions.firstWhere(
          (v) => v.versionId == state.selectedVersion!.versionId,
          orElse: () => state.selectedVersion!,
        );
      }
      state = state.copyWith(
        versions: versions,
        selectedVersion: updated ?? state.selectedVersion,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ── 버전 선택 ────────────────────────────────────────────────────────────────

  void selectVersion(OntologyVersion version) {
    state = state.copyWith(selectedVersion: version);
  }

  void clearSelection() {
    state = state.copyWith(clearSelected: true);
  }

  // ── Draft 종합 체크박스 ──────────────────────────────────────────────────────

  void toggleMergeSelect(String versionId) {
    final current = Set<String>.from(state.selectedForMerge);
    if (current.contains(versionId)) {
      current.remove(versionId);
    } else {
      current.add(versionId);
    }
    state = state.copyWith(selectedForMerge: current);
  }

  void clearMergeSelect() {
    state = state.copyWith(selectedForMerge: {});
  }

  // ── 새 Draft 생성 ────────────────────────────────────────────────────────────

  Future<OntologyVersion?> createDraft(
      String versionId, String description) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final v = await _api.createDraft(versionId, description);
      await loadVersions();
      state = state.copyWith(selectedVersion: v, isLoading: false);
      return v;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  // ── Draft 수정 (클래스/속성 일괄 PATCH) ────────────────────────────────────

  Future<bool> updateDraft(
    String versionId, {
    List<OntologyClass>? classes,
    List<OntologyPredicate>? predicates,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final v = await _api.updateDraft(versionId,
          classes: classes, predicates: predicates);
      // 버전 목록에서 해당 항목만 교체
      final updated = state.versions
          .map((x) => x.versionId == versionId ? v : x)
          .toList();
      state = state.copyWith(
        versions: updated,
        selectedVersion: v,
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  // ── Draft 삭제 ───────────────────────────────────────────────────────────────

  Future<bool> deleteDraft(String versionId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _api.deleteDraft(versionId);
      final updated =
          state.versions.where((v) => v.versionId != versionId).toList();
      final newSelected = state.selectedVersion?.versionId == versionId
          ? null
          : state.selectedVersion;
      state = state.copyWith(
        versions: updated,
        isLoading: false,
      );
      if (newSelected == null) {
        state = state.copyWith(clearSelected: true);
      }
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  // ── 확정 ─────────────────────────────────────────────────────────────────────

  Future<bool> confirmVersion(String versionId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final v = await _api.confirmVersion(versionId);
      final updated = state.versions
          .map((x) => x.versionId == versionId ? v : x)
          .toList();
      state = state.copyWith(
          versions: updated, selectedVersion: v, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  // ── 아카이브 ─────────────────────────────────────────────────────────────────

  Future<bool> archiveVersion(String versionId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final v = await _api.archiveVersion(versionId);
      final updated = state.versions
          .map((x) => x.versionId == versionId ? v : x)
          .toList();
      state = state.copyWith(
          versions: updated, selectedVersion: v, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  // ── AI 생성 ──────────────────────────────────────────────────────────────────

  Future<OntologyVersion?> generateFromSample(
    String sampleText, {
    String? baseVersionId,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final v = await _api.generateFromSample(sampleText,
          baseVersionId: baseVersionId);
      await loadVersions();
      state = state.copyWith(selectedVersion: v, isLoading: false);
      return v;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _aiErrorMessage(e));
      return null;
    }
  }

  // ── Draft 종합 ───────────────────────────────────────────────────────────────

  Future<OntologyVersion?> mergeDrafts(
      List<String> versionIds, String newVersionId, [String description = '']) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final v = await _api.mergeDrafts(versionIds, newVersionId, description);
      await loadVersions();
      state = state.copyWith(
        selectedVersion: v,
        selectedForMerge: {},
        isLoading: false,
      );
      return v;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _aiErrorMessage(e));
      return null;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

// ── 프로바이더 ────────────────────────────────────────────────────────────────

final ontologyProvider =
    StateNotifierProvider<OntologyNotifier, OntologyState>((ref) {
  return OntologyNotifier(ref.read(ontologyApiProvider));
});
