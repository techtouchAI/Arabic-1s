import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:bayan/app.dart';
import 'package:bayan/core/utils/arabic_text.dart';
import 'package:bayan/data/local/docx/exam_docx_builder.dart';
import 'package:bayan/data/local/exam_document_exporter.dart';
import 'package:bayan/domain/models/exam_paper.dart';
import 'package:bayan/domain/models/library.dart';
import 'package:bayan/domain/models/progress.dart';
import 'package:bayan/domain/services/exam_bank_picker.dart';
import 'package:bayan/domain/services/exam_layout_plan.dart';
import 'package:bayan/domain/services/question_print_plan.dart';
import 'package:bayan/presentation/screens/exam_composer_screen.dart';
import 'package:bayan/presentation/screens/question_print_screen.dart';
import 'package:bayan/presentation/screens/quiz_screen.dart';
import 'package:bayan/presentation/screens/saved_exams_screen.dart';
import 'package:bayan/presentation/state/exam_composer_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'test_harness.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Requirement 1 — Dynamic section and total degree calculation', () {
    test('all branch, question, and bank mutations recalculate section & total degrees', () {
      final content = loadTestContentSync();
      final ctrl = ExamComposerController(
        examBank: content.examBank,
        teacherProfile: const TeacherProfile(),
        activePart: CurriculumPart.part2,
      );
      addTearDown(ctrl.dispose);

      expect(ctrl.paper.composition.degree, 30);
      expect(ctrl.paper.effectiveGrammarDegree, 35);
      expect(ctrl.paper.effectiveOrthographyDegree, 15);
      expect(ctrl.paper.totalDegree, 80);

      // 1. Change first grammar branch degree (+4) -> grammar = 39, total = 84
      final firstGrammarBranch = ctrl.paper.grammar.questions[0].branches[0];
      ctrl.updateBranch(
        isGrammar: true,
        questionIndex: 0,
        branchIndex: 0,
        updated: firstGrammarBranch.copyWith(degree: firstGrammarBranch.degree + 4),
      );
      expect(ctrl.paper.grammar.degree, 39);
      expect(ctrl.paper.effectiveGrammarDegree, 39);
      expect(ctrl.paper.grammarBalanced, isTrue);
      expect(ctrl.paper.totalDegree, 84);

      // 2. Add a new grammar question (+5) -> grammar = 44, total = 89
      ctrl.addQuestionBlock(isGrammar: true);
      expect(ctrl.paper.grammar.degree, 44);
      expect(ctrl.paper.totalDegree, 89);

      // 3. Add a branch to that new question (+5) -> grammar = 49, total = 94
      final lastQ = ctrl.paper.grammar.questions.length - 1;
      ctrl.addBranchToQuestion(isGrammar: true, questionIndex: lastQ);
      expect(ctrl.paper.grammar.degree, 49);
      expect(ctrl.paper.totalDegree, 94);

      // 4. Remove a branch (-5) -> grammar = 44, total = 89
      ctrl.removeBranchFromQuestion(
        isGrammar: true,
        questionIndex: lastQ,
        branchIndex: 1,
      );
      expect(ctrl.paper.grammar.degree, 44);
      expect(ctrl.paper.totalDegree, 89);

      // 5. Remove the added question (-5) -> grammar = 39, total = 84
      ctrl.removeQuestionBlock(isGrammar: true, questionIndex: lastQ);
      expect(ctrl.paper.grammar.degree, 39);
      expect(ctrl.paper.totalDegree, 84);

      // 6. Replace an orthography branch from bank with degree 8
      final firstOrthoDeg = ctrl.paper.orthography.questions[0].branches[0].degree;
      ctrl.replaceBranchFromBank(
        isGrammar: false,
        questionIndex: 0,
        branchIndex: 0,
        prompt: 'ما التنوين ؟ وما صوره ؟',
        degree: 8,
        items: const <String>[],
        itemLayout: ExamItemLayout.prose,
      );
      final expectedOrtho = 15 - firstOrthoDeg + 8;
      expect(ctrl.paper.orthography.degree, expectedOrtho);
      expect(ctrl.paper.effectiveOrthographyDegree, expectedOrtho);
      expect(ctrl.paper.orthographyBalanced, isTrue);
      expect(ctrl.paper.totalDegree, 30 + 39 + expectedOrtho);

      // 7. Update composition degree to 25
      ctrl.updateComposition(ctrl.paper.composition.copyWith(degree: 25));
      expect(ctrl.paper.totalDegree, 25 + 39 + expectedOrtho);

      // 8. Verify ExamLayoutPlan and exported Word .docx reflect updated section degrees
      final plan = ExamLayoutPlan.build(ctrl.paper);
      final headings = plan
          .where((p) => p.kind == ExamParagraphKind.heading)
          .toList(growable: false);
      expect(headings[0].degree, 25);
      expect(headings[1].degree, 39);
      expect(headings[2].degree, expectedOrtho);

      final docxBytes = ExamDocxBuilder.build(ctrl.paper);
      final archive = ZipDecoder().decodeBytes(docxBytes);
      final docXml = XmlDocument.parse(
        utf8.decode(archive.findFile('word/document.xml')!.content as List<int>),
      );
      final fullText = docXml.findAllElements('w:t').map((e) => e.innerText).join(' ');
      expect(fullText, contains('39'));
    });

    test('legacy JSON with stale section degree computes live effectiveDegree', () {
      final content = loadTestContentSync();
      final base = content.examBank.officialTemplates.first.toExamPaper();
      final json = base.toJson();
      (json['grammar'] as Map<String, dynamic>)['degree'] = 10;
      final restored = ArabicExamPaper.fromJson(json);

      expect(restored.grammar.branchesSum, 35);
      expect(restored.effectiveGrammarDegree, 35);
      expect(restored.totalDegree, 80);
    });

    testWidgets('composer UI & SavedExamsScreen update total degree live without false warnings', (
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
      nav.push(
        MaterialPageRoute<void>(builder: (_) => const ExamComposerScreen()),
      );
      await _settle(tester);

      expect(find.byKey(const ValueKey<String>('degree-summary-badge')), findsOneWidget);
      expect(find.textContaining('المجموع الكلي: ٨٠ درجة'), findsWidgets);
      expect(find.textContaining('راجع مجموع درجات الأفرع'), findsNothing);

      // Tap '+' on the composition degree stepper -> total becomes 81
      final addIcons = find.byIcon(Icons.add);
      await tester.ensureVisible(addIcons.first);
      await _settle(tester);
      // Find the '+' inside the first _DegreeStepper (composition degree = 30)
      final compDegreeText = find.text('٣٠').first;
      await tester.ensureVisible(compDegreeText);
      await _settle(tester);
      await tester.tap(compDegreeText);
      await _settle(tester);

      // Direct numeric input dialog opens; enter 25 in Arabic digits
      expect(find.text('تعديل الدرجة'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, '30'),
        '٢٥',
      );
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();
      await _settle(tester);

      expect(find.textContaining('المجموع الكلي: ٧٥ درجة'), findsWidgets);
      expect(find.textContaining('راجع مجموع درجات الأفرع'), findsNothing);

      // Add a new grammar question (+5) -> total becomes 80 again (25 + 40 + 15)
      final addQuestionBtn = find.text('سؤال جديد');
      await tester.ensureVisible(addQuestionBtn);
      await _settle(tester);
      await tester.tap(addQuestionBtn);
      await _settle(tester);

      expect(find.textContaining('المجموع الكلي: ٨٠ درجة'), findsWidgets);
      expect(
        find.textContaining('ثانياً: قواعد اللغة العربية (٤٠ درجة)'),
        findsOneWidget,
      );
      expect(find.textContaining('راجع مجموع درجات الأفرع'), findsNothing);

      // Open SavedExamsScreen and verify no warning appears there either
      nav.push(
        MaterialPageRoute<void>(builder: (_) => const SavedExamsScreen()),
      );
      await _settle(tester);
      expect(find.textContaining('راجع مجموع درجات الأفرع'), findsNothing);
      expect(find.textContaining('٢٥ + ٤٠ + ١٥'), findsOneWidget);
    });
  });

  group('Requirement 2 — A4 preview single-row toolbar & ultra-HD PNG export', () {
    testWidgets('all 5 preview buttons stay strictly on 1 horizontal line even on 320px narrow screen', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = createTestAppState();
      state.setTextScale(1.30);

      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: DiskAssetBundle(),
          child: BayanApp(state: state),
        ),
      );
      await _settle(tester);

      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.push(
        MaterialPageRoute<void>(builder: (_) => const ExamComposerScreen()),
      );
      await _settle(tester);

      await tester.tap(find.text('معاينة ورقة A4'));
      await _settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey<String>('preview-zoom-label')), findsNothing);
      expect(find.textContaining('معاينة تقريبية'), findsNothing);

      const keys = <String>[
        'preview-zoom-in',
        'preview-zoom-out',
        'preview-zoom-fit',
        'preview-zoom-reset',
        'preview-fullscreen',
      ];
      final centers = <Offset>[
        for (final key in keys)
          tester.getCenter(find.byKey(ValueKey<String>(key))),
      ];
      final firstDy = centers.first.dy;
      for (final c in centers) {
        expect((c.dy - firstDy).abs(), lessThan(0.5));
      }
    });

    testWidgets('preview-download-image exports high-resolution PNG of the A4 canvas', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      Uint8List? exportedBytes;
      ArabicExamPaper? exportedPaper;

      final state = createTestAppState();
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: DiskAssetBundle(),
          child: BayanApp(state: state),
        ),
      );
      await _settle(tester);

      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => ExamComposerScreen(
            onExportImage: (Uint8List bytes, ArabicExamPaper paper) async {
              exportedBytes = bytes;
              exportedPaper = paper;
              return const ExportOutcome(
                kind: ExportOutcomeKind.savedToFile,
                filePath: '/tmp/exam_preview.png',
              );
            },
          ),
        ),
      );
      await _settle(tester);

      await tester.tap(find.text('معاينة ورقة A4'));
      await _settle(tester);

      final downloadBtn = tester.widget<ButtonStyleButton>(
        find.byKey(const ValueKey<String>('preview-download-image')),
      );
      expect(downloadBtn.onPressed, isNotNull);

      await tester.runAsync(() async {
        downloadBtn.onPressed!();
        for (var i = 0; i < 50 && exportedBytes == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      });
      await _settle(tester);

      expect(exportedBytes, isNotNull);
      expect(exportedPaper, isNotNull);
      // Verify PNG magic signature: 89 50 4E 47 0D 0A 1A 0A
      expect(
        exportedBytes!.sublist(0, 8),
        equals(<int>[137, 80, 78, 71, 13, 10, 26, 10]),
      );
      // Parse big-endian width & height from PNG IHDR chunk (bytes 16..23)
      final header = ByteData.sublistView(exportedBytes!, 16, 24);
      final width = header.getUint32(0);
      final height = header.getUint32(4);
      expect(width, greaterThanOrEqualTo(3000));
      expect(height, greaterThanOrEqualTo(4000));

      // Also verify fullscreen preview download button (preview-fullscreen-download-image)
      exportedBytes = null;
      await tester.tap(find.byKey(const ValueKey<String>('preview-fullscreen')));
      await _settle(tester);

      final fullscreenBtn = tester.widget<IconButton>(
        find.byKey(const ValueKey<String>('preview-fullscreen-download-image')),
      );
      expect(fullscreenBtn.onPressed, isNotNull);

      await tester.runAsync(() async {
        fullscreenBtn.onPressed!();
        for (var i = 0; i < 50 && exportedBytes == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      });
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(exportedBytes, isNotNull);
      expect(
        exportedBytes!.sublist(0, 8),
        equals(<int>[137, 80, 78, 71, 13, 10, 26, 10]),
      );
    });

    test('ExamDocumentExporter.exportPng saves directly via Android MediaStore channel', () async {
      final content = loadTestContentSync();
      final paper = content.examBank.officialTemplates.first.paper;
      final samplePng = Uint8List.fromList(<int>[
        137, 80, 78, 71, 13, 10, 26, 10, 1, 2, 3, 4,
      ]);

      MethodCall? capturedCall;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        ExamDocumentExporter.mediaStoreChannel,
        (MethodCall call) async {
          capturedCall = call;
          final args = call.arguments as Map<Object?, Object?>;
          return 'Pictures/Bayan/${args['fileName']}';
        },
      );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          ExamDocumentExporter.mediaStoreChannel,
          null,
        );
        debugDefaultTargetPlatformOverride = null;
      });

      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final outcome = await const ExamDocumentExporter().exportPng(
        samplePng,
        paper,
      );
      debugDefaultTargetPlatformOverride = null;

      expect(capturedCall, isNotNull);
      expect(capturedCall!.method, 'saveImageToGallery');
      expect(outcome.kind, ExportOutcomeKind.savedToFile);
      expect(outcome.filePath, startsWith('Pictures/Bayan/'));
      expect(outcome.filePath, endsWith('.png'));
    });

    test('production code in lib/ never calls debug-only RenderObject getters outside assert', () {
      // In Flutter release builds (`flutter build apk --release`), getters like
      // `RenderObject.debugNeedsPaint` throw `LateInitializationError: Local 'result'
      // has not been initialized` if invoked outside an `assert(...)` block.
      final libDir = Directory('lib');
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((File f) => f.path.endsWith('.dart'));
      final forbiddenOutsideAssert = RegExp(
        r'\.(debugNeedsPaint|debugNeedsLayout|debugDoingThisPaint|debugDoingThisLayout|debugNeedsCompositingBitsUpdate)\b',
      );
      for (final file in dartFiles) {
        final source = file.readAsStringSync();
        // Strip comments and assert(...) blocks, then ensure zero matches remain.
        final withoutLineComments = source.replaceAll(RegExp(r'//.*'), '');
        final withoutAsserts = withoutLineComments.replaceAll(
          RegExp(r'assert\s*\(\s*\(\s*\)\s*\{[\s\S]*?\}\s*\(\s*\)\s*\)\s*;'),
          '',
        );
        expect(
          forbiddenOutsideAssert.hasMatch(withoutAsserts),
          isFalse,
          reason:
              'Release-crashing debug getter found outside assert in ${file.path}',
        );
      }
    });
  });

  group('Requirement 3 — Official exam question types in Bank & Interactive Quiz', () {
    test('curriculum has zero trueFalse questions and 100% official exam styles', () {
      final content = loadTestContentSync();
      const validStyles = <String>{
        'mcq',
        'irab',
        'difference',
        'apply',
        'murab_mabni',
        'ishara',
        'extract',
        'five_verbs',
        'ortho',
      };
      final seenStyles = <String>{};
      var count = 0;
      for (final unit in content.library.units) {
        for (final q in unit.questions) {
          count++;
          expect(q.kind, isNot(QuestionKind.trueFalse));
          expect(validStyles.contains(q.effectiveExamStyle), isTrue);
          expect(q.hasInteractiveChoices, isTrue);
          expect(q.interactiveOptions, hasLength(3));
          for (final seg in parseUnderlinedSegments(q.prompt)) {
            expect(seg.text.contains('_'), isFalse);
          }
          seenStyles.add(q.effectiveExamStyle);
        }
      }
      expect(count, 114);
      expect(seenStyles, equals(validStyles));
      expect(ExamBankPicker.grammarStyles.contains('taqwim'), isFalse);
    });

    testWidgets('QuestionPrintScreen filters by official exam styles without true/false', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      QuestionPrintPlan? capturedPlan;
      final state = createTestAppState();
      await tester.pumpWidget(BayanApp(state: state));
      await _settle(tester);

      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => QuestionPrintScreen(
            printQuestions: (QuestionPrintPlan plan, String _) async {
              capturedPlan = plan;
            },
          ),
        ),
      );
      await _settle(tester);

      expect(find.textContaining('الصح والخطأ'), findsNothing);
      expect(find.byKey(const ValueKey<String>('print-style-irab')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('print-style-mcq')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('print-style-ortho')), findsOneWidget);

      // Deselect all styles, then select only 'irab'
      await tester.tap(find.byKey(const ValueKey<String>('print-style-all')));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey<String>('print-style-irab')));
      await _settle(tester);

      await tester.tap(find.byKey(const ValueKey<String>('print-questions-button')));
      await _settle(tester);

      expect(capturedPlan, isNotNull);
      expect(capturedPlan!.trueFalseQuestions, isEmpty);
      expect(capturedPlan!.sections, hasLength(1));
      expect(capturedPlan!.sections.single.id, 'irab');
      expect(
        capturedPlan!.sections.single.questions.every(
          (q) => q.effectiveExamStyle == 'irab',
        ),
        isTrue,
      );
    });

    testWidgets('QuizScreen runs interactive session across official exam styles', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = createTestAppState();
      await tester.pumpWidget(BayanApp(state: state));
      await _settle(tester);

      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.push(
        MaterialPageRoute<void>(builder: (_) => const QuizScreen()),
      );
      await _settle(tester);

      expect(find.text('صح'), findsNothing);
      expect(find.text('خطأ'), findsNothing);

      // Filter quiz strictly to 'irab' (أعرب ما تحته خط)
      final irabChip = find.byKey(const ValueKey<String>('quiz-style-irab'));
      await tester.ensureVisible(irabChip);
      await _settle(tester);
      await tester.tap(irabChip);
      await _settle(tester);

      final startBtn = find.byKey(const ValueKey<String>('start-quiz-button'));
      await tester.ensureVisible(startBtn);
      await _settle(tester);
      await tester.tap(startBtn);
      await _settle(tester);

      // Answer every question in the session (3 choices each, zero صح/خطأ)
      for (var step = 0; step < 10; step++) {
        expect(find.text('أعرب ما تحته خط'), findsWidgets);
        expect(find.byKey(const ValueKey<String>('quiz-option-0')), findsOneWidget);
        expect(find.byKey(const ValueKey<String>('quiz-option-1')), findsOneWidget);
        expect(find.byKey(const ValueKey<String>('quiz-option-2')), findsOneWidget);

        final opt0 = find.byKey(const ValueKey<String>('quiz-option-0'));
        await tester.ensureVisible(opt0);
        await _settle(tester);
        await tester.tap(opt0);
        await _settle(tester);

        final nextBtn = find.byKey(const ValueKey<String>('quiz-next-button'));
        if (nextBtn.evaluate().isEmpty) {
          break;
        }
        await tester.ensureVisible(nextBtn);
        await _settle(tester);
        await tester.tap(nextBtn);
        await _settle(tester);
        if (find.byKey(const ValueKey<String>('start-quiz-button')).evaluate().isNotEmpty) {
          break;
        }
      }

      expect(state.progress.quizHistory, isNotEmpty);
      expect(
        state.progress.quizHistory.first.scopeLabel,
        contains('أعرب ما تحته خط'),
      );
    });
  });
}
