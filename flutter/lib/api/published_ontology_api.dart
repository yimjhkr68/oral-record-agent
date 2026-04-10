import '../api/api_client.dart';
import '../models/published_ontology.dart';

class PublishedOntologyApi {
  final ApiClient _client;
  PublishedOntologyApi(this._client);

  // ── 온톨로지 CRUD ─────────────────────────────────────────────────────────────

  Future<List<PublishedOntology>> listOntologies() async {
    final res = await _client.get('/api/published-ontologies/');
    return (res.data as List)
        .map((e) => PublishedOntology.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PublishedOntology> getOntology(String id) async {
    final res = await _client.get('/api/published-ontologies/$id');
    return PublishedOntology.fromJson(res.data as Map<String, dynamic>);
  }

  Future<PublishedOntology> createOntology({
    required String id,
    required String name,
    required String prefix,
    required String namespaceUri,
    String description = '',
    String version = '',
  }) async {
    final res = await _client.post('/api/published-ontologies/', data: {
      'id': id,
      'name': name,
      'prefix': prefix,
      'namespace_uri': namespaceUri,
      'description': description,
      'version': version,
    });
    return PublishedOntology.fromJson(res.data as Map<String, dynamic>);
  }

  Future<PublishedOntology> updateOntology(
    String id, {
    String? name,
    String? prefix,
    String? namespaceUri,
    String? description,
    String? version,
  }) async {
    final res = await _client.patch('/api/published-ontologies/$id', data: {
      if (name != null) 'name': name,
      if (prefix != null) 'prefix': prefix,
      if (namespaceUri != null) 'namespace_uri': namespaceUri,
      if (description != null) 'description': description,
      if (version != null) 'version': version,
    });
    return PublishedOntology.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteOntology(String id) async {
    await _client.delete('/api/published-ontologies/$id');
  }

  // ── 클래스 CRUD ──────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listAllClasses() async {
    final res = await _client.get('/api/published-ontologies/classes');
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<PublishedOntology> addClass(
    String ontologyId, {
    required String curie,
    required String uri,
    required String label,
    required String labelKo,
    String description = '',
  }) async {
    final res = await _client.post(
      '/api/published-ontologies/$ontologyId/classes',
      data: {
        'curie': curie,
        'uri': uri,
        'label': label,
        'label_ko': labelKo,
        'description': description,
      },
    );
    return PublishedOntology.fromJson(res.data as Map<String, dynamic>);
  }

  Future<PublishedOntology> updateClass(
    String ontologyId,
    String classId, {
    String? curie,
    String? uri,
    String? label,
    String? labelKo,
    String? description,
  }) async {
    final res = await _client.patch(
      '/api/published-ontologies/$ontologyId/classes/$classId',
      data: {
        if (curie != null) 'curie': curie,
        if (uri != null) 'uri': uri,
        if (label != null) 'label': label,
        if (labelKo != null) 'label_ko': labelKo,
        if (description != null) 'description': description,
      },
    );
    return PublishedOntology.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteClass(String ontologyId, String classId) async {
    await _client.delete(
        '/api/published-ontologies/$ontologyId/classes/$classId');
  }
}
