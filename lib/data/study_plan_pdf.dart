/// PDF rendering for the daily and annual study-plan sheets.
///
/// The plan sheets are printed through the same A4 pipeline as the exam
/// papers: fixed A4 page size, embedded Arabic fonts, no external assets.
/// Building the document with the `pdf` widgets (rather than an HTML
/// pipeline) keeps printing deterministic, offline and unit-testable, and
/// lets the teacher's column visibility and typography settings map directly
/// onto the printed sheet.
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/utils/arabic_text.dart';
import '../domain/models/study_plan.dart';

class StudyPlanPdf {
  const StudyPlanPdf._();

  static const PdfColor _teal = PdfColor(0xFF0F766E);
  static const PdfColor _ink = PdfColor(0xFF232229);
  static const PdfColor _muted = PdfColor(0xFF5C5866);
  static const PdfColor _line = PdfColor(0xFF94A3B8);
  static const PdfColor _total = PdfColor(0xFFCCFBF1);

  /// Renders [plans] for [mode] to A4 PDF bytes. [settings] controls
  /// typography and column visibility; an invalid setting is rejected before
  /// rendering so the printed sheet is never malformed.
  static Future<Uint8List> buildPlanPdfBytes({
    required StudyPlanMode mode,
    required StudyPlans plans,
    required AssetBundle bundle,
  }) async {
    final settings = plans.settings;
    if (!settings.isValid) {
      throw ArgumentError.value(
        settings,
        'settings',
        'bodyFontSize and headingFontSize must be within '
        '${StudyPlanSettings.minFontSize}..${StudyPlanSettings.maxFontSize}',
      );
    }

    final (regular, bold) = await _loadFonts(settings, bundle);
    final bodySize = settings.bodyFontSize.toDouble();
    final headingSize = settings.headingFontSize.toDouble();

    final bodyStyle = pw.TextStyle(
      font: regular,
      fontSize: bodySize,
      color: _ink,
    );
    final boldBody = pw.TextStyle(
      font: bold,
      fontSize: bodySize,
      fontWeight: pw.FontWeight.bold,
      color: _ink,
    );
    final titleStyle = pw.TextStyle(
      font: bold,
      fontSize: headingSize * 1.6,
      fontWeight: pw.FontWeight.bold,
      color: _ink,
    );
    final subtitleStyle = pw.TextStyle(
      font: regular,
      fontSize: bodySize * 0.85,
      color: _muted,
    );

    final title = mode == StudyPlanMode.annual
        ? 'الخطة السنوية'
        : 'الخطة اليومية';
    final subtitle = mode == StudyPlanMode.annual
        ? 'المنهج التكاملي — اللغة العربية للصف الأول المتوسط'
        : 'جدول التدريس اليومي — ${toArabicDigits(plans.dailyEntries.length)} يوماً';

    final body = mode == StudyPlanMode.annual
        ? _annualTable(plans, bodyStyle, boldBody)
        : _dailyTable(plans, bodyStyle, boldBody);

    final doc = pw.Document(
      title: title,
      author: 'بَيَان — الأول المتوسط',
    );
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        header: (pw.Context ctx) => pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: const pw.BoxDecoration(
            color: _teal,
            borderRadius: pw.BorderRadius.only(
              topLeft: pw.Radius.circular(8),
              topRight: pw.Radius.circular(8),
            ),
          ),
          child: pw.Column(
            children: <pw.Widget>[
              pw.Text(title, style: titleStyle.copyWith(color: const PdfColor(0xFFFFFFFF))),
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 4),
                child: pw.Text(subtitle, style: subtitleStyle.copyWith(color: const PdfColor(0xFFE6F4F5))),
              ),
            ],
          ),
        ),
        build: (pw.Context ctx) => <pw.Widget>[
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 10),
            child: body,
          ),
        ],
        footer: (pw.Context ctx) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 12),
          padding: const pw.EdgeInsets.only(top: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: _line, width: 0.5),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: <pw.Widget>[
              pw.Text('منصة بيان للتعليم — $title', style: subtitleStyle),
              pw.Text('الطباعة: A4', style: subtitleStyle),
            ],
          ),
        ),
      ),
    );

    return doc.save();
  }

  static Future<(pw.Font, pw.Font)> _loadFonts(
    StudyPlanSettings settings,
    AssetBundle bundle,
  ) async {
    final regularData = await bundle.load(settings.font.regularAsset);
    final boldData = await bundle.load(settings.font.boldAsset);
    return (pw.Font.ttf(regularData), pw.Font.ttf(boldData));
  }

  static pw.Widget _annualTable(
    StudyPlans plans,
    pw.TextStyle bodyStyle,
    pw.TextStyle boldStyle,
  ) {
    final visible = StudyPlanColumns.annual
        .where((c) => plans.settings.visibleAnnualColumns.contains(c.id))
        .toList(growable: false);
    final totalWeight = visible.fold(0, (sum, c) => sum + c.weight);

    final compact = plans.settings.compactLines;
    final pad = compact ? 3.0 : 6.0;

    pw.Widget cell(String text, {bool bold = false, bool center = false, PdfColor? background}) {
      return pw.TableCell(
        padding: pw.EdgeInsets.all(pad),
        decoration: pw.BoxDecoration(
          color: background,
          border: pw.Border.all(color: _line, width: 0.5),
        ),
        child: pw.Align(
          alignment: center ? pw.Alignment.center : pw.Alignment.topRight,
          child: pw.Text(text, style: bold ? boldStyle : bodyStyle),
        ),
      );
    }

    final header = pw.TableRow(
      decoration: pw.BoxDecoration(color: _teal),
      children: visible
          .map((c) => cell(c.label, bold: true, center: true, background: _teal))
          .toList(growable: false),
    );

    String annualText(AnnualPlanRow row, String id) {
      switch (id) {
        case 'index':
          return toArabicDigits(row.id.split('-').last);
        case 'unit':
          return row.unitLabel;
        case 'pages':
          return row.pages;
        case 'reading':
          return row.readingTitle;
        case 'grammar':
          return row.grammarTitle;
        case 'orthography':
          return row.orthographyTitle.isNotEmpty
              ? row.orthographyTitle
              : '—';
        case 'days':
          return toArabicDigits(row.teachingDays);
        case 'week':
          return toArabicDigits(row.startWeek);
        case 'exam':
          return row.examFocus;
        default:
          return row.notes;
      }
    }

    final centered = <String>{'index', 'pages', 'days', 'week'};
    final dataRows = <pw.TableRow>[
      for (final row in plans.annualRows)
        pw.TableRow(
          children: visible
              .map((c) => cell(
                    annualText(row, c.id),
                    center: centered.contains(c.id),
                  ))
              .toList(growable: false),
        ),
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _total),
        children: <pw.TableCell>[
          pw.TableCell(
            colspan: visible.length,
            decoration: pw.BoxDecoration(
              color: _total,
              border: pw.Border.all(color: _line, width: 0.5),
            ),
            child: pw.Align(
              alignment: pw.Alignment.center,
              child: pw.Text(
                'المجموع: ${toArabicDigits(plans.totalTeachingDays)} يوماً دراسياً — الفصول: ${toArabicDigits(plans.totalWeeks)} أسبوعاً',
                style: boldStyle,
              ),
            ),
          ),
        ],
      ),
    ];

    return pw.Table(
      columnWidths: visible
          .map((c) => pw.ColumnWidth.fraction(c.weight / totalWeight))
          .toList(growable: false),
      border: pw.TableBorder.all(color: _line, width: 0.5),
      children: <pw.TableRow>[header, ...dataRows],
    );
  }

  static pw.Widget _dailyTable(
    StudyPlans plans,
    pw.TextStyle bodyStyle,
    pw.TextStyle boldStyle,
  ) {
    final visible = StudyPlanColumns.daily
        .where((c) => plans.settings.visibleDailyColumns.contains(c.id))
        .toList(growable: false);
    final totalWeight = visible.fold(0, (sum, c) => sum + c.weight);

    final compact = plans.settings.compactLines;
    final pad = compact ? 3.0 : 6.0;

    pw.Widget cell(String text, {bool bold = false, bool center = false, PdfColor? background}) {
      return pw.TableCell(
        padding: pw.EdgeInsets.all(pad),
        decoration: pw.BoxDecoration(
          color: background,
          border: pw.Border.all(color: _line, width: 0.5),
        ),
        child: pw.Align(
          alignment: center ? pw.Alignment.center : pw.Alignment.topRight,
          child: pw.Text(text, style: bold ? boldStyle : bodyStyle),
        ),
      );
    }

    final header = pw.TableRow(
      decoration: pw.BoxDecoration(color: _teal),
      children: visible
          .map((c) => cell(c.label, bold: true, center: true, background: _teal))
          .toList(growable: false),
    );

    String dailyText(DailyPlanEntry entry, String id) {
      switch (id) {
        case 'day':
          return entry.dayLabel;
        case 'date':
          return entry.dateText.isEmpty ? '—' : entry.dateText;
        case 'focus':
          return entry.focus;
        case 'content':
          return entry.content;
        case 'homework':
          return entry.homework.isEmpty ? '—' : entry.homework;
        case 'notes':
          return entry.notes;
        default:
          return entry.done ? '✓' : '—';
      }
    }

    final centered = <String>{'date', 'done'};
    final dataRows = <pw.TableRow>[
      for (final entry in plans.dailyEntries)
        pw.TableRow(
          children: visible
              .map((c) => cell(
                    dailyText(entry, c.id),
                    center: centered.contains(c.id),
                    bold: c.id == 'done',
                  ))
              .toList(growable: false),
        ),
    ];

    return pw.Table(
      columnWidths: visible
          .map((c) => pw.ColumnWidth.fraction(c.weight / totalWeight))
          .toList(growable: false),
      border: pw.TableBorder.all(color: _line, width: 0.5),
      children: <pw.TableRow>[header, ...dataRows],
    );
  }
}
