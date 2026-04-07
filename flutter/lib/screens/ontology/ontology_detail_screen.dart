import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OntologyDetailScreen extends ConsumerWidget {
  final String versionId;
  const OntologyDetailScreen({super.key, required this.versionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('온톨로지: $versionId')),
      body: const Center(child: Text('온톨로지 상세 준비 중')),
    );
  }
}
