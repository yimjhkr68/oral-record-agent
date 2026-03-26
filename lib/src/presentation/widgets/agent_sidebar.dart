// lib/src/presentation/widgets/agent_sidebar.dart
// 52px 슬림 사이드바: 아이콘 + Tooltip 네비게이션

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AgentSidebar extends StatelessWidget {
  const AgentSidebar({super.key});

  static const _kNavy = Color(0xFF1A2332);

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    return Container(
      width: 52,
      color: _kNavy,
      child: Column(
        children: [
          const SizedBox(height: 8),
          _SidebarIcon(
            icon: Icons.smart_toy_outlined,
            label: '에이전트 홈',
            active: location == '/',
            onTap: () => context.go('/'),
          ),
          _SidebarIcon(
            icon: Icons.people_outline,
            label: '인물사전',
            active: location.startsWith('/people'),
            onTap: () => context.go('/people'),
          ),
          _SidebarIcon(
            icon: Icons.list_alt_outlined,
            label: '기록 목록',
            active: location.startsWith('/records'),
            onTap: () => context.go('/records'),
          ),
          _SidebarIcon(
            icon: Icons.search_outlined,
            label: '검색',
            active: location.startsWith('/search'),
            onTap: () => context.go('/search'),
          ),
          const Spacer(),
          _SidebarIcon(
            icon: Icons.settings_outlined,
            label: '설정',
            active: location.startsWith('/settings'),
            onTap: () => context.go('/settings'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SidebarIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SidebarIcon({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      preferBelow: false,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: active ? Colors.white : Colors.white54,
            size: 22,
          ),
        ),
      ),
    );
  }
}
