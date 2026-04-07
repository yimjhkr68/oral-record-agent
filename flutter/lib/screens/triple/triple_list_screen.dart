import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TripleListScreen extends ConsumerWidget {
  const TripleListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('트리플 관리')),
      body: const Center(child: Text('트리플 목록')),
    );
  }
}
