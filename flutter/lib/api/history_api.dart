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
}
