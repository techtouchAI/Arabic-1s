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

class QuestionPrintSettings {
  const QuestionPrintSettings({
    this.font = QuestionPrintFont.plex,
    this.bodyFontSize = defaultBodyFontSize,
    this.headingFontSize = defaultHeadingFontSize,
    this.includeAnswers = true,
  });

  static const int minFontSize = 9;
  static const int maxFontSize = 24;
  static const int defaultBodyFontSize = 12;
  static const int defaultHeadingFontSize = 15;

  final QuestionPrintFont font;
  final int bodyFontSize;
  final int headingFontSize;
  final bool includeAnswers;

  static bool isValidFontSize(int? value) =>
      value != null && value >= minFontSize && value <= maxFontSize;

  bool get isValid =>
      isValidFontSize(bodyFontSize) && isValidFontSize(headingFontSize);
}
