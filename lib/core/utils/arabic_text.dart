/// Utilities for Arabic digits, diacritic-insensitive search normalization,
/// and `_underlined_` exam span parsing.
library;

const List<String> _arabicDigits = <String>[
  '٠',
  '١',
  '٢',
  '٣',
  '٤',
  '٥',
  '٦',
  '٧',
  '٨',
  '٩',
];

/// Converts ASCII digits `0–9` in [input] to Arabic-Indic digits `٠–٩`.
String toArabicDigits(Object input) {
  final text = input.toString();
  final buffer = StringBuffer();
  for (final codeUnit in text.codeUnits) {
    if (codeUnit >= 0x30 && codeUnit <= 0x39) {
      buffer.write(_arabicDigits[codeUnit - 0x30]);
    } else {
      buffer.writeCharCode(codeUnit);
    }
  }
  return buffer.toString();
}

/// Converts Arabic-Indic (`٠–٩`) and Eastern (`۰–۹`) digits to ASCII `0–9`.
String toWesternDigits(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    if (rune >= 0x0660 && rune <= 0x0669) {
      buffer.writeCharCode(0x30 + (rune - 0x0660));
    } else if (rune >= 0x06F0 && rune <= 0x06F9) {
      buffer.writeCharCode(0x30 + (rune - 0x06F0));
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

/// Parses an integer written in Western or Arabic digits.
int? parseIntegerDigits(String raw) {
  final cleaned = toWesternDigits(raw.trim());
  if (cleaned.isEmpty) {
    return null;
  }
  return int.tryParse(cleaned);
}

final RegExp _diacriticsAndTatweel = RegExp(r'[\u064B-\u065F\u0670\u0640]');
final RegExp _multiSpace = RegExp(r'\s+');

/// Normalizes Arabic text for instant, forgiving search regardless of harakat,
/// hamza variants, alif maqsura, or taa marbuta.
String normalizeArabicForSearch(String input) {
  var result = toWesternDigits(input.toLowerCase());
  result = result.replaceAll(_diacriticsAndTatweel, '');
  result = result
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ٱ', 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ؤ', 'ء')
      .replaceAll('ئ', 'ء')
      .replaceAll('ة', 'ه')
      .replaceAll('_', '');
  return result.replaceAll(_multiSpace, ' ').trim();
}

/// Represents a text span that may be underlined in official Arabic exams
/// (encoded as `_فَسَقَى لَهُمَا_` in exam bank items).
class UnderlinedSegment {
  const UnderlinedSegment({required this.text, required this.underlined});

  final String text;
  final bool underlined;
}

/// Splits [source] on balanced `_..._` markers into plain and underlined spans.
List<UnderlinedSegment> parseUnderlinedSegments(String source) {
  if (!source.contains('_')) {
    return <UnderlinedSegment>[UnderlinedSegment(text: source, underlined: false)];
  }
  final parts = source.split('_');
  // If unbalanced, render literally without stripping underscores.
  if (parts.length.isEven) {
    return <UnderlinedSegment>[UnderlinedSegment(text: source, underlined: false)];
  }
  final segments = <UnderlinedSegment>[];
  for (var i = 0; i < parts.length; i++) {
    final text = parts[i];
    if (text.isEmpty) {
      continue;
    }
    segments.add(UnderlinedSegment(text: text, underlined: i.isOdd));
  }
  return segments.isEmpty
      ? <UnderlinedSegment>[const UnderlinedSegment(text: '', underlined: false)]
      : segments;
}

/// Formats an Iraqi Arabic degree label (`درجة واحدة`, `درجتان`, `٥ درجات`, `١٥ درجة`).
String formatDegreeLabel(int degree, {bool westernDigits = false}) {
  String numStr(int n) => westernDigits ? '$n' : toArabicDigits(n);
  if (degree == 1) {
    return '${numStr(1)} درجة';
  }
  if (degree == 2) {
    return 'درجتان';
  }
  if (degree >= 3 && degree <= 10) {
    return '${numStr(degree)} درجات';
  }
  return '${numStr(degree)} درجة';
}
