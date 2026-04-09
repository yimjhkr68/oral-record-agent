import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/history_api.dart';
import '../models/history.dart';

final historyApiProvider = Provider<HistoryApi>((ref) {
  return HistoryApi(ref.read(apiClientProvider));
});

// 온톨로지 이벤트
class OntologyEventState {
  final List<OntologyEvent> events;
  final bool loading;
  final String? error;

  const OntologyEventState({
    this.events = const [],
    this.loading = false,
    this.error,
  });

  OntologyEventState copyWith({
    List<OntologyEvent>? events,
    bool? loading,
    String? error,
  }) =>
      OntologyEventState(
        events: events ?? this.events,
        loading: loading ?? this.loading,
        error: error,
      );
}

class OntologyEventNotifier extends StateNotifier<OntologyEventState> {
  final HistoryApi _api;

  OntologyEventNotifier(this._api) : super(const OntologyEventState()) {
    load();
  }

  Future<void> load({String versionId = '', String eventType = ''}) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final events = await _api.listOntologyEvents(
          versionId: versionId, eventType: eventType);
      state = state.copyWith(events: events, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
}

final ontologyEventProvider =
    StateNotifierProvider<OntologyEventNotifier, OntologyEventState>((ref) {
  return OntologyEventNotifier(ref.read(historyApiProvider));
});

// 트리플 생성 세션
class SessionListState {
  final List<ExtractionSession> sessions;
  final bool loading;
  final String? error;

  const SessionListState({
    this.sessions = const [],
    this.loading = false,
    this.error,
  });

  SessionListState copyWith({
    List<ExtractionSession>? sessions,
    bool? loading,
    String? error,
  }) =>
      SessionListState(
        sessions: sessions ?? this.sessions,
        loading: loading ?? this.loading,
        error: error,
      );
}

class SessionListNotifier extends StateNotifier<SessionListState> {
  final HistoryApi _api;

  SessionListNotifier(this._api) : super(const SessionListState()) {
    load();
  }

  Future<void> load({String status = '', String ontologyVersion = ''}) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final sessions = await _api.listSessions(
          status: status, ontologyVersion: ontologyVersion);
      state = state.copyWith(sessions: sessions, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
}

final sessionListProvider =
    StateNotifierProvider<SessionListNotifier, SessionListState>((ref) {
  return SessionListNotifier(ref.read(historyApiProvider));
});

// 요약 통계
final historySummaryProvider = FutureProvider<HistorySummary>((ref) async {
  return ref.read(historyApiProvider).getSummary();
});
