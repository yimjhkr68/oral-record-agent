// lib/src/presentation/widgets/agent_chat_panel.dart
// 에이전트 대화 패널 (입력 → 실행 → 로그 스트리밍)

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/agent_state_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import 'multi_step_progress.dart';
import 'review_dialog.dart';
import 'prompt_enhance_card.dart';
import 'search_confirm_dialog.dart';
import '../../../agents/core/prompt_enhancer.dart';

// ── 메인 패널 ──────────────────────────────────────────

class AgentChatPanel extends ConsumerStatefulWidget {
  const AgentChatPanel({super.key});

  @override
  ConsumerState<AgentChatPanel> createState() => _AgentChatPanelState();
}

class _AgentChatPanelState extends ConsumerState<AgentChatPanel>
    with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  late final AnimationController _pulseController;
  bool _reviewDialogShown = false;
  bool _searchDialogShown = false;

  // ── 프롬프트 개선 상태 ──────────────────────────────
  EnhancedPrompt? _pendingEnhance;
  bool _isEnhancing = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final agentState = ref.watch(agentStateProvider);
    final logs = ref.watch(agentLogProvider);

    // 로그 업데이트 시 자동 스크롤
    ref.listen(agentLogProvider, (_, __) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    });

    // pendingReview 시 검토 다이얼로그 표시
    ref.listen(isPendingReviewProvider, (_, isPending) {
      if (isPending && !_reviewDialogShown) {
        _reviewDialogShown = true;
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const ReviewDialog(),
        ).then((_) => _reviewDialogShown = false);
      }
    });

    // pendingSearchConfirm 시 검색 결과 컨펌 다이얼로그 표시
    ref.listen(agentStateProvider, (prev, next) {
      if (next.status == AgentProcessStatus.pendingSearchConfirm &&
          next.pendingSearchResult != null &&
          !_searchDialogShown) {
        _searchDialogShown = true;
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) =>
              SearchConfirmDialog(data: next.pendingSearchResult!),
        ).then((_) => _searchDialogShown = false);
      }
    });

    final isBusy = agentState.status == AgentProcessStatus.thinking ||
        agentState.status == AgentProcessStatus.executing ||
        agentState.status == AgentProcessStatus.pendingSearchConfirm;

    return Column(
      children: [
        _StatusBar(state: agentState, pulseController: _pulseController),
        const MultiStepProgressWidget(),
        Expanded(
          child: _LogPanel(
            logs: logs,
            scrollController: _scrollController,
          ),
        ),
        // 프롬프트 개선 로딩
        if (_isEnhancing)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('프롬프트 분석 중...', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        // 프롬프트 개선 카드
        if (_pendingEnhance != null)
          PromptEnhanceCard(
            enhanced: _pendingEnhance!,
            onUseEnhanced: _submitWithEnhanced,
            onUseOriginal: _submitWithOriginal,
            onCancel: () => setState(() => _pendingEnhance = null),
          ),
        _InputArea(
          controller: _textController,
          isBusy: isBusy || _isEnhancing,
          onSubmit: _handleSubmit,
          onFileDrop: _handleFileDrop,
        ),
      ],
    );
  }

  Future<void> _handleSubmit() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    // 프롬프트 개선 대상 여부 확인
    if (PromptEnhancer.shouldEnhance(text)) {
      final apiKey = ref.read(settingsProvider).apiKey;
      setState(() => _isEnhancing = true);
      _textController.clear();
      try {
        final enhanced = await PromptEnhancer(apiKey: apiKey.isEmpty ? null : apiKey)
            .enhance(text);
        if (!mounted) return;
        if (enhanced.isImproved) {
          setState(() {
            _pendingEnhance = enhanced;
            _isEnhancing = false;
          });
          return;
        }
      } catch (_) {
        // 개선 실패 시 원본으로 진행
      }
      if (!mounted) return;
      setState(() => _isEnhancing = false);
      ref.read(agentStateProvider.notifier).handleInput(text);
    } else {
      ref.read(agentStateProvider.notifier).handleInput(text);
      _textController.clear();
    }
  }

  void _submitWithEnhanced() {
    final enhanced = _pendingEnhance;
    setState(() => _pendingEnhance = null);
    if (enhanced == null) return;
    ref.read(agentStateProvider.notifier)
      ..setPromptContext(enhanced.original, enhanced.enhanced)
      ..handleInput(enhanced.enhanced);
  }

  void _submitWithOriginal() {
    final enhanced = _pendingEnhance;
    setState(() => _pendingEnhance = null);
    if (enhanced == null) return;
    ref.read(agentStateProvider.notifier).handleInput(enhanced.original);
  }

  void _handleFileDrop(String filePath) {
    _textController.text = '$filePath 등록해줘';
    _textController.selection = TextSelection.fromPosition(
      TextPosition(offset: _textController.text.length),
    );
  }
}

// ── 상태 표시 바 ──────────────────────────────────────

class _StatusBar extends StatelessWidget {
  final AgentState state;
  final AnimationController pulseController;

  const _StatusBar({required this.state, required this.pulseController});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon, showPulse) = _statusInfo();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          if (showPulse)
            AnimatedBuilder(
              animation: pulseController,
              builder: (_, __) => Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(
                      alpha: 0.4 + pulseController.value * 0.6),
                ),
              ),
            )
          else
            Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (state.status == AgentProcessStatus.executing &&
              state.stepProgress > 0 &&
              state.totalSteps > 0)
            Text(
              '${state.stepProgress}/${state.totalSteps}',
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w500),
            ),
        ],
      ),
    );
  }

  (String, Color, IconData, bool) _statusInfo() {
    switch (state.status) {
      case AgentProcessStatus.idle:
        return ('대기 중', AppTheme.textDisabled, Icons.circle_outlined, false);
      case AgentProcessStatus.thinking:
        return (
          '계획 수립 중...',
          AppTheme.primaryLight,
          Icons.psychology_outlined,
          true,
        );
      case AgentProcessStatus.executing:
        final step = state.currentTask ?? state.currentStep ?? '';
        final label = step.isNotEmpty ? '실행 중  $step' : '실행 중...';
        return (label, AppTheme.primaryLight, Icons.settings_outlined, true);
      case AgentProcessStatus.pendingReview:
        return (
          '검토 대기 — 결과를 확인해주세요',
          AppTheme.accent,
          Icons.rate_review_outlined,
          false,
        );
      case AgentProcessStatus.pendingSearchConfirm:
        return (
          '검색 결과 확인 — 진행할 기록을 선택해주세요',
          AppTheme.primaryLight,
          Icons.fact_check_outlined,
          false,
        );
      case AgentProcessStatus.error:
        return (
          state.errorMessage != null
              ? '오류: ${state.errorMessage!.length > 60 ? '${state.errorMessage!.substring(0, 60)}...' : state.errorMessage!}'
              : '오류 발생',
          AppTheme.error,
          Icons.error_outline,
          false,
        );
    }
  }
}

// ── 로그 패널 ─────────────────────────────────────────

class _LogPanel extends StatelessWidget {
  final List<AgentLogEntry> logs;
  final ScrollController scrollController;

  const _LogPanel({required this.logs, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.smart_toy_outlined,
                size: 48, color: AppTheme.textDisabled),
            const SizedBox(height: 12),
            Text(
              '명령을 입력하면 에이전트가 실행됩니다',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.textDisabled),
            ),
            const SizedBox(height: 4),
            Text(
              '예: "interview.mp3 파일 등록해줘"  •  "3월 보고서 만들어줘"',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.textDisabled),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      itemCount: logs.length,
      itemBuilder: (context, i) => _LogBubble(entry: logs[i]),
    );
  }
}

// ── 로그 말풍선 ───────────────────────────────────────

class _LogBubble extends StatelessWidget {
  final AgentLogEntry entry;
  const _LogBubble({required this.entry});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _stepStyle();
    final prefix = _logPrefix();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 아이콘
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(top: 2, right: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          // 말풍선
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: entry.isError
                    ? AppTheme.error.withValues(alpha: 0.07)
                    : AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: entry.isError
                      ? AppTheme.error.withValues(alpha: 0.3)
                      : AppTheme.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        prefix.isNotEmpty ? prefix : entry.step,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatTime(entry.timestamp),
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: AppTheme.textDisabled),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.detail,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: entry.isError
                              ? AppTheme.error
                              : AppTheme.textPrimary,
                        ),
                  ),
                  if (entry.folderPath != null) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () async {
                          final uri = Uri.directory(entry.folderPath!);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          }
                        },
                        icon: const Icon(Icons.folder_open_outlined, size: 13),
                        label: const Text('폴더 열기',
                            style: TextStyle(fontSize: 11)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// logType 기반 말풍선 헤더 접두어
  String _logPrefix() {
    switch (entry.logType) {
      case 'promptOriginal': return '📝 원본';
      case 'promptEnhanced': return '✨ 개선';
      case 'promptExecuted': return '▶ 실행';
      case 'searchQuery':    return '🔍 검색';
      case 'searchResult':   return '📋 결과';
      case 'searchConfirmed':return '✅ 선택';
      case 'agentComplete':  return '🎉 완료';
      case 'toolError':      return '❌ 오류';
      default: return '';
    }
  }

  (IconData, Color) _stepStyle() {
    if (entry.isError) return (Icons.error_outline, AppTheme.error);
    // logType 우선
    switch (entry.logType) {
      case 'promptOriginal':
      case 'promptEnhanced':
      case 'promptExecuted':
        return (Icons.edit_note_outlined, AppTheme.primaryLight);
      case 'searchQuery':
        return (Icons.search, AppTheme.primaryLight);
      case 'searchResult':
        return (Icons.list_alt_outlined, AppTheme.primaryLight);
      case 'searchConfirmed':
        return (Icons.check_circle_outline, Colors.green.shade600);
      case 'agentComplete':
        return (Icons.done_all, Colors.green.shade600);
      case 'toolError':
        return (Icons.error_outline, AppTheme.error);
    }
    // step 이름 기반 폴백
    switch (entry.step) {
      case '계획':
        return (Icons.assignment_outlined, AppTheme.primaryLight);
      case '분석':
        return (Icons.psychology_outlined, AppTheme.primaryLight);
      case '검색':
        return (Icons.search, AppTheme.primaryLight);
      case '선택':
        return (Icons.check_circle_outline, Colors.green.shade600);
      case '실행':
        return (Icons.settings_outlined, AppTheme.primaryLight);
      case '검증':
        return (Icons.fact_check_outlined, Colors.orange.shade600);
      case '완료':
        return (Icons.done_all, Colors.green.shade600);
      case '검토':
        return (Icons.rate_review_outlined, AppTheme.accent);
      case '승인':
        return (Icons.check_circle_outline, Colors.green.shade600);
      case '거부':
        return (Icons.cancel_outlined, AppTheme.error);
      default:
        return (Icons.info_outline, AppTheme.textSecondary);
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

// ── 입력 영역 ─────────────────────────────────────────

class _InputArea extends StatefulWidget {
  final TextEditingController controller;
  final bool isBusy;
  final VoidCallback onSubmit;
  final ValueChanged<String> onFileDrop;

  const _InputArea({
    required this.controller,
    required this.isBusy,
    required this.onSubmit,
    required this.onFileDrop,
  });

  @override
  State<_InputArea> createState() => _InputAreaState();
}

class _InputAreaState extends State<_InputArea> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: DropTarget(
        onDragEntered: (_) => setState(() => _isDragging = true),
        onDragExited: (_) => setState(() => _isDragging = false),
        onDragDone: (detail) {
          setState(() => _isDragging = false);
          if (detail.files.isEmpty) {
            debugPrint('[드롭] 파일 없음 - detail: $detail');
            return;
          }
          final path = detail.files.first.path;
          debugPrint('[드롭] 파일 경로: $path');
          widget.onFileDrop(path);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: _isDragging
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppTheme.primaryLight, width: 2),
                  color: AppTheme.primaryLight.withValues(alpha: 0.05),
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 드래그 힌트
              if (_isDragging)
                Container(
                  height: 36,
                  alignment: Alignment.center,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.upload_file_outlined,
                          size: 16, color: AppTheme.primaryLight),
                      SizedBox(width: 6),
                      Text('파일을 놓으면 경로가 입력됩니다',
                          style: TextStyle(
                              color: AppTheme.primaryLight,
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),

              // 텍스트 입력창 + 전송 버튼
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      enabled: !widget.isBusy,
                      maxLines: 4,
                      minLines: 1,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: widget.isBusy
                            ? '처리 중입니다...'
                            : '무엇을 도와드릴까요?\n예: interview.mp3 파일 등록해줘',
                        hintMaxLines: 2,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        suffixIcon: !widget.isBusy &&
                                widget.controller.text.isEmpty
                            ? const Icon(Icons.keyboard_alt_outlined,
                                size: 16, color: AppTheme.textDisabled)
                            : null,
                      ),
                      onChanged: (_) =>
                          (context as Element).markNeedsBuild(),
                      onSubmitted: (_) {
                        if (!widget.isBusy) widget.onSubmit();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: widget.isBusy ? null : widget.onSubmit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      child: widget.isBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                    ),
                  ),
                ],
              ),

              // 드롭 안내 텍스트 (비활성 상태)
              if (!_isDragging && !widget.isBusy)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '파일을 이 영역에 드래그하거나  Shift+Enter로 줄바꿈',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: AppTheme.textDisabled),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
