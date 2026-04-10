import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/published_ontology_api.dart';
import '../models/published_ontology.dart';

final publishedOntologyApiProvider = Provider<PublishedOntologyApi>((ref) {
  return PublishedOntologyApi(ref.read(apiClientProvider));
});

// ── 상태 모델 ─────────────────────────────────────────────────────────────────

class PublishedOntologyState {
  final List<PublishedOntology> ontologies;
  final PublishedOntology? selected;
  final bool isLoading;
  final String? error;

  const PublishedOntologyState({
    this.ontologies = const [],
    this.selected,
    this.isLoading = false,
    this.error,
  });

  PublishedOntologyState copyWith({
    List<PublishedOntology>? ontologies,
    PublishedOntology? selected,
    bool clearSelected = false,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      PublishedOntologyState(
        ontologies: ontologies ?? this.ontologies,
        selected: clearSelected ? null : (selected ?? this.selected),
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

// ── StateNotifier ─────────────────────────────────────────────────────────────

class PublishedOntologyNotifier
    extends StateNotifier<PublishedOntologyState> {
  final PublishedOntologyApi _api;

  PublishedOntologyNotifier(this._api)
      : super(const PublishedOntologyState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final list = await _api.listOntologies();
      // 선택된 항목 갱신
      PublishedOntology? updatedSelected;
      if (state.selected != null) {
        updatedSelected = list.cast<PublishedOntology?>().firstWhere(
          (o) => o?.id == state.selected!.id,
          orElse: () => null,
        );
      }
      state = state.copyWith(
        ontologies: list,
        selected: updatedSelected,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void select(PublishedOntology onto) =>
      state = state.copyWith(selected: onto);

  void clearSelection() => state = state.copyWith(clearSelected: true);

  // ── 온톨로지 CRUD ───────────────────────────────────────────────────────────

  Future<bool> createOntology({
    required String id,
    required String name,
    required String prefix,
    required String namespaceUri,
    String description = '',
    String version = '',
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _api.createOntology(
        id: id,
        name: name,
        prefix: prefix,
        namespaceUri: namespaceUri,
        description: description,
        version: version,
      );
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> deleteOntology(String id) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _api.deleteOntology(id);
      final updated = state.ontologies.where((o) => o.id != id).toList();
      final wasSelected = state.selected?.id == id;
      state = state.copyWith(
        ontologies: updated,
        isLoading: false,
        clearSelected: wasSelected,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  // ── 클래스 CRUD ─────────────────────────────────────────────────────────────

  Future<bool> addClass(
    String ontologyId, {
    required String curie,
    required String uri,
    required String label,
    required String labelKo,
    String description = '',
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updated = await _api.addClass(
        ontologyId,
        curie: curie,
        uri: uri,
        label: label,
        labelKo: labelKo,
        description: description,
      );
      _replaceOntology(updated);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> updateClass(
    String ontologyId,
    String classId, {
    String? curie,
    String? uri,
    String? label,
    String? labelKo,
    String? description,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updated = await _api.updateClass(
        ontologyId,
        classId,
        curie: curie,
        uri: uri,
        label: label,
        labelKo: labelKo,
        description: description,
      );
      _replaceOntology(updated);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> deleteClass(String ontologyId, String classId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _api.deleteClass(ontologyId, classId);
      // 로컬 상태에서 즉시 제거
      final updatedList = state.ontologies.map((o) {
        if (o.id != ontologyId) return o;
        return PublishedOntology(
          id: o.id,
          name: o.name,
          prefix: o.prefix,
          namespaceUri: o.namespaceUri,
          description: o.description,
          version: o.version,
          classes: o.classes.where((c) => c.id != classId).toList(),
        );
      }).toList();
      final updatedSelected = state.selected?.id == ontologyId
          ? updatedList.firstWhere((o) => o.id == ontologyId)
          : state.selected;
      state = state.copyWith(
        ontologies: updatedList,
        selected: updatedSelected,
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  void clearError() => state = state.copyWith(clearError: true);

  // ── 내부 헬퍼 ──────────────────────────────────────────────────────────────

  void _replaceOntology(PublishedOntology updated) {
    final list = state.ontologies
        .map((o) => o.id == updated.id ? updated : o)
        .toList();
    state = state.copyWith(
      ontologies: list,
      selected: state.selected?.id == updated.id ? updated : state.selected,
      isLoading: false,
    );
  }
}

final publishedOntologyProvider = StateNotifierProvider<
    PublishedOntologyNotifier, PublishedOntologyState>((ref) {
  return PublishedOntologyNotifier(ref.read(publishedOntologyApiProvider));
});
