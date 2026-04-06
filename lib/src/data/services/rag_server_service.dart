import 'dart:io';

class RagServerService {
  static Process? _qdrantProcess;
  static Process? _fastapiProcess;

  /// 앱 시작 시 호출 - Qdrant + FastAPI 실행
  static Future<void> start() async {
    try {
      await _startQdrant();
      await Future.delayed(const Duration(seconds: 3));
      await _startFastapi();
    } catch (e) {
      // 서버 시작 실패해도 앱 실행에 영향 없음
    }
  }

  /// 앱 종료/로그아웃 시 호출
  static Future<void> stop() async {
    try {
      _fastapiProcess?.kill();
      _qdrantProcess?.kill();
      _fastapiProcess = null;
      _qdrantProcess = null;
    } catch (e) {
      // 종료 실패해도 무시
    }
  }

  static Future<void> _startQdrant() async {
    try {
      _qdrantProcess = await Process.start(
        'docker',
        ['start', 'qdrant'],
        runInShell: true,
      );
    } catch (e) {
      // ignore: avoid_print
      print('[RagServer] Qdrant 시작 실패: $e');
    }
  }

  static Future<void> _startFastapi() async {
    try {
      final projectRoot = _getProjectRoot();
      _fastapiProcess = await Process.start(
        'python',
        ['-m', 'uvicorn', 'main:app', '--host', '0.0.0.0', '--port', '9000'],
        workingDirectory: '$projectRoot/server',
        runInShell: true,
      );
    } catch (e) {
      // ignore: avoid_print
      print('[RagServer] FastAPI 시작 실패: $e');
    }
  }

  static String _getProjectRoot() {
    // 실행 파일 기준 상위 디렉토리
    // Windows: build/windows/x64/runner/Release/ → 5단계 상위
    final execPath = Platform.resolvedExecutable;
    final execDir = File(execPath).parent;
    return execDir.parent.parent.parent.parent.parent.path;
  }
}
