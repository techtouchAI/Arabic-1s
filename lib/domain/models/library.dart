/// Immutable curriculum models parsed from `assets/content/*.json`.
library;

/// Active semester/book part selected by the teacher or student.
enum CurriculumPart {
  part1('part1', 'الجزء الأول', 'الفصل الدراسي الأول • ١٠ وحدات'),
  part2('part2', 'الجزء الثاني', 'الفصل الدراسي الثاني • ٩ وحدات');

  const CurriculumPart(this.id, this.title, this.subtitle);

  final String id;
  final String title;
  final String subtitle;

  static CurriculumPart? fromId(String? raw) {
    for (final value in CurriculumPart.values) {
      if (value.id == raw) {
        return value;
      }
    }
    return null;
  }
}

class StudyLibrary {
  const StudyLibrary({
    required this.title,
    required this.subtitle,
    required this.sections,
    required this.units,
    required this.lessons,
    required this.glossary,
  });

  final String title;
  final String subtitle;
  final List<SectionMeta> sections;
  final List<Unit> units;
  final List<GrammarLesson> lessons;
  final List<GlossaryTerm> glossary;

  Unit? unitById(String id) {
    for (final unit in units) {
      if (unit.id == id) {
        return unit;
      }
    }
    return null;
  }

  GrammarLesson? lessonById(String id) {
    for (final lesson in lessons) {
      if (lesson.id == id) {
        return lesson;
      }
    }
    return null;
  }

  List<Unit> unitsForPart(CurriculumPart part) =>
      units.where((unit) => unit.sectionId == part.id).toList(growable: false)
        ..sort((a, b) => a.order.compareTo(b.order));

  List<GrammarLesson> lessonsForPart(CurriculumPart part) =>
      lessons.where((lesson) => lesson.part == part.id).toList(growable: false)
        ..sort((a, b) => a.order.compareTo(b.order));

  List<GlossaryTerm> glossaryForPart(CurriculumPart part) =>
      glossary.where((term) => term.part == part.id).toList(growable: false);
}

class SectionMeta {
  const SectionMeta({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.kind,
  });

  factory SectionMeta.fromJson(Map<String, dynamic> json) => SectionMeta(
        id: json['id'] as String,
        title: json['title'] as String,
        subtitle: (json['subtitle'] as String?) ?? '',
        kind: json['kind'] as String,
      );

  final String id;
  final String title;
  final String subtitle;
  final String kind;
}

class FigureLegend {
  const FigureLegend({required this.label, required this.color});

  factory FigureLegend.fromJson(Map<String, dynamic> json) => FigureLegend(
        label: json['label'] as String,
        color: json['color'] as String,
      );

  final String label;
  final String color;
}

class Figure {
  const Figure({
    required this.asset,
    required this.caption,
    required this.legend,
  });

  factory Figure.fromJson(Map<String, dynamic> json) => Figure(
        asset: json['asset'] as String,
        caption: json['caption'] as String,
        legend: ((json['legend'] as List<dynamic>?) ?? const <dynamic>[])
            .map((item) => FigureLegend.fromJson(item as Map<String, dynamic>))
            .toList(growable: false),
      );

  final String asset;
  final String caption;
  final List<FigureLegend> legend;
}

class TaqwimPair {
  const TaqwimPair({required this.say, required this.dontSay});

  factory TaqwimPair.fromJson(Map<String, dynamic> json) => TaqwimPair(
        say: json['say'] as String,
        dontSay: json['dontSay'] as String,
      );

  final String say;
  final String dontSay;
}

class Topic {
  const Topic({
    required this.id,
    required this.title,
    required this.category,
    required this.lessonBadge,
    required this.kind,
    required this.bullets,
    required this.listTitle,
    required this.listItems,
    required this.taqwim,
  });

  factory Topic.fromJson(Map<String, dynamic> json) => Topic(
        id: json['id'] as String,
        title: json['title'] as String,
        category: (json['category'] as String?) ?? 'reading',
        lessonBadge: (json['lessonBadge'] as String?) ?? '',
        kind: (json['kind'] as String?) ?? 'prose',
        bullets: ((json['bullets'] as List<dynamic>?) ?? const <dynamic>[])
            .map((item) => item as String)
            .toList(growable: false),
        listTitle: json['listTitle'] as String?,
        listItems: ((json['listItems'] as List<dynamic>?) ?? const <dynamic>[])
            .map((item) => item as String)
            .toList(growable: false),
        taqwim: ((json['taqwim'] as List<dynamic>?) ?? const <dynamic>[])
            .map((item) => TaqwimPair.fromJson(item as Map<String, dynamic>))
            .toList(growable: false),
      );

  final String id;
  final String title;
  final String category; // opener | reading | grammar | orthography | expression | evaluative
  final String lessonBadge;
  final String kind; // prose | poetry | rules | exercises | list
  final List<String> bullets;
  final String? listTitle;
  final List<String> listItems;
  final List<TaqwimPair> taqwim;
}

enum QuestionKind {
  trueFalse,
  choice,
  open;

  static QuestionKind fromRaw(String raw) {
    switch (raw) {
      case 'trueFalse':
        return QuestionKind.trueFalse;
      case 'choice':
        return QuestionKind.choice;
      case 'open':
      default:
        return QuestionKind.open;
    }
  }
}

class Question {
  const Question({
    required this.id,
    required this.kind,
    required this.prompt,
    this.boolAnswer,
    this.options = const <String>[],
    this.answerIndex,
    this.textAnswer,
    this.answerSupport,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    final kind = QuestionKind.fromRaw(json['kind'] as String);
    return Question(
      id: json['id'] as String,
      kind: kind,
      prompt: json['prompt'] as String,
      boolAnswer: kind == QuestionKind.trueFalse ? json['answer'] as bool? : null,
      options: ((json['options'] as List<dynamic>?) ?? const <dynamic>[])
          .map((item) => item as String)
          .toList(growable: false),
      answerIndex: json['answerIndex'] as int?,
      textAnswer: kind == QuestionKind.open ? json['answer'] as String? : null,
      answerSupport: json['answerSupport'] as String?,
    );
  }

  final String id;
  final QuestionKind kind;
  final String prompt;
  final bool? boolAnswer;
  final List<String> options;
  final int? answerIndex;
  final String? textAnswer;
  final String? answerSupport;

  String get displayAnswer {
    switch (kind) {
      case QuestionKind.trueFalse:
        final label = (boolAnswer ?? false) ? 'صح' : 'خطأ';
        return answerSupport == null || answerSupport!.isEmpty
            ? label
            : '$label — $answerSupport';
      case QuestionKind.choice:
        if (answerIndex != null &&
            answerIndex! >= 0 &&
            answerIndex! < options.length) {
          return options[answerIndex!];
        }
        return '';
      case QuestionKind.open:
        return textAnswer ?? '';
    }
  }
}

class Unit {
  const Unit({
    required this.id,
    required this.sectionId,
    required this.part,
    required this.order,
    required this.title,
    required this.displayTitle,
    required this.unitLabel,
    required this.grade,
    required this.pageRange,
    required this.grammarTitle,
    required this.readingTitle,
    required this.thirdLessonTitle,
    required this.evaluativeTitle,
    required this.template,
    required this.accent,
    required this.figures,
    required this.topics,
    required this.questions,
    required this.glossaryIds,
  });

  factory Unit.fromJson(Map<String, dynamic> json) => Unit(
        id: json['id'] as String,
        sectionId: json['sectionId'] as String,
        part: (json['part'] as String?) ?? 'both',
        order: (json['order'] as int?) ?? 1,
        title: json['title'] as String,
        displayTitle: (json['displayTitle'] as String?) ?? (json['title'] as String),
        unitLabel: (json['unitLabel'] as String?) ?? '',
        grade: (json['grade'] as String?) ?? '',
        pageRange: (json['pageRange'] as String?) ?? '',
        grammarTitle: (json['grammarTitle'] as String?) ?? '',
        readingTitle: (json['readingTitle'] as String?) ?? '',
        thirdLessonTitle: json['thirdLessonTitle'] as String?,
        evaluativeTitle: json['evaluativeTitle'] as String?,
        template: (json['template'] as String?) ?? 'concept',
        accent: (json['accent'] as String?) ?? 'primary',
        figures: ((json['figures'] as List<dynamic>?) ?? const <dynamic>[])
            .map((item) => Figure.fromJson(item as Map<String, dynamic>))
            .toList(growable: false),
        topics: ((json['topics'] as List<dynamic>?) ?? const <dynamic>[])
            .map((item) => Topic.fromJson(item as Map<String, dynamic>))
            .toList(growable: false),
        questions: ((json['questions'] as List<dynamic>?) ?? const <dynamic>[])
            .map((item) => Question.fromJson(item as Map<String, dynamic>))
            .toList(growable: false),
        glossaryIds: ((json['glossary'] as List<dynamic>?) ?? const <dynamic>[])
            .map((item) => item as String)
            .toList(growable: false),
      );

  final String id;
  final String sectionId;
  final String part;
  final int order;
  final String title;
  final String displayTitle;
  final String unitLabel;
  final String grade;
  final String pageRange;
  final String grammarTitle;
  final String readingTitle;
  final String? thirdLessonTitle;
  final String? evaluativeTitle;
  final String template;
  final String accent;
  final List<Figure> figures;
  final List<Topic> topics;
  final List<Question> questions;
  final List<String> glossaryIds;
}

class PlanBlock {
  const PlanBlock({required this.kind, required this.text});

  factory PlanBlock.fromJson(Map<String, dynamic> json) => PlanBlock(
        kind: json['kind'] as String,
        text: json['text'] as String,
      );

  final String kind; // heading | bullet | paragraph
  final String text;
}

class LessonPlan {
  const LessonPlan({
    required this.kind,
    required this.label,
    required this.subject,
    required this.body,
  });

  factory LessonPlan.fromJson(Map<String, dynamic> json) => LessonPlan(
        kind: json['kind'] as String,
        label: json['label'] as String,
        subject: json['subject'] as String,
        body: ((json['body'] as List<dynamic>?) ?? const <dynamic>[])
            .map((item) => PlanBlock.fromJson(item as Map<String, dynamic>))
            .toList(growable: false),
      );

  final String kind;
  final String label;
  final String subject;
  final List<PlanBlock> body;
}

class GrammarLesson {
  const GrammarLesson({
    required this.id,
    required this.part,
    required this.partLabel,
    required this.unitId,
    required this.order,
    required this.title,
    required this.summary,
    required this.accent,
    required this.figures,
    required this.taqwim,
    required this.plans,
  });

  factory GrammarLesson.fromJson(Map<String, dynamic> json) => GrammarLesson(
        id: json['id'] as String,
        part: json['part'] as String,
        partLabel: json['partLabel'] as String,
        unitId: json['unitId'] as String,
        order: json['order'] as int,
        title: json['title'] as String,
        summary: json['summary'] as String,
        accent: (json['accent'] as String?) ?? 'primary',
        figures: ((json['figures'] as List<dynamic>?) ?? const <dynamic>[])
            .map((item) => Figure.fromJson(item as Map<String, dynamic>))
            .toList(growable: false),
        taqwim: ((json['taqwim'] as List<dynamic>?) ?? const <dynamic>[])
            .map((item) => TaqwimPair.fromJson(item as Map<String, dynamic>))
            .toList(growable: false),
        plans: ((json['plans'] as List<dynamic>?) ?? const <dynamic>[])
            .map((item) => LessonPlan.fromJson(item as Map<String, dynamic>))
            .toList(growable: false),
      );

  final String id;
  final String part;
  final String partLabel;
  final String unitId;
  final int order;
  final String title;
  final String summary;
  final String accent;
  final List<Figure> figures;
  final List<TaqwimPair> taqwim;
  final List<LessonPlan> plans;
}

class GlossaryTerm {
  const GlossaryTerm({
    required this.id,
    required this.part,
    required this.term,
    required this.definition,
    required this.unitId,
    required this.topicId,
  });

  factory GlossaryTerm.fromJson(Map<String, dynamic> json) => GlossaryTerm(
        id: json['id'] as String,
        part: json['part'] as String,
        term: json['term'] as String,
        definition: json['definition'] as String,
        unitId: json['unitId'] as String,
        topicId: json['topicId'] as String,
      );

  final String id;
  final String part;
  final String term;
  final String definition;
  final String unitId;
  final String topicId;
}
