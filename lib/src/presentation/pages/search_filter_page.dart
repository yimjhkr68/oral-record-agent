// 파일 목적: SearchFilterPage - 검색·필터 화면
// 구술자, 날짜 범위, 장소, 주제, 비공개 여부

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/search_filter_provider.dart';
import '../providers/master_data_provider.dart';

class SearchFilterPage extends ConsumerWidget {
  const SearchFilterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(searchFilterProvider);
    final narrators = ref.watch(narratorListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('검색·필터')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 구술자 필터
            Text(
              '구술자',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            narrators.when(
              loading: () => const CircularProgressIndicator(),
              data: (list) => DropdownButton<String?>(
                isExpanded: true,
                value: (filters.narratorId?.isEmpty ?? true) ? null : filters.narratorId,
                hint: const Text('모두 선택'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('모두 선택'),
                  ),
                  ...list.map((n) => DropdownMenuItem(
                        value: n.id,
                        child: Text(n.name),
                      )),
                ].toList(),
                onChanged: (id) {
                  ref.read(searchFilterProvider.notifier).setNarrator(id ?? '');
                },
              ),
              error: (_, __) => const Text('구술자 로드 실패'),
            ),
            const SizedBox(height: 24),

            // 날짜 범위 필터
            Text(
              '날짜 범위',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: filters.startDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        ref.read(searchFilterProvider.notifier).setStartDate(date);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        filters.startDate == null
                            ? '시작 날짜'
                            : '${filters.startDate!.year}-${filters.startDate!.month}-${filters.startDate!.day}',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: filters.endDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        ref.read(searchFilterProvider.notifier).setEndDate(date);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        filters.endDate == null
                            ? '종료 날짜'
                            : '${filters.endDate!.year}-${filters.endDate!.month}-${filters.endDate!.day}',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 장소 필터
            Text(
              '장소',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              onChanged: (value) {
                ref.read(searchFilterProvider.notifier).setLocation(value);
              },
              decoration: InputDecoration(
                hintText: '장소 입력',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 주제 분류 필터
            Text(
              '주제 분류',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            DropdownButton<String>(
              isExpanded: true,
              value: filters.mainCategory,
              hint: const Text('모두 선택'),
              items: const [
                '역사',
                '문화',
                '과학',
                '정치',
                '경제',
                '교육',
                '보건',
                '농업',
              ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (category) {
                if (category != null) {
                  ref
                      .read(searchFilterProvider.notifier)
                      .setMainCategory(category);
                }
              },
            ),
            const SizedBox(height: 24),

            // 비공개 여부 필터
            Row(
              children: [
                Checkbox(
                  value: filters.isPrivate ?? false,
                  onChanged: (value) {
                    ref
                        .read(searchFilterProvider.notifier)
                        .setPrivacy(value ?? false);
                  },
                ),
                const Text('비공개 기록만 보기'),
              ],
            ),
            const SizedBox(height: 32),

            // 검색 및 초기화 버튼
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      context.pop();
                    },
                    child: const Text('검색'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ref.read(searchFilterProvider.notifier).reset();
                    },
                    child: const Text('초기화'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
