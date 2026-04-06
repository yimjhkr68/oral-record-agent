// lib/src/presentation/providers/rag_provider.dart
// RAG 쿼리 상태 관리 (Riverpod)
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/rag_service.dart';

export '../../data/services/rag_service.dart' show RagResult, RagSource;

// ── RAG 서비스 프로바이더 ─────────────────────────────────────
final ragServiceProvider = Provider<RagService>(
  (ref) => const RagService(baseUrl: 'http://127.0.0.1:9000'),
);

// ── RAG 상태 ─────────────────────────────────────────────────
class RagState {
  final bool isLoading;
  final RagResult? result;
  final String? error;
  final bool serverAvailable;

  const RagState({
    this.isLoading = false,
    this.result,
    this.error,
    this.serverAvailable = true,
  });

  bool get hasResult => result != null;
  bool get hasError => error != null;

  RagState copyWith({
    bool? isLoading,
    RagResult? result,
    String? error,
    bool? serverAvailable,
  }) =>
      RagState(
        isLoading: isLoading ?? this.isLoading,
        result: result ?? this.result,
        error: error ?? this.error,
        serverAvailable: serverAvailable ?? this.serverAvailable,
      );
}

// ── RAG Notifier ─────────────────────────────────────────────
class RagNotifier extends StateNotifier<RagState> {
  final RagService _service;
  int _currentSearchId = 0;

  RagNotifier(this._service) : super(const RagState());

  Future<void> query(String q) async {
    if (q.trim().isEmpty) return;

    final searchId = ++_currentSearchId;
    state = const RagState(isLoading: true);

    try {
      final result = await _service.query(q.trim());
      if (searchId != _currentSearchId) return;
      state = RagState(result: result, serverAvailable: true);
    } on Exception catch (e) {
      if (searchId != _currentSearchId) return;
      final msg = e.toString();
      // 서버 미응답 → 별도 메시지
      if (msg.contains('Connection refused') ||
          msg.contains('SocketException') ||
          msg.contains('TimeoutException')) {
        state = const RagState(
          serverAvailable: false,
          error: 'RAG 서버에 연결할 수 없습니다.',
        );
      } else {
        state = RagState(error: msg, serverAvailable: true);
      }
    }
  }

  void clear() => state = const RagState();
}

final ragProvider =
    StateNotifierProvider<RagNotifier, RagState>((ref) {
  return RagNotifier(ref.read(ragServiceProvider));
});
