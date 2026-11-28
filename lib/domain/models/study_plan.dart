/// Immutable models for the teacher's daily and annual study plans
/// (الخطة اليومية والخطة السنوية), printable as professional A4 PDF sheets.
///
/// The annual plan is generated in formal curriculum order (مقدمة المنهج،
/// الجزء الأول، الجزء الثاني، مرجع الإملاء) with per-unit teaching days,
/// start weeks and exam focus; the daily plan is a teacher-editable sequence
/// of day entries. Every field is editable afterwards, so the teacher keeps
/// full control of the content printed on each A4 sheet.
library;

import '../../core/utils/arabic_text.dart';
import 'library.dart';
import 'question_print_settings.dart';

enum StudyPlanMode {
  daily('daily', 'الخطة اليومية'),
  annual('annual', 'الخطة السنوية');

  const StudyPlanMode(this.id, this.label);

  final String id;
  final String label;

  static StudyPlanMode fromId(String? raw) {
    for (final value in StudyPlanMode.values) {
      if (value.id == raw) {
        return value;
      }
    }
    return StudyPlanMode.annual;
  }
}

/// One column of a printed plan sheet. [weight] controls the relative
/// width of the column on the printed sheet; the teacher toggles visibility
/// per column.
class PlanColumn {
  const PlanColumn(this.id, this.label, {required this.weight});

  final String id;
  final String label;
  final double weight;
}

abstract final class StudyPlanColumns {
  static const List<PlanColumn> annual = <PlanColumn>[
    PlanColumn('index', '#', weight: 5),
    PlanColumn('unit', 'الوحدة', weight: 20),
    PlanColumn('pages', 'الصفحات', weight: 7),
    PlanColumn('reading', 'المطالعة', weight: 13),
    PlanColumn('grammar', 'القواعد', weight: 13),
    PlanColumn('orthography', 'الإملاء والتعبير', weight: 11),
    PlanColumn('days', 'أيام التدريس', weight: 6),
    PlanColumn('week', 'الأسبوع', weight: 7),
    PlanColumn('exam', 'محور التقويم', weight: 11),
    PlanColumn('notes', 'ملاحظات', weight: 15),
  ];

  static const List<PlanColumn> daily = <PlanColumn>[
    PlanColumn('day', 'اليوم', weight: 14),
    PlanColumn('date', 'التاريخ', weight: 12),
    PlanColumn('focus', 'محور الدرس', weight: 16),
    PlanColumn('content', 'محتوى الدرس', weight: 34),
    PlanColumn('homework', 'الواجب', weight: 12),
    PlanColumn('notes', 'ملاحظات', weight: 12),
    PlanColumn('done', 'تم', weight: 5),
  ];

  static PlanColumn? annualColumn(String id) {
    for (final column in annual) {
      if (column.id == id) {
        return column;
      }
    }
    return null;
  }

  static PlanColumn? dailyColumn(String id) {
    for (final column in daily) {
      if (column.id == id) {
        return column;
      }
    }
    return null;
  }

  /// All column ids for each sheet, as const sets usable in default
  /// constructor arguments.
  static const Set<String> allAnnualIds = <String>{
    'index',
    'unit',
    'pages',
    'reading',
    'grammar',
    'orthography',
    'days',
    'week',
    'exam',
    'notes',
  };

  static const Set<String> allDailyIds = <String>{
    'day',
    'date',
    'focus',
    'content',
    'homework',
    'notes',
    'done',
  };
}

/// Official daily-plan focus labels, in the order a unit is taught.
abstract final class StudyPlanFocus {
  static const List<String> options = <String>[
    'تمهيد وقراءة',
    'تحليل النص والاستيعاب',
    'القواعد (١)',
    'القواعد (٢)',
    'الإملاء والتعبير',
    'التقويم والتمرينات',
    'مراجعة',
  ];

  static const List<String> defaultSequence = <String>[
    'تمهيد وقراءة',
    'تحليل النص والاستيعاب',
    'القواعد (١)',
    'القواعد (٢)',
    'الإملاء والتعبير',
    'التقويم والتمرينات',
  ];
}

/// Typography and content-visibility settings for the printed plan sheets.
class StudyPlanSettings {
  const StudyPlanSettings({
    this.font = QuestionPrintFont.plex,
    this.bodyFontSize = 11,
    this.headingFontSize = 14,
    this.compactLines = false,
    this.visibleAnnualColumns = StudyPlanColumns.allAnnualIds,
    this.visibleDailyColumns = StudyPlanColumns.allDailyIds,
  });

  static const int minFontSize = 9;
  static const int maxFontSize = 20;

  final QuestionPrintFont font;
  final int bodyFontSize;
  final int headingFontSize;
  final bool compactLines;
  final Set<String> visibleAnnualColumns;
  final Set<String> visibleDailyColumns;

  static bool isValidFontSize(int? value) =>
      value != null && value >= minFontSize && value <= maxFontSize;

  bool get isValid =>
      isValidFontSize(bodyFontSize) && isValidFontSize(headingFontSize);

  StudyPlanSettings copyWith({
    QuestionPrintFont? font,
    int? bodyFontSize,
    int? headingFontSize,
    bool? compactLines,
    Set<String>? visibleAnnualColumns,
    Set<String>? visibleDailyColumns,
  }) =>
      StudyPlanSettings(
        font: font ?? this.font,
        bodyFontSize: bodyFontSize ?? this.bodyFontSize,
        headingFontSize: headingFontSize ?? this.headingFontSize,
        compactLines: compactLines ?? this.compactLines,
        visibleAnnualColumns:
            visibleAnnualColumns ?? this.visibleAnnualColumns,
        visibleDailyColumns: visibleDailyColumns ?? this.visibleDailyColumns,
      );

  factory StudyPlanSettings.fromJson(Map<String, dynamic> json) {
    const d = StudyPlanSettings();
    final body = ((json['bodyFontSize'] as int?) ?? d.bodyFontSize)
        .clamp(minFontSize, maxFontSize);
    final heading = ((json['headingFontSize'] as int?) ?? d.headingFontSize)
        .clamp(minFontSize, maxFontSize);
    final fontName = json['font'] as String?;
    return StudyPlanSettings(
      font: QuestionPrintFont.values.firstWhere(
        (f) => f.name == fontName,
        orElse: () => d.font,
      ),
      bodyFontSize: body,
      headingFontSize: heading,
      compactLines: (json['compactLines'] as bool?) ?? d.compactLines,
      visibleAnnualColumns: ((json['visibleAnnualColumns'] as List<dynamic>?) ??
              const <dynamic>[])
          .map((e) => e as String)
          .toSet(),
      visibleDailyColumns: ((json['visibleDailyColumns'] as List<dynamic>?) ??
              const <dynamic>[])
          .map((e) => e as String)
          .toSet(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'font': font.name,
        'bodyFontSize': bodyFontSize,
        'headingFontSize': headingFontSize,
        'compactLines': compactLines,
        'visibleAnnualColumns': visibleAnnualColumns.toList(growable: false),
        'visibleDailyColumns': visibleDailyColumns.toList(growable: false),
      };
}

/// One row of the annual plan: a curriculum unit with its teaching schedule.
class AnnualPlanRow {
  const AnnualPlanRow({
    required this.id,
    required this.sectionLabel,
    required this.unitId,
    required this.unitLabel,
    required this.unitTitle,
    required this.pages,
    required this.readingTitle,
    required this.grammarTitle,
    this.orthographyTitle = '',
    required this.teachingDays,
    required this.startWeek,
    required this.examFocus,
    this.notes = '',
  });

  /// Restores a row written by [toJson]; missing keys keep sensible defaults
  /// so a partially damaged record still opens.
  factory AnnualPlanRow.fromJson(Map<String, dynamic> json) {
    const d = AnnualPlanRow(
      id: '',
      sectionLabel: '',
      unitId: '',
      unitLabel: '',
      unitTitle: '',
      pages: '',
      readingTitle: '',
      grammarTitle: '',
      teachingDays: 6,
      startWeek: 1,
      examFocus: '',
    );
    return AnnualPlanRow(
      id: (json['id'] as String?) ?? d.id,
      sectionLabel: (json['sectionLabel'] as String?) ?? d.sectionLabel,
      unitId: (json['unitId'] as String?) ?? d.unitId,
      unitLabel: (json['unitLabel'] as String?) ?? d.unitLabel,
      unitTitle: (json['unitTitle'] as String?) ?? d.unitTitle,
      pages: (json['pages'] as String?) ?? d.pages,
      readingTitle: (json['readingTitle'] as String?) ?? d.readingTitle,
      grammarTitle: (json['grammarTitle'] as String?) ?? d.grammarTitle,
      orthographyTitle:
          (json['orthographyTitle'] as String?) ?? d.orthographyTitle,
      teachingDays:
          ((json['teachingDays'] as int?) ?? d.teachingDays).clamp(1, 60),
      startWeek: ((json['startWeek'] as int?) ?? d.startWeek).clamp(1, 52),
      examFocus: (json['examFocus'] as String?) ?? d.examFocus,
      notes: (json['notes'] as String?) ?? d.notes,
    );
  }

  final String id;
  final String sectionLabel;
  final String unitId;
  final String unitLabel;
  final String unitTitle;
  final String pages;
  final String readingTitle;
  final String grammarTitle;
  final String orthographyTitle;
  final int teachingDays;
  final int startWeek;
  final String examFocus;
  final String notes;

  AnnualPlanRow copyWith({
    String? id,
    String? sectionLabel,
    String? unitId,
    String? unitLabel,
    String? unitTitle,
    String? pages,
    String? readingTitle,
    String? grammarTitle,
    String? orthographyTitle,
    int? teachingDays,
    int? startWeek,
    String? examFocus,
    String? notes,
  }) =>
      AnnualPlanRow(
        id: id ?? this.id,
        sectionLabel: sectionLabel ?? this.sectionLabel,
        unitId: unitId ?? this.unitId,
        unitLabel: unitLabel ?? this.unitLabel,
        unitTitle: unitTitle ?? this.unitTitle,
        pages: pages ?? this.pages,
        readingTitle: readingTitle ?? this.readingTitle,
        grammarTitle: grammarTitle ?? this.grammarTitle,
        orthographyTitle: orthographyTitle ?? this.orthographyTitle,
        teachingDays: teachingDays ?? this.teachingDays,
        startWeek: startWeek ?? this.startWeek,
        examFocus: examFocus ?? this.examFocus,
        notes: notes ?? this.notes,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'sectionLabel': sectionLabel,
        'unitId': unitId,
        'unitLabel': unitLabel,
        'unitTitle': unitTitle,
        'pages': pages,
        'readingTitle': readingTitle,
        'grammarTitle': grammarTitle,
        'orthographyTitle': orthographyTitle,
        'teachingDays': teachingDays,
        'startWeek': startWeek,
        'examFocus': examFocus,
        'notes': notes,
      };
}

/// One day entry of the daily plan.
class DailyPlanEntry {
  const DailyPlanEntry({
    required this.id,
    required this.dayLabel,
    this.dateText = '',
    required this.focus,
    required this.content,
    this.homework = '',
    this.notes = '',
    this.done = false,
  });

  factory DailyPlanEntry.fromJson(Map<String, dynamic> json) {
    const d = DailyPlanEntry(
      id: '',
      dayLabel: '',
      focus: '',
      content: '',
    );
    return DailyPlanEntry(
      id: (json['id'] as String?) ?? d.id,
      dayLabel: (json['dayLabel'] as String?) ?? d.dayLabel,
      dateText: (json['dateText'] as String?) ?? d.dateText,
      focus: (json['focus'] as String?) ?? d.focus,
      content: (json['content'] as String?) ?? d.content,
      homework: (json['homework'] as String?) ?? d.homework,
      notes: (json['notes'] as String?) ?? d.notes,
      done: (json['done'] as bool?) ?? d.done,
    );
  }

  final String id;
  final String dayLabel;
  final String dateText;
  final String focus;
  final String content;
  final String homework;
  final String notes;
  final bool done;

  DailyPlanEntry copyWith({
    String? id,
    String? dayLabel,
    String? dateText,
    String? focus,
    String? content,
    String? homework,
    String? notes,
    bool? done,
  }) =>
      DailyPlanEntry(
        id: id ?? this.id,
        dayLabel: dayLabel ?? this.dayLabel,
        dateText: dateText ?? this.dateText,
        focus: focus ?? this.focus,
        content: content ?? this.content,
        homework: homework ?? this.homework,
        notes: notes ?? this.notes,
        done: done ?? this.done,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'dayLabel': dayLabel,
        'dateText': dateText,
        'focus': focus,
        'content': content,
        'homework': homework,
        'notes': notes,
        'done': done,
      };
}

/// The teacher's complete plan set: annual rows, daily entries and settings.
class StudyPlans {
  const StudyPlans({
    required this.annualRows,
    required this.dailyEntries,
    this.settings = const StudyPlanSettings(),
  });

  factory StudyPlans.fromJson(Map<String, dynamic> json) => StudyPlans(
        annualRows: ((json['annualRows'] as List<dynamic>?) ?? const <dynamic>[])
            .map((e) => AnnualPlanRow.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        dailyEntries:
            ((json['dailyEntries'] as List<dynamic>?) ?? const <dynamic>[])
                .map((e) => DailyPlanEntry.fromJson(e as Map<String, dynamic>))
                .toList(growable: false),
        settings: json['settings'] is Map<String, dynamic>
            ? StudyPlanSettings.fromJson(json['settings'] as Map<String, dynamic>)
            : const StudyPlanSettings(),
      );

  final List<AnnualPlanRow> annualRows;
  final List<DailyPlanEntry> dailyEntries;
  final StudyPlanSettings settings;

  int get annualRowCount => annualRows.length;
  int get dailyEntryCount => dailyEntries.length;

  int get totalTeachingDays =>
      annualRows.fold(0, (sum, row) => sum + row.teachingDays);

  int get totalWeeks => annualRows.fold(
        0,
        (sum, row) => sum > row.startWeek ? sum : row.startWeek,
      );

  StudyPlans copyWith({
    List<AnnualPlanRow>? annualRows,
    List<DailyPlanEntry>? dailyEntries,
    StudyPlanSettings? settings,
  }) =>
      StudyPlans(
        annualRows: annualRows ?? this.annualRows,
        dailyEntries: dailyEntries ?? this.dailyEntries,
        settings: settings ?? this.settings,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'annualRows':
            annualRows.map((row) => row.toJson()).toList(growable: false),
        'dailyEntries':
            dailyEntries.map((entry) => entry.toJson()).toList(growable: false),
        'settings': settings.toJson(),
      };

  /// Fills a fully empty plan with the generated defaults (first open), then
  /// fixes structural inconsistencies (dangling unit references, empty ids,
  /// duplicate ids) so the printed sheet is always well-formed.
  StudyPlans sanitize(StudyLibrary library) {
    if (annualRows.isEmpty && dailyEntries.isEmpty) {
      return StudyPlans(
        annualRows: buildDefaultAnnualPlan(library),
        dailyEntries: buildDefaultDailyPlan(library, CurriculumPart.part1),
      );
    }
    final usedIds = <String>{};

    String nextId(String base) {
      if (base.isNotEmpty && !usedIds.contains(base)) {
        usedIds.add(base);
        return base;
      }
      var i = usedIds.length + 1;
      String candidate = '$base-$i';
      while (usedIds.contains(candidate)) {
        i++;
        candidate = '$base-$i';
      }
      usedIds.add(candidate);
      return candidate;
    }

    final cleanRows = <AnnualPlanRow>[];
    for (var i = 0; i < annualRows.length; i++) {
      final row = annualRows[i];
      if (row.unitId.isEmpty && row.unitLabel.isEmpty) {
        continue;
      }
      cleanRows.add(
        row.copyWith(
          id: nextId(row.id.isEmpty ? 'annual-${i + 1}' : row.id),
          unitId: library.unitById(row.unitId) == null ? '' : row.unitId,
        ),
      );
    }

    final cleanEntries = <DailyPlanEntry>[];
    for (var i = 0; i < dailyEntries.length; i++) {
      final entry = dailyEntries[i];
      cleanEntries.add(
        entry.copyWith(
          id: nextId(entry.id.isEmpty ? 'daily-${i + 1}' : entry.id),
        ),
      );
    }

    return copyWith(
      annualRows: List<AnnualPlanRow>.unmodifiable(cleanRows),
      dailyEntries: List<DailyPlanEntry>.unmodifiable(cleanEntries),
    );
  }
}

/// Builds the formal annual plan in official curriculum order:
/// مقدمة المنهج، الجزء الأول (١٠ وحدات)، الجزء الثاني (٩ وحدات)،
/// then the الإملاء والخط والتعبير reference. Each core unit is scheduled
/// for six teaching days; the reference unit and the introduction are shorter.
List<AnnualPlanRow> buildDefaultAnnualPlan(StudyLibrary library) {
  final rows = <AnnualPlanRow>[];
  var teachingDays = 0;

  void addRow(
    Unit unit,
    String sectionLabel,
    int unitDays,
    String examFocus,
  ) {
    rows.add(
      AnnualPlanRow(
        id: 'annual-${rows.length + 1}',
        sectionLabel: sectionLabel,
        unitId: unit.id,
        unitLabel: unit.unitLabel.isNotEmpty
            ? unit.unitLabel
            : 'الوحدة ${toArabicDigits(unit.order)}',
        unitTitle: unit.displayTitle,
        pages: unit.pageRange,
        readingTitle: unit.readingTitle,
        grammarTitle: unit.grammarTitle,
        orthographyTitle: unit.thirdLessonTitle ?? '',
        teachingDays: unitDays,
        startWeek: startWeekForDays(teachingDays),
        examFocus: examFocus,
        notes: '',
      ),
    );
    teachingDays += unitDays;
  }

  final intro = library.unitById('intro');
  if (intro != null) {
    addRow(intro, 'مقدمة المنهج التكاملي', 2, 'تمهيد المنهج');
  }
  for (final unit in library.unitsForPart(CurriculumPart.part1)) {
    addRow(
      unit,
      'الجزء الأول — الفصل الدراسي الأول',
      6,
      'امتحان نصف السنة',
    );
  }
  for (final unit in library.unitsForPart(CurriculumPart.part2)) {
    addRow(
      unit,
      'الجزء الثاني — الفصل الدراسي الثاني',
      6,
      'امتحان نهاية السنة',
    );
  }
  final orthography = library.unitById('orthography-expression');
  if (orthography != null) {
    addRow(orthography, 'مرجع الإملاء والخط والتعبير', 4, 'مرجع الإملاء');
  }
  return List<AnnualPlanRow>.unmodifiable(rows);
}

/// First school week (1–52) that starts at or after [daysBefore] teaching
/// days have already been scheduled (a five-day school week).
int startWeekForDays(int daysBefore) {
  if (daysBefore <= 0) {
    return 1;
  }
  return (daysBefore + 4) ~/ 5 + 1;
}

/// Arabic day label: «اليوم الأول»، «اليوم الثاني»، … «اليوم ١٢».
String dayLabelFor(int index) {
  const ordinals = <String>[
    'الأول',
    'الثاني',
    'الثالث',
    'الرابع',
    'الخامس',
    'السادس',
    'السابع',
    'الثامن',
    'التاسع',
    'العاشر',
  ];
  final word = index >= 1 && index <= ordinals.length ? ordinals[index - 1] : null;
  return word == null ? 'اليوم ${toArabicDigits(index)}' : 'اليوم $word';
}

/// Activity text planned for one focus label inside a unit.
String activityForFocus(String focus, Unit unit) {
  switch (focus) {
    case 'تمهيد وقراءة':
      return 'التمهيد وقراءة نص الوحدة';
    case 'تحليل النص والاستيعاب':
      return 'تحليل النص ونشاط الفهم والاستيعاب';
    case 'القواعد (١)':
      return 'دراسة قواعد: ${unit.grammarTitle}';
    case 'القواعد (٢)':
      return 'تطبيقات وتمرينات القواعد';
    case 'الإملاء والتعبير':
      return 'درس الإملاء والخط والتعبير';
    case 'التقويم والتمرينات':
      return 'التمرينات والنص التقويمي';
    default:
      return 'مراجعة ${unit.displayTitle}';
  }
}

/// Builds a default daily plan for [part]: every unit of the part gets the
/// official six-day teaching sequence (تمهيد، تحليل، قواعد ١، قواعد ٢،
/// إملاء وتعبير، تقويم وتمرينات).
List<DailyPlanEntry> buildDefaultDailyPlan(
  StudyLibrary library,
  CurriculumPart part,
) {
  final entries = <DailyPlanEntry>[];
  var counter = 0;
  for (final unit in library.unitsForPart(part)) {
    for (final focus in StudyPlanFocus.defaultSequence) {
      counter++;
      entries.add(
        DailyPlanEntry(
          id: 'daily-$counter',
          dayLabel: dayLabelFor(counter),
          focus: focus,
          content: '${unit.displayTitle} — ${activityForFocus(focus, unit)}',
        ),
      );
    }
  }
  return List<DailyPlanEntry>.unmodifiable(entries);
}
