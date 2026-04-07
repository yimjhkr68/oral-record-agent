import 'api_client.dart';
import '../models/triple.dart';

class GraphApi {
  final ApiClient _client;
  GraphApi(this._client);

  Future<GraphData> fullGraph() async {
    final res = await _client.get('/api/graph');
    return GraphData.fromJson(res.data as Map<String, dynamic>);
  }

  Future<GraphData> searchGraph(String q) async {
    final res = await _client.get('/api/graph/search', params: {'q': q});
    return GraphData.fromJson(res.data as Map<String, dynamic>);
  }
}
