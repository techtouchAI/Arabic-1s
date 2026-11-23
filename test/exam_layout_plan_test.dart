import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:bayan/core/utils/arabic_text.dart';
import 'package:bayan/data/local/docx/exam_docx_builder.dart';
import 'package:bayan/domain/models/exam_paper.dart';
import 'package:bayan/domain/models/library.dart';
import 'package:bayan/domain/models/progress.dart';
import 'package:bayan/domain/services/exam_layout_plan.dart';
import 'package:bayan/presentation/state/exam_composer_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'test_harness.dart';

XmlDocument document(ArabicExamPaper paper) {
  final zip = ZipDecoder().decodeBytes(ExamDocxBuilder.build(paper));
  return XmlDocument.parse(utf8.decode(
    zip.findFile('word/document.xml')!.content as List<int>,
  ));
}

String paragraphText(XmlElement paragraph) => paragraph.descendants
    .whereType<XmlElement>()
    .where((e) => e.name.qualified == 'w:t' || e.name.qualified == 'w:br')
    .map((e) => e.name.qualified == 'w:br' ? '\n' : e.innerText)
    .join();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all source templates retain section/question/branch order and marks', () async {
    final content = await loadTestContent();
    for (final template in content.examBank.officialTemplates) {
      final paper = template.toExamPaper();
      final plan = ExamLayoutPlan.build(paper);
      expect(plan.first.text, startsWith('_الانشاء :_ اكتب'));
      expect(plan.first.degree, 30);
      expect(plan.where((p) => p.kind == ExamParagraphKind.heading)
          .map((p) => p.degree), <int>[30, 35, 15]);
      final grammarDegrees = paper.grammar.questions
          .map((q) => q.branches.map((b) => b.degree).toList()).toList();
      expect(grammarDegrees, template.part == 'part1'
          ? <List<int>>[<int>[6, 4], <int>[10], <int>[10, 5]]
          : <List<int>>[<int>[10, 5], <int>[6, 4], <int>[6, 4]]);
      expect(plan.where((p) => p.kind == ExamParagraphKind.prompt)
          .map((p) => p.text).where((t) => t.startsWith('س'))
          .map((t) => t.substring(0, 3)), <String>['س1/', 'س2/', 'س3/', 'س1/']);
    }
  });

  test('every planned paragraph exports in order with exact configurable spacing', () async {
    final content = await loadTestContent();
    for (final template in content.examBank.officialTemplates) {
      for (final spacing in <ExamSpacing>[
        const ExamSpacing(),
        const ExamSpacing(lineHeight: 1.25, itemGapPt: 2.5,
            branchGapPt: 7, questionGapPt: 10),
        const ExamSpacing(lineHeight: 2, itemGapPt: 12,
            branchGapPt: 18, questionGapPt: 24),
      ]) {
        final paper = template.toExamPaper().copyWith(
          typography: ExamTypography(spacing: spacing),
        );
        final plan = ExamLayoutPlan.build(paper);
        final body = document(paper).findAllElements('w:body').single;
        final paragraphs = body.findElements('w:p').toList();
        // First direct paragraph is the student bar/divider, then all questions.
        final exported = paragraphs.skip(1).take(plan.length).toList();
        expect(exported.length, plan.length);
        for (var i = 0; i < plan.length; i++) {
          final source = plan[i];
          final actual = exported[i];
          final plain = parseUnderlinedSegments(source.text).map((s) => s.text).join();
          expect(paragraphText(actual), startsWith(plain));
          final xmlSpacing = actual.findAllElements('w:spacing').single;
          expect(xmlSpacing.getAttribute('w:before'), '${(source.spaceBeforePt * 20).round()}');
          expect(xmlSpacing.getAttribute('w:after'), '0');
          expect(xmlSpacing.getAttribute('w:line'), '${(spacing.lineHeight * 240).round()}');
          expect(xmlSpacing.getAttribute('w:lineRule'), 'auto');
          expect(actual.findAllElements('w:keepNext').isNotEmpty, source.keepWithNext);
          expect(actual.findAllElements('w:jc').single.getAttribute('w:val'), 'right');
          if (source.degree != null) {
            expect(paragraphText(actual), endsWith('( ${formatDegreeLabel(source.degree!, westernDigits: true)} )'));
          }
        }
      }
    }
  });

  test('blank items are skipped, numbering restarts, prose and XML escaping survive', () async {
    final content = await loadTestContent();
    final paper = content.examBank.officialTemplates.first.toExamPaper().copyWith(
      typography: const ExamTypography(useWesternDigits: false),
      grammar: const ExamQuestionSection(degree: 35, questions: <ExamQuestionBlock>[
        ExamQuestionBlock(number: 7, branches: <ExamBranch>[
          ExamBranch(branch: 'أ', prompt: 'نص < & >', degree: 35,
              items: <String>[' ', '_أول_\nتابع', '', 'ثان']),
          ExamBranch(branch: 'ب', prompt: 'نص متصل', degree: 0,
              itemLayout: ExamItemLayout.prose, items: <String>['سطر\nآخر']),
        ]),
      ]),
    );
    final plan = ExamLayoutPlan.build(paper);
    expect(plan.any((p) => p.text == '١- _أول_\nتابع'), isTrue);
    expect(plan.any((p) => p.text == '٢- ثان'), isTrue);
    expect(plan.any((p) => p.text.startsWith('س٧/ أ- نص < & >')), isTrue);
    final xml = document(paper);
    expect(xml.findAllElements('w:br'), isNotEmpty);
    expect(xml.findAllElements('w:t').any((e) => e.innerText.contains('نص < & >')), isTrue);
  });

  test('editable header cells and eight-point body are shared with Word', () async {
    final content = await loadTestContent();
    final paper = content.examBank.officialTemplates.first.toExamPaper().copyWith(
      header: const ExamHeader(
        showAdditionalHeaderLines: true,
        countryLine: 'الدولة المعدلة', ministryLine: '',
        examDate: '٢٠٢٦/١١/٢٣', noteLine: 'ملاحظة معدلة',
        academicYear: '٢٠٢٦',
      ),
      typography: const ExamTypography(bodySizePt: 8, headingSizePt: 9),
    );
    final cells = ExamHeaderLayout.build(paper);
    expect(cells[0], contains('الدولة المعدلة'));
    expect(cells[0], isNot(contains('')));
    expect(cells[1], contains('للعام الدراسي 2026'));
    expect(cells[2], contains('التاريخ : ٢٠٢٦/١١/٢٣'));
    final xml = document(paper);
    final tableCells = xml.findAllElements('w:tbl').first.findAllElements('w:tc').toList();
    for (var i = 0; i < cells.length; i++) {
      expect(tableCells[i].findAllElements('w:t').map((e) => e.innerText), cells[i]);
    }
    final body = xml.findAllElements('w:body').single;
    final paragraphs = body.findElements('w:p').toList();
    final plan = ExamLayoutPlan.build(paper);
    final promptIndex = plan.indexWhere((p) => p.kind == ExamParagraphKind.prompt);
    final prompt = paragraphs[promptIndex + 1];
    expect(prompt.findAllElements('w:sz').first.getAttribute('w:val'), '16');
    expect(prompt.findAllElements('w:szCs').first.getAttribute('w:val'), '16');
  });

  test('reference header has three ordered columns and editable student labels', () async {
    final content = await loadTestContent();
    final paper = content.examBank.officialTemplates.first.toExamPaper().copyWith(
      header: const ExamHeader(
        administrationLine: 'ادارة', schoolName: 'ثانوية الاعلام للبنين',
        examTitleLine: 'اسئلة امتحان نهاية السنة', academicYear: '2024-2025',
        roundLine: 'الدور الاول', subjectLine: 'المادة : اللغة العربية',
        gradeLine: 'الصف : الاول المتوسط', timeAllowed: 'الوقت : ساعة ونصف',
        studentNameLabel: 'اسم الطالب :', studentNumberLabel: 'الرقم الامتحاني :',
      ),
    );
    final cells = ExamHeaderLayout.build(paper);
    expect(cells, <List<String>>[
      <String>['ادارة', 'ثانوية الاعلام للبنين'],
      <String>['اسئلة امتحان نهاية السنة', 'للعام الدراسي 2024-2025', 'الدور الاول'],
      <String>['المادة : اللغة العربية', 'الصف : الاول المتوسط', 'الوقت : ساعة ونصف'],
    ]);
    final xml = document(paper);
    final tableCells = xml.findAllElements('w:tbl').first.findAllElements('w:tc').toList();
    for (var i = 0; i < cells.length; i++) {
      expect(tableCells[i].findAllElements('w:t').map((e) => e.innerText), cells[i]);
      expect(tableCells[i].findAllElements('w:vAlign').single.getAttribute('w:val'), 'top');
      expect(tableCells[i].findAllElements('w:b'), isEmpty);
      expect(tableCells[i].findAllElements('w:sz').first.getAttribute('w:val'), '28');
    }
    final firstParagraph = xml.findAllElements('w:body').single.findElements('w:p').first;
    expect(firstParagraph.findAllElements('w:t').map((e) => e.innerText),
        <String>['اسم الطالب :', 'الرقم الامتحاني :']);
    expect(firstParagraph.findAllElements('w:tab'), isNotEmpty);
    expect(firstParagraph.findAllElements('w:bottom'), isNotEmpty);
    final custom = paper.copyWith(header: paper.header.copyWith(
      administrationLine: 'إدارة معدّلة', studentNameLabel: 'اسم المتعلم :',
      studentNumberLabel: 'رقمه :', showAdditionalHeaderLines: true,
    ));
    expect(ExamHeaderLayout.build(custom)[0], contains('إدارة معدّلة'));
    expect(ExamHeaderLayout.build(custom)[0], contains(custom.header.directorateLine));
    final text = document(custom).findAllElements('w:t').map((e) => e.innerText);
    expect(text, containsAll(<String>['اسم المتعلم :', 'رقمه :']));
  });

  test('generation keeps source structure and spacing survives template switches', () async {
    final content = await loadTestContent();
    final controller = ExamComposerController(
      examBank: content.examBank,
      teacherProfile: const TeacherProfile(),
      activePart: CurriculumPart.part2,
    );
    addTearDown(controller.dispose);
    const spacing = ExamSpacing(lineHeight: 1.1, itemGapPt: 1, branchGapPt: 2, questionGapPt: 3);
    controller.updateTypography(controller.paper.typography.copyWith(spacing: spacing));
    for (final scope in <String>['part1', 'part2', 'both']) {
      for (var i = 0; i < 10; i++) {
        controller.generateBalancedExam(scope: scope);
        expect(controller.paper.typography.spacing, same(spacing));
        expect(controller.paper.grammarBalanced, isTrue);
        expect(controller.paper.orthographyBalanced, isTrue);
        expect(controller.paper.grammar.questions.map((q) => q.branches.map((b) => b.degree).toList()).toList(),
            scope == 'part1'
                ? <List<int>>[<int>[6, 4], <int>[10], <int>[10, 5]]
                : <List<int>>[<int>[10, 5], <int>[6, 4], <int>[6, 4]]);
      }
    }
    controller.updateHeader(controller.paper.header.copyWith(
      administrationLine: 'إدارة معدلة',
      includeStudentFields: true,
      studentNameLabel: 'اسم المتعلم',
      showAdditionalHeaderLines: true,
      noteLine: 'ملاحظة محفوظة',
    ));
    controller.loadOfficialTemplate(content.examBank.officialTemplates.first);
    expect(controller.paper.typography.spacing, same(spacing));
    expect(controller.paper.header.administrationLine, 'إدارة معدلة');
    expect(controller.paper.header.studentNameLabel, 'اسم المتعلم');
    expect(controller.paper.header.includeStudentFields, isTrue);
    expect(controller.paper.header.showAdditionalHeaderLines, isTrue);
    expect(controller.paper.header.noteLine, 'ملاحظة محفوظة');
    expect(() => const ExamSpacing().copyWith(lineHeight: 0), throwsAssertionError);
    expect(() => const ExamSpacing().copyWith(itemGapPt: -1), throwsAssertionError);
  });
}
