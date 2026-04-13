// 파일 목적: CSV/JSON 가져오기·내보내기 서비스
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../models/record.dart';
import '../models/narrator.dart';
import '../models/interviewer.dart';
import '../models/interview_session.dart';
import '../models/search_filters.dart';
import '../repositories/narrator_repository.dart';
import '../repositories/interviewer_repository.dart';
import '../repositories/record_repository.dart';
import '../repositories/interview_session_repository.dart';
import '../repositories/file_storage_repository.dart';
import '../services/display_id_service.dart';

// ── ImportResult ─────────────────────────────────────────
class ImportResult {
  final int imported;
  final int failed;
  final int importedWithFile;
  final int importedTextOnly;
  final List<String> errors;

  const ImportResult({
    required this.imported,
    required this.failed,
    required this.errors,
    this.importedWithFile = 0,
    this.importedTextOnly = 0,
  });
}

// ── 파일 확장자 → MIME 타입 ──────────────────────────────
String _mimeTypeFromExt(String ext) {
  const map = {
    'mp3': 'audio/mpeg',
    'wav': 'audio/wav',
    'm4a': 'audio/mp4',
    'aac': 'audio/aac',
    'flac': 'audio/flac',
    'mp4': 'video/mp4',
    'avi': 'video/x-msvideo',
    'mov': 'video/quicktime',
    'mkv': 'video/x-matroska',
    'wmv': 'video/x-ms-wmv',
    'pdf': 'application/pdf',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'txt': 'text/plain',
  };
  return map[ext] ?? 'application/octet-stream';
}

// ── MIME 타입 → inputType ────────────────────────────────
String _inputTypeFromMime(String mime) {
  if (mime.startsWith('audio/')) return 'audio';
  if (mime.startsWith('video/')) return 'video';
  return 'document';
}

// ── CSV 파서 (quoted fields 지원) ─────────────────────────
List<List<String>> parseCsv(String text) {
  final rows = <List<String>>[];
  final lines = text.split('\n');
  for (final raw in lines) {
    final line = raw.trimRight();
    if (line.isEmpty) continue;
    rows.add(_parseCsvRow(line));
  }
  return rows;
}

List<String> _parseCsvRow(String line) {
  final fields = <String>[];
  bool inQuote = false;
  final buf = StringBuffer();
  for (int i = 0; i < line.length; i++) {
    final c = line[i];
    if (c == '"') {
      if (inQuote && i + 1 < line.length && line[i + 1] == '"') {
        buf.write('"');
        i++;
      } else {
        inQuote = !inQuote;
      }
    } else if (c == ',' && !inQuote) {
      fields.add(buf.toString());
      buf.clear();
    } else {
      buf.write(c);
    }
  }
  fields.add(buf.toString());
  return fields;
}

String _csvField(String? value) {
  if (value == null || value.isEmpty) return '';
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

String _buildCsvRow(List<String?> fields) =>
    fields.map(_csvField).join(',');

// ── 날짜 파싱 ────────────────────────────────────────────
DateTime? _parseDate(String s) {
  final trimmed = s.trim();
  if (trimmed.isEmpty) return null;
  try {
    if (trimmed.length == 10) return DateTime.parse('${trimmed}T00:00:00');
    if (trimmed.length >= 16) {
      return DateTime.parse(trimmed.replaceFirst(' ', 'T'));
    }
  } catch (_) {}
  return null;
}

String _formatDate(DateTime? dt) {
  if (dt == null) return '';
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

String _formatDateTime(DateTime dt) {
  return '${_formatDate(dt)} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// 전체 조회용 필터
final _allFilters = SearchFilters(limit: 999999);

// ── ImportExportService ───────────────────────────────────
class ImportExportService {
  // ─── 기록 CSV 가져오기 ────────────────────────────────
  // 헤더: 제목,구술자,면담자,면담일시,면담장소,주제대분류,주제소분류,키워드태그,비공개,메모,파일경로
  static Future<ImportResult> importRecordsCsv(
    String csvText,
    bool overwrite,
    RecordRepository recordRepo,
    NarratorRepository narratorRepo,
    InterviewerRepository interviewerRepo,
    InterviewSessionRepository sessionRepo, {
    FileStorage? fileStorage,
  }) async {
    final rows = parseCsv(csvText);
    if (rows.isEmpty) {
      return const ImportResult(
          imported: 0, failed: 0, errors: ['CSV가 비어 있습니다']);
    }
    final dataRows = rows.skip(1).toList();

    if (overwrite) {
      final all = await recordRepo.searchRecords(_allFilters);
      for (final r in all) {
        await recordRepo.deleteRecord(r.id);
      }
    }

    final errors = <String>[];
    int imported = 0;
    int importedWithFile = 0;
    int importedTextOnly = 0;

    // 기존 displayId 수집
    final existingRecords = await recordRepo.searchRecords(_allFilters);
    final existingDisplayIds = existingRecords
        .where((r) => r.displayId != null)
        .map((r) => r.displayId!)
        .toList();

    // 기존 구술자/면담자 맵
    final narrators = await narratorRepo.getAllNarrators();
    final narratorByName = <String, Narrator>{
      for (final n in narrators) n.name: n,
    };
    final interviewers = await interviewerRepo.getAllInterviewers();
    final interviewerByName = <String, Interviewer>{
      for (final i in interviewers) i.name: i,
    };
    // 기존 세션 목록
    final sessions = await sessionRepo.getAllSessions();

    for (int i = 0; i < dataRows.length; i++) {
      final rowNum = i + 2;
      final row = dataRows[i];
      try {
        final title = row.isNotEmpty ? row[0].trim() : '';
        if (title.isEmpty) {
          errors.add('$rowNum행: 제목 누락');
          continue;
        }
        final narratorName = row.length > 1 ? row[1].trim() : '';
        if (narratorName.isEmpty) {
          errors.add('$rowNum행: 구술자 이름 누락');
          continue;
        }
        final interviewerName = row.length > 2 ? row[2].trim() : '';
        final interviewDateStr = row.length > 3 ? row[3].trim() : '';
        final location = row.length > 4 ? row[4].trim() : '';
        final mainCategory =
            row.length > 5 && row[5].trim().isNotEmpty ? row[5].trim() : '기타';
        final subCategory = row.length > 6 ? row[6].trim() : '';
        final keywordTagsStr = row.length > 7 ? row[7].trim() : '';
        final isPrivateStr = row.length > 8 ? row[8].trim() : '';
        // col 9: 메모 (세션 notes - 현재 미사용)
        final filePath = row.length > 10 ? row[10].trim() : '';

        // ── 파일 처리 ────────────────────────────────────
        String inputType = 'text';
        String? originalFileName;
        int? fileSize;
        String? mimeType;
        Uint8List? fileBytes;

        if (filePath.isNotEmpty) {
          final srcFile = File(filePath);
          if (await srcFile.exists()) {
            fileBytes = await srcFile.readAsBytes();
            originalFileName = srcFile.uri.pathSegments.last;
            fileSize = fileBytes.length;
            final ext = originalFileName.contains('.')
                ? originalFileName.split('.').last.toLowerCase()
                : '';
            mimeType = _mimeTypeFromExt(ext);
            inputType = _inputTypeFromMime(mimeType);
          } else {
            errors.add('$rowNum행: 파일을 찾을 수 없습니다 — $filePath (텍스트만 가져옵니다)');
          }
        }

        // 구술자 조회 또는 생성
        Narrator narrator;
        if (narratorByName.containsKey(narratorName)) {
          narrator = narratorByName[narratorName]!;
        } else {
          final allNarrators = await narratorRepo.getAllNarrators();
          final existingNarDisplayIds = allNarrators
              .where((n) => n.displayId != null)
              .map((n) => n.displayId!)
              .toList();
          final newDisplayId = DisplayIdService.generateNarratorId(
              DateTime.now(), existingNarDisplayIds);
          narrator = Narrator(name: narratorName, displayId: newDisplayId);
          await narratorRepo.createNarrator(narrator);
          narratorByName[narratorName] = narrator;
        }

        // 면담자 조회 또는 생성
        final effInterviewerName =
            interviewerName.isEmpty ? '미상' : interviewerName;
        Interviewer interviewer;
        if (interviewerByName.containsKey(effInterviewerName)) {
          interviewer = interviewerByName[effInterviewerName]!;
        } else {
          final allInterviewers = await interviewerRepo.getAllInterviewers();
          final existingIntDisplayIds = allInterviewers
              .where((iv) => iv.displayId != null)
              .map((iv) => iv.displayId!)
              .toList();
          final newDisplayId = DisplayIdService.generateInterviewerId(
              DateTime.now(), existingIntDisplayIds);
          interviewer =
              Interviewer(name: effInterviewerName, displayId: newDisplayId);
          await interviewerRepo.createInterviewer(interviewer);
          interviewerByName[effInterviewerName] = interviewer;
        }

        // 세션 생성
        final narratorSessions =
            sessions.where((s) => s.narratorId == narrator.id).toList();
        final nextSessionNo = narratorSessions.isEmpty
            ? 1
            : narratorSessions
                    .map((s) => s.sessionNo)
                    .reduce((a, b) => a > b ? a : b) +
                1;
        final interviewDate = _parseDate(interviewDateStr) ?? DateTime.now();
        final session = InterviewSession(
          narratorId: narrator.id,
          interviewerId: interviewer.id,
          sessionNo: nextSessionNo,
          interviewDate: interviewDate,
          location: location.isEmpty ? null : location,
          interviewType: 'oral',
        );
        await sessionRepo.createSession(session);
        sessions.add(session);

        // 키워드 태그 파싱
        final keywordTags = keywordTagsStr.isEmpty
            ? <String>[]
            : keywordTagsStr
                .split(',')
                .map((t) => t.trim())
                .where((t) => t.isNotEmpty)
                .toList();

        // 비공개 여부
        final isPrivate =
            isPrivateStr == 'Y' || isPrivateStr == 'y' || isPrivateStr == '1';

        // displayId 생성
        final newDisplayId = DisplayIdService.generateRecordId(
            DateTime.now(), existingDisplayIds);
        existingDisplayIds.add(newDisplayId);

        final record = Record(
          title: title,
          content: '',
          inputType: inputType,
          sessionId: session.id,
          narratorId: narrator.id,
          mainCategory: mainCategory,
          subCategory: subCategory.isEmpty ? null : subCategory,
          keywordTags: keywordTags,
          visibility: isPrivate ? 'private' : 'public',
          recordedBy: 'imported',
          displayId: newDisplayId,
          originalFileName: originalFileName,
          fileSize: fileSize,
          mimeType: mimeType,
        );
        await recordRepo.createRecord(record);

        // ── 파일 저장소에 복사 ────────────────────────────
        if (fileBytes != null &&
            fileStorage != null &&
            originalFileName != null &&
            mimeType != null) {
          await fileStorage.saveFile(
            recordId: record.id,
            bytes: fileBytes,
            fileName: originalFileName,
            mimeType: mimeType,
          );
          importedWithFile++;
        } else {
          importedTextOnly++;
        }

        imported++;
      } catch (e) {
        errors.add('$rowNum행: $e');
      }
    }

    return ImportResult(
      imported: imported,
      failed: errors.length,
      errors: errors,
      importedWithFile: importedWithFile,
      importedTextOnly: importedTextOnly,
    );
  }

  // ─── 구술자 CSV 가져오기 ──────────────────────────────
  // 헤더: 이름,생년월일,성별,직업(당시),직업(현재),소속,메모
  static Future<ImportResult> importNarratorsCsv(
    String csvText,
    bool overwrite,
    NarratorRepository repo,
  ) async {
    final rows = parseCsv(csvText);
    if (rows.isEmpty) {
      return const ImportResult(
          imported: 0, failed: 0, errors: ['CSV가 비어 있습니다']);
    }
    final dataRows = rows.skip(1).toList();

    if (overwrite) {
      final all = await repo.getAllNarrators();
      for (final n in all) {
        await repo.deleteNarrator(n.id);
      }
    }

    final errors = <String>[];
    int imported = 0;
    final existingAll = await repo.getAllNarrators();
    final existingDisplayIds = existingAll
        .where((n) => n.displayId != null)
        .map((n) => n.displayId!)
        .toList();

    for (int i = 0; i < dataRows.length; i++) {
      final rowNum = i + 2;
      final row = dataRows[i];
      try {
        final name = row.isNotEmpty ? row[0].trim() : '';
        if (name.isEmpty) {
          errors.add('$rowNum행: 이름 누락');
          continue;
        }
        final dobStr = row.length > 1 ? row[1].trim() : '';
        final genderRaw = row.length > 2 ? row[2].trim() : '';
        final jobTitle = row.length > 3 ? row[3].trim() : '';
        final currentJobTitle = row.length > 4 ? row[4].trim() : '';
        final affiliation = row.length > 5 ? row[5].trim() : '';
        final notes = row.length > 6 ? row[6].trim() : '';

        final dob = _parseDate(dobStr);
        String? gender;
        if (genderRaw == '남' || genderRaw == 'M') {
          gender = 'M';
        } else if (genderRaw == '여' || genderRaw == 'F') {
          gender = 'F';
        } else if (genderRaw.isNotEmpty) {
          gender = genderRaw;
        }

        final displayId = DisplayIdService.generateNarratorId(
            DateTime.now(), existingDisplayIds);
        existingDisplayIds.add(displayId);

        final narrator = Narrator(
          name: name,
          dateOfBirth: dob,
          gender: gender,
          jobTitle: jobTitle.isEmpty ? null : jobTitle,
          currentJobTitle: currentJobTitle.isEmpty ? null : currentJobTitle,
          affiliation: affiliation.isEmpty ? null : affiliation,
          notes: notes.isEmpty ? null : notes,
          displayId: displayId,
        );
        await repo.createNarrator(narrator);
        imported++;
      } catch (e) {
        errors.add('$rowNum행: $e');
      }
    }

    return ImportResult(
        imported: imported, failed: errors.length, errors: errors);
  }

  // ─── 면담자 CSV 가져오기 ──────────────────────────────
  // 헤더: 이름,소속,직위,전문분야,메모
  static Future<ImportResult> importInterviewersCsv(
    String csvText,
    bool overwrite,
    InterviewerRepository repo,
  ) async {
    final rows = parseCsv(csvText);
    if (rows.isEmpty) {
      return const ImportResult(
          imported: 0, failed: 0, errors: ['CSV가 비어 있습니다']);
    }
    final dataRows = rows.skip(1).toList();

    if (overwrite) {
      final all = await repo.getAllInterviewers();
      for (final iv in all) {
        await repo.deleteInterviewer(iv.id);
      }
    }

    final errors = <String>[];
    int imported = 0;
    final existingAll = await repo.getAllInterviewers();
    final existingDisplayIds = existingAll
        .where((iv) => iv.displayId != null)
        .map((iv) => iv.displayId!)
        .toList();

    for (int i = 0; i < dataRows.length; i++) {
      final rowNum = i + 2;
      final row = dataRows[i];
      try {
        final name = row.isNotEmpty ? row[0].trim() : '';
        if (name.isEmpty) {
          errors.add('$rowNum행: 이름 누락');
          continue;
        }
        final affiliation = row.length > 1 ? row[1].trim() : '';
        final jobTitle = row.length > 2 ? row[2].trim() : '';
        final specialization = row.length > 3 ? row[3].trim() : '';
        final notes = row.length > 4 ? row[4].trim() : '';

        final displayId = DisplayIdService.generateInterviewerId(
            DateTime.now(), existingDisplayIds);
        existingDisplayIds.add(displayId);

        final interviewer = Interviewer(
          name: name,
          affiliation: affiliation.isEmpty ? null : affiliation,
          jobTitle: jobTitle.isEmpty ? null : jobTitle,
          specialization: specialization.isEmpty ? null : specialization,
          notes: notes.isEmpty ? null : notes,
          displayId: displayId,
        );
        await repo.createInterviewer(interviewer);
        imported++;
      } catch (e) {
        errors.add('$rowNum행: $e');
      }
    }

    return ImportResult(
        imported: imported, failed: errors.length, errors: errors);
  }

  // ─── 기록 CSV 내보내기 ────────────────────────────────
  // 헤더: 식별자,제목,구술자,면담자,면담일시,면담장소,주제대분류,주제소분류,파일형식,파일크기,전사내용,요약,키워드태그,비공개,작성일
  static String exportRecordsCsv(
    List<Record> records,
    Map<String, Narrator> narratorMap,
    Map<String, Interviewer> interviewerMap,
    Map<String, InterviewSession> sessionMap, {
    bool includeContent = false,
    bool includeSummary = false,
  }) {
    final sb = StringBuffer();
    sb.writeln(
        '식별자,제목,구술자,면담자,면담일시,면담장소,주제대분류,주제소분류,파일형식,파일크기,전사내용,요약,키워드태그,비공개,작성일');
    for (final r in records) {
      final narrator = narratorMap[r.narratorId];
      final session = sessionMap[r.sessionId];
      final interviewer =
          session != null ? interviewerMap[session.interviewerId] : null;
      final tags = r.keywordTags.join(',');
      final tagsField =
          r.keywordTags.length > 1 ? '"$tags"' : tags;
      sb.writeln(_buildCsvRow([
        r.displayId ?? r.id,
        r.title,
        narrator?.name ?? '',
        interviewer?.name ?? '',
        session != null ? _formatDateTime(session.interviewDate) : '',
        session?.location ?? '',
        r.mainCategory,
        r.subCategory ?? '',
        r.mimeType ?? r.inputType,
        r.fileSize?.toString() ?? '',
        includeContent ? r.content : '',
        includeSummary ? (r.summary ?? '') : '',
        tagsField,
        r.visibility == 'private' ? 'Y' : 'N',
        _formatDate(r.createdAt),
      ]));
    }
    return sb.toString();
  }

  // ─── 구술자 CSV 내보내기 ──────────────────────────────
  static String exportNarratorsCsv(List<Narrator> narrators) {
    final sb = StringBuffer();
    sb.writeln('식별자,이름,생년월일,성별,직업(당시),직업(현재),소속,메모');
    for (final n in narrators) {
      sb.writeln(_buildCsvRow([
        n.displayId ?? n.id,
        n.name,
        _formatDate(n.dateOfBirth),
        n.gender ?? '',
        n.jobTitle ?? '',
        n.currentJobTitle ?? '',
        n.affiliation ?? '',
        n.notes ?? '',
      ]));
    }
    return sb.toString();
  }

  // ─── 면담자 CSV 내보내기 ──────────────────────────────
  static String exportInterviewersCsv(List<Interviewer> interviewers) {
    final sb = StringBuffer();
    sb.writeln('식별자,이름,소속,직위,전문분야,메모');
    for (final iv in interviewers) {
      sb.writeln(_buildCsvRow([
        iv.displayId ?? iv.id,
        iv.name,
        iv.affiliation ?? '',
        iv.jobTitle ?? '',
        iv.specialization ?? '',
        iv.notes ?? '',
      ]));
    }
    return sb.toString();
  }

  // ─── 전체 JSON 내보내기 ───────────────────────────────
  static String exportAllJson(
    List<Record> records,
    List<Narrator> narrators,
    List<Interviewer> interviewers,
    List<InterviewSession> sessions,
  ) {
    final data = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'records': records
          .map((r) => {
                'id': r.id,
                'displayId': r.displayId,
                'title': r.title,
                'content': r.content,
                'inputType': r.inputType,
                'sessionId': r.sessionId,
                'narratorId': r.narratorId,
                'mainCategory': r.mainCategory,
                'subCategory': r.subCategory,
                'keywordTags': r.keywordTags,
                'visibility': r.visibility,
                'recordedBy': r.recordedBy,
                'summary': r.summary,
                'tags': r.tags,
                'originalFileName': r.originalFileName,
                'fileSize': r.fileSize,
                'mimeType': r.mimeType,
                'createdAt': r.createdAt.toIso8601String(),
                'updatedAt': r.updatedAt.toIso8601String(),
              })
          .toList(),
      'narrators': narrators
          .map((n) => {
                'id': n.id,
                'displayId': n.displayId,
                'name': n.name,
                'dateOfBirth': n.dateOfBirth?.toIso8601String(),
                'gender': n.gender,
                'jobTitle': n.jobTitle,
                'currentJobTitle': n.currentJobTitle,
                'affiliation': n.affiliation,
                'notes': n.notes,
                'createdAt': n.createdAt.toIso8601String(),
                'updatedAt': n.updatedAt.toIso8601String(),
              })
          .toList(),
      'interviewers': interviewers
          .map((iv) => {
                'id': iv.id,
                'displayId': iv.displayId,
                'name': iv.name,
                'affiliation': iv.affiliation,
                'jobTitle': iv.jobTitle,
                'specialization': iv.specialization,
                'notes': iv.notes,
                'createdAt': iv.createdAt.toIso8601String(),
                'updatedAt': iv.updatedAt.toIso8601String(),
              })
          .toList(),
      'sessions': sessions
          .map((s) => {
                'id': s.id,
                'narratorId': s.narratorId,
                'interviewerId': s.interviewerId,
                'sessionNo': s.sessionNo,
                'interviewDate': s.interviewDate.toIso8601String(),
                'location': s.location,
                'interviewType': s.interviewType,
                'language': s.language,
                'notes': s.notes,
                'createdAt': s.createdAt.toIso8601String(),
                'updatedAt': s.updatedAt.toIso8601String(),
              })
          .toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  // ─── JSON 가져오기 ────────────────────────────────────
  static Future<ImportResult> importJson(
    String jsonText,
    RecordRepository recordRepo,
    NarratorRepository narratorRepo,
    InterviewerRepository interviewerRepo,
    InterviewSessionRepository sessionRepo,
    bool overwrite,
  ) async {
    final errors = <String>[];
    int imported = 0;

    try {
      final data = jsonDecode(jsonText) as Map<String, dynamic>;

      if (overwrite) {
        final allRecords = await recordRepo.searchRecords(_allFilters);
        for (final r in allRecords) {
          await recordRepo.deleteRecord(r.id);
        }
        final allNarrators = await narratorRepo.getAllNarrators();
        for (final n in allNarrators) {
          await narratorRepo.deleteNarrator(n.id);
        }
        final allInterviewers = await interviewerRepo.getAllInterviewers();
        for (final iv in allInterviewers) {
          await interviewerRepo.deleteInterviewer(iv.id);
        }
        final allSessions = await sessionRepo.getAllSessions();
        for (final s in allSessions) {
          await sessionRepo.deleteSession(s.id);
        }
      }

      // 구술자 복원
      final narratorsJson = data['narrators'] as List<dynamic>? ?? [];
      for (int i = 0; i < narratorsJson.length; i++) {
        try {
          final j = narratorsJson[i] as Map<String, dynamic>;
          final narrator = Narrator(
            id: j['id'] as String?,
            name: j['name'] as String,
            dateOfBirth: j['dateOfBirth'] != null
                ? DateTime.tryParse(j['dateOfBirth'] as String)
                : null,
            gender: j['gender'] as String?,
            jobTitle: j['jobTitle'] as String?,
            currentJobTitle: j['currentJobTitle'] as String?,
            affiliation: j['affiliation'] as String?,
            notes: j['notes'] as String?,
            displayId: j['displayId'] as String?,
          );
          await narratorRepo.createNarrator(narrator);
          imported++;
        } catch (e) {
          errors.add('구술자 ${i + 1}: $e');
        }
      }

      // 면담자 복원
      final interviewersJson = data['interviewers'] as List<dynamic>? ?? [];
      for (int i = 0; i < interviewersJson.length; i++) {
        try {
          final j = interviewersJson[i] as Map<String, dynamic>;
          final interviewer = Interviewer(
            id: j['id'] as String?,
            name: j['name'] as String,
            affiliation: j['affiliation'] as String?,
            jobTitle: j['jobTitle'] as String?,
            specialization: j['specialization'] as String?,
            notes: j['notes'] as String?,
            displayId: j['displayId'] as String?,
          );
          await interviewerRepo.createInterviewer(interviewer);
          imported++;
        } catch (e) {
          errors.add('면담자 ${i + 1}: $e');
        }
      }

      // 세션 복원
      final sessionsJson = data['sessions'] as List<dynamic>? ?? [];
      for (int i = 0; i < sessionsJson.length; i++) {
        try {
          final j = sessionsJson[i] as Map<String, dynamic>;
          final session = InterviewSession(
            id: j['id'] as String?,
            narratorId: j['narratorId'] as String,
            interviewerId: j['interviewerId'] as String,
            sessionNo: j['sessionNo'] as int,
            interviewDate: DateTime.parse(j['interviewDate'] as String),
            location: j['location'] as String?,
            interviewType: j['interviewType'] as String? ?? 'oral',
            language: j['language'] as String? ?? 'ko',
            notes: j['notes'] as String?,
          );
          await sessionRepo.createSession(session);
          imported++;
        } catch (e) {
          errors.add('세션 ${i + 1}: $e');
        }
      }

      // 기록 복원
      final recordsJson = data['records'] as List<dynamic>? ?? [];
      for (int i = 0; i < recordsJson.length; i++) {
        try {
          final j = recordsJson[i] as Map<String, dynamic>;
          final record = Record(
            id: j['id'] as String?,
            title: j['title'] as String,
            content: j['content'] as String? ?? '',
            inputType: j['inputType'] as String? ?? 'text',
            sessionId: j['sessionId'] as String,
            narratorId: j['narratorId'] as String,
            mainCategory: j['mainCategory'] as String? ?? '기타',
            subCategory: j['subCategory'] as String?,
            keywordTags: (j['keywordTags'] as List<dynamic>?)
                    ?.map((e) => e as String)
                    .toList() ??
                [],
            visibility: j['visibility'] as String? ?? 'public',
            recordedBy: j['recordedBy'] as String? ?? 'imported',
            summary: j['summary'] as String?,
            tags: (j['tags'] as List<dynamic>?)
                    ?.map((e) => e as String)
                    .toList() ??
                [],
            originalFileName: j['originalFileName'] as String?,
            fileSize: j['fileSize'] as int?,
            mimeType: j['mimeType'] as String?,
            displayId: j['displayId'] as String?,
            createdAt: j['createdAt'] != null
                ? DateTime.tryParse(j['createdAt'] as String)
                : null,
            updatedAt: j['updatedAt'] != null
                ? DateTime.tryParse(j['updatedAt'] as String)
                : null,
          );
          await recordRepo.createRecord(record);
          imported++;
        } catch (e) {
          errors.add('기록 ${i + 1}: $e');
        }
      }
    } catch (e) {
      errors.add('JSON 파싱 오류: $e');
    }

    return ImportResult(
        imported: imported, failed: errors.length, errors: errors);
  }
}
