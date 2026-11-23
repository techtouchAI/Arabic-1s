import 'package:bayan/app.dart';
import 'package:bayan/domain/models/exam_paper.dart';
import 'package:bayan/domain/models/library.dart';
import 'package:bayan/domain/models/progress.dart';
import 'package:bayan/domain/services/exam_bank_picker.dart';
import 'package:bayan/presentation/screens/exam_composer_screen.dart';
import 'package:bayan/presentation/state/exam_composer_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_harness.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

ExamBank _bank() => loadTestContentSync().examBank;

void main() {
  group('ExamBankPicker filtering', () {
    test('grammar items filter by part, style, unit and query', () {
      final bank = _bank();
      final part1 = ExamBankPicker.filterGrammarItems(bank, part: 'part1');
      expect(part1, isNotEmpty);
      expect(part1.every((e) => e.part == 'part1'), isTrue);

      final irab = ExamBankPicker.filterGrammarItems(bank, style: 'irab');
      expect(irab, isNotEmpty);
      expect(irab.every((e) => e.style == 'irab'), isTrue);

      final unit = ExamBankPicker.filterGrammarItems(bank, unitId: 'p1-u6');
      expect(unit, isNotEmpty);
      expect(unit.every((e) => e.unitId == 'p1-u6'), isTrue);

      final general =
          ExamBankPicker.filterGrammarItems(bank, unitId: '');
      expect(general, isNotEmpty);
      expect(general.every((e) => e.unitId.isEmpty), isTrue);

      final query = ExamBankPicker.filterGrammarItems(bank, query: 'التنوين');
      expect(query, isNotEmpty);
      expect(
        query.every((e) => e.text.contains('التنوين')),
        isTrue,
      );
    });

    test('orthography and composition filter by part, unit and query', () {
      final bank = _bank();
      final ortho = ExamBankPicker.filterOrthographyItems(
        bank,
        unitId: 'orthography-expression',
      );
      expect(ortho, hasLength(bank.orthographyItems.length));

      final comp = ExamBankPicker.filterCompositionTopics(
        bank,
        part: 'part2',
        unitId: 'p2-u2',
      );
      expect(comp.map((e) => e.id), contains('comp-p2-1'));

      final compQuery = ExamBankPicker.filterCompositionTopics(
        bank,
        query: 'الوطن',
      );
      expect(compQuery.map((e) => e.id), contains('comp-p1-5'));
    });

    test('unit questions flatten per-unit banks with kind filter', () {
      final library = loadTestContentSync().library;
      final all = ExamBankPicker.filterUnitQuestions(library);
      expect(all.length, greaterThan(50));
      expect(all.every((e) => e.unit.questions.contains(e.question)), isTrue);

      final part1 = ExamBankPicker.filterUnitQuestions(library, part: 'part1');
      expect(part1, isNotEmpty);
      expect(
        part1.every((e) => e.unit.part == 'part1' || e.unit.part == 'both'),
        isTrue,
      );

      final oneUnit = ExamBankPicker.filterUnitQuestions(
        library,
        unitId: 'p1-u1',
      );
      expect(oneUnit, hasLength(6));
      expect(oneUnit.every((e) => e.unit.id == 'p1-u1'), isTrue);

      final choices = ExamBankPicker.filterUnitQuestions(
        library,
        kind: QuestionKind.choice,
      );
      expect(choices, isNotEmpty);
      expect(
        choices.every((e) => e.question.kind == QuestionKind.choice),
        isTrue,
      );
    });

    test('inferGrammarStyle matches generator and picker', () {
      expect(ExamBankPicker.inferGrammarStyle('أعرب ما تحته خط :'), 'irab');
      expect(ExamBankPicker.inferGrammarStyle('اختر الإجابة الصحيحة :'), 'mcq');
      expect(ExamBankPicker.inferGrammarStyle('ما الفرق بين الجملتين :'), 'difference');
      expect(ExamBankPicker.inferGrammarStyle('أجب عما يأتي :'), isNull);
    });

    test('unitQuestionAsExamText formats choices like official Word items', () {
      const choice = Question(
        id: 'q1',
        kind: QuestionKind.choice,
        prompt: 'الفعل الأمر دائماً ما يكون',
        options: <String>['معرباً', 'مبنياً', 'مرفوعاً'],
        answerIndex: 1,
      );
      expect(
        ExamBankPicker.unitQuestionAsExamText(choice),
        'الفعل الأمر دائماً ما يكون ( معرباً – مبنياً – مرفوعاً )',
      );
      const tf = Question(
        id: 'q2',
        kind: QuestionKind.trueFalse,
        prompt: 'الكلام ثلاثة أقسام.',
        boolAnswer: true,
      );
      expect(
        ExamBankPicker.unitQuestionAsExamText(tf),
        'الكلام ثلاثة أقسام.',
      );
    });
  });

  group('ExamBank parsing', () {
    test('legacy JSON without unitId/title/defaultDegree still parses', () {
      final bank = ExamBank.fromJson(<String, dynamic>{
        'compositionTopics': <dynamic>[
          <String, dynamic>{'id': 'c1', 'part': 'part1', 'text': 'موضوع'},
        ],
        'grammarItems': <dynamic>[
          <String, dynamic>{
            'id': 'g1',
            'part': 'part1',
            'category': 'اختيارات',
            'text': 'سؤال',
          },
        ],
        'orthographyItems': <dynamic>[
          <String, dynamic>{
            'id': 'o1',
            'part': 'part1',
            'title': 'عنوان العرض',
            'prompt': 'ما التنوين؟',
            'items': <dynamic>[],
          },
        ],
        'officialTemplates': <dynamic>[],
      });
      expect(bank.compositionTopics.single.title, isEmpty);
      expect(bank.compositionTopics.single.unitId, isEmpty);
      expect(bank.grammarItems.single.defaultDegree, 5);
      expect(bank.grammarItems.single.unitId, isEmpty);
      // The display title must never leak into unitId (regression).
      expect(bank.orthographyItems.single.title, 'عنوان العرض');
      expect(bank.orthographyItems.single.unitId, isEmpty);
    });

    test('new JSON unitIds and titles are preserved', () {
      final bank = _bank();
      final grammar = bank.grammarItems.firstWhere((e) => e.id == 'gr-p1-1');
      expect(grammar.unitId, 'p1-u6');
      final ortho = bank.orthographyItems.firstWhere((e) => e.id == 'or-p1-1');
      expect(ortho.unitId, 'orthography-expression');
      expect(ortho.title, isNotEmpty);
      final comp = bank.compositionTopics.firstWhere((e) => e.id == 'comp-p1-1');
      expect(comp.unitId, 'p1-u2');
      expect(comp.title, isNotEmpty);
    });
  });

  group('ExamComposerController bank application', () {
    ExamComposerController controller() => ExamComposerController(
          examBank: _bank(),
          teacherProfile: const TeacherProfile(),
          activePart: CurriculumPart.part1,
        );

    test('replaceBranchFromBank keeps the branch letter', () {
      final ctrl = controller();
      final before = ctrl.paper.grammar.questions.first.branches.first;
      ctrl.replaceBranchFromBank(
        isGrammar: true,
        questionIndex: 0,
        branchIndex: 0,
        prompt: 'منطوق من البنك',
        degree: 7,
        items: const <String>['نقطة بنكية'],
        itemLayout: ExamItemLayout.inline,
      );
      final after = ctrl.paper.grammar.questions.first.branches.first;
      expect(after.branch, before.branch);
      expect(after.prompt, 'منطوق من البنك');
      expect(after.degree, 7);
      expect(after.items, <String>['نقطة بنكية']);
      expect(after.itemLayout, ExamItemLayout.inline);
    });

    test('addBranchFromBank appends to the chosen question only', () {
      final ctrl = controller();
      final q0Count = ctrl.paper.orthography.questions[0].branches.length;
      ctrl.addBranchFromBank(
        isGrammar: false,
        questionIndex: 0,
        prompt: 'فرع إملاء من البنك',
        degree: 5,
        items: const <String>[],
        itemLayout: ExamItemLayout.vertical,
      );
      expect(
        ctrl.paper.orthography.questions[0].branches.length,
        q0Count + 1,
      );
      expect(
        ctrl.paper.orthography.questions[0].branches.last.prompt,
        'فرع إملاء من البنك',
      );
    });

    test('addQuestionFromBank appends a new question block', () {
      final ctrl = controller();
      final before = ctrl.paper.grammar.questions.length;
      ctrl.addQuestionFromBank(
        isGrammar: true,
        prompt: 'سؤال جديد من البنك',
        degree: 5,
        items: const <String>['نقطة'],
        itemLayout: ExamItemLayout.vertical,
      );
      expect(ctrl.paper.grammar.questions.length, before + 1);
      expect(
        ctrl.paper.grammar.questions.last.branches.single.prompt,
        'سؤال جديد من البنك',
      );
    });

    test('composition topics add and replace', () {
      final ctrl = controller();
      final before = ctrl.paper.composition.topics.length;
      ctrl.addCompositionTopic('موضوع جديد');
      expect(ctrl.paper.composition.topics.length, before + 1);
      ctrl.replaceCompositionTopic(0, 'موضوع مستبدل');
      expect(ctrl.paper.composition.topics.first, 'موضوع مستبدل');
    });
  });

  testWidgets('A4 preview zooms with buttons and opens full screen', (
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
      MaterialPageRoute<void>(
        builder: (_) => const ExamComposerScreen(),
      ),
    );
    await _settle(tester);

    await tester.tap(find.text('معاينة ورقة A4'));
    await _settle(tester);

    expect(find.byKey(const ValueKey<String>('preview-viewer')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('preview-zoom-in')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('preview-zoom-out')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('preview-zoom-fit')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('preview-zoom-reset')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('preview-fullscreen')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey<String>('preview-zoom-label'))).data,
      '١٠٠٪',
    );

    await tester.tap(find.byKey(const ValueKey<String>('preview-zoom-in')));
    await _settle(tester);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey<String>('preview-zoom-label'))).data,
      '١٢٥٪',
    );

    await tester.tap(find.byKey(const ValueKey<String>('preview-zoom-out')));
    await _settle(tester);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey<String>('preview-zoom-label'))).data,
      '١٠٠٪',
    );

    await tester.tap(find.byKey(const ValueKey<String>('preview-zoom-in')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey<String>('preview-zoom-reset')));
    await _settle(tester);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey<String>('preview-zoom-label'))).data,
      '١٠٠٪',
    );

    await tester.tap(find.byKey(const ValueKey<String>('preview-fullscreen')));
    await _settle(tester);
    expect(
      find.byKey(const ValueKey<String>('preview-fullscreen-viewer')),
      findsOneWidget,
    );
    await tester.tap(find.byIcon(Icons.close));
    await _settle(tester);
    expect(
      find.byKey(const ValueKey<String>('preview-fullscreen-viewer')),
      findsNothing,
    );
  });

  testWidgets('every branch and topic offers its own bank picker', (
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
      MaterialPageRoute<void>(
        builder: (_) => const ExamComposerScreen(),
      ),
    );
    await _settle(tester);

    // Each composition topic can be replaced from its bank.
    expect(
      find.byKey(const ValueKey<String>('composition-replace-0')),
      findsOneWidget,
    );

    // Grammar branches and orthography branches each own a bank button.
    // (The editor is a lazy ListView, so scroll until they are built.)
    final grammarButton =
        find.byKey(const ValueKey<String>('branch-bank-grammar')).first;
    await tester.scrollUntilVisible(grammarButton, 300);
    await _settle(tester);
    expect(
      find.byKey(const ValueKey<String>('branch-bank-grammar')),
      findsWidgets,
    );
    final orthoButton =
        find.byKey(const ValueKey<String>('branch-bank-ortho')).first;
    await tester.scrollUntilVisible(orthoButton, 300);
    await _settle(tester);
    expect(
      find.byKey(const ValueKey<String>('branch-bank-ortho')),
      findsWidgets,
    );

    // Open the grammar bank picker: searchable, filterable, free choice.
    await tester.scrollUntilVisible(grammarButton, 300);
    await _settle(tester);
    await tester.tap(grammarButton);
    await _settle(tester);
    expect(find.byKey(const ValueKey<String>('bank-search')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('bank-unit-filter')), findsOneWidget);
    expect(find.text('إضافة كنقطة'), findsOneWidget);
    expect(find.text('استبدال الفرع'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('bank-search')),
      'التنوين',
    );
    await _settle(tester);
    expect(find.byType(ListTile), findsWidgets);

    // Pick the first result: the sheet closes and the branch gains a point.
    await tester.tap(find.byType(ListTile).first);
    await _settle(tester);
    expect(find.byKey(const ValueKey<String>('bank-search')), findsNothing);
  });
}
