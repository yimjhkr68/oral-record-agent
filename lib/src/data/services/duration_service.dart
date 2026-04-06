// 파일 목적: ffprobe로 음성/영상 파일 재생 시간 측정
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class DurationService {
  /// 파일 경로 → 재생 시간(초) 반환. 실패 시 null.
  static Future<int?> getDuration({
    required String filePath,
    String pythonPath = 'python',
    String? scriptDir,
  }) async {
    final script = _findScript(scriptDir, 'get_duration.py');
    if (script == null) {
      return null;
    }

    try {
      final env = Map<String, String>.from(Platform.environment)
        ..['PYTHONIOENCODING'] = 'utf-8'
        ..['PYTHONUTF8'] = '1';

      final result = await Process.run(
        pythonPath,
        ['-u', script, filePath],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
        runInShell: Platform.isWindows,
        environment: env,
      ).timeout(const Duration(seconds: 30));

      final stdout = result.stdout.toString().trim();
      if (stdout.isEmpty) return null;

      final jsonLine = _lastJsonLine(stdout);
      if (jsonLine == null) return null;

      final map = jsonDecode(jsonLine) as Map<String, dynamic>;
      if (map.containsKey('error')) return null;

      return map['duration'] as int?;
    } catch (e) {
      return null;
    }
  }

  static String? _lastJsonLine(String stdout) {
    for (final line in stdout.split('\n').map((l) => l.trim()).toList().reversed) {
      if (line.startsWith('{') && line.endsWith('}')) return line;
    }
    return null;
  }

  static String? _findScript(String? scriptDir, String name) {
    if (scriptDir != null) {
      final p = '$scriptDir${Platform.pathSeparator}$name';
      if (File(p).existsSync()) return p;
    }
    final devPath =
        '${Directory.current.path}${Platform.pathSeparator}scripts${Platform.pathSeparator}$name';
    if (File(devPath).existsSync()) return devPath;

    final exeDir = File(Platform.resolvedExecutable).parent.path;
    var dir = Directory(exeDir);
    for (var i = 0; i < 5; i++) {
      final c = '${dir.path}${Platform.pathSeparator}scripts${Platform.pathSeparator}$name';
      if (File(c).existsSync()) return c;
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }
}
