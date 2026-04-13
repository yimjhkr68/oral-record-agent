// 파일 목적: detectPII 통합 테스트 스펙
// 정규식 기반 + Claude 의미론적 분석 테스트

import 'package:flutter_test/flutter_test.dart';
import 'package:oral_record_agent/src/domain/tools/detect_pii.dart';

void main() {
  group('DetectPIITool 통합 테스트', () {
    // 테스트 데이터
    const emailContent = '연락처: user@example.com, test.email@company.co.kr';
    const phoneContent = '전화번호: 010-1234-5678, 02-555-1234';
    const ssnContent = '주민등록번호: 920101-1234567 (예시)';
    const creditCardContent = '결제: 1234-5678-9012-3456';
    const mixedContent = '''
사용자 정보:
이름: 홍길동
이메일: hong@example.com
전화: 010-1234-5678
주민번호: 920101-1234567
결제카드: 1234 5678 9012 3456
''';

    group('정규식 기반 탐지 (detectWithRegex)', () {
      test('[정규식] 이메일 탐지', () {
        final results = DetectPIITool.detectWithRegex(emailContent);
        expect(results, isNotEmpty);
        expect(results.where((r) => r.type == 'email').length, 2);
        expect(
          results.firstWhere((r) => r.type == 'email').value,
          'user@example.com',
        );
      });

      test('[정규식] 전화번호 탐지 (010 형식)', () {
        final results = DetectPIITool.detectWithRegex(phoneContent);
        final phoneMatches = results.where((r) => r.type == 'phone');
        expect(phoneMatches, isNotEmpty);
        expect(
          phoneMatches.firstWhere((r) => r.value == '010-1234-5678'),
          isNotNull,
        );
      });

      test('[정규식] 전화번호 탐지 (02 형식)', () {
        final results = DetectPIITool.detectWithRegex(phoneContent);
        final phoneMatches = results.where((r) => r.type == 'phone');
        expect(
          phoneMatches.firstWhere((r) => r.value == '02-555-1234'),
          isNotNull,
        );
      });

      test('[정규식] 주민등록번호 탐지', () {
        final results = DetectPIITool.detectWithRegex(ssnContent);
        expect(results, isNotEmpty);
        expect(
            results.firstWhere((r) => r.type == 'ssn').value, '920101-1234567');
      });

      test('[정규식] 신용카드 탐지 (하이픈 형식)', () {
        final results = DetectPIITool.detectWithRegex(creditCardContent);
        expect(results, isNotEmpty);
        expect(results.firstWhere((r) => r.type == 'credit_card').value,
            '1234-5678-9012-3456');
      });

      test('[정규식] 혼합 콘텐츠 탐지', () {
        final results = DetectPIITool.detectWithRegex(mixedContent);
        expect(results.length, greaterThanOrEqualTo(4));
        expect(results.map((r) => r.type).toSet(), {
          'email',
          'phone',
          'ssn',
          'credit_card',
        });
      });

      test('[정규식] 위치 정보 포함 (startIndex, endIndex)', () {
        final results = DetectPIITool.detectWithRegex(emailContent);
        final email = results.firstWhere((r) => r.type == 'email');
        expect(email.startIndex, isNotNull);
        expect(email.endIndex, isNotNull);
        expect(email.endIndex, greaterThan(email.startIndex));
      });

      test('[정규식] 빈 콘텐츠 처리', () {
        final results = DetectPIITool.detectWithRegex('');
        expect(results, isEmpty);
      });
    });

    group('Claude 기반 의미론적 분석 (detectWithClaude)', () {
      test('[Claude] 단순 텍스트 분석', () async {
        // NOTE: 실제 구현 시 Mock 또는 실제 API 호출
        // final results = await DetectPIITool.detectWithClaude(
        //   content: '홍길동은 서울에 산다',
        // );
        // expect(results, isNotEmpty);
        // expect(results.any((r) => r.type == 'person_name'), true);
      }, skip: 'Claude API 통합 필요');

      test('[Claude] 복잡한 콘텍스트 분석', () async {
        // NOTE: 실제 구현 시 Mock 또는 실제 API 호출
        // final results = await DetectPIITool.detectWithClaude(
        //   content: '2024년 1월 15일 김철수가 작성했습니다',
        // );
        // expect(results, isNotEmpty);
        // expect(results.any((r) => r.type == 'birth_date'), true);
      }, skip: 'Claude API 통합 필요');

      test('[Claude] 재시도 로직 (maxRetries)', () async {
        // NOTE: 실제 구현 시 네트워크 오류 시뮬레이션
        // final results = await DetectPIITool.detectWithClaude(
        //   content: 'test content',
        //   maxRetries: 3,
        // );
        // expect(results, isNotNull);
      }, skip: 'Claude API 통합 필요');
    });

    group('통합 실행 (execute)', () {
      test('[통합] 정규식 + Claude 분석', () async {
        // NOTE: 실제 구현 시 두 방식을 모두 실행
        // final results = await DetectPIITool.execute(
        //   content: mixedContent,
        //   useClaudeAnalysis: true,
        // );
        // expect(results, isNotEmpty);
      }, skip: 'Claude API 통합 필요');

      test('[통합] 정규식만 사용', () async {
        // NOTE: 실제 구현 시
        // final results = await DetectPIITool.execute(
        //   content: mixedContent,
        //   useClaudeAnalysis: false,
        // );
        // expect(results, isNotEmpty);
      }, skip: 'Claude API 통합 필요');
    });

    group('엣지 케이스', () {
      test('대소문자 혼합 이메일', () {
        const content = 'Email: John.Doe@Example.COM';
        final results = DetectPIITool.detectWithRegex(content);
        expect(results.any((r) => r.type == 'email'), true);
      });

      test('공백이 포함된 신용카드 번호', () {
        const content = '카드: 1234 5678 9012 3456';
        final results = DetectPIITool.detectWithRegex(content);
        expect(results.any((r) => r.type == 'credit_card'), true);
      });

      test('중복된 PII 탐지', () {
        const content = 'Email: test@example.com 또는 test@example.com';
        final results = DetectPIITool.detectWithRegex(content);
        expect(results.where((r) => r.type == 'email').length, 2);
      });

      test('특수문자 처리', () {
        const content = '이메일(user@test.com)를 입력하세요.';
        final results = DetectPIITool.detectWithRegex(content);
        expect(results.any((r) => r.type == 'email'), true);
      });
    });

    group('성능 테스트', () {
      test('[성능] 큰 콘텐츠 처리 (100KB)', () {
        final largeContent = '''
사용자 목록:
${List.generate(1000, (i) => 'user$i@example.com').join(', ')}
''';
        final stopwatch = Stopwatch()..start();
        DetectPIITool.detectWithRegex(largeContent);
        stopwatch.stop();

        // 1초 이내 완료 (정규식은 빠름)
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      });
    });
  });
}
