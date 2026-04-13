// 파일 목적: 입력 페이지 → MetadataInputPage 간 콘텐츠 전달용 임시 Provider
// TextInputPage / FilePickerPage / RecordingPage에서 저장 후 공유

import 'dart:typed_data';
import 'package:riverpod/riverpod.dart';

/// 저장 대기 중인 콘텐츠
class PendingContent {
  /// 텍스트 내용 (직접입력 또는 파일에서 추출된 텍스트)
  final String content;

  /// 입력 유형: 'text' | 'document' | 'audio'
  final String inputType;

  /// 원본 파일명 (document/audio일 때)
  final String? fileName;

  /// 파일 바이트 (document/audio일 때, 저장 후 FileStorageService로 이관)
  final Uint8List? bytes;

  /// 파일 크기 (bytes 단위)
  final int? fileSize;

  /// MIME 타입 (예: 'application/pdf', 'audio/mpeg')
  final String? mimeType;

  /// 전사 실패 여부 (audio 타입일 때만 의미 있음)
  final bool transcriptionFailed;

  /// 전사 실패 오류 메시지
  final String? transcriptionError;

  /// 제목 기본값 (파일명 또는 날짜 기반 자동 생성)
  final String? suggestedTitle;

  const PendingContent({
    required this.content,
    required this.inputType,
    this.fileName,
    this.bytes,
    this.fileSize,
    this.mimeType,
    this.transcriptionFailed = false,
    this.transcriptionError,
    this.suggestedTitle,
  });
}

/// 전역 임시 콘텐츠 Provider (MetadataInputPage 저장 후 null로 초기화)
final pendingContentProvider = StateProvider<PendingContent?>((ref) => null);
