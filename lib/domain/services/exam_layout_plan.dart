import '../../core/utils/arabic_text.dart';
import '../models/exam_paper.dart';

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
