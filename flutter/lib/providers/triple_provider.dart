import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/triple_api.dart';
import '../models/triple.dart';

final tripleApiProvider = Provider<TripleApi>((ref) {
  return TripleApi(ref.read(apiClientProvider));
});

// 검색어 상태
final tripleQueryProvider = StateProvider<String>((ref) => '');

// 상태 필터: 'active' | 'archived'
final tripleStatusProvider = StateProvider<String>((ref) => 'active');

// 목록 — query/status 변경 시 자동 갱신
final tripleListProvider = FutureProvider.autoDispose<GraphData>((ref) async {
  final q = ref.watch(tripleQueryProvider);
  final status = ref.watch(tripleStatusProvider);
  return ref.read(tripleApiProvider).listTriples(q: q, status: status);
});
