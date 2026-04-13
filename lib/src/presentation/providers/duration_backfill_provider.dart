// 파일 목적: 앱 시작 시 duration 없는 음성/영상 기록 백그라운드 일괄 측정
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/repositories/repository_provider.dart';
import '../../data/models/search_filters.dart' show SearchFilters;
import '../../data/services/duration_service.dart';
import '../providers/settings_provider.dart';
import '../providers/record_provider.dart';

final durationBackfillProvider = FutureProvider<void>((ref) async {
  final repo = await ref.read(recordRepositoryProvider.future);
  final fileStorage = ref.read(fileStorageProvider);
  final settings = ref.read(settingsProvider);

  final allRecords = await repo.searchRecords(SearchFilters());
  final targets = allRecords.where((r) =>
    r.duration == null &&
    (r.inputType == 'audio' || r.inputType == 'video'),
  ).toList();

  if (targets.isEmpty) return;

  final tmpDir = await getTemporaryDirectory();

  for (final record in targets) {
    try {
      final bytes = await fileStorage.loadBytes(record.id);
      if (bytes == null || bytes.isEmpty) continue;

      final ext = record.originalFileName?.split('.').last ?? 'wav';
      final tmpFile = File('${tmpDir.path}/dur_${record.id}.$ext');
      await tmpFile.writeAsBytes(bytes, flush: true);

      final seconds = await DurationService.getDuration(
        filePath: tmpFile.path,
        pythonPath: settings.pythonPath,
      );

      try { await tmpFile.delete(); } catch (_) {}

      if (seconds != null) {
        final updated = record.copyWith(duration: seconds);
        await repo.updateRecord(record.id, updated);
      }
    } catch (_) {}
  }

  ref.invalidate(recordListProvider);
  ref.invalidate(recentRecordsProvider);
});
