import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/ontology_api.dart';
import '../models/ontology.dart';

final ontologyApiProvider = Provider<OntologyApi>((ref) {
  return OntologyApi(ref.read(apiClientProvider));
});

// 목록 — invalidate()로 새로고침
final ontologyListProvider =
    FutureProvider<List<OntologyVersion>>((ref) async {
  return ref.read(ontologyApiProvider).listVersions();
});

// 단건 — versionId 기준
final ontologyDetailProvider =
    FutureProvider.family<OntologyVersion, String>((ref, versionId) async {
  return ref.read(ontologyApiProvider).getVersion(versionId);
});
