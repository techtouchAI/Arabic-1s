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
  /// Grammar styles understood by the bank, in display order, matching
  /// official Iraqi First Intermediate examination papers.
  static const List<String> grammarStyles = <String>[
    'apply',
    'irab',
    'mcq',
    'difference',
    'murab_mabni',
    'ishara',
    'extract',
    'five_verbs',
  ];

  /// Orthography styles understood by the bank, matching official papers.
  static const List<String> orthographyStyles = <String>[
    'ortho_rule',
    'sun_moon',
    'tanween_reason',
    'ortho_correct',
  ];

  /// Unit question styles available in the composer bank picker.
  static const List<String> unitQuestionStyles = <String>[
    'apply',
    'irab',
    'mcq',
    'difference',
    'murab_mabni',
    'ishara',
    'extract',
    'five_verbs',
    'ortho',
  ];

  /// Short Arabic label for a grammar [style] id.
  static String grammarStyleLabel(String style) {
    switch (style) {
      case 'irab':
        return 'أعرب ما تحته خط';
      case 'mcq':
        return 'اختيارات';
      case 'difference':
        return 'ما الفرق بين الجملتين';
      case 'murab_mabni':
        return 'معرب ومبني';
      case 'ishara':
        return 'أسماء الإشارة';
      case 'extract':
        return 'استخرج الخبر ونوعه';
      case 'five_verbs':
        return 'الأفعال الخمسة';
      case 'ortho':
        return 'إملاء';
      case 'apply':
      default:
        return 'تطبيق واستخراج';
    }
  }

  /// Short Arabic label for an orthography [style] id.
  static String orthographyStyleLabel(String style) {
    switch (style) {
      case 'sun_moon':
        return 'اللام الشمسية والقمرية';
      case 'tanween_reason':
        return 'امتناع التنوين';
      case 'ortho_correct':
        return 'تصحيح الخطأ الإملائي';
      case 'ortho_rule':
      default:
        return 'قواعد الإملاء والتعاريف';
    }
  }

  /// Canonical branch stem for a grammar [style] when creating/replacing a branch.
  static String grammarBranchPrompt(String style) {
    switch (style) {
      case 'irab':
        return 'أعرب ما تحته خط :';
      case 'mcq':
        return 'اختر الإجابة الصحيحة من بين الأقواس :';
      case 'difference':
        return 'ما الفرق بين الجملتين المتقابلتين :';
      case 'murab_mabni':
        return 'ميّز بين الأسماء المعربة والأسماء المبنية فيما تحته خط :';
      case 'ishara':
        return 'عيّن أسماء الإشارة والمشار إليه في الجمل الآتية :';
      case 'extract':
        return 'استخرج الخبر من الجمل الآتية وبيّن نوعه :';
      case 'five_verbs':
        return 'هاتِ الأفعال الخمسة للأفعال الآتية :';
      case 'apply':
      default:
        return 'أجب عمّا يأتي :';
    }
  }

  /// Canonical item layout for a grammar [style] when creating/replacing a branch.
  static ExamItemLayout grammarBranchLayout(String style) {
    switch (style) {
      case 'irab':
      case 'extract':
      case 'five_verbs':
        return ExamItemLayout.inline;
      case 'murab_mabni':
        return ExamItemLayout.prose;
      case 'mcq':
      case 'difference':
      case 'ishara':
      case 'apply':
      default:
        return ExamItemLayout.vertical;
    }
  }

  /// Builds a [BankSelection] from a [GrammarBankItem] with official branch
  /// stem and layout when applied as a whole branch or question.
  static BankSelection selectionForGrammarItem(GrammarBankItem item) {
    return BankSelection(
      text: item.text,
      prompt: grammarBranchPrompt(item.style),
      items: <String>[item.text],
      degree: item.defaultDegree,
      layout: grammarBranchLayout(item.style),
      title: item.promptGroup,
    );
  }

  /// Builds a [BankSelection] from a [UnitQuestionEntry] aligned with
  /// official exam question formatting.
  static BankSelection selectionForUnitQuestion(UnitQuestionEntry entry) {
    final q = entry.question;
    final itemText = unitQuestionAsExamText(q);
    final style = q.effectiveExamStyle;
    if (q.kind == QuestionKind.choice || style == 'mcq') {
      return BankSelection(
        text: itemText,
        prompt: grammarBranchPrompt('mcq'),
        items: <String>[itemText],
        layout: ExamItemLayout.vertical,
        title: entry.unit.displayTitle,
      );
    }
    if (style == 'ortho') {
      return BankSelection(
        text: itemText,
        prompt: q.prompt.trim(),
        items: const <String>[],
        layout: ExamItemLayout.prose,
        title: entry.unit.displayTitle,
      );
    }
    final colonIdx = q.prompt.indexOf(':');
    final canSplit = colonIdx > 0 &&
        colonIdx < 48 &&
        (style == 'irab' ||
            style == 'difference' ||
            style == 'murab_mabni' ||
            style == 'ishara' ||
            style == 'extract' ||
            style == 'five_verbs');
    final strippedBody = canSplit
        ? q.prompt.substring(colonIdx + 1).trim()
        : q.prompt.trim();
    return BankSelection(
      text: strippedBody.isNotEmpty ? strippedBody : itemText,
      prompt: grammarBranchPrompt(style),
      items: <String>[strippedBody.isNotEmpty ? strippedBody : itemText],
      layout: grammarBranchLayout(style),
      title: entry.unit.displayTitle,
    );
  }

  /// Infers the bank [style] a branch prompt asks for, or `null` when the
  /// prompt does not constrain the style (any bank item fits).
  ///
  /// Shared by the auto-generator and the picker so both agree on what
  /// "أعرب ما تحته خط" or "اختر الإجابة الصحيحة" needs. Delegates to
  /// [GrammarBankItem.styleFromText] — the single classification source.
  static String? inferGrammarStyle(String prompt) =>
      GrammarBankItem.styleFromText(prompt);

  /// Infers the orthography [style] of a branch prompt.
  static String inferOrthographyStyle(String prompt) =>
      OrthographyBankItem.styleFromText(prompt);

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

  /// Orthography bank items filtered by [part], [style], [unitId] and [query].
  static List<OrthographyBankItem> filterOrthographyItems(
    ExamBank bank, {
    String? part,
    String? style,
    String? unitId,
    String query = '',
  }) {
    return bank.orthographyItems.where((item) {
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
  /// filtered by [part], [unitId], [kind], [examStyle] and [query].
  ///
  /// Units without questions (intro / orthography summary) contribute
  /// nothing; the picker shows an empty state for them instead of failing.
  static List<UnitQuestionEntry> filterUnitQuestions(
    StudyLibrary library, {
    String? part,
    String? unitId,
    QuestionKind? kind,
    String? examStyle,
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
        if (examStyle != null && question.effectiveExamStyle != examStyle) {
          continue;
        }
        if (!_matchesQuery(query, <String>[
          question.prompt,
          question.id,
          question.examStyleLabel,
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
