import 'package:bayan/app.dart';
import 'package:bayan/data/local/exam_document_exporter.dart';
import 'package:bayan/domain/models/exam_paper.dart';
import 'package:bayan/presentation/screens/saved_exams_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_harness.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Finder _field(String label) => find.byWidgetPredicate((widget) =>
    widget is TextField && widget.decoration?.labelText == label);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home → composer edits are autosaved and listed in «أسئلتي المحفوظة»', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = createTestAppState();
    await tester.pumpWidget(BayanApp(state: state));
    await _settle(tester);

    final savedCard = find.byKey(const ValueKey<String>('open-saved-exams'));
    await tester.ensureVisible(savedCard);
    await _settle(tester);
    await tester.tap(savedCard);
    await _settle(tester);
    expect(find.text('لا توجد أسئلة محفوظة بعد'), findsOneWidget);

    // A new paper is created from the saved section; untouched, it is not stored.
    await tester.tap(find.byKey(const ValueKey<String>('saved-exams-new')));
    await _settle(tester);
    expect(find.byKey(const ValueKey<String>('autosave-idle')), findsOneWidget);
    expect(state.savedExams.isEmpty, isTrue);

    final prompt = _field('منطوق السؤال / الفرع').first;
    await tester.ensureVisible(prompt);
    await _settle(tester);
    await tester.enterText(prompt, 'عيّن أسماء الإشارة');
    await _settle(tester);
    expect(state.savedExams.papers, hasLength(1));
    expect(find.byKey(const ValueKey<String>('autosave-saved')), findsOneWidget);
    await tester.enterText(prompt, 'عيّن أسماء الإشارة والمشار إليه');
    await _settle(tester);
    final saved = state.savedExams.papers.single;
    expect(saved.revision, 2);
    expect(saved.paper.grammar.questions.first.branches.first.prompt,
        'عيّن أسماء الإشارة والمشار إليه');

    // Back in the saved section the paper is listed with its latest version.
    await tester.pageBack();
    await _settle(tester);
    expect(find.byKey(ValueKey<String>('saved-exam-${saved.id}')), findsOneWidget);
    expect(find.text(saved.displayTitle), findsOneWidget);
    expect(find.textContaining('النسخة ٢'), findsOneWidget);
  });

  testWidgets('saved papers reopen, export, rename and delete', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = createTestAppState();
    final template = state.examBank.officialTemplates.first;
    final record = state.savedExams.save(template.toExamPaper(
      schoolName: 'متوسطة الحلة للبنين',
    ));
    ArabicExamPaper? exported;

    await tester.pumpWidget(BayanApp(state: state));
    await _settle(tester);
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.push(MaterialPageRoute<void>(
      builder: (_) => SavedExamsScreen(
        onExport: (paper) async {
          exported = paper;
          return const ExportOutcome(
            kind: ExportOutcomeKind.savedToFile,
            filePath: '/tmp/saved.docx',
          );
        },
      ),
    ));
    await _settle(tester);

    Future<void> chooseAction(String label) async {
      await tester.tap(find.byKey(ValueKey<String>('saved-exam-menu-${record.id}')));
      await _settle(tester);
      await tester.tap(find.text(label).last);
      await _settle(tester);
    }

    // Reopen: the composer continues the same record.
    await tester.tap(find.text(record.displayTitle));
    await _settle(tester);
    final school = _field('اسم المدرسة');
    await tester.ensureVisible(school);
    await _settle(tester);
    expect(tester.widget<TextField>(school).controller!.text, 'متوسطة الحلة للبنين');
    await tester.enterText(school, 'متوسطة الفيحاء');
    await _settle(tester);
    expect(state.savedExams.papers, hasLength(1));
    expect(state.savedExams.byId(record.id)!.revision, 2);
    expect(state.savedExams.byId(record.id)!.paper.header.schoolName, 'متوسطة الفيحاء');
    await tester.pageBack();
    await _settle(tester);

    // Export straight from the list uses the saved version.
    await chooseAction('تصدير Word (.docx)');
    expect(exported!.header.schoolName, 'متوسطة الفيحاء');

    // Rename, then copy.
    await chooseAction('إعادة التسمية');
    await tester.enterText(
      find.byKey(const ValueKey<String>('saved-exam-title-field')),
      'امتحان الشعبة أ',
    );
    await tester.tap(find.byKey(const ValueKey<String>('saved-exam-title-save')));
    await _settle(tester);
    expect(find.text('امتحان الشعبة أ'), findsOneWidget);
    await chooseAction('إنشاء نسخة');
    expect(state.savedExams.papers, hasLength(2));
    expect(find.text('امتحان الشعبة أ (نسخة)'), findsOneWidget);

    // Delete asks for confirmation first.
    await chooseAction('حذف');
    await tester.tap(find.byKey(const ValueKey<String>('saved-exam-confirm-delete')));
    await _settle(tester);
    expect(state.savedExams.byId(record.id), isNull);
    expect(state.savedExams.papers, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
