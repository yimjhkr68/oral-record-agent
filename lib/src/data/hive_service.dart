// 파일 목적: Hive 데이터베이스 초기화 및 박스 관리 서비스
// 앱 시작 시 Hive를 초기화하고 5개 박스(테이블)를 등록/열기
// 모든 TypeAdapter를 Hive에 등록하여 모델 직렬화 준비

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'models/narrator.dart';
import 'models/interviewer.dart';
import 'models/interview_session.dart';
import 'models/record.dart';
import 'models/app_settings.dart';

import 'hive_adapters/narrator_adapter.dart';
import 'hive_adapters/interviewer_adapter.dart';
import 'hive_adapters/interview_session_adapter.dart';
import 'hive_adapters/record_adapter.dart';
import 'hive_adapters/pii_item_adapter.dart';
import 'hive_adapters/app_settings_adapter.dart';

/// Hive 데이터베이스 초기화 및 박스 관리 서비스
///
/// 책임:
/// 1. Hive 초기화 (HiveFlutter.initFlutter)
/// 2. 6개 TypeAdapter 등록 (Hive.registerAdapter)
/// 3. 5개 데이터 박스 오픈 및 반환
/// 4. 기본값 설정 (AppSettings 기본값)
class HiveService {
  /// Hive 초기화 및 모든 박스 준비
  /// 앱 main() 함수에서 가장 먼저 호출되어야 함
  static Future<void> initializeHive() async {
    // Hive Flutter 초기화 (플랫폼별 저장소 경로 자동 설정)
    await Hive.initFlutter();

    // 6개 TypeAdapter 등록 (순서: typeId 0 → 5)
    // 각 어댑터의 typeId는 고유해야 함 (중복 금지)
    Hive.registerAdapter(NarratorAdapter()); // typeId: 0
    Hive.registerAdapter(InterviewerAdapter()); // typeId: 1
    Hive.registerAdapter(InterviewSessionAdapter()); // typeId: 2
    Hive.registerAdapter(RecordAdapter()); // typeId: 3
    Hive.registerAdapter(PIIItemAdapter()); // typeId: 4
    Hive.registerAdapter(AppSettingsAdapter()); // typeId: 5
  }

  // ── lock 충돌 시 lock 파일 삭제 후 재시도 ──────────────────────
  static Future<Box<T>> _openBox<T>(String boxName) async {
    if (Hive.isBoxOpen(boxName)) return Hive.box<T>(boxName);
    try {
      return await Hive.openBox<T>(boxName);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('lock') || msg.contains('PathAccessException') ||
          msg.contains('errno = 33') || msg.contains('errno = 32')) {
        debugPrint('[Hive] lock 충돌 → $boxName.lock 삭제 후 재시도');
        try {
          final docsDir = await getApplicationDocumentsDirectory();
          final lockFile = File('${docsDir.path}/$boxName.lock');
          if (await lockFile.exists()) await lockFile.delete();
        } catch (_) {}
        return await Hive.openBox<T>(boxName);
      }
      rethrow;
    }
  }

  /// Narrator 박스 오픈
  static Future<Box<Narrator>> openNarratorBox() async {
    try {
      return await _openBox<Narrator>('narrators');
    } catch (e) {
      throw HiveException('Narrator 박스 오픈 실패: $e');
    }
  }

  /// Interviewer 박스 오픈
  static Future<Box<Interviewer>> openInterviewerBox() async {
    try {
      return await _openBox<Interviewer>('interviewers');
    } catch (e) {
      throw HiveException('Interviewer 박스 오픈 실패: $e');
    }
  }

  /// InterviewSession 박스 오픈
  static Future<Box<InterviewSession>> openSessionBox() async {
    try {
      return await _openBox<InterviewSession>('sessions');
    } catch (e) {
      throw HiveException('InterviewSession 박스 오픈 실패: $e');
    }
  }

  /// Record 박스 오픈
  static Future<Box<Record>> openRecordBox() async {
    try {
      return await _openBox<Record>('records');
    } catch (e) {
      throw HiveException('Record 박스 오픈 실패: $e');
    }
  }

  /// AppSettings 박스 오픈
  static Future<Box<AppSettings>> openSettingsBox() async {
    try {
      final settingsBox = await _openBox<AppSettings>('settings');
      if (!settingsBox.containsKey('app_settings')) {
        await settingsBox.put('app_settings', AppSettings(
          id: 'app_settings',
          language: 'ko',
          autoTranscribe: false,
          piiDetectionEnabled: true,
          exportFormat: 'json',
        ));
      }
      return settingsBox;
    } catch (e) {
      throw HiveException('AppSettings 박스 오픈 실패: $e');
    }
  }

  /// 모든 박스 초기화 및 오픈
  /// 정상적인 앱 시작 흐름:
  /// 1. await HiveService.initializeHive()          → TypeAdapter 등록
  /// 2. await HiveService.initializeAllBoxes()      → 모든 박스 오픈 + 기본값 설정
  /// 3. 이제 Repository에서 박스 접근 가능
  static Future<void> initializeAllBoxes() async {
    await openNarratorBox();
    await openInterviewerBox();
    await openSessionBox();
    await openRecordBox();
    await openSettingsBox();
    await _openFileBytesBox();
    await _openAccountsBox();
    await _openAuthPrefsBox();
  }

  /// 파일 바이트(base64) 박스 오픈 (FileStorageService 사용)
  static Future<Box<String>> _openFileBytesBox() async {
    if (!Hive.isBoxOpen('file_bytes')) {
      return await Hive.openBox<String>('file_bytes');
    }
    return Hive.box<String>('file_bytes');
  }

  /// 계정 박스 오픈 (JSON 문자열 직렬화)
  static Future<Box<String>> _openAccountsBox() async {
    if (!Hive.isBoxOpen('accounts')) {
      return await Hive.openBox<String>('accounts');
    }
    return Hive.box<String>('accounts');
  }

  /// 인증 환경설정 박스 오픈 (자동 로그인 등)
  static Future<Box<String>> _openAuthPrefsBox() async {
    if (!Hive.isBoxOpen('auth_prefs')) {
      return await Hive.openBox<String>('auth_prefs');
    }
    return Hive.box<String>('auth_prefs');
  }

  /// 샘플 데이터 시드 (빈 박스일 때만 삽입)
  /// 앱 최초 실행 시 드롭다운 옵션이 없는 문제 해결
  static Future<void> seedSampleData() async {
    final narratorBox = Hive.box<Narrator>('narrators');
    if (narratorBox.isEmpty) {
      final samples = [
        Narrator(id: 'narrator-001', name: '김철수', jobTitle: '전직 공무원'),
        Narrator(id: 'narrator-002', name: '이영희', jobTitle: '농업인'),
        Narrator(id: 'narrator-003', name: '박민준', jobTitle: '교육자'),
      ];
      for (final n in samples) {
        await narratorBox.put(n.id, n);
      }
    }

    final interviewerBox = Hive.box<Interviewer>('interviewers');
    if (interviewerBox.isEmpty) {
      final samples = [
        Interviewer(
            id: 'interviewer-001', name: '연구원 A', affiliation: '구술기록연구소'),
        Interviewer(
            id: 'interviewer-002', name: '연구원 B', affiliation: '구술기록연구소'),
      ];
      for (final i in samples) {
        await interviewerBox.put(i.id, i);
      }
    }
  }

  /// 모든 박스 닫기 (앱 종료 시)
  /// 주의: 이 함수 호출 후 박스 접근 불가능
  static Future<void> closeAllBoxes() async {
    try {
      await Hive.close();
    } catch (e) {
      throw HiveException('박스 닫기 실패: $e');
    }
  }

  /// 모든 데이터 삭제 (디버깅/테스트용)
  /// 주의: 운영 앱에서는 사용 금지!
  static Future<void> clearAllData() async {
    try {
      if (Hive.isBoxOpen('narrators')) {
        await Hive.box('narrators').clear();
      }
      if (Hive.isBoxOpen('interviewers')) {
        await Hive.box('interviewers').clear();
      }
      if (Hive.isBoxOpen('sessions')) {
        await Hive.box('sessions').clear();
      }
      if (Hive.isBoxOpen('records')) {
        await Hive.box('records').clear();
      }
      if (Hive.isBoxOpen('settings')) {
        await Hive.box('settings').clear();
      }
    } catch (e) {
      throw HiveException('데이터 삭제 실패: $e');
    }
  }
}

/// Hive 서비스 예외 (HiveException의 래퍼)
class HiveException implements Exception {
  final String message;
  HiveException(this.message);
  @override
  String toString() => 'HiveException: $message';
}
