// 파일 목적: 로컬 계정 인증 서비스 (bcrypt 해시, CRUD, 자동 로그인)
import 'package:bcrypt/bcrypt.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/account.dart';

const _accountsBox = 'accounts';
const _authPrefsBox = 'auth_prefs';
const _autoLoginKey = 'auto_login_username';

// ── compute용 최상위 함수 (isolate에서 실행) ─────────────────────
String _bcryptHashWorker(String password) {
  final salt = BCrypt.gensalt(logRounds: 10);
  return BCrypt.hashpw(password, salt);
}

bool _bcryptCheckWorker(List<String> args) {
  try {
    return BCrypt.checkpw(args[0], args[1]);
  } catch (_) {
    return false;
  }
}

// ── 서비스 ───────────────────────────────────────────────────────
class AuthService {
  static Box<String> get _box => Hive.box<String>(_accountsBox);
  static Box<String> get _prefs => Hive.box<String>(_authPrefsBox);

  // ── 계정 조회 ──────────────────────────────────────────────────

  static List<Account> getAllAccounts() {
    return _box.values
        .map((s) {
          try {
            return Account.fromJsonString(s);
          } catch (_) {
            return null;
          }
        })
        .whereType<Account>()
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  static Account? getAccountByUsername(String username) {
    try {
      return getAllAccounts()
          .firstWhere((a) => a.username == username);
    } catch (_) {
      return null;
    }
  }

  static Account? getAccountById(String id) {
    final s = _box.get(id);
    if (s == null) return null;
    try {
      return Account.fromJsonString(s);
    } catch (_) {
      return null;
    }
  }

  // ── 계정 생성/수정/삭제 ────────────────────────────────────────

  static Future<Account> createAccount({
    required String username,
    required String password,
    required UserRole role,
    required String displayName,
  }) async {
    if (getAccountByUsername(username) != null) {
      throw AuthException('이미 존재하는 사용자 이름입니다: $username');
    }
    final hashedPassword = await _hashPassword(password);
    final account = Account(
      id: const Uuid().v4(),
      username: username,
      hashedPassword: hashedPassword,
      role: role,
      displayName: displayName,
      createdAt: DateTime.now(),
    );
    await _box.put(account.id, account.toJsonString());
    return account;
  }

  static Future<void> updateAccount(Account account) async {
    await _box.put(account.id, account.toJsonString());
  }

  static Future<void> deleteAccount(String id) async {
    await _box.delete(id);
  }

  static Future<void> changePassword({
    required String accountId,
    required String newPassword,
  }) async {
    final account = getAccountById(accountId);
    if (account == null) throw AuthException('계정을 찾을 수 없습니다.');
    final hashed = await _hashPassword(newPassword);
    await updateAccount(account.copyWith(hashedPassword: hashed));
  }

  // ── 인증 ──────────────────────────────────────────────────────

  static Future<Account?> login({
    required String username,
    required String password,
    bool rememberMe = false,
  }) async {
    final account = getAccountByUsername(username);
    if (account == null) return null;

    final valid = await _verifyPassword(password, account.hashedPassword);
    if (!valid) return null;

    final updated = account.copyWith(
      lastLogin: DateTime.now(),
      autoLogin: rememberMe,
    );
    await updateAccount(updated);

    if (rememberMe) {
      await _prefs.put(_autoLoginKey, username);
    } else {
      await _prefs.delete(_autoLoginKey);
    }
    return updated;
  }

  static Future<void> logout(String accountId) async {
    final account = getAccountById(accountId);
    if (account != null && account.autoLogin) {
      await updateAccount(account.copyWith(autoLogin: false));
    }
    await _prefs.delete(_autoLoginKey);
  }

  /// 앱 재시작 시 자동 로그인 시도
  static Account? tryAutoLogin() {
    final username = _prefs.get(_autoLoginKey);
    if (username == null) return null;
    final account = getAccountByUsername(username);
    if (account == null || !account.autoLogin) {
      _prefs.delete(_autoLoginKey);
      return null;
    }
    return account;
  }

  /// 최초 실행 시 기본 관리자 계정 생성
  static Future<void> seedAdminAccount() async {
    if (_box.isEmpty) {
      await createAccount(
        username: 'admin',
        password: 'admin1234',
        role: UserRole.admin,
        displayName: '관리자',
      );
      debugPrint('[Auth] 기본 관리자 계정 생성: admin / admin1234');
    }
  }

  /// 현재 비밀번호 확인 (비밀번호 변경 시 사용)
  static Future<bool> verifyPassword({
    required String accountId,
    required String password,
  }) async {
    final account = getAccountById(accountId);
    if (account == null) return false;
    return _verifyPassword(password, account.hashedPassword);
  }

  // ── 비밀번호 해시 (bcrypt, background isolate) ─────────────────

  static Future<String> _hashPassword(String password) async {
    return compute(_bcryptHashWorker, password);
  }

  static Future<bool> _verifyPassword(String password, String hash) async {
    return compute(_bcryptCheckWorker, [password, hash]);
  }
}

// ── 예외 ─────────────────────────────────────────────────────────
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => 'AuthException: $message';
}
