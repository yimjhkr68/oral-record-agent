import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';

final serverStatusProvider = FutureProvider<bool>((ref) async {
  final client = ref.read(apiClientProvider);
  return client.checkConnection();
});
