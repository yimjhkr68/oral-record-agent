// 파일 목적: 파일 저장소 추상 인터페이스 + Windows 구현
//
// 설계 원칙:
//   - FileStorage: 추상 인터페이스 (클라우드 전환 시 이 인터페이스만 유지)
//   - WindowsFileStorage: dart:io + path_provider 기반 현재 구현
//   - S3FileStorage: 나중에 추가할 클라우드 구현 (주석 포함)
//
// 파일 저장 구조 (Windows):
//   Documents/OralRecordAgent/files/
//     {recordId}/
//       {원본파일명}     ← 실제 파일 바이트
//       meta.json       ← StoredFileInfo JSON

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

// ============================================================
// StoredFileInfo - 파일 메타데이터 (바이트 없이 조회 가능)
// ============================================================

class StoredFileInfo {
  final String recordId;
  final String fileName;
  final int fileSize;
  final String mimeType;

  const StoredFileInfo({
    required this.recordId,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
  });

  Map<String, dynamic> toJson() => {
        'recordId': recordId,
        'fileName': fileName,
        'fileSize': fileSize,
        'mimeType': mimeType,
      };

  factory StoredFileInfo.fromJson(Map<String, dynamic> json) => StoredFileInfo(
        recordId: json['recordId'] as String,
        fileName: json['fileName'] as String,
        fileSize: json['fileSize'] as int,
        mimeType: json['mimeType'] as String,
      );

  String formatSize() {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ============================================================
// FileStorage - 추상 인터페이스
// ============================================================

abstract class FileStorage {
  Future<void> saveFile({
    required String recordId,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  });

  Future<StoredFileInfo?> getFileInfo(String recordId);
  Future<Uint8List?> loadBytes(String recordId);
  /// 저장된 파일의 절대 경로 반환 (없으면 null). 대용량 파일 처리 시 loadBytes 대신 사용.
  Future<String?> getFilePath(String recordId);
  Future<void> deleteFile(String recordId);
  Future<bool> hasFile(String recordId);
}

// ============================================================
// WindowsFileStorage — dart:io + path_provider 로컬 파일 시스템
//
// 저장 경로:
//   Documents/OralRecordAgent/files/{recordId}/{fileName}
//   Documents/OralRecordAgent/files/{recordId}/meta.json
//
// 클라우드 전환 시:
//   이 클래스를 S3FileStorage로 교체하고
//   repository_provider.dart의 fileStorageProvider 바인딩만 변경
// ============================================================

class WindowsFileStorage implements FileStorage {
  // 게으른 초기화: 첫 호출 시 Documents 경로 확인
  String? _baseDir;

  Future<String> _getBaseDir() async {
    if (_baseDir != null) return _baseDir!;
    final docsDir = await getApplicationDocumentsDirectory();
    _baseDir = '${docsDir.path}/OralRecordAgent/files';
    return _baseDir!;
  }

  @override
  Future<void> saveFile({
    required String recordId,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final baseDir = await _getBaseDir();
    final dir = Directory('$baseDir/$recordId');
    await dir.create(recursive: true);


    // 파일 바이트 저장
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

    // 메타데이터 저장
    final info = StoredFileInfo(
      recordId: recordId,
      fileName: fileName,
      fileSize: bytes.length,
      mimeType: mimeType,
    );
    final metaFile = File('${dir.path}/meta.json');
    await metaFile.writeAsString(jsonEncode(info.toJson()));

  }

  @override
  Future<StoredFileInfo?> getFileInfo(String recordId) async {
    final baseDir = await _getBaseDir();
    final metaFile = File('$baseDir/$recordId/meta.json');
    if (!await metaFile.exists()) return null;
    try {
      final json = jsonDecode(await metaFile.readAsString());
      return StoredFileInfo.fromJson(json as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Uint8List?> loadBytes(String recordId) async {
    final info = await getFileInfo(recordId);
    if (info == null) {
      return null;
    }
    final baseDir = await _getBaseDir();
    final file = File('$baseDir/$recordId/${info.fileName}');
    if (!await file.exists()) {
      return null;
    }
    final bytes = await file.readAsBytes();
    return bytes;
  }

  @override
  Future<String?> getFilePath(String recordId) async {
    final info = await getFileInfo(recordId);
    if (info == null) return null;
    final baseDir = await _getBaseDir();
    final file = File('$baseDir/$recordId/${info.fileName}');
    if (!await file.exists()) return null;
    return file.path;
  }

  @override
  Future<void> deleteFile(String recordId) async {
    final baseDir = await _getBaseDir();
    final dir = Directory('$baseDir/$recordId');
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  @override
  Future<bool> hasFile(String recordId) async {
    final info = await getFileInfo(recordId);
    if (info == null) return false;
    final baseDir = await _getBaseDir();
    return File('$baseDir/$recordId/${info.fileName}').exists();
  }
}

// ============================================================
// (미래) S3FileStorage — 클라우드 이전 시 구현
//
// class S3FileStorage implements FileStorage {
//   final String bucketName;
//   final String region;
//   S3FileStorage({required this.bucketName, required this.region});
//   @override Future<void> saveFile({...}) async { /* PUT s3://... */ }
//   @override Future<StoredFileInfo?> getFileInfo(String id) async { /* HEAD s3://... */ }
//   @override Future<Uint8List?> loadBytes(String id) async { /* GET s3://... */ }
//   @override Future<void> deleteFile(String id) async { /* DELETE s3://... */ }
//   @override Future<bool> hasFile(String id) async { /* HEAD s3://... */ }
// }
// ============================================================
