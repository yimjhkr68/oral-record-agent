// 파일 목적: Windows 전용 기능 가드 위젯
// 웹에서 접근 시 안내 메시지 표시

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Windows에서만 동작하는 기능을 감싸는 가드.
/// 웹에서는 [title] 과 함께 안내 메시지를 표시하고, Windows에서는 [child] 를 렌더링.
class WindowsOnlyGuard extends StatelessWidget {
  final String title;
  final Widget child;

  const WindowsOnlyGuard({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.desktop_windows,
                size: 72,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 24),
              Text(
                '이 기능은 Windows 앱에서만\n사용 가능합니다.',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.grey[700],
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                '$title 기능은 마이크 접근, 파일 시스템, 로컬 AI 모델이 필요합니다.\n'
                'Windows 앱을 설치하여 이용해주세요.',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '웹에서 사용 가능한 기능',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _featureRow(Icons.text_fields, '텍스트 입력 및 기록 조회'),
                    _featureRow(Icons.search, '검색 및 필터'),
                    _featureRow(Icons.summarize, '요약 생성 (Claude API)'),
                    _featureRow(Icons.settings, '설정 관리'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blue[600]),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
