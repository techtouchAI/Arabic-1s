/// Domain models for the official Iraqi First Intermediate Arabic Word (.docx)
/// examination paper, matching the 4 reference Word files 100%:
/// - `الدور الاول.docx`
/// - `الدور الثاتيي.docx`
/// - `الدور الاول 2025.docx`
/// - `الدور الثاني 2025.docx`
library;

enum ExamFontChoice {
  arial('Arial', 'Arial (الرسمي المعتمد في نماذج الوزارة)'),
  timesNewRoman('Times New Roman', 'Times New Roman (كلاسيكي للطباعة)'),
  simplifiedArabic('Simplified Arabic', 'Simplified Arabic (مبسط واضح)'),
  cairo('Cairo', 'Cairo (عصري واضح)'),
  amiri('Amiri', 'Amiri (نسخ مطبعي)');

  const ExamFontChoice(this.family, this.label);

  final String family;
  final String label;
}

enum ExamItemLayout {
  vertical('vertical', 'عمودي مرقّم (١- ، ٢- ...)'),
  inline('inline', 'أفقي مدمج في سطر واحد'),
  prose('prose', 'نص متصل / فقرة');

  const ExamItemLayout(this.id, this.label);

  final String id;
  final String label;

  static ExamItemLayout fromId(String? raw) {
    for (final value in ExamItemLayout.values) {
      if (value.id == raw) {
        return value;
      }
    }
    return ExamItemLayout.vertical;
  }
}

class ExamHeader {
  const ExamHeader({
    this.administrationLine = 'ادارة',
    this.showAdditionalHeaderLines = false,
    this.studentNameLabel = 'اسم الطالب :',
    this.studentNumberLabel = 'الرقم الامتحاني :',
    this.countryLine = 'جمهورية العراق',
    this.ministryLine = 'وزارة التربية',
    this.directorateLine = 'المديرية العامة للتربية',
    this.schoolName = 'متوسطة ........ للبنين',
    this.examTitleLine = 'أسئلة امتحان نهاية السنة',
    this.subjectLine = 'المادة : اللغة العربية',
    this.gradeLine = 'الصف : الأول المتوسط',
    this.academicYear = '٢٠٢٥ - ٢٠٢٦ م',
    this.roundLine = 'الدور الأول',
    this.timeAllowed = 'الوقت : ساعتان',
    this.examDate = '',
    this.noteLine = 'ملاحظة : الإجابة عن جميع الأسئلة',
    this.includeStudentFields = true,
    this.closingWish = '((انتهت الأسئلة مع تمنياتي لكم بالنجاح))',
    this.teacherTitle = 'مدرس المادة',
    this.teacherName = '',
  });

  /// Restores a header saved by [toJson]; missing keys keep their defaults so
  /// papers saved by older versions still open.
  factory ExamHeader.fromJson(Map<String, dynamic> json) {
    const d = ExamHeader();
    String text(String key, String fallback) =>
        (json[key] as String?) ?? fallback;
    bool flag(String key, bool fallback) => (json[key] as bool?) ?? fallback;
    return ExamHeader(
      administrationLine: text('administrationLine', d.administrationLine),
      showAdditionalHeaderLines:
          flag('showAdditionalHeaderLines', d.showAdditionalHeaderLines),
      studentNameLabel: text('studentNameLabel', d.studentNameLabel),
      studentNumberLabel: text('studentNumberLabel', d.studentNumberLabel),
      countryLine: text('countryLine', d.countryLine),
      ministryLine: text('ministryLine', d.ministryLine),
      directorateLine: text('directorateLine', d.directorateLine),
      schoolName: text('schoolName', d.schoolName),
      examTitleLine: text('examTitleLine', d.examTitleLine),
      subjectLine: text('subjectLine', d.subjectLine),
      gradeLine: text('gradeLine', d.gradeLine),
      academicYear: text('academicYear', d.academicYear),
      roundLine: text('roundLine', d.roundLine),
      timeAllowed: text('timeAllowed', d.timeAllowed),
      examDate: text('examDate', d.examDate),
      noteLine: text('noteLine', d.noteLine),
      includeStudentFields:
          flag('includeStudentFields', d.includeStudentFields),
      closingWish: text('closingWish', d.closingWish),
      teacherTitle: text('teacherTitle', d.teacherTitle),
      teacherName: text('teacherName', d.teacherName),
    );
  }

  final String administrationLine;
  final bool showAdditionalHeaderLines;
  final String studentNameLabel;
  final String studentNumberLabel;
  final String countryLine;
  final String ministryLine;
  final String directorateLine;
  final String schoolName;
  final String examTitleLine;
  final String subjectLine;
  final String gradeLine;
  final String academicYear;
  final String roundLine;
  final String timeAllowed;
  final String examDate;
  final String noteLine;
  final bool includeStudentFields;
  final String closingWish;
  final String teacherTitle;
  final String teacherName;

  ExamHeader copyWith({
    String? administrationLine,
    bool? showAdditionalHeaderLines,
    String? studentNameLabel,
    String? studentNumberLabel,
    String? countryLine,
    String? ministryLine,
    String? directorateLine,
    String? schoolName,
    String? examTitleLine,
    String? subjectLine,
    String? gradeLine,
    String? academicYear,
    String? roundLine,
    String? timeAllowed,
    String? examDate,
    String? noteLine,
    bool? includeStudentFields,
    String? closingWish,
    String? teacherTitle,
    String? teacherName,
  }) =>
      ExamHeader(
        administrationLine: administrationLine ?? this.administrationLine,
        showAdditionalHeaderLines: showAdditionalHeaderLines ?? this.showAdditionalHeaderLines,
        studentNameLabel: studentNameLabel ?? this.studentNameLabel,
        studentNumberLabel: studentNumberLabel ?? this.studentNumberLabel,
        countryLine: countryLine ?? this.countryLine,
        ministryLine: ministryLine ?? this.ministryLine,
        directorateLine: directorateLine ?? this.directorateLine,
        schoolName: schoolName ?? this.schoolName,
        examTitleLine: examTitleLine ?? this.examTitleLine,
        subjectLine: subjectLine ?? this.subjectLine,
        gradeLine: gradeLine ?? this.gradeLine,
        academicYear: academicYear ?? this.academicYear,
        roundLine: roundLine ?? this.roundLine,
        timeAllowed: timeAllowed ?? this.timeAllowed,
        examDate: examDate ?? this.examDate,
        noteLine: noteLine ?? this.noteLine,
        includeStudentFields: includeStudentFields ?? this.includeStudentFields,
        closingWish: closingWish ?? this.closingWish,
        teacherTitle: teacherTitle ?? this.teacherTitle,
        teacherName: teacherName ?? this.teacherName,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'administrationLine': administrationLine,
        'showAdditionalHeaderLines': showAdditionalHeaderLines,
        'studentNameLabel': studentNameLabel,
        'studentNumberLabel': studentNumberLabel,
        'countryLine': countryLine,
        'ministryLine': ministryLine,
        'directorateLine': directorateLine,
        'schoolName': schoolName,
        'examTitleLine': examTitleLine,
        'subjectLine': subjectLine,
        'gradeLine': gradeLine,
        'academicYear': academicYear,
        'roundLine': roundLine,
        'timeAllowed': timeAllowed,
        'examDate': examDate,
        'noteLine': noteLine,
        'includeStudentFields': includeStudentFields,
        'closingWish': closingWish,
        'teacherTitle': teacherTitle,
        'teacherName': teacherName,
      };
}

class ExamCompositionSection {
  const ExamCompositionSection({
    this.degree = 30,
    this.prompt = 'اكتب في أحد الموضوعين الآتيين :',
    required this.topics,
  });

  factory ExamCompositionSection.fromJson(Map<String, dynamic> json) =>
      ExamCompositionSection(
        degree: (json['degree'] as int?) ?? 30,
        prompt:
            (json['prompt'] as String?) ?? 'اكتب في أحد الموضوعين الآتيين :',
        topics: ((json['topics'] as List<dynamic>?) ?? const <dynamic>[])
            .map((e) => e as String)
            .toList(growable: false),
      );

  final int degree;
  final String prompt;
  final List<String> topics;

  ExamCompositionSection copyWith({
    int? degree,
    String? prompt,
    List<String>? topics,
  }) =>
      ExamCompositionSection(
        degree: degree ?? this.degree,
        prompt: prompt ?? this.prompt,
        topics: topics ?? this.topics,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'degree': degree,
        'prompt': prompt,
        'topics': List<String>.of(topics),
      };
}

class ExamBranch {
  const ExamBranch({
    required this.branch,
    required this.prompt,
    required this.degree,
    required this.items,
    this.itemLayout = ExamItemLayout.vertical,
  });

  factory ExamBranch.fromJson(
    Map<String, dynamic> json, {
    String defaultBranch = '',
  }) =>
      ExamBranch(
        branch: (json['branch'] as String?) ?? defaultBranch,
        prompt: json['prompt'] as String,
        degree: json['degree'] as int,
        items: ((json['items'] as List<dynamic>?) ?? const <dynamic>[])
            .map((e) => e as String)
            .toList(growable: false),
        itemLayout: ExamItemLayout.fromId(
          (json['itemLayout'] as String?) ?? (json['layout'] as String?),
        ),
      );

  /// `'أ'`, `'ب'`, `'ج'`, or `''` for standalone question without sub-branch.
  final String branch;
  final String prompt;
  final int degree;
  final List<String> items;
  final ExamItemLayout itemLayout;

  ExamBranch copyWith({
    String? branch,
    String? prompt,
    int? degree,
    List<String>? items,
    ExamItemLayout? itemLayout,
  }) =>
      ExamBranch(
        branch: branch ?? this.branch,
        prompt: prompt ?? this.prompt,
        degree: degree ?? this.degree,
        items: items ?? this.items,
        itemLayout: itemLayout ?? this.itemLayout,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'branch': branch,
        'prompt': prompt,
        'degree': degree,
        'items': List<String>.of(items),
        'itemLayout': itemLayout.id,
      };
}

class ExamQuestionBlock {
  const ExamQuestionBlock({
    required this.number,
    required this.branches,
  });

  factory ExamQuestionBlock.fromJson(
    Map<String, dynamic> json, {
    int defaultNumber = 1,
  }) {
    final rawBranches =
        (json['branches'] as List<dynamic>?) ?? const <dynamic>[];
    const branchLetters = <String>['أ', 'ب', 'ج', 'د', 'هـ'];
    final branches = <ExamBranch>[];
    for (var i = 0; i < rawBranches.length; i++) {
      final fallback = rawBranches.length > 1 && i < branchLetters.length
          ? branchLetters[i]
          : '';
      branches.add(
        ExamBranch.fromJson(
          rawBranches[i] as Map<String, dynamic>,
          defaultBranch: fallback,
        ),
      );
    }
    return ExamQuestionBlock(
      number: (json['number'] as int?) ?? defaultNumber,
      branches: branches,
    );
  }

  final int number;
  final List<ExamBranch> branches;

  int get totalDegree =>
      branches.fold<int>(0, (sum, branch) => sum + branch.degree);

  ExamQuestionBlock copyWith({
    int? number,
    List<ExamBranch>? branches,
  }) =>
      ExamQuestionBlock(
        number: number ?? this.number,
        branches: branches ?? this.branches,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'number': number,
        'branches': branches.map((b) => b.toJson()).toList(growable: false),
      };
}

class ExamQuestionSection {
  const ExamQuestionSection({
    required this.degree,
    required this.questions,
  });

  factory ExamQuestionSection.fromJson(Map<String, dynamic> json) {
    final rawQuestions =
        (json['questions'] as List<dynamic>?) ?? const <dynamic>[];
    final questions = <ExamQuestionBlock>[];
    for (var i = 0; i < rawQuestions.length; i++) {
      questions.add(
        ExamQuestionBlock.fromJson(
          rawQuestions[i] as Map<String, dynamic>,
          defaultNumber: i + 1,
        ),
      );
    }
    return ExamQuestionSection(
      degree: json['degree'] as int,
      questions: questions,
    );
  }

  final int degree;
  final List<ExamQuestionBlock> questions;

  int get branchesSum =>
      questions.fold<int>(0, (sum, q) => sum + q.totalDegree);

  ExamQuestionSection copyWith({
    int? degree,
    List<ExamQuestionBlock>? questions,
  }) =>
      ExamQuestionSection(
        degree: degree ?? this.degree,
        questions: questions ?? this.questions,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'degree': degree,
        'questions': questions.map((q) => q.toJson()).toList(growable: false),
      };
}

/// Physical spacing in points; Word uses twentieths of a point (dxa).
/// Auto line spacing is a multiplier, avoiding clipped Arabic diacritics.
class ExamSpacing {
  const ExamSpacing({
    this.lineHeight = 1.0,
    this.itemGapPt = 0,
    this.branchGapPt = 3.5,
    this.questionGapPt = 6,
  })  : assert(lineHeight >= 1 && lineHeight <= 2),
        assert(itemGapPt >= 0 && itemGapPt <= 12),
        assert(branchGapPt >= 0 && branchGapPt <= 18),
        assert(questionGapPt >= 0 && questionGapPt <= 24);

  /// Values are clamped into the editor's ranges, so a damaged record can
  /// never violate the constructor's assertions or the sliders' bounds.
  factory ExamSpacing.fromJson(Map<String, dynamic> json) {
    const d = ExamSpacing();
    double read(String key, double fallback, double min, double max) =>
        ((json[key] as num?)?.toDouble() ?? fallback).clamp(min, max);
    return ExamSpacing(
      lineHeight: read('lineHeight', d.lineHeight, 1, 2),
      itemGapPt: read('itemGapPt', d.itemGapPt, 0, 12),
      branchGapPt: read('branchGapPt', d.branchGapPt, 0, 18),
      questionGapPt: read('questionGapPt', d.questionGapPt, 0, 24),
    );
  }

  final double lineHeight;
  final double itemGapPt;
  final double branchGapPt;
  final double questionGapPt;

  ExamSpacing copyWith({
    double? lineHeight,
    double? itemGapPt,
    double? branchGapPt,
    double? questionGapPt,
  }) => ExamSpacing(
    lineHeight: lineHeight ?? this.lineHeight,
    itemGapPt: itemGapPt ?? this.itemGapPt,
    branchGapPt: branchGapPt ?? this.branchGapPt,
    questionGapPt: questionGapPt ?? this.questionGapPt,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'lineHeight': lineHeight,
        'itemGapPt': itemGapPt,
        'branchGapPt': branchGapPt,
        'questionGapPt': questionGapPt,
      };
}

class ExamTypography {
  const ExamTypography({
    this.font = ExamFontChoice.arial,
    this.bodySizePt = 14,
    this.headingSizePt = 15,
    this.useWesternDigits = true,
    this.spacing = const ExamSpacing(),
  });

  /// Body sizes outside the editor range (8–18 pt) are clamped into it.
  factory ExamTypography.fromJson(Map<String, dynamic> json) {
    const d = ExamTypography();
    final fontName = json['font'] as String?;
    final body = ((json['bodySizePt'] as int?) ?? d.bodySizePt).clamp(8, 18);
    final heading =
        ((json['headingSizePt'] as int?) ?? body + 1).clamp(8, 24);
    return ExamTypography(
      font: ExamFontChoice.values.firstWhere(
        (f) => f.name == fontName,
        orElse: () => d.font,
      ),
      bodySizePt: body,
      headingSizePt: heading,
      useWesternDigits: (json['useWesternDigits'] as bool?) ?? d.useWesternDigits,
      spacing: json['spacing'] is Map<String, dynamic>
          ? ExamSpacing.fromJson(json['spacing'] as Map<String, dynamic>)
          : d.spacing,
    );
  }

  final ExamFontChoice font;
  final int bodySizePt;
  final int headingSizePt;
  final bool useWesternDigits;
  final ExamSpacing spacing;

  ExamTypography copyWith({
    ExamFontChoice? font,
    int? bodySizePt,
    int? headingSizePt,
    bool? useWesternDigits,
    ExamSpacing? spacing,
  }) =>
      ExamTypography(
        font: font ?? this.font,
        bodySizePt: bodySizePt ?? this.bodySizePt,
        headingSizePt: headingSizePt ?? this.headingSizePt,
        useWesternDigits: useWesternDigits ?? this.useWesternDigits,
        spacing: spacing ?? this.spacing,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'font': font.name,
        'bodySizePt': bodySizePt,
        'headingSizePt': headingSizePt,
        'useWesternDigits': useWesternDigits,
        'spacing': spacing.toJson(),
      };
}

class ArabicExamPaper {
  const ArabicExamPaper({
    required this.header,
    required this.composition,
    required this.grammar,
    required this.orthography,
    this.typography = const ExamTypography(),
  });

  factory ArabicExamPaper.fromJson(Map<String, dynamic> json) =>
      ArabicExamPaper(
        header: ExamHeader.fromJson(json['header'] as Map<String, dynamic>),
        composition: ExamCompositionSection.fromJson(
          json['composition'] as Map<String, dynamic>,
        ),
        grammar: ExamQuestionSection.fromJson(
          json['grammar'] as Map<String, dynamic>,
        ),
        orthography: ExamQuestionSection.fromJson(
          json['orthography'] as Map<String, dynamic>,
        ),
        typography: json['typography'] is Map<String, dynamic>
            ? ExamTypography.fromJson(
                json['typography'] as Map<String, dynamic>,
              )
            : const ExamTypography(),
      );

  final ExamHeader header;
  final ExamCompositionSection composition;
  final ExamQuestionSection grammar;
  final ExamQuestionSection orthography;
  final ExamTypography typography;

  int get totalDegree =>
      composition.degree + grammar.degree + orthography.degree;

  bool get grammarBalanced => grammar.branchesSum == grammar.degree;
  bool get orthographyBalanced => orthography.branchesSum == orthography.degree;

  ArabicExamPaper copyWith({
    ExamHeader? header,
    ExamCompositionSection? composition,
    ExamQuestionSection? grammar,
    ExamQuestionSection? orthography,
    ExamTypography? typography,
  }) =>
      ArabicExamPaper(
        header: header ?? this.header,
        composition: composition ?? this.composition,
        grammar: grammar ?? this.grammar,
        orthography: orthography ?? this.orthography,
        typography: typography ?? this.typography,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'header': header.toJson(),
        'composition': composition.toJson(),
        'grammar': grammar.toJson(),
        'orthography': orthography.toJson(),
        'typography': typography.toJson(),
      };
}

// ---------------------------------------------------------------------------
// Exam Bank models loaded from assets/content/exam_bank.json
// ---------------------------------------------------------------------------

class CompositionBankItem {
  const CompositionBankItem({
    required this.id,
    required this.part,
    required this.text,
    this.title = '',
    this.unitId = '',
  });

  factory CompositionBankItem.fromJson(Map<String, dynamic> json) =>
      CompositionBankItem(
        id: json['id'] as String,
        part: json['part'] as String,
        text: json['text'] as String,
        title: (json['title'] as String?) ?? '',
        unitId: (json['unitId'] as String?) ?? '',
      );

  final String id;
  final String part;
  final String text;

  /// Short display title from the bank (`title` in JSON); empty for legacy
  /// records, in which case callers fall back to [text].
  final String title;

  /// Owning curriculum unit (`p1-u1` … `p2-u9`); empty for general topics.
  final String unitId;
}

class GrammarBankItem {
  const GrammarBankItem({
    required this.id,
    required this.part,
    required this.unitId,
    required this.style,
    required this.promptGroup,
    required this.text,
    this.defaultDegree = 5,
  });

  factory GrammarBankItem.fromJson(Map<String, dynamic> json) {
    final category =
        (json['category'] as String?) ?? (json['promptGroup'] as String?) ?? '';
    return GrammarBankItem(
      id: json['id'] as String,
      part: json['part'] as String,
      unitId: (json['unitId'] as String?) ?? '',
      style: GrammarBankItem.styleFromText(category) ?? 'apply',
      promptGroup: category,
      text: json['text'] as String,
      defaultDegree: (json['defaultDegree'] as int?) ?? 5,
    );
  }

  /// Single source of truth for style classification across the bank JSON,
  /// the auto-generator and the per-branch bank picker. Matches both the
  /// bank's `category` vocabulary (`أعرب ما تحته خط`, `معرب ومبني`,
  /// `اختيارات`, `ما الفرق بين الجملتين`, `استخرج الخبر ونوعه`) and the
  /// wording of handwritten branch prompts (`اعرب`, `اختر`, …).
  /// Returns `null` when the text constrains no style (generic `apply`).
  static String? styleFromText(String text) {
    if (text.contains('إعراب') ||
        text.contains('أعرب') ||
        text.contains('اعرب') ||
        text.contains('معرب')) {
      return 'irab';
    }
    if (text.contains('اختر') || text.contains('اختيارات')) {
      return 'mcq';
    }
    if (text.contains('الفرق')) {
      return 'difference';
    }
    if (text.contains('الخبر') || text.contains('استخرج')) {
      return 'extract';
    }
    if (text.contains('تقويم')) {
      return 'taqwim';
    }
    return null;
  }

  final String id;
  final String part;
  final String unitId;
  final String style;
  final String promptGroup;
  final String text;

  /// Suggested degree when this item replaces a whole branch; the teacher
  /// can still adjust it with the branch stepper afterwards.
  final int defaultDegree;
}

class OrthographyBankItem {
  const OrthographyBankItem({
    required this.id,
    required this.part,
    required this.unitId,
    required this.prompt,
    required this.items,
    required this.defaultDegree,
    required this.itemLayout,
    this.title = '',
  });

  factory OrthographyBankItem.fromJson(Map<String, dynamic> json) =>
      OrthographyBankItem(
        id: json['id'] as String,
        part: json['part'] as String,
        // `unitId` is the owning curriculum unit; the display `title` must
        // never be used as a unit id (legacy records simply have no unit).
        unitId: (json['unitId'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        prompt: json['prompt'] as String,
        items: ((json['items'] as List<dynamic>?) ?? const <dynamic>[])
            .map((e) => e as String)
            .toList(growable: false),
        defaultDegree: (json['defaultDegree'] as int?) ?? 5,
        itemLayout: ExamItemLayout.fromId(json['itemLayout'] as String?),
      );

  final String id;
  final String part;
  final String unitId;
  final String prompt;
  final List<String> items;
  final int defaultDegree;
  final ExamItemLayout itemLayout;

  /// Short display title from the bank (`title` in JSON); empty for legacy
  /// records, in which case callers fall back to [prompt].
  final String title;
}

class OfficialExamTemplate {
  const OfficialExamTemplate({
    required this.id,
    this.part = 'both',
    required this.title,
    required this.examTitle,
    required this.round,
    required this.academicYear,
    required this.timeAllowed,
    required this.includeStudentFields,
    required this.composition,
    required this.grammar,
    required this.orthography,
  });

  factory OfficialExamTemplate.fromJson(Map<String, dynamic> json) {
    final label = (json['label'] as String?) ?? (json['title'] as String?) ?? '';
    final examTitle =
        (json['examTitle'] as String?) ?? 'أسئلة امتحان نهاية السنة';
    final roleLabel =
        (json['roleLabel'] as String?) ?? (json['round'] as String?) ?? '';
    return OfficialExamTemplate(
      id: json['id'] as String,
      part: (json['part'] as String?) ?? 'both',
      title: label,
      examTitle: examTitle,
      round: roleLabel.isNotEmpty ? roleLabel : label,
      academicYear: (json['academicYear'] as String?) ?? '٢٠٢٥ - ٢٠٢٦',
      timeAllowed:
          (json['duration'] as String?) ??
          (json['timeAllowed'] as String?) ??
          'ساعتان',
      includeStudentFields:
          (json['showStudentFields'] as bool?) ??
          (json['includeStudentFields'] as bool?) ??
          false,
      composition: ExamCompositionSection.fromJson(
        json['composition'] as Map<String, dynamic>,
      ),
      grammar: ExamQuestionSection.fromJson(
        json['grammar'] as Map<String, dynamic>,
      ),
      orthography: ExamQuestionSection.fromJson(
        json['orthography'] as Map<String, dynamic>,
      ),
    );
  }

  final String id;
  final String part;
  final String title;
  final String examTitle;
  final String round;
  final String academicYear;
  final String timeAllowed;
  final bool includeStudentFields;
  final ExamCompositionSection composition;
  final ExamQuestionSection grammar;
  final ExamQuestionSection orthography;

  ArabicExamPaper toExamPaper({
    String schoolName = 'متوسطة ........ للبنين',
    String directorate = 'المديرية العامة للتربية',
    String teacherName = '',
  }) =>
      ArabicExamPaper(
        header: ExamHeader(
          directorateLine:
              directorate.trim().isEmpty ? 'المديرية العامة للتربية' : directorate,
          schoolName:
              schoolName.trim().isEmpty ? 'متوسطة ........ للبنين' : schoolName,
          examTitleLine: examTitle,
          academicYear: academicYear,
          roundLine: round,
          timeAllowed: 'الوقت : $timeAllowed',
          includeStudentFields: includeStudentFields,
          teacherName: teacherName,
        ),
        composition: composition,
        grammar: grammar,
        orthography: orthography,
      );
}

class ExamBank {
  const ExamBank({
    required this.compositionTopics,
    required this.grammarItems,
    required this.orthographyItems,
    required this.officialTemplates,
  });

  factory ExamBank.fromJson(Map<String, dynamic> json) => ExamBank(
        compositionTopics:
            ((json['compositionTopics'] as List<dynamic>?) ?? const <dynamic>[])
                .map(
                  (e) =>
                      CompositionBankItem.fromJson(e as Map<String, dynamic>),
                )
                .toList(growable: false),
        grammarItems:
            ((json['grammarItems'] as List<dynamic>?) ?? const <dynamic>[])
                .map((e) => GrammarBankItem.fromJson(e as Map<String, dynamic>))
                .toList(growable: false),
        orthographyItems:
            ((json['orthographyItems'] as List<dynamic>?) ?? const <dynamic>[])
                .map(
                  (e) =>
                      OrthographyBankItem.fromJson(e as Map<String, dynamic>),
                )
                .toList(growable: false),
        officialTemplates:
            ((json['officialTemplates'] as List<dynamic>?) ?? const <dynamic>[])
                .map(
                  (e) =>
                      OfficialExamTemplate.fromJson(e as Map<String, dynamic>),
                )
                .toList(growable: false),
      );

  final List<CompositionBankItem> compositionTopics;
  final List<GrammarBankItem> grammarItems;
  final List<OrthographyBankItem> orthographyItems;
  final List<OfficialExamTemplate> officialTemplates;
}
