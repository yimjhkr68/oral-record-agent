// 파일 목적: 계정 관리 화면 (관리자 전용)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/account.dart';
import '../../data/services/auth_service.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

// ── 페이지 (AppBar 포함 래퍼) ─────────────────────────────────────
class AccountManagementPage extends StatelessWidget {
  const AccountManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('계정 관리')),
      body: const AccountManagementContent(),
    );
  }
}

// ── 콘텐츠 (AppBar 없음 — 설정 사이드바 패널에서 재사용) ───────────
class AccountManagementContent extends ConsumerStatefulWidget {
  const AccountManagementContent({super.key});

  @override
  ConsumerState<AccountManagementContent> createState() =>
      _AccountManagementContentState();
}

class _AccountManagementContentState
    extends ConsumerState<AccountManagementContent> {
  List<Account> _accounts = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() => _accounts = AuthService.getAllAccounts());
  }

  // ── 계정 추가/편집 다이얼로그 ────────────────────────────────────
  Future<void> _showAccountDialog({Account? existing}) async {
    final usernameCtrl =
        TextEditingController(text: existing?.username ?? '');
    final displayNameCtrl =
        TextEditingController(text: existing?.displayName ?? '');
    final passwordCtrl = TextEditingController();
    UserRole selectedRole = existing?.role ?? UserRole.viewer;
    bool obscure = true;
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(existing == null ? '새 계정 추가' : '계정 편집'),
          content: SizedBox(
            width: 380,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: displayNameCtrl,
                    decoration:
                        const InputDecoration(labelText: '이름 (표시용)'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? '이름을 입력하세요'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: usernameCtrl,
                    decoration: const InputDecoration(labelText: '아이디'),
                    enabled: existing == null,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? '아이디를 입력하세요'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passwordCtrl,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: existing == null
                          ? '비밀번호'
                          : '새 비밀번호 (변경 시만 입력)',
                      suffixIcon: IconButton(
                        icon: Icon(obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () =>
                            setDlg(() => obscure = !obscure),
                      ),
                    ),
                    validator: (v) {
                      if (existing == null &&
                          (v == null || v.isEmpty)) {
                        return '비밀번호를 입력하세요';
                      }
                      if (v != null &&
                          v.isNotEmpty &&
                          v.length < 6) {
                        return '6자 이상 입력하세요';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<UserRole>(
                    value: selectedRole,
                    decoration: const InputDecoration(labelText: '역할'),
                    items: UserRole.values
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(r.displayName),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setDlg(() => selectedRole = v!),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(ctx).pop(true);
                }
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      if (existing == null) {
        await AuthService.createAccount(
          username: usernameCtrl.text.trim(),
          password: passwordCtrl.text,
          role: selectedRole,
          displayName: displayNameCtrl.text.trim(),
        );
      } else {
        final updated = existing.copyWith(
          displayName: displayNameCtrl.text.trim(),
          role: selectedRole,
        );
        await AuthService.updateAccount(updated);
        if (passwordCtrl.text.isNotEmpty) {
          await AuthService.changePassword(
            accountId: existing.id,
            newPassword: passwordCtrl.text,
          );
        }
        if (ref.read(authProvider).currentUser?.id == existing.id) {
          ref.read(authProvider.notifier).refreshCurrentUser();
        }
      }
      _reload();
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e.message),
            backgroundColor: AppTheme.error),
      );
    }
  }

  // ── 계정 삭제 확인 ───────────────────────────────────────────────
  Future<void> _deleteAccount(Account account) async {
    final me = ref.read(authProvider).currentUser;
    if (me?.id == account.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('현재 로그인 계정은 삭제할 수 없습니다.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('계정 삭제'),
        content: Text(
            '"${account.displayName} (${account.username})" 계정을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: AppTheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await AuthService.deleteAccount(account.id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authProvider).currentUser;

    return Scaffold(
      body: _accounts.isEmpty
          ? const Center(child: Text('등록된 계정이 없습니다'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _accounts.length,
              itemBuilder: (context, index) {
                final account = _accounts[index];
                final isMe = me?.id == account.id;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _roleColor(account.role)
                          .withValues(alpha: 0.15),
                      child: Text(
                        account.displayName.isNotEmpty
                            ? account.displayName[0]
                            : '?',
                        style: TextStyle(
                          color: _roleColor(account.role),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(account.displayName),
                        if (isMe) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '나',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.accent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      '${account.username}  ·  ${account.role.displayName}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: '편집',
                          onPressed: () =>
                              _showAccountDialog(existing: account),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline,
                              color: isMe
                                  ? AppTheme.textDisabled
                                  : AppTheme.error),
                          tooltip: '삭제',
                          onPressed: isMe
                              ? null
                              : () => _deleteAccount(account),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAccountDialog(),
        icon: const Icon(Icons.person_add),
        label: const Text('계정 추가'),
      ),
    );
  }

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return AppTheme.primary;
      case UserRole.researcher:
        return const Color(0xFF388E3C);
      case UserRole.viewer:
        return AppTheme.textSecondary;
    }
  }
}
