// 파일 목적: Repository Provider 통합 (Riverpod 바인딩)
//
// 바인딩 전략:
//   - 텍스트 데이터 (Record, Narrator 등): HiveRecordRepository
//   - 파일 저장소: LocalFileStorage
//   - 나중에 클라우드 전환 시:
//     fileStorageProvider 바인딩만 LocalFileStorage → S3FileStorage로 교체

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:oral_record_agent/src/data/models/narrator.dart';
import 'package:oral_record_agent/src/data/models/interviewer.dart';
import 'package:oral_record_agent/src/data/models/interview_session.dart';
import 'package:oral_record_agent/src/data/models/record.dart';
import 'package:oral_record_agent/src/data/repositories/narrator_repository.dart';
import 'package:oral_record_agent/src/data/repositories/interviewer_repository.dart';
import 'package:oral_record_agent/src/data/repositories/interview_session_repository.dart';
import 'package:oral_record_agent/src/data/repositories/record_repository.dart';
import 'package:oral_record_agent/src/data/repositories/file_storage_repository.dart';

// ──────────────────────────────────────────────────────────
// Hive Box Providers (main.dart에서 initializeAllBoxes() 후 사용 가능)
// ──────────────────────────────────────────────────────────

final narratorBoxProvider = FutureProvider<Box<Narrator>>((ref) async {
  return Hive.box<Narrator>('narrators');
});

final interviewerBoxProvider = FutureProvider<Box<Interviewer>>((ref) async {
  return Hive.box<Interviewer>('interviewers');
});

final sessionBoxProvider = FutureProvider<Box<InterviewSession>>((ref) async {
  return Hive.box<InterviewSession>('sessions');
});

final recordBoxProvider = FutureProvider<Box<Record>>((ref) async {
  return Hive.box<Record>('records');
});

// ──────────────────────────────────────────────────────────
// Repository Providers (텍스트 데이터)
// ──────────────────────────────────────────────────────────

final narratorRepositoryProvider =
    FutureProvider<NarratorRepository>((ref) async {
  final box = await ref.watch(narratorBoxProvider.future);
  return HiveNarratorRepository(box);
});

final interviewerRepositoryProvider =
    FutureProvider<InterviewerRepository>((ref) async {
  final box = await ref.watch(interviewerBoxProvider.future);
  return HiveInterviewerRepository(box);
});

final sessionRepositoryProvider =
    FutureProvider<InterviewSessionRepository>((ref) async {
  final box = await ref.watch(sessionBoxProvider.future);
  return HiveInterviewSessionRepository(box);
});

final recordRepositoryProvider = FutureProvider<RecordRepository>((ref) async {
  final box = await ref.watch(recordBoxProvider.future);
  return HiveRecordRepository(box);
});

// ──────────────────────────────────────────────────────────
// FileStorage Provider (파일 바이트 저장소)
//
// 현재: LocalFileStorage (Hive/IndexedDB)
// 나중에: S3FileStorage로 이 한 줄만 교체
// ──────────────────────────────────────────────────────────

/// 파일 저장소 Provider
/// Windows: WindowsFileStorage (dart:io + path_provider)
/// 클라우드 전환 시 WindowsFileStorage → S3FileStorage 한 줄 교체
final fileStorageProvider = Provider<FileStorage>((ref) {
  return WindowsFileStorage();
});
