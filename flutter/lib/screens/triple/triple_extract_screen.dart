import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TripleExtractScreen extends ConsumerWidget {
  const TripleExtractScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('트리플 추출')),
      body: const Center(child: Text('구술자료 → 트리플 추출 준비 중')),
    );
  }
}
