import '../api/api_client.dart';
import '../models/history.dart';

class HistoryApi {
  final ApiClient _client;
  HistoryApi(this._client);

  Future<List<OntologyEvent>> listOntologyEvents({
    String versionId = '',
    String eventType = '',
    int limit = 50,
  }) async {
    final res = await _client.get('/api/history/ontology', params: {
      if (versionId.isNotEmpty) 'version_id': versionId,
      if (eventType.isNotEmpty) 'event_type': eventType,
      'limit': limit,
    });
    final List items = res.data['events'] ?? [];
    return items.map((e) => OntologyEvent.fromJson(e)).toList();
  }

  Future<List<OntologyEvent>> getVersionTimeline(String versionId) async {
    final res =
        await _client.get('/api/history/ontology/$versionId/timeline');
    final List items = res.data['events'] ?? [];
    return items.map((e) => OntologyEvent.fromJson(e)).toList();
  }

  Future<List<ExtractionSession>> listSessions({
    String status = '',
    String ontologyVersion = '',
    int limit = 20,
  }) async {
    final res = await _client.get('/api/history/extractions', params: {
      if (status.isNotEmpty) 'status': status,
      if (ontologyVersion.isNotEmpty) 'ontology_version': ontologyVersion,
      'limit': limit,
    });
    final List items = res.data['sessions'] ?? [];
    return items.map((e) => ExtractionSession.fromJson(e)).toList();
  }

  Future<ExtractionSession> getSession(String sessionId) async {
    final res = await _client.get('/api/history/extractions/$sessionId');
    return ExtractionSession.fromJson(res.data);
  }

  Future<HistorySummary> getSummary() async {
    final res = await _client.get('/api/history/summary');
    return HistorySummary.fromJson(res.data);
  }

  // ── 삭제 ──────────────────────────────────────────────────────────────────

  Future<void> deleteOntologyEvent(String eventId) async {
    await _client.delete('/api/history/ontology/$eventId');
  }

  Future<int> deleteOntologyEventsBulk(List<String> ids) async {
    final res = await _client.delete(
      '/api/history/ontology/bulk',
      data: {'ids': ids},
    );
    return (res.data['deleted'] as num?)?.toInt() ?? 0;
  }

  Future<void> clearAllOntologyEvents() async {
    await _client.delete('/api/history/ontology/all');
  }

  Future<void> deleteSession(String sessionId) async {
    await _client.delete('/api/history/extractions/$sessionId');
  }

  Future<int> deleteSessionsBulk(List<String> ids) async {
    final res = await _client.delete(
      '/api/history/extractions/bulk',
      data: {'ids': ids},
    );
    return (res.data['deleted'] as num?)?.toInt() ?? 0;
  }

  Future<void> clearAllSessions() async {
    await _client.delete('/api/history/extractions/all');
  }

  Future<void> clearAll() async {
    await _client.delete('/api/history/all');
  }
}
