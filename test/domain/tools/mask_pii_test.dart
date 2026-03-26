// 파일 목적: maskPII 도구 테스트
// 3가지 마스킹 전략 검증

import 'package:flutter_test/flutter_test.dart';
import 'package:oral_record_agent/src/domain/tools/mask_pii.dart';

void main() {
  group('MaskPIITool 테스트', () {
    group('전제 마스킹 (maskFull)', () {
      test('[Full] 기본 마스킹', () {
        expect(MaskPIITool.maskFull('user@example.com'), '*****');
      });

      test('[Full] 짧은 값', () {
        expect(MaskPIITool.maskFull('a'), '*');
      });

      test('[Full] 빈 문자열', () {
        expect(MaskPIITool.maskFull(''), '');
      });

      test('[Full] 긴 값 (5자 초과)', () {
        final masked = MaskPIITool.maskFull('123456789');
        expect(masked.length, 5);
        expect(masked, '*****');
      });
    });

    group('부분 마스킹 (maskPartial)', () {
      test('[Partial] 기본 설정 (첫 1자, 마지막 1자)', () {
        final masked = MaskPIITool.maskPartial('user@example.com');
        expect(masked, startsWith('u'));
        expect(masked, endsWith('m'));
        expect(masked.contains('*'), true);
      });

      test('[Partial] 커스텀 showFirst=2, showLast=2', () {
        final masked = MaskPIITool.maskPartial(
          'user@example.com',
          showFirst: 2,
          showLast: 2,
        );
        expect(masked, startsWith('us'));
        expect(masked, endsWith('om'));
      });

      test('[Partial] 값이 너무 짧으면 원본 반환', () {
        final masked = MaskPIITool.maskPartial('ab', showFirst: 1, showLast: 1);
        expect(masked, 'ab');
      });

      test('[Partial] 이메일 형식', () {
        final masked = MaskPIITool.maskPartial('hong@example.com');
        expect(masked.contains('@'), false); // @는 마스킹됨
      });
    });

    group('해시 마스킹 (maskHash)', () {
      test('[Hash] 기본 형식 {HASH:xxxx}', () {
        final masked = MaskPIITool.maskHash('user@example.com');
        expect(masked, startsWith('{HASH:'));
        expect(masked, endsWith('}'));
      });

      test('[Hash] 같은 값은 같은 해시', () {
        final masked1 = MaskPIITool.maskHash('test@example.com');
        final masked2 = MaskPIITool.maskHash('test@example.com');
        expect(masked1, equals(masked2));
      });

      test('[Hash] 다른 값은 다른 해시', () {
        final masked1 = MaskPIITool.maskHash('user1@example.com');
        final masked2 = MaskPIITool.maskHash('user2@example.com');
        expect(masked1, isNot(equals(masked2)));
      });

      test('[Hash] 빈 문자열', () {
        final masked = MaskPIITool.maskHash('');
        expect(masked, startsWith('{HASH:'));
      });
    });

    group('통합 실행 (execute)', () {
      test('[통합] PII 자동 탐지 + Full 마스킹', () async {
        // NOTE: 실제 구현 시
        // final result = await MaskPIITool.execute(
        //   content: content,
        //   strategy: MaskingStrategy.full,
        // );
        // expect(result['maskedContent'], isNotNull);
        // expect(result['piiCount'], greaterThan(0));
        // expect(result['maskingLog'], isNotNull);
      }, skip: 'execute 통합 구현 필요');

      test('[통합] PII 리스트 제공 + Partial 마스킹', () async {
        // NOTE: 실제 구현 시
        // final result = await MaskPIITool.execute(
        //   content: content,
        //   strategy: MaskingStrategy.partial,
        //   piiItems: piiItems,
        // );
        // expect(result['piiCount'], equals(3));
      }, skip: 'execute 통합 구현 필요');
    });

    group('성능 테스트', () {
      test('[성능] 100개 PII 마스킹 < 100ms', () {
        final stopwatch = Stopwatch()..start();

        for (int i = 0; i < 100; i++) {
          MaskPIITool.maskFull('user$i@example.com');
        }

        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });
    });
  });
}
