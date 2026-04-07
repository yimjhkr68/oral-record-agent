import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class KnowledgeGraphScreen extends ConsumerWidget {
  const KnowledgeGraphScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('지식그래프')),
      body: const Center(child: Text('지식그래프 시각화 준비 중')),
    );
  }
}
