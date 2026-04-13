import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../api/api_client.dart';

/// 온톨로지 / 트리플 일괄 내보내기 서비스.
///
/// - 모든 메서드는 static 유틸 함수
/// - 파일 저장은 Windows FilePicker 저장 다이얼로그 사용
/// - 최대 100건 제한은 백엔드에서도 검사, 프런트에서도 사전 방어
class ExportService {
  ExportService._();

  // ── 온톨로지 내보내기 ───────────────────────────────────────────────────────

  /// 선택한 버전 ID 목록 → JSON 파일로 저장.
  static Future<void> exportOntologies({
    required ApiClient apiClient,
    required List<String> versionIds,
    required BuildContext context,
  }) async {
    if (versionIds.isEmpty) return;
    if (versionIds.length > 100) {
      _snack(context, '최대 100건까지 선택 가능합니다', isError: true);
      return;
    }

    try {
      final response = await apiClient.post(
        '/api/ontologies/export',
        data: {'version_ids': versionIds},
      );
      final content = const JsonEncoder.withIndent('  ')
          .convert(response.data);
      if (!context.mounted) return;
      await _saveFile(
        context: context,
        content: content,
        defaultName: 'ontologies_export_${_timestamp()}.json',
      );
    } catch (e) {
      if (!context.mounted) return;
      _snack(context, '내보내기 실패: $e', isError: true);
    }
  }

  // ── 트리플 내보내기 ─────────────────────────────────────────────────────────

  /// 트리플 내보내기.
  ///
  /// [tripleIds] 지정 시 해당 ID만.
  /// 없으면 [statusFilter] / [ontologyVersion] 필터 적용 (전체).
  static Future<void> exportTriples({
    required ApiClient apiClient,
    required BuildContext context,
    List<String>? tripleIds,
    String? statusFilter,
    String? ontologyVersion,
  }) async {
    if (tripleIds != null && tripleIds.length > 100) {
      _snack(context, '최대 100건까지 선택 가능합니다', isError: true);
      return;
    }

    try {
      final body = <String, dynamic>{};
      if (tripleIds != null && tripleIds.isNotEmpty) {
        body['triple_ids'] = tripleIds;
      } else {
        if (statusFilter != null && statusFilter.isNotEmpty) {
          body['status'] = statusFilter;
        }
        if (ontologyVersion != null && ontologyVersion.isNotEmpty) {
          body['ontology_version'] = ontologyVersion;
        }
      }

      final response = await apiClient.post(
        '/api/triples/export',
        data: body,
      );
      final content = const JsonEncoder.withIndent('  ')
          .convert(response.data);
      if (!context.mounted) return;
      await _saveFile(
        context: context,
        content: content,
        defaultName: 'triples_export_${_timestamp()}.json',
      );
    } catch (e) {
      if (!context.mounted) return;
      _snack(context, '내보내기 실패: $e', isError: true);
    }
  }

  // ── 파일 저장 (Windows FilePicker 저장 다이얼로그) ─────────────────────────

  static Future<void> _saveFile({
    required BuildContext context,
    required String content,
    required String defaultName,
  }) async {
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'JSON 저장',
      fileName: defaultName,
      allowedExtensions: ['json'],
      type: FileType.custom,
    );
    if (savePath == null) return; // 사용자가 취소

    await File(savePath).writeAsString(content, encoding: utf8);

    if (!context.mounted) return;
    _snack(context, '저장 완료: $savePath');
  }

  // ── 내부 유틸 ────────────────────────────────────────────────────────────────

  static void _snack(BuildContext context, String msg,
      {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : null,
    ));
  }

  /// YYYYMMDD_HHmmss 형식 타임스탬프
  static String _timestamp() {
    final now = DateTime.now();
    final y  = now.year.toString().padLeft(4, '0');
    final mo = now.month.toString().padLeft(2, '0');
    final d  = now.day.toString().padLeft(2, '0');
    final h  = now.hour.toString().padLeft(2, '0');
    final mi = now.minute.toString().padLeft(2, '0');
    final s  = now.second.toString().padLeft(2, '0');
    return '$y$mo${d}_$h$mi$s';
  }
}
