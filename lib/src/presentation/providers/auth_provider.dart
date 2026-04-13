// 파일 목적: 인증 상태 관리 Provider
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/account.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/rag_server_service.dart';

// ── 상태 ─────────────────────────────────────────────────────────
class AuthState {
  final Account? currentUser;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.currentUser,
    this.isLoading = false,
    this.error,
  });

  bool get isLoggedIn => currentUser != null;

  AuthState copyWith({
    Account? currentUser,
    bool? isLoading,
    String? error,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      currentUser: clearUser ? null : (currentUser ?? this.currentUser),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ── Notifier ─────────────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _tryAutoLogin();
  }

  void _tryAutoLogin() {
    try {
      final account = AuthService.tryAutoLogin();
      if (account != null) {
        state = AuthState(currentUser: account);
      }
    } catch (_) {
      // Hive 박스 미초기화 환경(테스트)에서 무시
    }
  }

  Future<bool> login({
    required String username,
    required String password,
    bool rememberMe = false,
  }) async {
    state = const AuthState(isLoading: true);
    try {
      final account = await AuthService.login(
        username: username,
        password: password,
        rememberMe: rememberMe,
      );
      if (account != null) {
        state = AuthState(currentUser: account);
        return true;
      } else {
        state = const AuthState(
          error: '아이디 또는 비밀번호가 올바르지 않습니다.',
        );
        return false;
      }
    } catch (e) {
      state = AuthState(error: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    await RagServerService.stop();
    if (state.currentUser != null) {
      await AuthService.logout(state.currentUser!.id);
    }
    state = const AuthState();
  }

  void refreshCurrentUser() {
    if (state.currentUser == null) return;
    final updated = AuthService.getAccountById(state.currentUser!.id);
    if (updated != null) {
      state = state.copyWith(currentUser: updated);
    }
  }
}

// ── Provider ─────────────────────────────────────────────────────
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);

// ── 편의 확장 (ref에서 직접 권한 확인) ───────────────────────────
extension AuthRefExtension on WidgetRef {
  Account? get currentUser => read(authProvider).currentUser;

  bool can(Permission permission) =>
      watch(authProvider).currentUser?.hasPermission(permission) ?? false;
}
