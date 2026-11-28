import 'package:bayan/app.dart';
import 'package:bayan/data/local/exam_document_exporter.dart';
import 'package:bayan/domain/models/library.dart';
import 'package:bayan/domain/models/exam_paper.dart';
import 'package:bayan/domain/models/question_print_settings.dart';
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

      // Cycle through all 6 main destinations
      for (var navIdx = 0; navIdx < 6; navIdx++) {
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
    ArabicExamPaper? exportedPaper;
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => ExamComposerScreen(
          onExport: (paper) async {
            exportedPaper = paper;
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

    // Long prompts and points have a full-width, expanding editor on phones.
    Finder field(String label) => find.byWidgetPredicate((widget) =>
        widget is TextField && widget.decoration?.labelText == label);
    final prompt = field('منطوق السؤال / الفرع').first;
    await tester.ensureVisible(prompt);
    await _settle(tester);
    expect(tester.widget<TextField>(prompt).maxLines, isNull);
    const editedPrompt = 'نص طويل قابل للتحرير\nالسطر الثاني من السؤال';
    await tester.enterText(prompt, editedPrompt);
    await _settle(tester);
    final point = field('نقطة (١)').first;
    await tester.ensureVisible(point);
    await _settle(tester);
    expect(tester.widget<TextField>(point).maxLines, isNull);
    const editedPoint = 'نقطة محررة\nتتمة النقطة';
    await tester.enterText(point, editedPoint);
    await _settle(tester);
    final country = field('الدولة');
    await tester.ensureVisible(country);
    await _settle(tester);
    await tester.enterText(country, 'ترويسة محررة');
    await _settle(tester);
    final fontSlider = find.byKey(const ValueKey<String>('exam-body-font-size'));
    await tester.ensureVisible(fontSlider);
    await _settle(tester);
    expect(tester.widget<Slider>(fontSlider).min, 8);
    tester.widget<Slider>(fontSlider).onChanged!(8);
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
    expect(exportedPaper!.typography.bodySizePt, 8);
    expect(exportedPaper!.header.countryLine, 'ترويسة محررة');
    expect(exportedPaper!.grammar.questions.first.branches.first.prompt, editedPrompt);
    expect(exportedPaper!.grammar.questions.first.branches.first.items.first, editedPoint);

    // Every edit was autosaved into a single record of «أسئلتي المحفوظة».
    expect(state.savedExams.papers, hasLength(1));
    final saved = state.savedExams.papers.single;
    expect(identical(saved.paper, exportedPaper), isTrue);
    expect(saved.revision, greaterThan(1));
  });

  testWidgets('study plan shows a full-width A4 sheet with complete topics, no overflow', (
    WidgetTester tester,
  ) async {
    for (final viewport in <Size>[
      const Size(390, 844), // narrow phone
      const Size(412, 915), // normal phone
      const Size(1280, 800), // wide desktop
    ]) {
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      for (final mode in const <_PlanModeCase>[
        _PlanModeCase(tab: 'الخطة السنوية', header: 'المجموع'),
        _PlanModeCase(tab: 'الخطة اليومية', header: 'اليوم الأول'),
      ]) {
        final state = createTestAppState(
          selectedPart: CurriculumPart.part1,
          onboardingCompleted: true,
          textScale: 1.15,
        );

        await tester.pumpWidget(BayanApp(state: state));
        await _settle(tester);

        state.setNavIndex(5); // StudyPlanScreen
        await _settle(tester);

        // Wait for the async plan load (SharedPreferences) to finish before
        // asserting on the sheet's plan content.
        for (var i = 0;
            i < 20 &&
                state.studyPlans.plans.annualRows.isEmpty &&
                state.studyPlans.plans.dailyEntries.isEmpty;
            i++) {
          await tester.pump();
        }

        // Switch to the requested plan via its TabBar tab.
        await tester.tap(find.text(mode.tab).first, warnIfMissed: false);
        await _settle(tester);

        const sheetKey = ValueKey<String>('a4-sheet');
        final sheetBox =
            tester.renderObject(find.byKey(sheetKey)) as RenderBox;

        // The sheet must keep the exact A4 aspect ratio (210:297).
        final ratio = sheetBox.size.width / sheetBox.size.height;
        expect(
          (ratio - 210 / 297).abs(),
          lessThan(0.01),
          reason: 'A4 preview aspect ratio must be 210:297',
        );

        // The sheet fills the available width — no minimum-width clamp, so
        // there is no horizontal scrolling and no crushed/hidden content.
        expect(
          sheetBox.size.width,
          lessThanOrEqualTo(viewport.width),
          reason: 'sheet must not be wider than the viewport',
        );
        if (viewport.width < 640) {
          expect(
            sheetBox.size.width,
            lessThan(640),
            reason: 'sheet must not be clamped to a min width on phones',
          );
        }

        // Sheet content is present and the page is not split into two panes.
        expect(find.byKey(sheetKey), findsOneWidget);
        expect(find.text('A4'), findsOneWidget);
        expect(find.text('منصة بيان للتعليم'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(sheetKey),
            matching: find.textContaining(mode.header),
          ),
          findsOneWidget,
        );

        // Daily topics are shown in full inside the sheet.
        if (mode.tab == 'الخطة اليومية') {
          final firstContent = state.studyPlans.plans.dailyEntries.first.content;
          expect(
            find.descendant(
              of: find.byKey(sheetKey),
              matching: find.text(firstContent),
            ),
            findsOneWidget,
            reason: 'the daily topic content must be shown in full',
          );
        }

        // Any RenderFlex/BoxConstraints overflow throws during pump.
        await _settle(tester);
      }
    }
  });

  testWidgets('study plan topic card opens the editor as a popup, dismiss restores', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = createTestAppState(
      selectedPart: CurriculumPart.part1,
      onboardingCompleted: true,
      textScale: 1.15,
    );

    await tester.pumpWidget(BayanApp(state: state));
    await _settle(tester);
    state.setNavIndex(5); // StudyPlanScreen
    await _settle(tester);

    // Wait for the async plan load to finish before interacting.
    for (var i = 0;
        i < 20 &&
            state.studyPlans.plans.annualRows.isEmpty &&
            state.studyPlans.plans.dailyEntries.isEmpty;
        i++) {
      await tester.pump();
    }

    // Daily topic: open the first card's editor popup.
    final tabBar = find.byType(TabBar);
    await tester.tap(
      find.descendant(of: tabBar, matching: find.text('الخطة اليومية')),
    );
    await _settle(tester);
    await tester.ensureVisible(find.byTooltip('تعديل').first);
    await tester.tap(find.byTooltip('تعديل').first);
    await _settle(tester);
    expect(find.text('تحرير اليوم'), findsOneWidget);
    // The plan sheet stays in place while the editor overlays it.
    expect(find.byKey(const ValueKey<String>('a4-sheet')), findsOneWidget);

    // Dismiss the popup via the scrim — layout restores cleanly.
    await tester.tapAt(const Offset(10, 10));
    await _settle(tester);
    expect(find.text('تحرير اليوم'), findsNothing);

    // Annual unit: open its editor popup as well.
    await tester.tap(
      find.descendant(of: tabBar, matching: find.text('الخطة السنوية')),
    );
    await _settle(tester);
    await tester.ensureVisible(find.byTooltip('تعديل').first);
    await tester.tap(find.byTooltip('تعديل').first);
    await _settle(tester);
    expect(find.text('تحرير الوحدة'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('a4-sheet')), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await _settle(tester);
    expect(find.text('تحرير الوحدة'), findsNothing);
    await _settle(tester);
  });

  testWidgets('study plan print-options panel opens/closes without overlap or overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = createTestAppState(
      selectedPart: CurriculumPart.part1,
      onboardingCompleted: true,
      textScale: 1.15,
    );

    await tester.pumpWidget(BayanApp(state: state));
    await _settle(tester);
    state.setNavIndex(5); // StudyPlanScreen
    await _settle(tester);

    // Panel closed initially.
    expect(find.text('خيارات ال sheet'), findsNothing);

    // Open the panel as a modal popup — it overlays, it must not overflow and
    // must not split/compress the plan content behind it.
    await tester.tap(find.byTooltip('خيارات الطباعة'));
    await _settle(tester);
    expect(find.text('خيارات ال sheet'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<QuestionPrintFont>), findsOneWidget);
    // The plan content stays in place (page is not split or pushed down).
    expect(find.byKey(const ValueKey<String>('a4-sheet')), findsOneWidget);
    // Long font names stay inside the (expanded) field — no horizontal overflow.
    await _settle(tester);

    // Dismiss the popup by tapping the scrim above the sheet.
    await tester.tapAt(const Offset(10, 10));
    await _settle(tester);
    expect(find.text('خيارات ال sheet'), findsNothing);
    await _settle(tester);
  });
}

class _PlanModeCase {
  const _PlanModeCase({required this.tab, required this.header});

  final String tab;
  final String header;
}
