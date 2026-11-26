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

/// One body line inside a summary topic.
class SummaryLine {
  const SummaryLine({required this.text, this.isBullet = false});

  final String text;
  final bool isBullet;
}

/// One topic (موضوع) of a grammar summary: a bold heading plus its lines.
class SummaryTopic {
  const SummaryTopic({required this.heading, required this.lines});

  final String heading;
  final List<SummaryLine> lines;
}

/// Grammar summary of a single unit for the «ملخص فقط» print mode.
class StudentSummaryUnit {
  const StudentSummaryUnit({
    required this.unit,
    required this.lessonTitle,
    required this.summary,
    required this.topics,
  });

  final Unit unit;
  final String lessonTitle;
  final String summary;
  final List<SummaryTopic> topics;

  int get lineCount => topics.fold(0, (sum, topic) => sum + topic.lines.length);
}

/// «ملخص للطالب» plan: grammar summaries of the selected units, without
/// questions. Shares font, sizes and compact spacing with [QuestionPrintPlan].
class StudentSummaryPlan {
  const StudentSummaryPlan({required this.units, required this.settings});

  factory StudentSummaryPlan.fromSelection(
    List<Unit> availableUnits,
    Set<String> selectedUnitIds, {
    List<GrammarLesson> lessons = const <GrammarLesson>[],
    QuestionPrintSettings settings = const QuestionPrintSettings(),
  }) {
    final lessonsByUnit = <String, GrammarLesson>{
      for (final lesson in lessons) lesson.unitId: lesson,
    };
    final chosen = availableUnits
        .where((u) => selectedUnitIds.contains(u.id))
        .toList(growable: false);
    final summaryUnits = <StudentSummaryUnit>[];
    for (final unit in chosen) {
      final lesson = lessonsByUnit[unit.id];
      if (lesson != null) {
        summaryUnits.add(StudentSummaryUnit(
          unit: unit,
          lessonTitle: lesson.title,
          summary: lesson.summary,
          topics: _topicsFromLesson(lesson),
        ));
      } else {
        summaryUnits.add(StudentSummaryUnit(
          unit: unit,
          lessonTitle: unit.grammarTitle,
          summary: '',
          topics: _topicsFromUnit(unit),
        ));
      }
    }
    return StudentSummaryPlan(units: summaryUnits, settings: settings);
  }

  static List<SummaryTopic> _topicsFromLesson(GrammarLesson lesson) {
    final topics = <SummaryTopic>[];
    var heading = lesson.title;
    var lines = <SummaryLine>[];
    void flush() {
      if (lines.isNotEmpty) {
        topics.add(SummaryTopic(heading: heading, lines: List.of(lines)));
        lines = <SummaryLine>[];
      }
    }

    for (final plan in lesson.plans) {
      for (final block in plan.body) {
        if (block.kind == 'heading') {
          flush();
          heading = block.text;
        } else if (block.text.trim().isNotEmpty) {
          lines.add(SummaryLine(
            text: block.text,
            isBullet: block.kind == 'bullet',
          ));
        }
      }
    }
    flush();
    if (topics.isEmpty) {
      topics.add(SummaryTopic(heading: lesson.title, lines: const <SummaryLine>[]));
    }
    return List<SummaryTopic>.unmodifiable(topics);
  }

  static List<SummaryTopic> _topicsFromUnit(Unit unit) {
    final topics = <SummaryTopic>[];
    for (final topic in unit.topics) {
      final lines = <SummaryLine>[
        for (final bullet in topic.bullets)
          SummaryLine(text: bullet, isBullet: true),
        for (final item in topic.listItems)
          SummaryLine(text: item, isBullet: true),
        for (final pair in topic.taqwim)
          SummaryLine(text: 'قُلْ: «${pair.say}» — وَلا تَقُلْ: «${pair.dontSay}»'),
      ];
      if (lines.isNotEmpty) {
        topics.add(SummaryTopic(heading: topic.title, lines: lines));
      }
    }
    if (topics.isEmpty) {
      topics.add(
        SummaryTopic(heading: unit.grammarTitle, lines: const <SummaryLine>[]),
      );
    }
    return List<SummaryTopic>.unmodifiable(topics);
  }

  final List<StudentSummaryUnit> units;
  final QuestionPrintSettings settings;

  int get topicCount => units.fold(0, (sum, unit) => sum + unit.topics.length);

  int get lineCount => units.fold(0, (sum, unit) => sum + unit.lineCount);

  bool get isEmpty => units.isEmpty;
}
