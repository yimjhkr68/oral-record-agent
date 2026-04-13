// 파일 목적: 재사용 가능한 위젯 모음

import 'package:flutter/material.dart';

/// PII 하이라이트 텍스트 위젯
class PIIHighlightedText extends StatelessWidget {
  final String text;
  final Map<int, int> piiRanges; // startIndex -> endIndex
  final Color highlightColor;

  const PIIHighlightedText({
    required this.text,
    required this.piiRanges,
    this.highlightColor = const Color(0xFFFFE082),
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final textSpans = <TextSpan>[];
    int currentIndex = 0;

    piiRanges.entries.toList().sort((a, b) => a.key.compareTo(b.key));

    for (final entry in piiRanges.entries) {
      final startIndex = entry.key;
      final endIndex = entry.value;

      // 이전 텍스트 추가
      if (currentIndex < startIndex) {
        textSpans.add(
          TextSpan(
            text: text.substring(currentIndex, startIndex),
          ),
        );
      }

      // PII 텍스트 추가 (강조)
      textSpans.add(
        TextSpan(
          text: text.substring(startIndex, endIndex),
          style: TextStyle(
            backgroundColor: highlightColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      currentIndex = endIndex;
    }

    // 남은 텍스트 추가
    if (currentIndex < text.length) {
      textSpans.add(
        TextSpan(
          text: text.substring(currentIndex),
        ),
      );
    }

    return RichText(
      text: TextSpan(
        children: textSpans,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

/// 로딩 상태 표시 위젯
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;

  const LoadingOverlay({
    required this.isLoading,
    required this.child,
    this.message,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.3),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  if (message != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      message!,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// 에러 상태 표시 위젯
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorState({
    required this.message,
    this.onRetry,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          if (onRetry != null)
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('재시도'),
            ),
        ],
      ),
    );
  }
}

/// 빈 상태 표시 위젯
class EmptyState extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// 커스텀 AppBar
class CustomAppBar extends AppBar {
  CustomAppBar({
    required String title,
    bool showBackButton = true,
    super.actions,
    super.key,
  }) : super(
          title: Text(title),
          centerTitle: true,
          automaticallyImplyLeading: showBackButton,
        );
}
