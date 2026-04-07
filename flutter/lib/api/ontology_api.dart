import 'api_client.dart';
import '../models/ontology.dart';

class OntologyApi {
  final ApiClient _client;
  OntologyApi(this._client);

  Future<List<OntologyVersion>> listVersions() async {
    final res = await _client.get('/api/ontologies/');
    return (res.data as List)
        .map((e) => OntologyVersion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<OntologyVersion> getVersion(String versionId) async {
    final res = await _client.get('/api/ontologies/$versionId');
    return OntologyVersion.fromJson(res.data as Map<String, dynamic>);
  }

  Future<OntologyVersion> createDraft(
      String versionId, String description) async {
    final res = await _client.post('/api/ontologies/', data: {
      'version_id': versionId,
      'description': description,
    });
    return OntologyVersion.fromJson(res.data as Map<String, dynamic>);
  }

  Future<OntologyVersion> generateFromSample(String sampleText,
      {String? baseVersionId}) async {
    final res = await _client.post('/api/ontologies/generate', data: {
      'sample_text': sampleText,
      if (baseVersionId != null) 'base_version_id': baseVersionId,
    });
    return OntologyVersion.fromJson(res.data as Map<String, dynamic>);
  }

  Future<OntologyVersion> confirmVersion(String versionId) async {
    final res = await _client.post('/api/ontologies/$versionId/confirm');
    return OntologyVersion.fromJson(res.data as Map<String, dynamic>);
  }
}
