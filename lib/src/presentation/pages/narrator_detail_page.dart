// 파일 목적: 구술자 상세/편집 화면
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/master_data_provider.dart';
import '../../data/models/narrator.dart';
import '../../data/repositories/repository_provider.dart';

class NarratorDetailPage extends ConsumerWidget {
  final String narratorId;
  const NarratorDetailPage({super.key, required this.narratorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final narrators = ref.watch(narratorListProvider);

    return narrators.when(
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(body: Center(child: Text('오류: $e'))),
      data: (list) {
        final narrator = list.where((n) => n.id == narratorId).firstOrNull;
        if (narrator == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('구술자 상세')),
            body: const Center(child: Text('구술자를 찾을 수 없습니다.')),
          );
        }
        return _NarratorDetailView(narrator: narrator);
      },
    );
  }
}

class _NarratorDetailView extends ConsumerWidget {
  final Narrator narrator;
  const _NarratorDetailView({required this.narrator});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(narrator.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: '편집',
            onPressed: () =>
                context.push('/people/narrator/${narrator.id}/edit'),
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
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        narrator.name[0],
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(narrator.name,
                              style: Theme.of(context).textTheme.headlineSmall),
                          if (narrator.jobTitle != null)
                            Text(narrator.jobTitle!,
                                style: const TextStyle(color: Colors.grey)),
                          if (narrator.affiliation != null)
                            Text(narrator.affiliation!,
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
            _SectionCard(
              title: '기본 정보',
              children: [
                if (narrator.dateOfBirth != null)
                  _InfoRow('생년월일',
                      '${narrator.dateOfBirth!.year}년 ${narrator.dateOfBirth!.month}월 ${narrator.dateOfBirth!.day}일'),
                if (narrator.gender != null)
                  _InfoRow('성별', _genderLabel(narrator.gender!)),
                if (narrator.nationality != null)
                  _InfoRow('국적', narrator.nationality!),
                if (narrator.birthPlace != null)
                  _InfoRow('출생지', narrator.birthPlace!),
              ],
            ),

            // 경력 정보
            if (narrator.currentJobTitle != null ||
                narrator.careerList.isNotEmpty) ...[
              const SizedBox(height: 8),
              _SectionCard(
                title: '경력 정보',
                children: [
                  if (narrator.currentJobTitle != null)
                    _InfoRow('현재 직위', narrator.currentJobTitle!),
                  if (narrator.careerList.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('주요 경력',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey)),
                          const SizedBox(height: 4),
                          for (final career in narrator.careerList)
                            Padding(
                              padding: const EdgeInsets.only(left: 8, bottom: 2),
                              child: Row(
                                children: [
                                  const Icon(Icons.circle,
                                      size: 6, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text(career)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ],

            // 연락처
            if (narrator.phone != null ||
                narrator.email != null ||
                narrator.address != null) ...[
              const SizedBox(height: 8),
              _SectionCard(
                title: '연락처',
                children: [
                  if (narrator.phone != null)
                    _InfoRow('전화번호', _maskPII(narrator.phone!)),
                  if (narrator.email != null)
                    _InfoRow('이메일', _maskPII(narrator.email!)),
                  if (narrator.address != null)
                    _InfoRow('주소', narrator.address!),
                ],
              ),
            ],

            // 메모
            if (narrator.biography != null ||
                narrator.notes != null ||
                narrator.interviewNotes != null) ...[
              const SizedBox(height: 8),
              _SectionCard(
                title: '메모',
                children: [
                  if (narrator.biography != null)
                    _InfoBlock('약전/소개', narrator.biography!),
                  if (narrator.notes != null)
                    _InfoBlock('특이사항', narrator.notes!),
                  if (narrator.interviewNotes != null)
                    _InfoBlock('면담 전 조사', narrator.interviewNotes!),
                ],
              ),
            ],

            // 시스템 정보
            const SizedBox(height: 8),
            _SectionCard(
              title: '시스템 정보',
              children: [
                _InfoRow('등록일', _formatDate(narrator.createdAt)),
                _InfoRow('최종 수정', _formatDate(narrator.updatedAt)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _genderLabel(String g) {
    switch (g) {
      case 'M':
        return '남성';
      case 'F':
        return '여성';
      default:
        return '기타';
    }
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
        title: const Text('구술자 삭제'),
        content: Text('${narrator.name}을(를) 삭제하시겠습니까?\n'
            '연결된 기록은 유지되지만 구술자 정보가 사라집니다.'),
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
      final repo = await ref.read(narratorRepositoryProvider.future);
      await repo.deleteNarrator(narrator.id);
      ref.invalidate(narratorListProvider);
      if (context.mounted) context.pop();
    }
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    )),
            const Divider(height: 16),
            ...children,
          ],
        ),
      ),
    );
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

class _InfoBlock extends StatelessWidget {
  final String label;
  final String value;
  const _InfoBlock(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.grey, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
