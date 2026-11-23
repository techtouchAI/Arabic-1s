import '../../core/utils/arabic_text.dart';
import '../models/exam_paper.dart';

/// Header cells in logical right-to-left order, shared by Word and preview.
class ExamHeaderLayout {
  const ExamHeaderLayout._();

  static const int fontSizePt = 14;
  static const List<int> columnWidthsDxa = <int>[3316, 3834, 3316];

  static List<List<String>> build(ArabicExamPaper paper) {
    final h = paper.header;
    final westernYear = toWesternDigits(h.academicYear.trim());
    final year = paper.typography.useWesternDigits
        ? westernYear
        : toArabicDigits(westernYear);
    return <List<String>>[
      <String>[
        h.administrationLine,
        if (h.showAdditionalHeaderLines) ...<String>[
          h.countryLine, h.ministryLine, h.directorateLine,
        ],
        h.schoolName,
      ],
      <String>[
        h.examTitleLine,
        if (year.isNotEmpty) 'للعام الدراسي $year',
        h.roundLine,
      ],
      <String>[
        h.subjectLine, h.gradeLine, h.timeAllowed,
        if (h.showAdditionalHeaderLines && h.examDate.trim().isNotEmpty)
          'التاريخ : ${h.examDate.trim()}',
        if (h.showAdditionalHeaderLines) h.noteLine,
      ],
    ].map((lines) => lines.where((line) => line.trim().isNotEmpty)
        .toList(growable: false)).toList(growable: false);
  }
}

/// Degree badge text and the end-side column reserved for it, shared by the
/// Word builder and the live preview so both wrap a question identically.
abstract final class ExamDegreeBadge {
  static String text(int degree, {required bool westernDigits}) =>
      '( ${formatDegreeLabel(degree, westernDigits: westernDigits)} )';

  /// Width, in points, reserved at the end (left) of a question line. It is a
  /// deliberately generous estimate — half an em per character plus a one-em
  /// gutter, while Arabic letters and digits average under 0.4 em — because
  /// neither renderer may rely on installed font metrics. Overestimating only
  /// wraps a long prompt slightly earlier; underestimating would let the badge
  /// fall onto a line of its own.
  static double columnWidthPt(String badge, num fontSizePt) =>
      (badge.runes.length * 0.5 + 1) * fontSizePt;
}

enum ExamParagraphKind { heading, prompt, item }

/// Renderer-neutral, ordered exam content shared by Word and the live preview.
class ExamLayoutParagraph {
  const ExamLayoutParagraph({
    required this.text,
    required this.kind,
    required this.spaceBeforePt,
    this.degree,
    this.indentPt = 0,
    this.keepWithNext = false,
  });

  final String text;
  final ExamParagraphKind kind;
  final double spaceBeforePt;
  final int? degree;
  final double indentPt;
  final bool keepWithNext;
}

class ExamLayoutPlan {
  const ExamLayoutPlan._();

  static List<ExamLayoutParagraph> build(ArabicExamPaper paper) {
    final result = <ExamLayoutParagraph>[];
    final spacing = paper.typography.spacing;
    String digits(Object value) => paper.typography.useWesternDigits
        ? toWesternDigits('$value')
        : toArabicDigits(value);
    List<String> clean(List<String> items) => items
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);

    void heading(String text, int degree) {
      result.add(ExamLayoutParagraph(
        text: text,
        kind: ExamParagraphKind.heading,
        degree: degree,
        spaceBeforePt: spacing.questionGapPt,
        keepWithNext: true,
      ));
    }

    void item(String text, {double indent = 12}) {
      result.add(ExamLayoutParagraph(
        text: text,
        kind: ExamParagraphKind.item,
        spaceBeforePt: spacing.itemGapPt,
        indentPt: indent,
      ));
    }

    final compositionPrompt = paper.composition.prompt.trim();
    heading('_الانشاء :_${compositionPrompt.isEmpty ? '' : ' $compositionPrompt'}',
        paper.composition.degree);
    final topics = clean(paper.composition.topics);
    for (var i = 0; i < topics.length; i++) {
      item('${digits(i + 1)}- ${topics[i]}', indent: 0);
    }

    void section(ExamQuestionSection section) {
      for (final question in section.questions) {
        for (var bi = 0; bi < question.branches.length; bi++) {
          final branch = question.branches[bi];
          final letter = branch.branch.trim();
          final prefix = '${bi == 0 ? 'س${digits(question.number)}/ ' : ''}'
              '${letter.isEmpty ? '' : '$letter- '}';
          final items = clean(branch.items);
          result.add(ExamLayoutParagraph(
            text: '$prefix${branch.prompt.trim()}',
            kind: ExamParagraphKind.prompt,
            degree: branch.degree,
            spaceBeforePt: bi == 0
                ? spacing.questionGapPt
                : spacing.branchGapPt,
            keepWithNext: items.isNotEmpty,
          ));
          switch (branch.itemLayout) {
            case ExamItemLayout.vertical:
              for (var i = 0; i < items.length; i++) {
                item('${digits(i + 1)}- ${items[i]}');
              }
            case ExamItemLayout.inline:
              if (items.isNotEmpty) {
                item(<String>[
                  for (var i = 0; i < items.length; i++)
                    '${digits(i + 1)}- ${items[i]}',
                ].join('    '));
              }
            case ExamItemLayout.prose:
              if (items.isNotEmpty) item(items.join('\n'));
          }
        }
      }
    }

    heading('_قواعد اللغة العربية :_', paper.grammar.degree);
    section(paper.grammar);
    heading('_الاملاء :_', paper.orthography.degree);
    section(paper.orthography);
    return List<ExamLayoutParagraph>.unmodifiable(result);
  }
}
