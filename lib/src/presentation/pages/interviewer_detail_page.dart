// 파일 목적: 면담자 상세/편집 화면
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/master_data_provider.dart';
import '../../data/models/interviewer.dart';
import '../../data/repositories/repository_provider.dart';

class InterviewerDetailPage extends ConsumerWidget {
  final String interviewerId;
  const InterviewerDetailPage({super.key, required this.interviewerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interviewers = ref.watch(interviewerListProvider);

    return interviewers.when(
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(body: Center(child: Text('오류: $e'))),
      data: (list) {
        final interviewer =
            list.where((i) => i.id == interviewerId).firstOrNull;
        if (interviewer == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('면담자 상세')),
            body: const Center(child: Text('면담자를 찾을 수 없습니다.')),
          );
        }
        return _InterviewerDetailView(interviewer: interviewer);
      },
    );
  }
}

class _InterviewerDetailView extends ConsumerWidget {
  final Interviewer interviewer;
  const _InterviewerDetailView({required this.interviewer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(interviewer.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: '편집',
            onPressed: () =>
                context.push('/people/interviewer/${interviewer.id}/edit'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '삭제',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더 카드
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor:
                          Theme.of(context).colorScheme.secondaryContainer,
                      child: Text(
                        interviewer.name[0],
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(interviewer.name,
                              style:
                                  Theme.of(context).textTheme.headlineSmall),
                          if (interviewer.jobTitle != null)
                            Text(interviewer.jobTitle!,
                                style: const TextStyle(color: Colors.grey)),
                          if (interviewer.affiliation != null)
                            Text(interviewer.affiliation!,
                                style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 기본 정보
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('기본 정보',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary)),
                    const Divider(height: 16),
                    if (interviewer.affiliation != null)
                      _InfoRow('소속', interviewer.affiliation!),
                    if (interviewer.jobTitle != null)
                      _InfoRow('직위', interviewer.jobTitle!),
                    if (interviewer.specialization != null)
                      _InfoRow('전문 분야', interviewer.specialization!),
                    if (interviewer.phone != null)
                      _InfoRow('전화번호', _maskPII(interviewer.phone!)),
                    if (interviewer.email != null)
                      _InfoRow('이메일', _maskPII(interviewer.email!)),
                  ],
                ),
              ),
            ),

            if (interviewer.notes != null) ...[
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('메모',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.primary)),
                      const Divider(height: 16),
                      Text(interviewer.notes!),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('시스템 정보',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary)),
                    const Divider(height: 16),
                    _InfoRow('등록일', _formatDate(interviewer.createdAt)),
                    _InfoRow('최종 수정', _formatDate(interviewer.updatedAt)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _maskPII(String value) {
    if (value.length <= 4) return '****';
    return '${value.substring(0, 2)}${'*' * (value.length - 4)}${value.substring(value.length - 2)}';
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('면담자 삭제'),
        content: Text('${interviewer.name}을(를) 삭제하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final repo = await ref.read(interviewerRepositoryProvider.future);
      await repo.deleteInterviewer(interviewer.id);
      ref.invalidate(interviewerListProvider);
      if (context.mounted) context.pop();
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    color: Colors.grey, fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
