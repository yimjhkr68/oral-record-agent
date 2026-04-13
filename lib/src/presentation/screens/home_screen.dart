// lib/src/presentation/screens/home_screen.dart
// v2 홈 화면: 4열 에이전트 중심 레이아웃
// AgentSidebar(52px) | AgentHistoryPanel(200px) | AgentChatPanel(확장) | AgentDashboardPanel(200px)

import 'package:flutter/material.dart';
import '../widgets/agent_sidebar.dart';
import '../widgets/agent_history_panel.dart';
import '../widgets/agent_chat_panel.dart';
import '../widgets/agent_dashboard_panel.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        AgentSidebar(),
        AgentHistoryPanel(),
        Expanded(child: AgentChatPanel()),
        AgentDashboardPanel(),
      ],
    );
  }
}
