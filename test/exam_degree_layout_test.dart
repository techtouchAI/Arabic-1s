import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:bayan/data/local/docx/exam_docx_builder.dart';
import 'package:bayan/domain/models/exam_paper.dart';
import 'package:bayan/domain/services/exam_layout_plan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'test_harness.dart';

/// Regression tests for the Word layout of degree badges and RTL paragraphs.
///
/// Word reads tabs, indents and alignment of a `w:bidi` paragraph logically:
/// `pos` is measured from the right margin, `left` = start, `right` = end. The
/// old flush-"left" tab at the full text width therefore *started* the badge at
/// the left margin, so Word pushed `( 6 درجات )` onto the next line.
XmlDocument _document(ArabicExamPaper paper) {
  final zip = ZipDecoder().decodeBytes(ExamDocxBuilder.build(paper));
  return XmlDocument.parse(utf8.decode(
    zip.findFile('word/document.xml')!.content as List<int>,
  ));
}

List<XmlElement> _bodyParagraphs(XmlDocument xml) =>
    xml.findAllElements('w:body').single.findElements('w:p').toList();

XmlElement? _pPr(XmlElement paragraph) =>
    paragraph.getElement('w:pPr');

List<String> _childNames(XmlElement? element) => element == null
    ? const <String>[]
    : element.childElements.map((e) => e.name.qualified).toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every degree badge shares its question line and ends at the left margin', () async {
    final content = await loadTestContent();
    for (final template in content.examBank.officialTemplates) {
      for (final typography in <ExamTypography>[
        const ExamTypography(),
        const ExamTypography(bodySizePt: 8, headingSizePt: 9),
        const ExamTypography(bodySizePt: 18, headingSizePt: 19, useWesternDigits: false),
      ]) {
        final paper = template.toExamPaper().copyWith(typography: typography);
        final plan = ExamLayoutPlan.build(paper);
        final paragraphs = _bodyParagraphs(_document(paper)).skip(1).take(plan.length).toList();
        expect(paragraphs.length, plan.length);
        for (var i = 0; i < plan.length; i++) {
          final source = plan[i];
          final pPr = _pPr(paragraphs[i])!;
          final ind = pPr.getElement('w:ind');
          if (source.degree == null) {
            expect(pPr.getElement('w:tabs'), isNull);
            expect(ind?.getAttribute('w:right'), isNull);
            continue;
          }
          final badge = ExamDegreeBadge.text(
            source.degree!,
            westernDigits: typography.useWesternDigits,
          );
          final tabs = pPr.getElement('w:tabs')!.findElements('w:tab').toList();
          expect(tabs, hasLength(1));
          expect(tabs.single.getAttribute('w:val'), 'right', reason: 'end tab');
          expect(tabs.single.getAttribute('w:pos'), '${ExamDocxBuilder.printableWidthDxa}');

          // The end indent reserves the badge column so long prompts wrap first.
          final sizePt = source.kind == ExamParagraphKind.heading
              ? typography.headingSizePt
              : typography.bodySizePt;
          final reserved = int.parse(ind!.getAttribute('w:right')!);
          expect(reserved, (ExamDegreeBadge.columnWidthPt(badge, sizePt) * 20).ceil());
          expect(reserved, lessThan(ExamDocxBuilder.printableWidthDxa ~/ 3));

          // The prompt runs, one tab run, then the badge run — in one paragraph.
          final runs = paragraphs[i].findElements('w:r').toList();
          expect(runs[runs.length - 2].getElement('w:tab'), isNotNull);
          expect(runs.last.findElements('w:t').single.innerText, badge);
          expect(runs.where((r) => r.getElement('w:tab') != null), hasLength(1));
        }
      }
    }
  });

  test('paragraph alignment and indents use Word bidi (logical) semantics', () async {
    final content = await loadTestContent();
    final base = content.examBank.officialTemplates.first.toExamPaper();
    final paper = base.copyWith(
      header: base.header.copyWith(includeStudentFields: true),
    );
    final plan = ExamLayoutPlan.build(paper);
    final xml = _document(paper);
    final paragraphs = _bodyParagraphs(xml);

    // No full-width start tab survives anywhere (the reported bug).
    expect(
      xml.findAllElements('w:tab').where((t) =>
          t.getAttribute('w:val') == 'left' &&
          t.getAttribute('w:pos') == '${ExamDocxBuilder.printableWidthDxa}'),
      isEmpty,
    );

    for (var i = 0; i < plan.length; i++) {
      final pPr = _pPr(paragraphs[i + 1])!;
      expect(pPr.getElement('w:jc'), isNull, reason: 'start (right) is the bidi default');
      final ind = pPr.getElement('w:ind');
      final start = (plan[i].indentPt * 20).round();
      expect(ind?.getAttribute('w:left'), start > 0 ? '$start' : null,
          reason: '`w:left` is the start (right-hand) indent of a bidi paragraph');
    }

    // Student bar: the exam-number label starts at the page centre.
    final studentBar = paragraphs.first;
    final tab = _pPr(studentBar)!.getElement('w:tabs')!.getElement('w:tab')!;
    expect(tab.getAttribute('w:val'), 'left');
    expect(tab.getAttribute('w:pos'), '${ExamDocxBuilder.printableWidthDxa ~/ 2}');
    expect(_pPr(studentBar)!.getElement('w:jc'), isNull);
  });

  test('paragraph and run properties follow the OOXML schema order', () async {
    final content = await loadTestContent();
    const pPrOrder = <String>[
      'w:keepNext', 'w:keepLines', 'w:pBdr', 'w:tabs', 'w:bidi',
      'w:spacing', 'w:ind', 'w:jc',
    ];
    const rPrOrder = <String>[
      'w:rFonts', 'w:b', 'w:bCs', 'w:sz', 'w:szCs', 'w:u', 'w:rtl', 'w:lang',
    ];
    void expectOrdered(List<String> names, List<String> order) {
      final known = names.where(order.contains).map(order.indexOf).toList();
      final sorted = List<int>.of(known)..sort();
      expect(known, sorted, reason: names.join(', '));
    }

    for (final template in content.examBank.officialTemplates) {
      final xml = _document(template.toExamPaper());
      for (final pPr in xml.findAllElements('w:pPr')) {
        expectOrdered(_childNames(pPr), pPrOrder);
      }
      final underlined = xml.findAllElements('w:rPr')
          .where((rPr) => rPr.getElement('w:u') != null).toList();
      expect(underlined, isNotEmpty);
      for (final rPr in xml.findAllElements('w:rPr')) {
        expectOrdered(_childNames(rPr), rPrOrder);
      }
    }
  });

  test('badge text and reserved column are shared and scale with the font', () {
    expect(ExamDegreeBadge.text(6, westernDigits: true), '( 6 درجات )');
    expect(ExamDegreeBadge.text(30, westernDigits: false), '( ٣٠ درجة )');
    expect(ExamDegreeBadge.text(2, westernDigits: true), '( درجتان )');
    final badge = ExamDegreeBadge.text(10, westernDigits: true);
    expect(ExamDegreeBadge.columnWidthPt(badge, 28),
        ExamDegreeBadge.columnWidthPt(badge, 14) * 2);
    // Generous: at least 0.5 em per character, wider than the glyphs need.
    expect(ExamDegreeBadge.columnWidthPt(badge, 14), greaterThan(badge.length * 7));
  });
}
