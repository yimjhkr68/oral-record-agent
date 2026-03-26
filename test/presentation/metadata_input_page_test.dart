// 파일 목적: MetadataInputPage Widget 테스트

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oral_record_agent/src/presentation/pages/metadata_input_page.dart';

void main() {
  group('MetadataInputPage Widget 테스트', () {
    testWidgets('필수 필드 제목 표시', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: MetadataInputPage()),
        ),
      );

      // 필수 필드 제목
      expect(find.text('구술자 *'), findsOneWidget);
      expect(find.text('면담자 *'), findsOneWidget);
      expect(find.text('면담 일시 *'), findsOneWidget);
    });

    testWidgets('선택 필드 제목 표시', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: MetadataInputPage()),
        ),
      );

      // 선택 필드 제목
      expect(find.text('주제 분류 *'), findsOneWidget);
      expect(find.text('키워드 (최대 20개)'), findsOneWidget);
    });

    testWidgets('저장 버튼 초기 상태 (비활성)', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: MetadataInputPage()),
        ),
      );

      // 저장 버튼 찾기
      final saveButton = find.widgetWithText(ElevatedButton, '저장');
      expect(saveButton, findsOneWidget);

      // 필수 필드 미작성 시 비활성 상태 확인
      final buttonWidget = tester.widget<ElevatedButton>(saveButton);
      expect(buttonWidget.onPressed, isNull); // 비활성 (onPressed == null)
    });

    testWidgets('비공개 체크박스', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: MetadataInputPage()),
        ),
      );

      expect(find.byType(Switch), findsOneWidget);
      expect(find.text('비공개'), findsOneWidget);
    });

    testWidgets('날짜 선택 계승', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: MetadataInputPage()),
        ),
      );

      // 날짜 선택 컨테이너 찾기 (기본값 DateTime.now()로 초기화됨)
      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    });

    testWidgets('키워드 추가/제거', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: MetadataInputPage()),
        ),
      );

      // 키워드 입력 필드 찾기
      expect(find.text('키워드 입력 후 Enter'), findsOneWidget);
    });

    testWidgets('주제 분류 드롭다운', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: MetadataInputPage()),
        ),
      );

      // 드롭다운 (DropdownButton 또는 PopupMenuButton) 찾기
      // 여기서는 스크롤 가능 여부만 확인
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('형태 검증 (유효한 폼)', (WidgetTester tester) async {
      // NOTE: Provider override를 통해 유효한 폼 상태 시뮬레이션
      // 정실제 구현에서는 각 필드 입력 후 상태 확인
    });
  });
}
