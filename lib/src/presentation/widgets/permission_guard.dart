// 파일 목적: 권한 기반 UI 헬퍼 위젯 및 유틸리티
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/account.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

/// 권한 없을 때 스낵바 메시지 표시
void showNoPermissionSnackBar(BuildContext context, Permission permission) {
  final message = switch (permission) {
    Permission.canDeleteRecord => '삭제 권한이 없습니다.',
    Permission.canEditRecord => '편집 권한이 없습니다. 관리자에게 문의하세요.',
    Permission.canCreateRecord => '기록 등록 권한이 없습니다.',
    Permission.canDeleteNarrator => '인물 삭제 권한이 없습니다.',
    Permission.canEditNarrator => '인물 편집 권한이 없습니다.',
    Permission.canCreateNarrator => '인물 등록 권한이 없습니다.',
    Permission.canImport => '들여오기 권한이 없습니다.',
    Permission.canChangeSettings => '설정 변경 권한이 없습니다. 관리자에게 문의하세요.',
    Permission.canManageAccounts => '계정 관리 권한이 없습니다.',
    _ => '권한이 없습니다. 관리자에게 문의하세요.',
  };
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: AppTheme.primary,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// 권한에 따라 버튼/위젯을 활성/비활성 처리하는 위젯
class PermissionGuard extends ConsumerWidget {
  final Permission permission;
  /// 권한 있을 때 표시할 위젯
  final Widget child;
  /// 권한 없을 때 표시할 위젯 (null이면 child를 비활성화 상태로 표시)
  final Widget? fallback;
  /// 권한 없어도 위젯 표시 (단, 클릭 시 snackbar)
  final bool showDisabled;

  const PermissionGuard({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
    this.showDisabled = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPermission =
        ref.watch(authProvider).currentUser?.hasPermission(permission) ??
            false;

    if (hasPermission) return child;
    if (fallback != null) return fallback!;
    if (showDisabled) {
      return Opacity(
        opacity: 0.38,
        child: AbsorbPointer(
          child: child,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

/// IconButton을 권한 체크와 함께 생성하는 헬퍼
Widget permissionIconButton({
  required BuildContext context,
  required WidgetRef ref,
  required Permission permission,
  required IconData icon,
  required VoidCallback onPressed,
  String? tooltip,
  Color? color,
}) {
  final hasPermission =
      ref.read(authProvider).currentUser?.hasPermission(permission) ?? false;

  return IconButton(
    icon: hasPermission
        ? Icon(icon, color: color)
        : Icon(icon, color: AppTheme.textDisabled),
    tooltip: hasPermission ? tooltip : '권한 없음',
    onPressed: hasPermission
        ? onPressed
        : () => showNoPermissionSnackBar(context, permission),
  );
}
