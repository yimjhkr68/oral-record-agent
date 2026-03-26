// 파일 목적: parseDocument 도구 구현 (스펙)
// 녹취문 문서(txt/docx/pdf)에서 텍스트 추출
// 문서 형식 파싱 또는 텍스트 정규화 수행 (향후 고도화)

import 'dart:io';
import 'tool_base.dart';

/// parseDocument 도구
///
/// 책임:
/// 1. 문서 파일 검증 (형식: txt, docx, pdf / 크기: 50MB 이하)
/// 2. 파일 읽기
/// 3. 형식에 따라 텍스트 추출 (txt: 직접 읽기, docx/pdf: 파서 활용 향후)
/// 4. 텍스트 정규화 (공백 정리, 인코딩 확인)
/// 5. 추출된 텍스트 반환
///
/// 지원 형식:
/// - txt: 일반 텍스트 (UTF-8)
/// - docx: Word 문서 (향후 구현)
/// - pdf: PDF 문서 (향후 구현)
///
/// 크기 제한:
/// - 최대 50MB
///
/// 예외처리:
/// - ValidationException: 파일 형식 미지원, 크기 초과, 경로 비어있음
/// - FileException: 파일 미존재, 읽기 권한 없음, 인코딩 오류
abstract class ParseDocumentTool {
  /// 문서 파일에서 텍스트 추출
  ///
  /// 파라미터:
  /// - documentPath: 문서 파일 경로 (필수)
  ///
  /// 반환:
  /// - 추출된 텍스트 (정규화됨)
  ///
  /// 예외:
  /// - ValidationException: 파일 형식 미지원, 크기 초과
  /// - FileException: 파일 미존재, 파싱 오류
  static Future<String> execute({required String documentPath}) async {
    throw UnimplementedError(
      'parseDocument는 향후 구현 (docx/pdf 파서 필요)\n'
      '현재: txt 형식만 지원 예정',
    );
  }

  /// 문서 파일 검증
  static void validateDocumentFile(String documentPath) {
    if (documentPath.isEmpty) {
      throw ValidationException('documentPath는 필수입니다');
    }

    final file = File(documentPath);
    if (!file.existsSync()) {
      throw FileException('문서 파일을 찾을 수 없습니다', filePath: documentPath);
    }

    // 파일 형식 검증
    const supportedFormats = ['txt', 'docx', 'pdf'];
    final extension = documentPath.split('.').last.toLowerCase();
    if (!supportedFormats.contains(extension)) {
      throw ValidationException(
        '지원하지 않는 형식입니다. 지원 형식: ${supportedFormats.join(", ")}',
      );
    }

    // 파일 크기 검증 (50MB)
    const maxSizeBytes = 50 * 1024 * 1024;
    if (file.lengthSync() > maxSizeBytes) {
      throw ValidationException(
        '파일 크기가 너무 큽니다. 최대: 50MB, 현재: ${(file.lengthSync() / 1024 / 1024).toStringAsFixed(2)}MB',
      );
    }
  }

  /// 텍스트 파일 읽기
  static Future<String> readTextFile(String filePath) async {
    try {
      final file = File(filePath);
      return await file.readAsString();
    } on FileSystemException catch (e) {
      throw FileException('파일을 읽을 수 없습니다: $e', filePath: filePath);
    } on FormatException catch (e) {
      throw FileException(
        '파일 인코딩을 지원하지 않습니다: $e',
        filePath: filePath,
      );
    }
  }

  /// 텍스트 정규화
  static String normalizeText(String text) {
    // 여러 공백을 단일 공백으로
    var normalized = text.replaceAll(RegExp(r'\s+'), ' ');
    // 앞뒤 공백 제거
    normalized = normalized.trim();
    return normalized;
  }
}
