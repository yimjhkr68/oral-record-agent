// 파일 목적: Windows 파일 읽기 + 텍스트 추출 서비스
// TXT: dart:io → UTF-8 decode
// PDF: 바이트만 저장, 텍스트 placeholder 반환
// DOCX: archive 패키지로 word/document.xml 파싱 → <w:t> 텍스트 추출
// Audio: 파일명 기반 placeholder 반환 (실제 전사는 TranscriptionService 사용)
// Video: 파일명 기반 placeholder 반환 (오디오 추출 미지원)

import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

// ============================================================
// 결과 클래스
// ============================================================

class FileReadResult {
  final String content;
  final Uint8List bytes;
  final String fileName;
  final int fileSize;
  final String mimeType;
  /// true이면 TranscriptionService로 전사 가능한 오디오/영상 파일
  final bool isAudioOrVideo;

  const FileReadResult({
    required this.content,
    required this.bytes,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    this.isAudioOrVideo = false,
  });
}

// ============================================================
// FileService — Windows dart:io 기반
// ============================================================

class FileService {
  /// 파일 경로를 받아 [FileReadResult] 반환
  static Future<FileReadResult> readFilePath(String filePath) async {
    final file = File(filePath);
    final name = file.uri.pathSegments.last;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    final mimeType = mimeTypeFromExt(ext);


    final bytes = await file.readAsBytes();
    final size = bytes.length;

    // ── 영상 파일 ──
    const videoExts = {'mp4', 'avi', 'mov', 'mkv', 'wmv'};
    if (videoExts.contains(ext)) {
      return FileReadResult(
        content: '[영상 파일: $name]',
        bytes: bytes,
        fileName: name,
        fileSize: size,
        mimeType: mimeType,
        isAudioOrVideo: true,
      );
    }

    // ── 오디오 파일 ──
    const audioExts = {'mp3', 'wav', 'm4a', 'ogg', 'flac', 'aac'};
    if (audioExts.contains(ext)) {
      return FileReadResult(
        content: '[음성 파일: $name]',
        bytes: bytes,
        fileName: name,
        fileSize: size,
        mimeType: mimeType,
        isAudioOrVideo: true,
      );
    }

    // ── TXT 파일 ──
    if (ext == 'txt') {
      final text = utf8.decode(bytes, allowMalformed: true);
      return FileReadResult(
        content: text,
        bytes: bytes,
        fileName: name,
        fileSize: size,
        mimeType: mimeType,
      );
    }

    // ── DOCX 파일 ──
    if (ext == 'docx') {
      final text = _extractDocxText(bytes);
      return FileReadResult(
        content: text.isNotEmpty ? text : '[DOCX 내용을 추출할 수 없습니다: $name]',
        bytes: bytes,
        fileName: name,
        fileSize: size,
        mimeType: mimeType,
      );
    }

    // ── PDF 파일 ── (Windows 텍스트 추출 미지원 → 파일 저장만)
    if (ext == 'pdf') {
      return FileReadResult(
        content: '[PDF 파일: $name\n원본 파일을 열어 내용을 확인하세요.]',
        bytes: bytes,
        fileName: name,
        fileSize: size,
        mimeType: mimeType,
      );
    }

    // ── 미지원 형식 ──
    return FileReadResult(
      content: '[지원하지 않는 파일 형식: $name]',
      bytes: bytes,
      fileName: name,
      fileSize: size,
      mimeType: mimeType,
    );
  }

  // ----------------------------------------------------------
  // DOCX 텍스트 추출: archive 패키지 → word/document.xml → <w:t> 파싱
  // ----------------------------------------------------------
  static String _extractDocxText(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final entry = archive.findFile('word/document.xml');
      if (entry == null) return '';

      final xmlStr =
          utf8.decode(entry.content as List<int>, allowMalformed: true);

      // <w:t> 태그 내 텍스트 추출
      final regex = RegExp(r'<w:t(?:\s[^>]*)?>([^<]*)</w:t>');
      final buffer = StringBuffer();
      for (final m in regex.allMatches(xmlStr)) {
        final t = m.group(1);
        if (t != null && t.isNotEmpty) buffer.write('$t ');
      }
      return buffer.toString().replaceAll(RegExp(r' +'), ' ').trim();
    } catch (e) {
      return '';
    }
  }

  static String mimeTypeFromExt(String ext) {
    const map = {
      'txt': 'text/plain',
      'pdf': 'application/pdf',
      'docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'mp3': 'audio/mpeg',
      'wav': 'audio/wav',
      'm4a': 'audio/mp4',
      'ogg': 'audio/ogg',
      'flac': 'audio/flac',
      'aac': 'audio/aac',
      'mp4': 'video/mp4',
      'avi': 'video/x-msvideo',
      'mov': 'video/quicktime',
      'mkv': 'video/x-matroska',
      'wmv': 'video/x-ms-wmv',
    };
    return map[ext] ?? 'application/octet-stream';
  }
}
