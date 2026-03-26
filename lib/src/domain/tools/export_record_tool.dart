// 파일 목적: 기록 내보내기 도구 (AI 호출용 래퍼)
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/models/record.dart';
import '../../data/models/narrator.dart';
import '../../data/models/interviewer.dart';
import '../../data/models/interview_session.dart';
import '../../data/services/import_export_service.dart';

class ExportResult {
  final bool success;
  final String? filePath;
  final String? error;
  final int count;
  const ExportResult({
    required this.success,
    this.filePath,
    this.error,
    this.count = 0,
  });
}

class ExportRecordTool {
  /// 기록 CSV 내보내기
  static Future<ExportResult> exportRecordsCsv(
    List<Record> records, {
    Map<String, Narrator> narratorMap = const {},
    Map<String, Interviewer> interviewerMap = const {},
    Map<String, InterviewSession> sessionMap = const {},
    bool includeContent = false,
    bool includeSummary = false,
  }) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final exportDir =
          Directory('${docsDir.path}/OralRecordAgent/exports');
      await exportDir.create(recursive: true);
      final now = DateTime.now();
      final fileName =
          'records_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.csv';
      final filePath = '${exportDir.path}/$fileName';
      final content = ImportExportService.exportRecordsCsv(
        records,
        narratorMap,
        interviewerMap,
        sessionMap,
        includeContent: includeContent,
        includeSummary: includeSummary,
      );
      await File(filePath).writeAsString(content, flush: true);
      debugPrint(
          '[ExportTool] 기록 CSV 내보내기 완료: $filePath (${records.length}건)');
      return ExportResult(
          success: true, filePath: filePath, count: records.length);
    } catch (e) {
      return ExportResult(success: false, error: '$e');
    }
  }

  /// 구술자 CSV 내보내기
  static Future<ExportResult> exportNarratorsCsv(
      List<Narrator> narrators) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final exportDir =
          Directory('${docsDir.path}/OralRecordAgent/exports');
      await exportDir.create(recursive: true);
      final now = DateTime.now();
      final fileName =
          'narrators_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.csv';
      final filePath = '${exportDir.path}/$fileName';
      final content =
          ImportExportService.exportNarratorsCsv(narrators);
      await File(filePath).writeAsString(content, flush: true);
      debugPrint(
          '[ExportTool] 구술자 CSV 내보내기 완료: $filePath (${narrators.length}건)');
      return ExportResult(
          success: true, filePath: filePath, count: narrators.length);
    } catch (e) {
      return ExportResult(success: false, error: '$e');
    }
  }

  /// 전체 JSON 백업
  static Future<ExportResult> exportAllJson({
    required List<Record> records,
    required List<Narrator> narrators,
    required List<Interviewer> interviewers,
    List<InterviewSession> sessions = const [],
  }) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final exportDir =
          Directory('${docsDir.path}/OralRecordAgent/exports');
      await exportDir.create(recursive: true);
      final now = DateTime.now();
      final fileName =
          'backup_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.json';
      final filePath = '${exportDir.path}/$fileName';
      final content = ImportExportService.exportAllJson(
          records, narrators, interviewers, sessions);
      await File(filePath).writeAsString(content, flush: true);
      final total =
          records.length + narrators.length + interviewers.length;
      debugPrint('[ExportTool] JSON 백업 완료: $filePath ($total건)');
      return ExportResult(
          success: true, filePath: filePath, count: total);
    } catch (e) {
      return ExportResult(success: false, error: '$e');
    }
  }

  /// CSV 템플릿 파일 생성 (들여오기용)
  static Future<ExportResult> createCsvTemplate(String type) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final exportDir =
          Directory('${docsDir.path}/OralRecordAgent/templates');
      await exportDir.create(recursive: true);
      final filePath = '${exportDir.path}/${type}_template.csv';
      final content = _getTemplate(type);
      await File(filePath).writeAsString(content, flush: true);
      debugPrint('[ExportTool] 템플릿 생성 완료: $filePath');
      return ExportResult(
          success: true, filePath: filePath, count: 1);
    } catch (e) {
      return ExportResult(success: false, error: '$e');
    }
  }

  static String _getTemplate(String type) {
    switch (type) {
      case 'records':
        return '제목,구술자,면담자,면담일시,면담장소,주제대분류,주제소분류,키워드태그,비공개,메모\n'
            '예시 기록,홍길동,김연구,2024-01-01,서울,개인사,생애사,태그1,N,\n';
      case 'narrators':
        return '이름,생년월일,성별,직업(당시),직업(현재),소속,메모\n'
            '홍길동,1950-01-01,M,전직 공무원,退職,자택,\n';
      case 'interviewers':
        return '이름,소속,직위,전문분야,메모\n'
            '김연구,역사연구소,연구원,구술사,\n';
      default:
        return '';
    }
  }
}
