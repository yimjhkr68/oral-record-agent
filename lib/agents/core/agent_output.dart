// lib/agents/core/agent_output.dart
// 에이전트 산출물 모델 (Hive Box<String> JSON 직렬화)

import 'dart:convert';
import 'dart:io';

enum OutputType {
  report,    // 보고서 docx
  book,      // 생애사 책 docx
  summary,   // 요약집 docx
  exportCsv, // CSV 내보내기
  exportJson, // JSON 내보내기
}

extension OutputTypeExt on OutputType {
  String get label {
    switch (this) {
      case OutputType.report: return '보고서';
      case OutputType.book: return '생애사 책';
      case OutputType.summary: return '요약집';
      case OutputType.exportCsv: return 'CSV';
      case OutputType.exportJson: return 'JSON';
    }
  }

  String get key {
    switch (this) {
      case OutputType.report: return 'report';
      case OutputType.book: return 'book';
      case OutputType.summary: return 'summary';
      case OutputType.exportCsv: return 'export_csv';
      case OutputType.exportJson: return 'export_json';
    }
  }

  static OutputType fromKey(String key) {
    switch (key) {
      case 'book': return OutputType.book;
      case 'summary': return OutputType.summary;
      case 'export_csv': return OutputType.exportCsv;
      case 'export_json': return OutputType.exportJson;
      default: return OutputType.report;
    }
  }
}

class AgentOutput {
  final String id;
  final String userAccount;
  final DateTime executedAt;
  final String userPrompt;
  final String enhancedPrompt;
  final String outputTypeKey;
  final String filePath;
  final String fileName;
  final int fileSizeBytes;
  bool fileExists;

  AgentOutput({
    required this.id,
    required this.userAccount,
    required this.executedAt,
    required this.userPrompt,
    required this.enhancedPrompt,
    required this.outputTypeKey,
    required this.filePath,
    required this.fileName,
    required this.fileSizeBytes,
    this.fileExists = true,
  });

  OutputType get type => OutputTypeExt.fromKey(outputTypeKey);

  factory AgentOutput.create({
    required String userAccount,
    required String userPrompt,
    required String enhancedPrompt,
    required String outputTypeKey,
    required String filePath,
  }) {
    final now = DateTime.now();
    final fileName = filePath.split(Platform.pathSeparator).last;
    int size = 0;
    try {
      final f = File(filePath);
      if (f.existsSync()) size = f.lengthSync();
    } catch (_) {}

    return AgentOutput(
      id: '${now.millisecondsSinceEpoch}',
      userAccount: userAccount,
      executedAt: now,
      userPrompt: userPrompt,
      enhancedPrompt: enhancedPrompt,
      outputTypeKey: outputTypeKey,
      filePath: filePath,
      fileName: fileName,
      fileSizeBytes: size,
      fileExists: size > 0 || File(filePath).existsSync(),
    );
  }

  Future<void> refreshExists() async {
    try {
      fileExists = await File(filePath).exists();
    } catch (_) {
      fileExists = false;
    }
  }

  String toJsonString() => jsonEncode({
        'id': id,
        'userAccount': userAccount,
        'executedAt': executedAt.millisecondsSinceEpoch,
        'userPrompt': userPrompt,
        'enhancedPrompt': enhancedPrompt,
        'outputTypeKey': outputTypeKey,
        'filePath': filePath,
        'fileName': fileName,
        'fileSizeBytes': fileSizeBytes,
        'fileExists': fileExists,
      });

  factory AgentOutput.fromJsonString(String jsonStr) {
    final m = jsonDecode(jsonStr) as Map<String, dynamic>;
    return AgentOutput(
      id: m['id'] as String,
      userAccount: m['userAccount'] as String? ?? '',
      executedAt:
          DateTime.fromMillisecondsSinceEpoch(m['executedAt'] as int),
      userPrompt: m['userPrompt'] as String? ?? '',
      enhancedPrompt: m['enhancedPrompt'] as String? ?? '',
      outputTypeKey: m['outputTypeKey'] as String? ?? 'report',
      filePath: m['filePath'] as String? ?? '',
      fileName: m['fileName'] as String? ?? '',
      fileSizeBytes: m['fileSizeBytes'] as int? ?? 0,
      fileExists: m['fileExists'] as bool? ?? false,
    );
  }
}
