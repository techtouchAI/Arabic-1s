import '../models/exam_paper.dart';
import '../models/library.dart';

/// One curriculum unit question flattened for the exam bank picker.
///
/// Every unit owns its own question bank (`Unit.questions`); this entry keeps
/// the owning [unit] next to the [question] so the picker can group, filter
/// and label results per topic while the teacher picks freely.
class UnitQuestionEntry {
  const UnitQuestionEntry({required this.unit, required this.question});

  final Unit unit;
  final Question question;
}

/// How a picked bank item is applied to the paper. The teacher chooses
/// freely in the picker; the composer applies the choice.
enum BankApplyMode {
  /// Append the item text as one more point of the current branch.
  addAsItem,

  /// Replace the current branch content (prompt, degree, items, layout).
  replaceBranch,

  /// Append a new branch built from the item to the target question.
  addBranch,

  /// Append a new question block holding a single branch from the item.
  addQuestion,

  /// Append a new composition topic.
  addTopic,

  /// Replace the composition topic at the chosen index.
  replaceTopic,
}

/// One bank item chosen in the picker, in a renderer-neutral shape.
class BankSelection {
  const BankSelection({
    required this.text,
    this.prompt = '',
    this.items = const <String>[],
    this.degree = 5,
    this.layout = ExamItemLayout.vertical,
    this.title = '',
  });

  /// Primary text: the point text (grammar / unit questions) or the
  /// composition topic text.
  final String text;

  /// Branch prompt when the item becomes a whole branch.
  final String prompt;

  /// Branch points when the item becomes a whole branch.
  final List<String> items;

  /// Suggested degree for a whole-branch application.
  final int degree;

  /// Suggested point layout for a whole-branch application.
  final ExamItemLayout layout;

  /// Short display title, when the bank provides one.
  final String title;
}

/// Result returned by the bank picker sheet.
class BankPickOutcome {
  const BankPickOutcome({
    required this.selection,
    required this.mode,
    this.targetQuestionIndex = 0,
  });

  final BankSelection selection;
  final BankApplyMode mode;

  /// Target question for [BankApplyMode.addBranch]; ignored otherwise.
  final int targetQuestionIndex;
}

/// Pure, testable helpers behind the per-branch question bank pickers.
///
/// The composer previously offered a single flat list per section (and, for
/// orthography, always targeted question 0). These helpers give every
/// question, branch and composition topic its own searchable bank filtered
/// by part, grammar style, owning unit and free text — the teacher stays
/// free to choose any item for any branch.
abstract final class ExamBankPicker {
  /// Grammar styles understood by the bank, in display order.
  static const List<String> grammarStyles = <String>[
    'apply',
    'irab',
    'mcq',
    'difference',
    'taqwim',
    'extract',
  ];

  /// Short Arabic label for a grammar [style] id.
  static String grammarStyleLabel(String style) {
    switch (style) {
      case 'irab':
        return 'إعراب';
      case 'mcq':
        return 'اختيارات';
      case 'difference':
        return 'الفرق بين الجملتين';
      case 'taqwim':
        return 'تقويم اللسان';
      case 'extract':
        return 'استخراج الخبر';
      case 'apply':
      default:
        return 'تطبيق واستخراج';
    }
  }

  /// Infers the bank [style] a branch prompt asks for, or `null` when the
  /// prompt does not constrain the style (any bank item fits).
  ///
  /// Shared by the auto-generator and the picker so both agree on what
  /// "أعرب ما تحته خط" or "اختر الإجابة الصحيحة" needs.
  static String? inferGrammarStyle(String prompt) {
    if (prompt.contains('اعرب') || prompt.contains('أعرب')) {
      return 'irab';
    }
    if (prompt.contains('اختر')) {
      return 'mcq';
    }
    if (prompt.contains('الفرق')) {
      return 'difference';
    }
    if (prompt.contains('تقويم')) {
      return 'taqwim';
    }
    if (prompt.contains('الخبر')) {
      return 'extract';
    }
    return null;
  }

  static bool _matchesQuery(String query, Iterable<String> haystacks) {
    final q = query.trim();
    if (q.isEmpty) {
      return true;
    }
    final needle = q.toLowerCase();
    for (final haystack in haystacks) {
      if (haystack.toLowerCase().contains(needle)) {
        return true;
      }
    }
    return false;
  }

  /// Grammar bank items filtered by [part] (`part1`/`part2`, null = all),
  /// [style] (null = all), [unitId] (null = all, empty = general only) and
  /// free-text [query]. Order is stable (bank order).
  static List<GrammarBankItem> filterGrammarItems(
    ExamBank bank, {
    String? part,
    String? style,
    String? unitId,
    String query = '',
  }) {
    return bank.grammarItems.where((item) {
      if (part != null && item.part != part) {
        return false;
      }
      if (style != null && item.style != style) {
        return false;
      }
      if (unitId != null && item.unitId != unitId) {
        return false;
      }
      return _matchesQuery(query, <String>[
        item.text,
        item.promptGroup,
        item.id,
      ]);
    }).toList(growable: false);
  }

  /// Orthography bank items filtered by [part], [unitId] and [query].
  static List<OrthographyBankItem> filterOrthographyItems(
    ExamBank bank, {
    String? part,
    String? unitId,
    String query = '',
  }) {
    return bank.orthographyItems.where((item) {
      if (part != null && item.part != part) {
        return false;
      }
      if (unitId != null && item.unitId != unitId) {
        return false;
      }
      return _matchesQuery(query, <String>[
        item.prompt,
        item.title,
        item.id,
        ...item.items,
      ]);
    }).toList(growable: false);
  }

  /// Composition topics filtered by [part], [unitId] and [query].
  static List<CompositionBankItem> filterCompositionTopics(
    ExamBank bank, {
    String? part,
    String? unitId,
    String query = '',
  }) {
    return bank.compositionTopics.where((item) {
      if (part != null && item.part != part) {
        return false;
      }
      if (unitId != null && item.unitId != unitId) {
        return false;
      }
      return _matchesQuery(query, <String>[
        item.text,
        item.title,
        item.id,
      ]);
    }).toList(growable: false);
  }

  /// All per-unit questions flattened in curriculum order, optionally
  /// filtered by [part], [unitId], [kind] and [query].
  ///
  /// Units without questions (intro / orthography summary) contribute
  /// nothing; the picker shows an empty state for them instead of failing.
  static List<UnitQuestionEntry> filterUnitQuestions(
    StudyLibrary library, {
    String? part,
    String? unitId,
    QuestionKind? kind,
    String query = '',
  }) {
    final result = <UnitQuestionEntry>[];
    final units = library.units.toList(growable: false)
      ..sort((a, b) => a.order.compareTo(b.order));
    for (final unit in units) {
      if (part != null && unit.part != part && unit.part != 'both') {
        continue;
      }
      if (unitId != null && unit.id != unitId) {
        continue;
      }
      for (final question in unit.questions) {
        if (kind != null && question.kind != kind) {
          continue;
        }
        if (!_matchesQuery(query, <String>[
          question.prompt,
          question.id,
          unit.displayTitle,
          ...question.options,
        ])) {
          continue;
        }
        result.add(UnitQuestionEntry(unit: unit, question: question));
      }
    }
    return result;
  }

  /// Short Arabic label for a unit [QuestionKind].
  static String questionKindLabel(QuestionKind kind) {
    switch (kind) {
      case QuestionKind.trueFalse:
        return 'صح / خطأ';
      case QuestionKind.choice:
        return 'اختيارات';
      case QuestionKind.open:
        return 'مقالي';
    }
  }

  /// Formats a curriculum unit question as exam branch item text, matching
  /// the official Word MCQ convention: options in parentheses separated
  /// by `–`, e.g. `الفعل الأمر … ( معرباً – مبنياً – مرفوعاً )`.
  static String unitQuestionAsExamText(Question question) {
    final prompt = question.prompt.trim();
    switch (question.kind) {
      case QuestionKind.choice:
        if (question.options.isEmpty) {
          return prompt;
        }
        final options = question.options
            .map((o) => o.trim())
            .where((o) => o.isNotEmpty)
            .join(' – ');
        if (options.isEmpty) {
          return prompt;
        }
        return '$prompt ( $options )';
      case QuestionKind.trueFalse:
      case QuestionKind.open:
        return prompt;
    }
  }

  /// Resolves the display title of the unit owning [unitId], or `null`
  /// when the id is empty/unknown (general bank items).
  static String? unitTitleFor(StudyLibrary library, String unitId) {
    if (unitId.trim().isEmpty) {
      return null;
    }
    return library.unitById(unitId)?.displayTitle;
  }
}
