import 'package:bayan/core/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a long trailing action wraps instead of overflowing a narrow row', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: SectionHeader(
                  title: 'ثالثاً: الإملاء (٢٠ درجة)',
                  subtitle: 'مجموع الأفرع الحالي: ٢٠ درجة',
                  trailing: TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.library_add_outlined, size: 18),
                    label: const Text('استبدال من بنك الإملاء'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final action = tester.getSize(find.byType(TextButton));
    expect(action.width, lessThanOrEqualTo(320 * SectionHeader.maxTrailingFraction));
    expect(find.text('استبدال من بنك الإملاء'), findsOneWidget);
  });
}
