import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:bayan/data/local/docx/exam_docx_builder.dart';
import 'package:bayan/data/local/question_pdf.dart';
import 'package:bayan/domain/models/library.dart';
import 'package:bayan/domain/models/progress.dart';
import 'package:bayan/domain/models/question_print_settings.dart';
import 'package:bayan/domain/services/question_print_plan.dart';
import 'package:bayan/presentation/state/exam_composer_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('exports all 4 official Word exam templates as valid RTL OOXML .docx', () async {
    final content = await loadTestContent();
    expect(content.examBank.officialTemplates.length, 4);

    for (final tpl in content.examBank.officialTemplates) {
      final paper = tpl.toExamPaper(
        schoolName: 'متوسطة الفراهيدي للبنين',
        directorate: 'المديرية العامة للتربية في بابل',
        teacherName: 'أحمد قاسم الأسدي',
      );
      expect(paper.totalDegree, 80);
      expect(paper.grammarBalanced, isTrue);
      expect(paper.orthographyBalanced, isTrue);

      final bytes = ExamDocxBuilder.build(paper);
      // Determinism check: second call produces identical byte array
      expect(ExamDocxBuilder.build(paper), equals(bytes));

      final archive = ZipDecoder().decodeBytes(bytes);
      final fileNames = archive.files.map((f) => f.name).toSet();
      expect(
        fileNames,
        containsAll(<String>[
          '[Content_Types].xml',
          '_rels/.rels',
          'word/document.xml',
          'word/styles.xml',
          'word/settings.xml',
          'word/fontTable.xml',
          'word/numbering.xml',
          'docProps/core.xml',
          'docProps/app.xml',
        ]),
      );

      // Parse every XML part strictly
      for (final file in archive.files) {
        if (file.name.endsWith('.xml') || file.name.endsWith('.rels')) {
          final xmlStr = utf8.decode(file.content as List<int>);
          expect(() => XmlDocument.parse(xmlStr), returnsNormally);
        }
      }

      final docFile = archive.findFile('word/document.xml')!;
      final docXml = XmlDocument.parse(utf8.decode(docFile.content as List<int>));

      // Verify A4 dimensions & 720 dxa margins + RTL bidi section
      final pgSz = docXml.findAllElements('w:pgSz').single;
      expect(pgSz.getAttribute('w:w'), '11906');
      expect(pgSz.getAttribute('w:h'), '16838');

      final pgMar = docXml.findAllElements('w:pgMar').single;
      expect(pgMar.getAttribute('w:top'), '720');
      expect(pgMar.getAttribute('w:right'), '720');
      expect(pgMar.getAttribute('w:left'), '720');

      expect(docXml.findAllElements('w:bidiVisual'), isNotEmpty);
      expect(docXml.findAllElements('w:rtlGutter'), isNotEmpty);

      // Degree badges end at the left margin: an *end* tab (logical `right`
      // in a bidi paragraph) at printableWidth = 10466 dxa.
      final badgeTabs = docXml
          .findAllElements('w:tab')
          .where((el) => el.getAttribute('w:pos') == '10466');
      expect(badgeTabs, isNotEmpty);
      expect(badgeTabs.every((el) => el.getAttribute('w:val') == 'right'), isTrue);

      // Verify underlined words emit <w:u w:val="single"/> and zero stray '_'
      final uRuns = docXml
          .findAllElements('w:u')
          .where((el) => el.getAttribute('w:val') == 'single');
      expect(uRuns.length, greaterThan(3));

      final fullPlain = docXml
          .findAllElements('w:t')
          .map((e) => e.innerText)
          .join(' ');
      expect(fullPlain.contains('_'), isFalse);
      expect(fullPlain, contains('متوسطة الفراهيدي للبنين'));
      expect(fullPlain, contains('أحمد قاسم الأسدي'));
      expect(fullPlain, contains('الانشاء :'));
      expect(fullPlain, contains('قواعد اللغة العربية :'));
      expect(fullPlain, contains('الاملاء :'));
    }
  });

  test('smart exam generator builds balanced 80-mark papers for part1, part2, and both', () async {
    final content = await loadTestContent();
    final ctrl = ExamComposerController(
      examBank: content.examBank,
      teacherProfile: const TeacherProfile(
        teacherName: 'علي حسين',
        schoolName: 'ثانوية الحلة',
      ),
      activePart: CurriculumPart.part1,
    );

    for (final scope in <String>['part1', 'part2', 'both']) {
      ctrl.generateBalancedExam(scope: scope);
      expect(ctrl.paper.totalDegree, 80);
      expect(ctrl.paper.grammarBalanced, isTrue);
      expect(ctrl.paper.orthographyBalanced, isTrue);
      final bytes = ExamDocxBuilder.build(ctrl.paper);
      expect(bytes.length, greaterThan(4000));
    }
  });

  test('QuestionPrinter generates valid multi-page A4 PDF bytes', () async {
    final content = await loadTestContent();
    final p1Units = content.library.unitsForPart(CurriculumPart.part1);
    final selected = <String>{p1Units.first.id, p1Units[1].id};
    final plan = QuestionPrintPlan.fromSelection(p1Units, selected);
    expect(plan.questionCount, 24);
    expect(plan.settings.compactLines, isFalse);
    expect(plan.settings.pdfLineSpacing, 4);
    expect(plan.settings.pdfItemGap, 8);
    expect(plan.settings.pdfHeadingGap, 10);

    final pdfBytes = await QuestionPrinter.buildPdfBytes(
      plan,
      'الجزء الأول',
      bundle: DiskAssetBundle(),
    );
    expect(pdfBytes.length, greaterThan(5000));
    expect(String.fromCharCodes(pdfBytes.take(5)), '%PDF-');

    final compactPlan = QuestionPrintPlan.fromSelection(
      p1Units,
      selected,
      settings: const QuestionPrintSettings(
        font: QuestionPrintFont.amiri,
        bodyFontSize: 11,
        headingFontSize: 14,
        compactLines: true,
      ),
    );
    expect(compactPlan.settings.compactLines, isTrue);
    expect(compactPlan.settings.pdfLineSpacing, 1.5);
    expect(compactPlan.settings.pdfItemGap, 3);
    expect(compactPlan.settings.pdfHeadingGap, 6);
    final compactBytes = await QuestionPrinter.buildPdfBytes(
      compactPlan,
      'الجزء الأول',
      bundle: DiskAssetBundle(),
    );
    expect(compactBytes.length, greaterThan(5000));
    expect(String.fromCharCodes(compactBytes.take(5)), '%PDF-');
  });

  test('StudentSummaryPlan and buildSummaryPdfBytes generate bold-topic summary PDF', () async {
    final content = await loadTestContent();
    final p1Units = content.library.unitsForPart(CurriculumPart.part1);
    final selected = <String>{p1Units.first.id, p1Units[1].id};

    // Lesson-backed summary plan
    final summaryPlan = StudentSummaryPlan.fromSelection(
      p1Units,
      selected,
      lessons: content.library.lessons,
      settings: const QuestionPrintSettings(
        font: QuestionPrintFont.cairo,
        bodyFontSize: 12,
        headingFontSize: 15,
        compactLines: true,
      ),
    );
    expect(summaryPlan.isEmpty, isFalse);
    expect(summaryPlan.units, hasLength(2));
    expect(summaryPlan.topicCount, greaterThanOrEqualTo(6));
    expect(summaryPlan.lineCount, greaterThan(10));
    for (final su in summaryPlan.units) {
      expect(su.lessonTitle.trim(), isNotEmpty);
      expect(su.topics, isNotEmpty);
      for (final topic in su.topics) {
        expect(topic.heading.trim(), isNotEmpty);
      }
    }

    final summaryPdf = await QuestionPrinter.buildSummaryPdfBytes(
      summaryPlan,
      'الجزء الأول',
      bundle: DiskAssetBundle(),
    );
    expect(summaryPdf.length, greaterThan(5000));
    expect(String.fromCharCodes(summaryPdf.take(5)), '%PDF-');

    // Fallback when lessons list is omitted: derives topics directly from Unit.topics
    final fallbackPlan = StudentSummaryPlan.fromSelection(
      p1Units,
      <String>{p1Units.first.id},
    );
    expect(fallbackPlan.units, hasLength(1));
    expect(fallbackPlan.topicCount, greaterThan(0));
    expect(fallbackPlan.lineCount, greaterThan(0));
    final fallbackPdf = await QuestionPrinter.buildSummaryPdfBytes(
      fallbackPlan,
      'الجزء الأول',
      bundle: DiskAssetBundle(),
    );
    expect(String.fromCharCodes(fallbackPdf.take(5)), '%PDF-');
  });
}
