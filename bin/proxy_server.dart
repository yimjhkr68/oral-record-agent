// 파일 목적: CORS 프록시 서버 (개발용)
// Flutter Web → http://localhost:8080/api/messages → Anthropic API
// CORS 헤더를 응답에 추가하여 브라우저 CORS 차단 우회

import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

const _proxyPort = 8080;
const _anthropicUrl = 'https://api.anthropic.com/v1/messages';

// .env 파일에서 API 키 읽기
String _readApiKeyFromEnv() {
  // 1순위: 환경 변수
  final envKey = Platform.environment['ANTHROPIC_API_KEY'];
  if (envKey != null && envKey.isNotEmpty) return envKey;

  // 2순위: .env 파일
  final envFile = File('.env');
  if (envFile.existsSync()) {
    for (final line in envFile.readAsLinesSync()) {
      final trimmed = line.trim();
      if (trimmed.startsWith('ANTHROPIC_API_KEY=')) {
        return trimmed.substring('ANTHROPIC_API_KEY='.length).trim();
      }
    }
  }
  return '';
}

Map<String, String> _corsHeaders() => {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
      'Access-Control-Allow-Headers':
          'Content-Type, Authorization, x-api-key, anthropic-version',
    };

Future<Response> _handler(Request request) async {
  // OPTIONS 프리플라이트 요청 처리
  if (request.method == 'OPTIONS') {
    return Response.ok('', headers: _corsHeaders());
  }

  // 헬스체크
  if (request.url.path == 'health') {
    return Response.ok(
      jsonEncode({'status': 'ok', 'port': _proxyPort}),
      headers: {..._corsHeaders(), 'content-type': 'application/json'},
    );
  }

  // Anthropic API 프록시
  if (request.url.path == 'api/messages' && request.method == 'POST') {
    // API 키: 요청 헤더 > .env 파일 순으로 우선 적용
    final requestApiKey = request.headers['x-api-key'] ?? '';
    final apiKey = requestApiKey.isNotEmpty ? requestApiKey : _readApiKeyFromEnv();

    if (apiKey.isEmpty) {
      return Response(
        401,
        body: jsonEncode({'error': 'API 키가 없습니다. .env 파일 또는 설정 화면에서 입력해주세요.'}),
        headers: {..._corsHeaders(), 'content-type': 'application/json'},
      );
    }

    final body = await request.readAsString();

    try {
      final anthropicResponse = await http.post(
        Uri.parse(_anthropicUrl),
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        body: body,
      );

      return Response(
        anthropicResponse.statusCode,
        body: anthropicResponse.body,
        headers: {
          ..._corsHeaders(),
          'content-type': 'application/json; charset=utf-8',
        },
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Anthropic API 호출 실패: $e'}),
        headers: {..._corsHeaders(), 'content-type': 'application/json'},
      );
    }
  }

  return Response.notFound(
    jsonEncode({'error': '알 수 없는 경로: ${request.url.path}'}),
    headers: {..._corsHeaders(), 'content-type': 'application/json'},
  );
}

void main() async {
  final apiKey = _readApiKeyFromEnv();

  final pipeline = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(_handler);

  final server = await shelf_io.serve(pipeline, 'localhost', _proxyPort);

  print('');
  print('╔══════════════════════════════════════════╗');
  print('║      CORS 프록시 서버 시작               ║');
  print('╠══════════════════════════════════════════╣');
  print('║  주소: http://localhost:${server.port}          ║');
  print('║  API 키: ${apiKey.isEmpty ? '❌ 미설정 (.env 확인)' : '✅ 로드됨              '}  ║');
  print('╚══════════════════════════════════════════╝');
  print('');
  print('Flutter 앱을 별도 터미널에서 실행하세요:');
  print('  flutter run -d chrome');
  print('');
  print('[Ctrl+C] 를 눌러 종료');
}
