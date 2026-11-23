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
}

class ExamTypography {
  const ExamTypography({
    this.font = ExamFontChoice.arial,
    this.bodySizePt = 14,
    this.headingSizePt = 15,
    this.useWesternDigits = true,
    this.spacing = const ExamSpacing(),
  });

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
}

class ArabicExamPaper {
  const ArabicExamPaper({
    required this.header,
    required this.composition,
    required this.grammar,
    required this.orthography,
    this.typography = const ExamTypography(),
  });

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
}

// ---------------------------------------------------------------------------
// Exam Bank models loaded from assets/content/exam_bank.json
// ---------------------------------------------------------------------------

class CompositionBankItem {
  const CompositionBankItem({
    required this.id,
    required this.part,
    required this.text,
  });

  factory CompositionBankItem.fromJson(Map<String, dynamic> json) =>
      CompositionBankItem(
        id: json['id'] as String,
        part: json['part'] as String,
        text: json['text'] as String,
      );

  final String id;
  final String part;
  final String text;
}

class GrammarBankItem {
  const GrammarBankItem({
    required this.id,
    required this.part,
    required this.unitId,
    required this.style,
    required this.promptGroup,
    required this.text,
  });

  factory GrammarBankItem.fromJson(Map<String, dynamic> json) {
    final category =
        (json['category'] as String?) ?? (json['promptGroup'] as String?) ?? '';
    final explicitStyle = json['style'] as String?;
    final String style;
    if (explicitStyle != null && explicitStyle.isNotEmpty) {
      style = explicitStyle;
    } else if (category.contains('إعراب')) {
      style = 'irab';
    } else if (category.contains('الفرق')) {
      style = 'difference';
    } else if (category.contains('اختيارات')) {
      style = 'mcq';
    } else if (category.contains('تقويم')) {
      style = 'taqwim';
    } else if (category.contains('الخبر') || category.contains('كان')) {
      style = 'extract';
    } else {
      style = 'apply';
    }
    return GrammarBankItem(
      id: json['id'] as String,
      part: json['part'] as String,
      unitId: (json['unitId'] as String?) ?? '',
      style: style,
      promptGroup: category,
      text: json['text'] as String,
    );
  }

  final String id;
  final String part;
  final String unitId;
  final String style;
  final String promptGroup;
  final String text;
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
  });

  factory OrthographyBankItem.fromJson(Map<String, dynamic> json) =>
      OrthographyBankItem(
        id: json['id'] as String,
        part: json['part'] as String,
        unitId: (json['unitId'] as String?) ?? (json['title'] as String?) ?? '',
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
          academicYear: '$academicYear م',
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
