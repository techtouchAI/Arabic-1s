/// Typography settings for printing unit questions & model answers as A4 PDF.
library;

enum QuestionPrintFont {
  plex(
    'IBMPlexSansArabic',
    'IBM Plex Sans Arabic (واضح وحديث)',
    'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    'assets/fonts/IBMPlexSansArabic-Bold.ttf',
  ),
  amiri(
    'Amiri',
    'Amiri (نسخ مطبعي كلاسيكي)',
    'assets/fonts/Amiri-Regular.ttf',
    'assets/fonts/Amiri-Bold.ttf',
  ),
  cairo(
    'Cairo',
    'Cairo (عصري متوازن)',
    'assets/fonts/Cairo-Regular.ttf',
    'assets/fonts/Cairo-Bold.ttf',
  ),
  tajawal(
    'Tajawal',
    'Tajawal (مريح للقراءة)',
    'assets/fonts/Tajawal-Regular.ttf',
    'assets/fonts/Tajawal-Bold.ttf',
  ),
  almarai(
    'Almarai',
    'Almarai (مختصر أنيق)',
    'assets/fonts/Almarai-Regular.ttf',
    'assets/fonts/Almarai-Bold.ttf',
  ),
  kufi(
    'NotoKufiArabic',
    'Noto Kufi Arabic (كوفي هندسي)',
    'assets/fonts/NotoKufiArabic-Regular.ttf',
    'assets/fonts/NotoKufiArabic-Bold.ttf',
  );

  const QuestionPrintFont(
    this.family,
    this.label,
    this.regularAsset,
    this.boldAsset,
  );

  final String family;
  final String label;
  final String regularAsset;
  final String boldAsset;
}

/// What the student-summary printer produces.
enum QuestionPrintMode {
  /// Official-style questions with model answers underneath each question.
  questionsAnswers,

  /// Grammar summary only (rules, examples and irab) without any questions.
  summaryOnly;

  /// Short Arabic label shown in the mode selector.
  String get label => switch (this) {
        QuestionPrintMode.questionsAnswers => 'أسئلة وأجوبة',
        QuestionPrintMode.summaryOnly => 'ملخص فقط',
      };
}

class QuestionPrintSettings {
  const QuestionPrintSettings({
    this.font = QuestionPrintFont.plex,
    this.bodyFontSize = defaultBodyFontSize,
    this.headingFontSize = defaultHeadingFontSize,
    this.includeAnswers = true,
    this.compactLines = false,
  });

  static const int minFontSize = 9;
  static const int maxFontSize = 24;
  static const int defaultBodyFontSize = 12;
  static const int defaultHeadingFontSize = 15;

  final QuestionPrintFont font;
  final int bodyFontSize;
  final int headingFontSize;
  final bool includeAnswers;

  /// Tight line spacing for dense handouts; shared by both print modes.
  final bool compactLines;

  static bool isValidFontSize(int? value) =>
      value != null && value >= minFontSize && value <= maxFontSize;

  bool get isValid =>
      isValidFontSize(bodyFontSize) && isValidFontSize(headingFontSize);

  /// PDF line spacing in points (compact mode packs lines closer together).
  double get pdfLineSpacing => compactLines ? 1.5 : 4;

  /// Vertical gap after each question / summary line in points.
  double get pdfItemGap => compactLines ? 3 : 8;

  /// Vertical gap before each section / topic heading in points.
  double get pdfHeadingGap => compactLines ? 6 : 10;
}
