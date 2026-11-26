import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/utils/arabic_text.dart';
import '../../domain/models/library.dart';
import '../../domain/models/question_print_settings.dart';
import '../../domain/services/question_print_plan.dart';

abstract final class QuestionPrinter {
  static Future<(pw.Font, pw.Font)> _loadFonts(
    QuestionPrintSettings settings,
    AssetBundle? bundle,
  ) async {
    final effectiveBundle = bundle ?? rootBundle;
    final regularData = await effectiveBundle.load(settings.font.regularAsset);
    final boldData = await effectiveBundle.load(settings.font.boldAsset);
    return (pw.Font.ttf(regularData), pw.Font.ttf(boldData));
  }

  static pw.Widget _underlinedPdfText(String text, pw.TextStyle style) {
    final segments = parseUnderlinedSegments(text);
    return pw.RichText(
      textDirection: pw.TextDirection.rtl,
      text: pw.TextSpan(
        style: style,
        children: <pw.InlineSpan>[
          for (final seg in segments)
            pw.TextSpan(
              text: seg.text,
              style: seg.underlined
                  ? style.copyWith(
                      decoration: pw.TextDecoration.underline,
                    )
                  : null,
            ),
        ],
      ),
    );
  }

  static Future<Uint8List> buildPdfBytes(
    QuestionPrintPlan plan,
    String partTitle, {
    AssetBundle? bundle,
  }) async {
    final (regularFont, boldFont) = await _loadFonts(plan.settings, bundle);

    final bodySize = plan.settings.bodyFontSize.toDouble();
    final headingSize = plan.settings.headingFontSize.toDouble();
    final lineSpacing = plan.settings.pdfLineSpacing;
    final itemGap = plan.settings.pdfItemGap;
    final headingGap = plan.settings.pdfHeadingGap;

    final baseStyle = pw.TextStyle(
      font: regularFont,
      fontBold: boldFont,
      fontSize: bodySize,
      lineSpacing: lineSpacing,
    );
    final boldStyle = pw.TextStyle(
      font: boldFont,
      fontSize: bodySize,
      fontWeight: pw.FontWeight.bold,
      lineSpacing: lineSpacing,
    );
    final sectionStyle = pw.TextStyle(
      font: boldFont,
      fontSize: headingSize,
      fontWeight: pw.FontWeight.bold,
      lineSpacing: lineSpacing,
    );

    final doc = pw.Document(
      title: 'بنك أسئلة اللغة العربية — $partTitle',
      author: 'بَيَان — الأول المتوسط',
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
        header: (pw.Context ctx) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 12),
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(width: 1)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: <pw.Widget>[
              pw.Text(
                'اللغة العربية للصف الأول المتوسط — $partTitle',
                style: boldStyle,
              ),
              pw.Text(
                plan.settings.includeAnswers
                    ? 'أسئلة المراجعة مع الأجوبة النموذجية'
                    : 'ورقة أسئلة بدون أجوبة',
                style: baseStyle.copyWith(fontSize: bodySize - 1),
              ),
            ],
          ),
        ),
        footer: (pw.Context ctx) => pw.Align(
          alignment: pw.Alignment.center,
          child: pw.Text(
            'صفحة ${toArabicDigits(ctx.pageNumber)} من ${toArabicDigits(ctx.pagesCount)}',
            style: baseStyle.copyWith(fontSize: bodySize - 1.5),
          ),
        ),
        build: (pw.Context ctx) {
          final widgets = <pw.Widget>[];

          for (final section in plan.sections) {
            if (section.questions.isEmpty) {
              continue;
            }
            widgets.add(
              pw.Padding(
                padding: pw.EdgeInsets.only(top: headingGap, bottom: 6),
                child: pw.Text(section.heading, style: sectionStyle),
              ),
            );
            for (var i = 0; i < section.questions.length; i++) {
              final q = section.questions[i];
              final numberPrefix = '${toArabicDigits(i + 1)}- ';
              final promptText = q.kind == QuestionKind.choice &&
                      q.options.isNotEmpty
                  ? '$numberPrefix${q.prompt.trim()} ( ${q.options.join(' – ')} )'
                  : '$numberPrefix${q.prompt.trim()}';
              widgets.add(
                pw.Padding(
                  padding: pw.EdgeInsets.only(bottom: itemGap),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: <pw.Widget>[
                      _underlinedPdfText(promptText, boldStyle),
                      if (plan.settings.includeAnswers &&
                          q.displayAnswer.trim().isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(right: 12, top: 2),
                          child: _underlinedPdfText(
                            'الجواب: ${q.displayAnswer}',
                            baseStyle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }
          }

          return widgets;
        },
      ),
    );

    return doc.save();
  }

  static Future<void> print(QuestionPrintPlan plan, String partTitle) async {
    await Printing.layoutPdf(
      name: 'أسئلة_اللغة_العربية_$partTitle.pdf',
      format: PdfPageFormat.a4,
      onLayout: (_) => buildPdfBytes(plan, partTitle),
    );
  }

  /// Builds the «ملخص فقط» PDF: grammar summaries with every topic heading
  /// in bold, sharing font, sizes and compact spacing with the questions PDF.
  static Future<Uint8List> buildSummaryPdfBytes(
    StudentSummaryPlan plan,
    String partTitle, {
    AssetBundle? bundle,
  }) async {
    final (regularFont, boldFont) = await _loadFonts(plan.settings, bundle);

    final bodySize = plan.settings.bodyFontSize.toDouble();
    final headingSize = plan.settings.headingFontSize.toDouble();
    final lineSpacing = plan.settings.pdfLineSpacing;
    final itemGap = plan.settings.pdfItemGap;
    final headingGap = plan.settings.pdfHeadingGap;

    final baseStyle = pw.TextStyle(
      font: regularFont,
      fontBold: boldFont,
      fontSize: bodySize,
      lineSpacing: lineSpacing,
    );
    final unitStyle = pw.TextStyle(
      font: boldFont,
      fontSize: headingSize,
      fontWeight: pw.FontWeight.bold,
      lineSpacing: lineSpacing,
    );
    // Every summary topic (موضوع) is rendered bold at heading size.
    final topicStyle = pw.TextStyle(
      font: boldFont,
      fontSize: headingSize,
      fontWeight: pw.FontWeight.bold,
      lineSpacing: lineSpacing,
    );

    final doc = pw.Document(
      title: 'ملخص الطالب — اللغة العربية — $partTitle',
      author: 'بَيَان — الأول المتوسط',
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
        header: (pw.Context ctx) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 12),
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(width: 1)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: <pw.Widget>[
              pw.Text(
                'اللغة العربية للصف الأول المتوسط — $partTitle',
                style: unitStyle.copyWith(fontSize: bodySize),
              ),
              pw.Text(
                'ملخص للطالب — قواعد فقط بدون أسئلة',
                style: baseStyle.copyWith(fontSize: bodySize - 1),
              ),
            ],
          ),
        ),
        footer: (pw.Context ctx) => pw.Align(
          alignment: pw.Alignment.center,
          child: pw.Text(
            'صفحة ${toArabicDigits(ctx.pageNumber)} من ${toArabicDigits(ctx.pagesCount)}',
            style: baseStyle.copyWith(fontSize: bodySize - 1.5),
          ),
        ),
        build: (pw.Context ctx) {
          final widgets = <pw.Widget>[];

          for (final summaryUnit in plan.units) {
            final unit = summaryUnit.unit;
            widgets.add(
              pw.Padding(
                padding: pw.EdgeInsets.only(top: headingGap, bottom: 6),
                child: pw.Text(
                  '${unit.displayTitle} — ${summaryUnit.lessonTitle}',
                  style: unitStyle,
                ),
              ),
            );
            if (summaryUnit.summary.trim().isNotEmpty) {
              widgets.add(
                pw.Padding(
                  padding: pw.EdgeInsets.only(bottom: itemGap),
                  child: _underlinedPdfText(
                    summaryUnit.summary.trim(),
                    baseStyle,
                  ),
                ),
              );
            }
            for (final topic in summaryUnit.topics) {
              widgets.add(
                pw.Padding(
                  padding: pw.EdgeInsets.only(top: headingGap, bottom: 4),
                  child: _underlinedPdfText(topic.heading, topicStyle),
                ),
              );
              for (final line in topic.lines) {
                final text = line.isBullet ? '• ${line.text}' : line.text;
                widgets.add(
                  pw.Padding(
                    padding: pw.EdgeInsets.only(bottom: itemGap),
                    child: _underlinedPdfText(text, baseStyle),
                  ),
                );
              }
            }
          }

          return widgets;
        },
      ),
    );

    return doc.save();
  }

  static Future<void> printSummary(
    StudentSummaryPlan plan,
    String partTitle,
  ) async {
    await Printing.layoutPdf(
      name: 'ملخص_الطالب_اللغة_العربية_$partTitle.pdf',
      format: PdfPageFormat.a4,
      onLayout: (_) => buildSummaryPdfBytes(plan, partTitle),
    );
  }
}
