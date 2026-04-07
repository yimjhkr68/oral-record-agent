import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/graph_api.dart';
import '../models/triple.dart';

final graphApiProvider = Provider<GraphApi>((ref) {
  return GraphApi(ref.read(apiClientProvider));
});

final graphQueryProvider = StateProvider<String>((ref) => '');

final graphDataProvider = FutureProvider.autoDispose<GraphData>((ref) async {
  final q = ref.watch(graphQueryProvider);
  final api = ref.read(graphApiProvider);
  if (q.isEmpty) return api.fullGraph();
  return api.searchGraph(q);
});
