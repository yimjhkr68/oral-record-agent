// 파일 목적: 앱 시작 시 displayId 없는 레코드/구술자/면담자에 displayId 일괄 할당
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/search_filters.dart';
import '../../data/services/display_id_service.dart';
import '../../data/repositories/repository_provider.dart';
import 'record_provider.dart';
import 'master_data_provider.dart';

final displayIdMigrationProvider = FutureProvider<void>((ref) async {
  // ── Records ──────────────────────────────────────────────────────
  final recordRepo = await ref.read(recordRepositoryProvider.future);
  final allRecords = await recordRepo.searchRecords(
    SearchFilters(limit: 100000),
  );

  final recordsNeedingId = allRecords.where((r) => r.displayId == null).toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  if (recordsNeedingId.isNotEmpty) {
    // 이미 할당된 displayId 목록 수집
    final existingRecordIds = allRecords
        .where((r) => r.displayId != null)
        .map((r) => r.displayId!)
        .toList();

    for (final record in recordsNeedingId) {
      final newId = DisplayIdService.generateRecordId(
          record.createdAt, existingRecordIds);
      existingRecordIds.add(newId);
      final updated = record.copyWith(displayId: newId);
      await recordRepo.updateRecord(record.id, updated);
    }
    ref.invalidate(recordListProvider);
    ref.invalidate(recentRecordsProvider);
  }

  // ── Narrators ──────────────────────────────────────────────────────
  final narratorRepo = await ref.read(narratorRepositoryProvider.future);
  final allNarrators = await narratorRepo.getAllNarrators();

  final narratorsNeedingId =
      allNarrators.where((n) => n.displayId == null).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  if (narratorsNeedingId.isNotEmpty) {
    final existingNarratorIds = allNarrators
        .where((n) => n.displayId != null)
        .map((n) => n.displayId!)
        .toList();

    for (final narrator in narratorsNeedingId) {
      final newId = DisplayIdService.generateNarratorId(
          narrator.createdAt, existingNarratorIds);
      existingNarratorIds.add(newId);
      final updated = narrator.copyWith(displayId: newId);
      await narratorRepo.updateNarrator(narrator.id, updated);
    }
    ref.invalidate(narratorListProvider);
    ref.invalidate(narratorMapProvider);
  }

  // ── Interviewers ──────────────────────────────────────────────────────
  final interviewerRepo = await ref.read(interviewerRepositoryProvider.future);
  final allInterviewers = await interviewerRepo.getAllInterviewers();

  final interviewersNeedingId =
      allInterviewers.where((i) => i.displayId == null).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  if (interviewersNeedingId.isNotEmpty) {
    final existingInterviewerIds = allInterviewers
        .where((i) => i.displayId != null)
        .map((i) => i.displayId!)
        .toList();

    for (final interviewer in interviewersNeedingId) {
      final newId = DisplayIdService.generateInterviewerId(
          interviewer.createdAt, existingInterviewerIds);
      existingInterviewerIds.add(newId);
      final updated = interviewer.copyWith(displayId: newId);
      await interviewerRepo.updateInterviewer(interviewer.id, updated);
    }
    ref.invalidate(interviewerListProvider);
    ref.invalidate(interviewerMapProvider);
  }
});
