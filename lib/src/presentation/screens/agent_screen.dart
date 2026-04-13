// lib/src/presentation/screens/agent_screen.dart
// 에이전트 전체 화면 — AgentChatPanel 감싸는 Scaffold

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/agent_state_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/agent_chat_panel.dart';

class AgentScreen extends ConsumerWidget {
  const AgentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(
      agentStateProvider.select((s) => s.status),
    );
    final isBusy = status == AgentProcessStatus.thinking ||
        status == AgentProcessStatus.executing;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.smart_toy_outlined, size: 20),
            const SizedBox(width: 8),
            const Text('구술기록관리 에이전트 v2'),
            const SizedBox(width: 8),
            if (isBusy)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '실행 중',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accent,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          // 로그 초기화 버튼
          IconButton(
            tooltip: '로그 초기화',
            icon: const Icon(Icons.cleaning_services_outlined, size: 20),
            onPressed: isBusy
                ? null
                : () => ref.read(agentStateProvider.notifier).clearLog(),
          ),
          // 전체 리셋 버튼
          IconButton(
            tooltip: '에이전트 초기화',
            icon: const Icon(Icons.refresh_outlined, size: 20),
            onPressed: isBusy
                ? null
                : () {
                    ref.read(agentStateProvider.notifier).reset();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('에이전트 상태가 초기화되었습니다'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
          ),
        ],
      ),
      body: const AgentChatPanel(),
    );
  }
}
