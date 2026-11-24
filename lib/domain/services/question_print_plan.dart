import '../models/library.dart';
import '../models/question_print_settings.dart';

/// Filters units that contain printable self-test / exam questions.
List<Unit> printableUnits(Iterable<Unit> units) =>
    units.where((unit) => unit.questions.isNotEmpty).toList(growable: false);

/// One grouped official exam-style section inside a [QuestionPrintPlan].
class QuestionPrintSection {
  const QuestionPrintSection({
    required this.id,
    required this.heading,
    required this.questions,
  });

  final String id;
  final String heading;
  final List<Question> questions;
}

class QuestionPrintPlan {
  const QuestionPrintPlan({
    required this.units,
    required this.trueFalseQuestions,
    required this.choiceQuestions,
    required this.openQuestions,
    required this.sections,
    required this.settings,
  });

  static const List<(String, String, Set<String>)> _officialGroupDefs =
      <(String, String, Set<String>)>[
        (
          'apply_group',
          'أسئلة التطبيق والاستخراج (أجب عمّا يأتي)',
          <String>{'apply', 'ishara', 'extract', 'five_verbs'},
        ),
        (
          'irab',
          'أسئلة الإعراب (أعرب ما تحته خط)',
          <String>{'irab'},
        ),
        (
          'murab_mabni',
          'أسئلة المعرب والمبني (ميّز بين المعرب والمبني فيما تحته خط)',
          <String>{'murab_mabni'},
        ),
        (
          'difference',
          'أسئلة بيان الفرق بين الجملتين المتقابلتين',
          <String>{'difference'},
        ),
        (
          'mcq',
          'أسئلة الاختيارات (اختر الإجابة الصحيحة من بين الأقواس)',
          <String>{'mcq'},
        ),
        (
          'ortho',
          'أسئلة الإملاء الرسمي',
          <String>{'ortho'},
        ),
      ];

  static const List<String> arabicOrdinals = <String>[
    'أولاً',
    'ثانياً',
    'ثالثاً',
    'رابعاً',
    'خامساً',
    'سادساً',
    'سابعاً',
  ];

  factory QuestionPrintPlan.fromSelection(
    List<Unit> availableUnits,
    Set<String> selectedUnitIds, {
    Set<String>? allowedExamStyles,
    QuestionPrintSettings settings = const QuestionPrintSettings(),
  }) {
    final chosen = availableUnits
        .where((u) => selectedUnitIds.contains(u.id) && u.questions.isNotEmpty)
        .toList(growable: false);
    final tf = <Question>[];
    final choice = <Question>[];
    final open = <Question>[];
    final allFiltered = <Question>[];
    for (final unit in chosen) {
      for (final q in unit.questions) {
        if (allowedExamStyles != null &&
            !allowedExamStyles.contains(q.effectiveExamStyle)) {
          continue;
        }
        allFiltered.add(q);
        switch (q.kind) {
          case QuestionKind.trueFalse:
            tf.add(q);
          case QuestionKind.choice:
            choice.add(q);
          case QuestionKind.open:
            open.add(q);
        }
      }
    }

    final sections = <QuestionPrintSection>[];
    final assignedIds = <String>{};
    for (final def in _officialGroupDefs) {
      final items = allFiltered
          .where((q) => def.$3.contains(q.effectiveExamStyle))
          .toList(growable: false);
      if (items.isNotEmpty) {
        final ordinal = sections.length < arabicOrdinals.length
            ? arabicOrdinals[sections.length]
            : 'القسم ${sections.length + 1}';
        sections.add(
          QuestionPrintSection(
            id: def.$1,
            heading: '$ordinal: ${def.$2}',
            questions: items,
          ),
        );
        for (final q in items) {
          assignedIds.add(q.id);
        }
      }
    }
    final remaining = allFiltered
        .where((q) => !assignedIds.contains(q.id))
        .toList(growable: false);
    if (remaining.isNotEmpty) {
      final ordinal = sections.length < arabicOrdinals.length
          ? arabicOrdinals[sections.length]
          : 'القسم ${sections.length + 1}';
      sections.add(
        QuestionPrintSection(
          id: 'other',
          heading: '$ordinal: أسئلة إضافية',
          questions: remaining,
        ),
      );
    }

    return QuestionPrintPlan(
      units: chosen,
      trueFalseQuestions: tf,
      choiceQuestions: choice,
      openQuestions: open,
      sections: sections,
      settings: settings,
    );
  }

  final List<Unit> units;
  final List<Question> trueFalseQuestions;
  final List<Question> choiceQuestions;
  final List<Question> openQuestions;
  final List<QuestionPrintSection> sections;
  final QuestionPrintSettings settings;

  int get questionCount =>
      trueFalseQuestions.length + choiceQuestions.length + openQuestions.length;

  bool get isEmpty => questionCount == 0;
}
