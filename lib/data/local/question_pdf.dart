import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/utils/arabic_text.dart';
import '../../domain/models/library.dart';
import '../../domain/services/question_print_plan.dart';

abstract final class QuestionPrinter {
  static Future<Uint8List> buildPdfBytes(
    QuestionPrintPlan plan,
    String partTitle, {
    AssetBundle? bundle,
  }) async {
    final effectiveBundle = bundle ?? rootBundle;
    final regularData = await effectiveBundle.load(plan.settings.font.regularAsset);
    final boldData = await effectiveBundle.load(plan.settings.font.boldAsset);
    final regularFont = pw.Font.ttf(regularData);
    final boldFont = pw.Font.ttf(boldData);

    final bodySize = plan.settings.bodyFontSize.toDouble();
    final headingSize = plan.settings.headingFontSize.toDouble();

    final baseStyle = pw.TextStyle(
      font: regularFont,
      fontBold: boldFont,
      fontSize: bodySize,
      lineSpacing: 4,
    );
    final boldStyle = pw.TextStyle(
      font: boldFont,
      fontSize: bodySize,
      fontWeight: pw.FontWeight.bold,
      lineSpacing: 4,
    );
    final sectionStyle = pw.TextStyle(
      font: boldFont,
      fontSize: headingSize,
      fontWeight: pw.FontWeight.bold,
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

          void addSection(
            String heading,
            List<Question> items,
            pw.Widget Function(int idx, Question q) itemBuilder,
          ) {
            if (items.isEmpty) {
              return;
            }
            widgets.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 10, bottom: 6),
                child: pw.Text(heading, style: sectionStyle),
              ),
            );
            for (var i = 0; i < items.length; i++) {
              widgets.add(itemBuilder(i + 1, items[i]));
            }
          }

          addSection(
            'أولاً: أسئلة الصح والخطأ',
            plan.trueFalseQuestions,
            (int idx, Question q) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: <pw.Widget>[
                  pw.Text(
                    '${toArabicDigits(idx)}- ${q.prompt}',
                    style: boldStyle,
                  ),
                  if (plan.settings.includeAnswers)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(right: 12, top: 2),
                      child: pw.Text(
                        'الجواب: ${q.displayAnswer}',
                        style: baseStyle,
                      ),
                    ),
                ],
              ),
            ),
          );

          addSection(
            'ثانياً: أسئلة الاختيار من متعدد',
            plan.choiceQuestions,
            (int idx, Question q) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: <pw.Widget>[
                  pw.Text(
                    '${toArabicDigits(idx)}- ${q.prompt}',
                    style: boldStyle,
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(right: 12, top: 2),
                    child: pw.Wrap(
                      spacing: 14,
                      runSpacing: 3,
                      children: <pw.Widget>[
                        for (var o = 0; o < q.options.length; o++)
                          pw.Text('(${_arabicLetter(o)}) ${q.options[o]}', style: baseStyle),
                      ],
                    ),
                  ),
                  if (plan.settings.includeAnswers)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(right: 12, top: 2),
                      child: pw.Text(
                        'الجواب الصحيح: ${q.displayAnswer}',
                        style: boldStyle,
                      ),
                    ),
                ],
              ),
            ),
          );

          addSection(
            'ثالثاً: الأسئلة المقالية والتطبيقية',
            plan.openQuestions,
            (int idx, Question q) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: <pw.Widget>[
                  pw.Text(
                    '${toArabicDigits(idx)}- ${q.prompt}',
                    style: boldStyle,
                  ),
                  if (plan.settings.includeAnswers)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(right: 12, top: 2),
                      child: pw.Text(
                        'الجواب: ${q.displayAnswer}',
                        style: baseStyle,
                      ),
                    ),
                ],
              ),
            ),
          );

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

  static String _arabicLetter(int index) {
    const letters = <String>['أ', 'ب', 'ج', 'د', 'هـ'];
    return index < letters.length ? letters[index] : '${index + 1}';
  }
}
