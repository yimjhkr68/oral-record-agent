// 파일 목적: 구술자/면담자 목록 Provider
// 드롭다운 선택용 마스터 데이터

import 'package:riverpod/riverpod.dart';
import '../../data/models/narrator.dart';
import '../../data/models/interviewer.dart';
import '../../data/models/interview_session.dart';
import '../../data/repositories/repository_provider.dart';

/// 전체 구술자 목록 Provider
final narratorListProvider = FutureProvider<List<Narrator>>(
  (ref) async {
    final repository = await ref.watch(narratorRepositoryProvider.future);
    return repository.getAllNarrators();
  },
);

/// 전체 면담자 목록 Provider
final interviewerListProvider = FutureProvider<List<Interviewer>>(
  (ref) async {
    final repository = await ref.watch(interviewerRepositoryProvider.future);
    return repository.getAllInterviewers();
  },
);

/// 선택된 구술자 Provider
final selectedNarratorProvider = StateProvider<Narrator?>((ref) => null);

/// 선택된 면담자 Provider
final selectedInterviewerProvider = StateProvider<Interviewer?>((ref) => null);

/// 최근 구술자 3명 (updatedAt 기준 내림차순)
final recentNarratorsProvider = FutureProvider<List<Narrator>>(
  (ref) async {
    final list = await ref.watch(narratorListProvider.future);
    final sorted = [...list]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted.take(3).toList();
  },
);

/// 최근 면담자 3명 (updatedAt 기준 내림차순)
final recentInterviewersProvider = FutureProvider<List<Interviewer>>(
  (ref) async {
    final list = await ref.watch(interviewerListProvider.future);
    final sorted = [...list]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted.take(3).toList();
  },
);

/// 구술자 ID → Narrator 조회 맵
final narratorMapProvider = FutureProvider<Map<String, Narrator>>(
  (ref) async {
    final list = await ref.watch(narratorListProvider.future);
    return {for (final n in list) n.id: n};
  },
);

/// 면담자 ID → Interviewer 조회 맵
final interviewerMapProvider = FutureProvider<Map<String, Interviewer>>(
  (ref) async {
    final list = await ref.watch(interviewerListProvider.future);
    return {for (final i in list) i.id: i};
  },
);

/// 전체 면담 세션 목록 Provider
final sessionListProvider = FutureProvider<List<InterviewSession>>(
  (ref) async {
    final repository = await ref.watch(sessionRepositoryProvider.future);
    return repository.getAllSessions();
  },
);

/// 세션 ID → InterviewSession 조회 맵
final sessionMapProvider = FutureProvider<Map<String, InterviewSession>>(
  (ref) async {
    final list = await ref.watch(sessionListProvider.future);
    return {for (final s in list) s.id: s};
  },
);
