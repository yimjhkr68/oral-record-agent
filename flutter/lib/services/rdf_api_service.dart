import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';

final rdfApiProvider = Provider<RdfApiService>((ref) {
  return RdfApiService(ref.read(apiClientProvider));
});

// ────────────────────────────────────────────────────────────────────────────
// RDF API 서비스 — /rdf/* 엔드포인트 전체 래핑
// ────────────────────────────────────────────────────────────────────────────
class RdfApiService {
  final ApiClient _c;
  RdfApiService(this._c);

  // ── Migration (7) ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> migrationStatus() async {
    final r = await _c.get('/rdf/migration/status');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> migrationAnalyze() async {
    final r = await _c.post('/rdf/migration/analyze');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> migrationBackup() async {
    final r = await _c.post('/rdf/migration/backup');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> migrationRun({
    String namespaceUri =
        'https://yimjhkr68.github.io/oral-history-ontology/core#',
    List<String> formats = const ['turtle', 'json-ld', 'xml'],
  }) async {
    final r = await _c.post('/rdf/migration/run',
        data: {'namespace_uri': namespaceUri, 'formats': formats});
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> migrationPreview({int limit = 50}) async {
    final r = await _c.get('/rdf/migration/preview',
        params: {'limit': limit});
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> migrationConfirm() async {
    final r = await _c.post('/rdf/migration/confirm');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> migrationRollback() async {
    final r = await _c.post('/rdf/migration/rollback');
    return Map<String, dynamic>.from(r.data as Map);
  }

  // ── Ontology Editor (13) ───────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> ontologyClasses() async {
    final r = await _c.get('/rdf/ontology/classes');
    return (r.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> ontologyClassDetail(String local) async {
    final r = await _c.get('/rdf/ontology/classes/$local');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> ontologyAddClass(
      String local, Map<String, dynamic> body) async {
    final r = await _c.post(
        '/rdf/ontology/classes?local=${Uri.encodeComponent(local)}',
        data: body);
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> ontologyUpdateClass(
      String local, Map<String, dynamic> body) async {
    final r = await _c.put('/rdf/ontology/classes/$local', data: body);
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> ontologyDeprecateClass(String local) async {
    final r = await _c.delete('/rdf/ontology/classes/$local');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<List<Map<String, dynamic>>> ontologyProperties() async {
    final r = await _c.get('/rdf/ontology/properties');
    return (r.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> ontologyGetTurtle() async {
    final r = await _c.get('/rdf/ontology/turtle');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> ontologyValidateTurtle(String turtle) async {
    final r = await _c.post('/rdf/ontology/turtle/validate',
        data: {'turtle': turtle});
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> ontologyApplyTurtle(String turtle) async {
    final r =
        await _c.put('/rdf/ontology/turtle', data: {'turtle': turtle});
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> ontologyReload() async {
    final r = await _c.get('/rdf/ontology/turtle/reload');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> ontologyVersion() async {
    final r = await _c.get('/rdf/ontology/version');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> ontologyBumpVersion(String bumpType) async {
    final r = await _c.post('/rdf/ontology/version/bump',
        data: {'bump_type': bumpType});
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<List<Map<String, dynamic>>> ontologyChangelog({int limit = 50}) async {
    final r = await _c.get('/rdf/ontology/changelog',
        params: {'limit': limit});
    return (r.data as List).cast<Map<String, dynamic>>();
  }

  // ── Validate (4) ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> validateRun() async {
    final r = await _c.post('/rdf/validate/run');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> validateResults() async {
    final r = await _c.get('/rdf/validate/results');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> validateReadiness() async {
    final r = await _c.get('/rdf/validate/readiness');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> validateConsistency() async {
    final r = await _c.post('/rdf/validate/consistency');
    return Map<String, dynamic>.from(r.data as Map);
  }

  // ── Search (5) ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> searchQuery(
      String query, String mode, int limit) async {
    final r = await _c.post('/rdf/search/query',
        data: {'query': query, 'mode': mode, 'limit': limit});
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> searchTemplates() async {
    final r = await _c.get('/rdf/search/templates');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> searchSaveTemplate(
      String name, String description, String sparql) async {
    final r = await _c.post('/rdf/search/templates/save',
        data: {'name': name, 'description': description, 'sparql': sparql});
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> searchReason() async {
    final r = await _c.post('/rdf/search/reason');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> searchReasonStatus() async {
    final r = await _c.get('/rdf/search/reason/status');
    return Map<String, dynamic>.from(r.data as Map);
  }

  // ── Publish (4) ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> publishPackage(
      Map<String, dynamic> config) async {
    final r = await _c.post('/rdf/publish/package', data: config);
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> publishPreview() async {
    final r = await _c.get('/rdf/publish/preview');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> publishRun(Map<String, dynamic> config) async {
    final r = await _c.post('/rdf/publish/run', data: config);
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<List<Map<String, dynamic>>> publishHistory() async {
    final r = await _c.get('/rdf/publish/history');
    return (r.data as List).cast<Map<String, dynamic>>();
  }

  // ── Export (2) — 파일 저장 포함 ────────────────────────────────────────────

  /// RDF 내보내기 — FilePicker 저장 다이얼로그로 파일 저장
  Future<void> exportAndSave({
    required BuildContext context,
    required String endpoint, // '/rdf/export/ontology' | '/rdf/export/triples'
    required String format,   // 'turtle' | 'json-ld' | 'xml'
    required String prefix,   // 'oral-history' | 'triples'
  }) async {
    const extMap = {
      'turtle':  '.ttl',
      'json-ld': '.jsonld',
      'xml':     '.owl',
    };
    final ext = extMap[format] ?? '.ttl';

    try {
      final res = await _c.get(
        endpoint,
        params: {'format': format},
        options: Options(responseType: ResponseType.bytes),
      );

      if (!context.mounted) return;

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'RDF 파일 저장',
        fileName: '$prefix$ext',
        allowedExtensions: [ext.replaceFirst('.', '')],
        type: FileType.custom,
      );
      if (savePath == null) return;

      await File(savePath).writeAsBytes(res.data as List<int>);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('저장 완료: $savePath'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('내보내기 실패: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }
}
