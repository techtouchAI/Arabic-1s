import 'package:bayan/app.dart';
import 'package:bayan/data/local/exam_document_exporter.dart';
import 'package:bayan/domain/models/library.dart';
import 'package:bayan/presentation/screens/exam_composer_screen.dart';
import 'package:bayan/presentation/screens/glossary_screen.dart';
import 'package:bayan/presentation/screens/lesson_screen.dart';
import 'package:bayan/presentation/screens/question_print_screen.dart';
import 'package:bayan/presentation/screens/unit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_harness.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first-launch onboarding saves teacher/school and opens Part 1', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = createTestAppState(
      selectedPart: null,
      onboardingCompleted: false,
    );

    await tester.pumpWidget(BayanApp(state: state));
    await _settle(tester);

    expect(find.text('١. اختر الجزء الدراسي الحالي'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('onboard-teacher-name')),
      'حيدر الكعبي',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('onboard-school-name')),
      'متوسطة الفيحاء',
    );

    await tester.tap(find.byKey(const ValueKey<String>('onboard-start-button')));
    await _settle(tester);

    expect(state.needsOnboarding, isFalse);
    expect(state.activePart, CurriculumPart.part1);
    expect(state.teacherProfile.teacherName, 'حيدر الكعبي');
    expect(find.textContaining('الأستاذ: حيدر الكعبي'), findsOneWidget);
  });

  testWidgets('renders cleanly with zero overflow on narrow 390px phone & 1280px desktop', (
    WidgetTester tester,
  ) async {
    for (final viewport in <Size>[const Size(390, 844), const Size(1280, 800)]) {
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1.0;

      final state = createTestAppState(
        selectedPart: CurriculumPart.part1,
        onboardingCompleted: true,
        textScale: 1.15,
      );

      await tester.pumpWidget(BayanApp(state: state));
      await _settle(tester);

      if (viewport.width >= 840) {
        expect(find.byType(NavigationRail), findsOneWidget);
      } else {
        expect(find.byType(NavigationBar), findsOneWidget);
      }

      // Cycle through all 5 main destinations
      for (var navIdx = 0; navIdx < 5; navIdx++) {
        state.setNavIndex(navIdx);
        await _settle(tester);
      }

      // Switch to Part 2 and verify Home updates cleanly
      state.setNavIndex(0);
      state.selectPart(CurriculumPart.part2);
      await _settle(tester);
      expect(find.textContaining('الجزء الثاني'), findsWidgets);
    }
    tester.view.reset();
  });

  testWidgets('UnitScreen, LessonScreen, GlossaryScreen, PrintScreen & ExamComposerScreen render without errors', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = createTestAppState();

    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: DiskAssetBundle(),
        child: BayanApp(state: state),
      ),
    );
    await _settle(tester);

    final nav = tester.state<NavigatorState>(find.byType(Navigator));

    // 1. UnitScreen
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => const UnitScreen(unitId: 'p1-u1'),
      ),
    );
    await _settle(tester);
    expect(find.textContaining('أقسام الكلام'), findsWidgets);
    nav.pop();
    await _settle(tester);

    // 2. LessonScreen
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => const LessonScreen(lessonId: 'grammar-p2-u3'),
      ),
    );
    await _settle(tester);
    expect(find.textContaining('الأفعال الخمسة'), findsWidgets);
    nav.pop();
    await _settle(tester);

    // 3. GlossaryScreen
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => const GlossaryScreen(),
      ),
    );
    await _settle(tester);
    expect(find.text('معجم الطالب اللغوي'), findsOneWidget);
    nav.pop();
    await _settle(tester);

    // 4. QuestionPrintScreen
    var printCalled = false;
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => QuestionPrintScreen(
          printQuestions: (plan, title) async {
            printCalled = true;
          },
        ),
      ),
    );
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey<String>('print-questions-button')));
    await _settle(tester);
    expect(printCalled, isTrue);
    nav.pop();
    await _settle(tester);

    // 5. ExamComposerScreen + Live A4 Preview + Export callback
    var exportedTotal = 0;
    double? exportedItemGap;
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => ExamComposerScreen(
          onExport: (paper) async {
            exportedTotal = paper.totalDegree;
            exportedItemGap = paper.typography.spacing.itemGapPt;
            return const ExportOutcome(
              kind: ExportOutcomeKind.savedToFile,
              filePath: '/tmp/exam.docx',
            );
          },
        ),
      ),
    );
    await _settle(tester);

    // Spacing controls remain usable on the real composer and affect export.
    final gapSlider = find.byKey(const ValueKey<String>('المسافة بين النقاط'));
    await tester.ensureVisible(gapSlider);
    await _settle(tester);
    tester.widget<Slider>(gapSlider).onChanged!(2.5);
    await _settle(tester);
    expect(tester.widget<Slider>(gapSlider).value, 2.5);

    // Switch to A4 preview tab
    await tester.tap(find.text('معاينة ورقة A4'));
    await _settle(tester);
    expect(find.textContaining('الانشاء :'), findsOneWidget);

    // Export .docx
    await tester.tap(find.byKey(const ValueKey<String>('export-docx-button')));
    await _settle(tester);
    expect(exportedTotal, 80);
    expect(exportedItemGap, 2.5);
  });
}
