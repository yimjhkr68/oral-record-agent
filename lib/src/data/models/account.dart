// 파일 목적: 로컬 계정 모델, 역할(Role), 권한(Permission) 정의
import 'dart:convert';

// ── 역할 ────────────────────────────────────────────────────────
enum UserRole {
  admin,
  researcher,
  viewer;

  String get displayName {
    switch (this) {
      case UserRole.admin:
        return '관리자';
      case UserRole.researcher:
        return '연구원';
      case UserRole.viewer:
        return '열람자';
    }
  }

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (r) => r.name == value,
      orElse: () => UserRole.viewer,
    );
  }
}

// ── 권한 ────────────────────────────────────────────────────────
enum Permission {
  canViewRecords,
  canCreateRecord,
  canEditRecord,
  canDeleteRecord,
  canViewNarrators,
  canCreateNarrator,
  canEditNarrator,
  canDeleteNarrator,
  canExport,
  canImport,
  canManageAccounts,
  canChangeSettings,
  canViewAllRecords,
}

// ── 역할별 권한 매핑 ─────────────────────────────────────────────
const Map<UserRole, Set<Permission>> _rolePermissions = {
  UserRole.admin: {
    Permission.canViewRecords,
    Permission.canCreateRecord,
    Permission.canEditRecord,
    Permission.canDeleteRecord,
    Permission.canViewNarrators,
    Permission.canCreateNarrator,
    Permission.canEditNarrator,
    Permission.canDeleteNarrator,
    Permission.canExport,
    Permission.canImport,
    Permission.canManageAccounts,
    Permission.canChangeSettings,
    Permission.canViewAllRecords,
  },
  UserRole.researcher: {
    Permission.canViewRecords,
    Permission.canCreateRecord,
    Permission.canEditRecord,
    Permission.canViewNarrators,
    Permission.canCreateNarrator,
    Permission.canEditNarrator,
    Permission.canExport,
    Permission.canViewAllRecords,
  },
  UserRole.viewer: {
    Permission.canViewRecords,
    Permission.canViewNarrators,
    Permission.canExport,
  },
};

// ── 계정 모델 ────────────────────────────────────────────────────
class Account {
  final String id;
  final String username;
  final String hashedPassword;
  final UserRole role;
  final String displayName;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final bool autoLogin;

  const Account({
    required this.id,
    required this.username,
    required this.hashedPassword,
    required this.role,
    required this.displayName,
    required this.createdAt,
    this.lastLogin,
    this.autoLogin = false,
  });

  Set<Permission> get permissions => _rolePermissions[role] ?? {};

  bool hasPermission(Permission permission) =>
      permissions.contains(permission);

  Account copyWith({
    String? username,
    String? hashedPassword,
    UserRole? role,
    String? displayName,
    DateTime? lastLogin,
    bool? autoLogin,
    bool clearLastLogin = false,
  }) {
    return Account(
      id: id,
      username: username ?? this.username,
      hashedPassword: hashedPassword ?? this.hashedPassword,
      role: role ?? this.role,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt,
      lastLogin: clearLastLogin ? null : (lastLogin ?? this.lastLogin),
      autoLogin: autoLogin ?? this.autoLogin,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'hashedPassword': hashedPassword,
        'role': role.name,
        'displayName': displayName,
        'createdAt': createdAt.toIso8601String(),
        'lastLogin': lastLogin?.toIso8601String(),
        'autoLogin': autoLogin,
      };

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        id: json['id'] as String,
        username: json['username'] as String,
        hashedPassword: json['hashedPassword'] as String,
        role: UserRole.fromString(json['role'] as String),
        displayName: json['displayName'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        lastLogin: json['lastLogin'] != null
            ? DateTime.parse(json['lastLogin'] as String)
            : null,
        autoLogin: json['autoLogin'] as bool? ?? false,
      );

  String toJsonString() => jsonEncode(toJson());

  factory Account.fromJsonString(String s) =>
      Account.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
