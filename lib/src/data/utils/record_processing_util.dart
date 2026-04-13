// 파일 목적: 기록의 처리 필요 여부 및 처리 유형 판단 유틸
import '../models/record.dart';

enum ProcessingType { none, extractDocument, transcribeAudio, transcribeVideo }

class RecordProcessingUtil {
  /// 텍스트 처리가 필요한지 판단
  static bool needsProcessing(Record r) {
    return getProcessingType(r) != ProcessingType.none;
  }

  /// 처리 유형 반환
  static ProcessingType getProcessingType(Record r) {
    if (r.content.isNotEmpty &&
        !_isPlaceholder(r.content) &&
        !_isUntranscribed(r)) {
      return ProcessingType.none;
    }

    final mime = (r.mimeType ?? '').toLowerCase();
    final ext = (r.originalFileName ?? '').split('.').last.toLowerCase();

    // 영상
    if (r.inputType == 'video' ||
        mime.contains('mp4') ||
        mime.contains('avi') ||
        mime.contains('mov') ||
        mime.contains('video') ||
        {'mp4', 'avi', 'mov', 'mkv', 'wmv', 'webm'}.contains(ext)) {
      return ProcessingType.transcribeVideo;
    }

    // 오디오
    if (r.inputType == 'audio' ||
        mime.contains('wav') ||
        mime.contains('mpeg') ||
        mime.contains('mp3') ||
        mime.contains('m4a') ||
        mime.contains('audio') ||
        {'wav', 'mp3', 'm4a', 'aac', 'ogg', 'flac'}.contains(ext)) {
      return ProcessingType.transcribeAudio;
    }

    // 문서
    if (r.inputType == 'document' ||
        mime.contains('pdf') ||
        mime.contains('docx') ||
        mime.contains('wordprocessingml') ||
        {'pdf', 'docx', 'doc', 'txt'}.contains(ext)) {
      return ProcessingType.extractDocument;
    }

    return ProcessingType.none;
  }

  /// 처리 버튼 라벨
  static String getButtonLabel(Record r) {
    switch (getProcessingType(r)) {
      case ProcessingType.extractDocument:
        return '텍스트 추출하기';
      case ProcessingType.transcribeAudio:
        return '음성 전사하기';
      case ProcessingType.transcribeVideo:
        return '영상 전사하기';
      case ProcessingType.none:
        return '';
    }
  }

  static bool _isPlaceholder(String content) {
    if (content.startsWith('[PDF 원본]')) return true;
    if (content.startsWith('[DOCX 원본]')) return true;
    if (content.startsWith('[음성 녹음:')) return true;
    if (content.startsWith('[영상 파일:')) return true;
    if (content.startsWith('전사 실패:')) return true;
    return false;
  }

  static bool _isUntranscribed(Record r) {
    if (r.content.isEmpty) return true;
    if (r.content.startsWith('[음성 녹음:')) return true;
    if (r.content.startsWith('[영상 파일:')) return true;
    if (r.content.startsWith('전사 실패:')) return true;
    return false;
  }
}
