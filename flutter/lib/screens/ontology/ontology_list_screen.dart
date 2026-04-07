import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OntologyListScreen extends ConsumerWidget {
  const OntologyListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('온톨로지 관리')),
      body: const Center(child: Text('온톨로지 목록')),
    );
  }
}
