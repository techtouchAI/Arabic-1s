/// OOXML `.docx` exam paper builder faithfully matching the 4 official Iraqi
/// First Intermediate Arabic Word examination papers:
/// - `الدور الاول.docx`
/// - `الدور الثاتيي.docx`
/// - `الدور الاول 2025.docx`
/// - `الدور الثاني 2025.docx`
///
/// Key structural guarantees:
/// 1. A4 portrait (`11906 × 16838` dxa), 0.5-inch (`720` dxa) margins on all
///    four sides (`printableWidthDxa = 10466`), `<w:bidi/>` and `<w:rtlGutter/>`.
/// 2. Borderless 3-column `<w:bidiVisual/>` header table (`3316 + 3834 + 3316`)
///    with optional student-name / exam-number bar and bottom rule (`sz="12"`).
/// 3. Right-aligned section titles with flush-left marks, as in the sources;
///    single-underlined section labels (`الانشاء : ( 30 درجة )`,
///    `قواعد اللغة العربية : ( 35 درجة )`, `الاملاء : ( 15 درجة )`).
/// 4. Degree badges sit on the same line as their question, flush with the
///    left margin. Word reads every tab/indent/alignment of a `w:bidi`
///    paragraph *logically*: `pos` is measured from the right (leading)
///    margin, `left` means start and `right` means end. The badge therefore
///    uses an end tab (`<w:tab w:val="right" w:pos="10466"/>`) so the badge
///    *ends* at the left margin, and an end indent (`<w:ind w:right=…/>`)
///    reserves the badge column so a long prompt wraps before it instead of
///    pushing the badge onto a line of its own. Word honours a custom tab stop
///    placed beyond the paragraph's end indent.
/// 5. Balanced `_..._` markers in prompts and items emit `<w:u w:val="single"/>`
///    runs for underlined words/phrases (`اعرب ما تحته خط`, etc.).
/// 6. Supports `vertical`, `inline`, and `prose` item layouts, closing wish,
///    and left-aligned `مدرس المادة` / `<اسم المدرس>` signature block.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../../../core/utils/arabic_text.dart';
import '../../../domain/models/exam_paper.dart';
import '../../../domain/services/exam_layout_plan.dart';
import 'stored_zip_writer.dart';

class ExamDocxBuilder {
  const ExamDocxBuilder._();

  static const int pageWidthDxa = 11906;
  static const int pageHeightDxa = 16838;
  static const int marginDxa = 720;
  static const int printableWidthDxa = pageWidthDxa - (marginDxa * 2); // 10466

  static Uint8List build(ArabicExamPaper paper) {
    final fontName = paper.typography.font.family;
    final entries = <String, List<int>>{
      '[Content_Types].xml': utf8.encode(_contentTypesXml),
      '_rels/.rels': utf8.encode(_rootRelsXml),
      'docProps/core.xml': utf8.encode(_corePropsXml(paper)),
      'docProps/app.xml': utf8.encode(_appPropsXml),
      'word/_rels/document.xml.rels': utf8.encode(_documentRelsXml),
      'word/styles.xml': utf8.encode(_stylesXml(paper)),
      'word/fontTable.xml': utf8.encode(_fontTableXml(fontName)),
      'word/settings.xml': utf8.encode(_settingsXml),
      'word/numbering.xml': utf8.encode(_numberingXml(fontName)),
      'word/document.xml': utf8.encode(_documentXml(paper)),
    };
    return buildStoredZip(entries);
  }

  static String _documentXml(ArabicExamPaper paper) {
    final bodyHalfPt = paper.typography.bodySizePt * 2;
    final headingHalfPt = paper.typography.headingSizePt * 2;
    // The reference header uses regular 14-point text independently of the body.
    const headerHalfPt = ExamHeaderLayout.fontSizePt * 2;
    final font = _esc(paper.typography.font.family);

    final buf = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write(
        '<w:document '
        'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<w:body>',
      );

    // 1. Official 3-column RTL header table
    buf.write(_buildHeaderTable(paper, font, headerHalfPt));

    // 2. Optional student name & exam number line + solid divider rule
    if (paper.header.includeStudentFields) {
      buf.write(
        '<w:p><w:pPr>'
        '<w:pBdr><w:bottom w:val="single" w:sz="12" w:space="1" w:color="000000"/></w:pBdr>'
        // Start tab (logical `left`) at the page centre: the exam-number label
        // begins in the left half, exactly like the two-column preview.
        '<w:tabs><w:tab w:val="left" w:pos="${printableWidthDxa ~/ 2}"/></w:tabs>'
        '<w:bidi/>'
        '<w:spacing w:before="0" w:after="100" w:line="240" w:lineRule="auto"/>'
        '</w:pPr>'
        '${_run(paper.header.studentNameLabel, font, headerHalfPt, bold: false)}'
        '<w:r>${_rPr(font, headerHalfPt, bold: false)}<w:tab/></w:r>'
        '${_run(paper.header.studentNumberLabel, font, headerHalfPt, bold: false)}'
        '</w:p>',
      );
    } else {
      buf.write(
        '<w:p><w:pPr>'
        '<w:pBdr><w:bottom w:val="single" w:sz="12" w:space="4" w:color="000000"/></w:pBdr>'
        '<w:bidi/>'
        '<w:spacing w:before="20" w:after="90" w:line="240" w:lineRule="auto"/>'
        '</w:pPr></w:p>',
      );
    }

    // One canonical ordering/spacing plan for both renderers.
    for (final paragraph in ExamLayoutPlan.build(paper)) {
      buf.write(_layoutParagraph(paragraph, paper, font,
          paragraph.kind == ExamParagraphKind.heading
              ? headingHalfPt
              : bodyHalfPt));
    }

    // 6. Closing wish
    if (paper.header.closingWish.trim().isNotEmpty) {
      buf.write(
        '<w:p><w:pPr>'
        '<w:bidi/>'
        '<w:spacing w:before="140" w:after="80" w:line="260" w:lineRule="auto"/>'
        '<w:jc w:val="center"/>'
        '</w:pPr>'
        '${_run(paper.header.closingWish.trim(), font, bodyHalfPt, bold: true)}'
        '</w:p>',
      );
    }

    // 7. Teacher signature block (flush-left in RTL via left-aligned table / paragraph)
    buf.write(_buildSignatureBlock(paper, font, bodyHalfPt));

    // 8. A4 Section properties
    buf.write(
      '<w:sectPr>'
      '<w:pgSz w:w="$pageWidthDxa" w:h="$pageHeightDxa"/>'
      '<w:pgMar w:top="$marginDxa" w:right="$marginDxa" w:bottom="$marginDxa" '
      'w:left="$marginDxa" w:header="360" w:footer="360" w:gutter="0"/>'
      '<w:bidi/>'
      '<w:rtlGutter/>'
      '</w:sectPr>'
      '</w:body></w:document>',
    );

    return buf.toString();
  }

  static String _buildHeaderTable(
    ArabicExamPaper paper,
    String font,
    int halfPt,
  ) {
    final cells = ExamHeaderLayout.build(paper);

    String cellXml(List<String> lines, int widthDxa) {
      final pXml = StringBuffer();
      for (final line in lines) {
        pXml.write(
          '<w:p><w:pPr>'
          '<w:bidi/>'
          '<w:spacing w:before="0" w:after="24" w:line="240" w:lineRule="auto"/>'
          '<w:jc w:val="center"/>'
          '</w:pPr>'
          '${_run(line, font, halfPt, bold: false)}'
          '</w:p>',
        );
      }
      if (lines.isEmpty) {
        pXml.write('<w:p><w:pPr><w:bidi/></w:pPr></w:p>');
      }
      return '<w:tc>'
          '<w:tcPr><w:tcW w:w="$widthDxa" w:type="dxa"/><w:vAlign w:val="top"/></w:tcPr>'
          '$pXml'
          '</w:tc>';
    }

    return '<w:tbl>'
        '<w:tblPr>'
        '<w:bidiVisual/>'
        '<w:tblW w:w="$printableWidthDxa" w:type="dxa"/>'
        '<w:tblBorders>'
        '<w:top w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
        '<w:left w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
        '<w:bottom w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
        '<w:right w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
        '<w:insideH w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
        '<w:insideV w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
        '</w:tblBorders>'
        '<w:tblLayout w:type="fixed"/>'
        '</w:tblPr>'
        '<w:tblGrid>'
        '<w:gridCol w:w="${ExamHeaderLayout.columnWidthsDxa[0]}"/>'
        '<w:gridCol w:w="${ExamHeaderLayout.columnWidthsDxa[1]}"/>'
        '<w:gridCol w:w="${ExamHeaderLayout.columnWidthsDxa[2]}"/>'
        '</w:tblGrid>'
        '<w:tr>'
        '${cellXml(cells[0], ExamHeaderLayout.columnWidthsDxa[0])}'
        '${cellXml(cells[1], ExamHeaderLayout.columnWidthsDxa[1])}'
        '${cellXml(cells[2], ExamHeaderLayout.columnWidthsDxa[2])}'
        '</w:tr>'
        '</w:tbl>';
  }

  static String _layoutParagraph(
    ExamLayoutParagraph paragraph,
    ArabicExamPaper paper,
    String font,
    int halfPt,
  ) {
    final before = (paragraph.spaceBeforePt * 20).round();
    final line = (paper.typography.spacing.lineHeight * 240).round();
    final startIndent = (paragraph.indentPt * 20).round();
    final degree = paragraph.degree;
    final badge = degree == null
        ? null
        : ExamDegreeBadge.text(
            degree,
            westernDigits: paper.typography.useWesternDigits,
          );
    final endIndent = badge == null
        ? 0
        : (ExamDegreeBadge.columnWidthPt(badge, halfPt / 2) * 20).ceil();
    // Alignment is left to the RTL default (start = right edge): an explicit
    // `w:jc="right"` means *end* in a Word bidi paragraph, i.e. flush left.
    return '<w:p><w:pPr>'
        '${paragraph.keepWithNext ? '<w:keepNext/>' : ''}'
        '<w:keepLines/>'
        '${badge != null ? '<w:tabs><w:tab w:val="right" w:pos="$printableWidthDxa"/></w:tabs>' : ''}'
        '<w:bidi/>'
        '<w:spacing w:before="$before" w:after="0" w:line="$line" w:lineRule="auto"/>'
        '${_indentXml(startDxa: startIndent, endDxa: endIndent)}'
        '</w:pPr>'
        '${_richRuns(paragraph.text, font: font, sizeHalfPt: halfPt)}'
        '${badge != null ? '<w:r>${_rPr(font, halfPt)}<w:tab/></w:r>${_run(badge, font, halfPt)}' : ''}'
        '</w:p>';
  }

  /// `w:left`/`w:right` are the start/end indents of a bidi paragraph.
  static String _indentXml({required int startDxa, required int endDxa}) {
    if (startDxa <= 0 && endDxa <= 0) {
      return '';
    }
    return '<w:ind'
        '${startDxa > 0 ? ' w:left="$startDxa"' : ''}'
        '${endDxa > 0 ? ' w:right="$endDxa"' : ''}'
        '/>';
  }

  static String _richRuns(
    String source, {
    required String font,
    required int sizeHalfPt,
    bool bold = true,
  }) {
    final segments = parseUnderlinedSegments(source);
    final buf = StringBuffer();
    for (final seg in segments) {
      buf.write(
        _run(
          seg.text,
          font,
          sizeHalfPt,
          bold: bold,
          underline: seg.underlined,
        ),
      );
    }
    return buf.toString();
  }

  static String _buildSignatureBlock(
    ArabicExamPaper paper,
    String font,
    int halfPt,
  ) {
    final title = paper.header.teacherTitle.trim();
    final name = paper.header.teacherName.trim();
    if (title.isEmpty && name.isEmpty) {
      return '';
    }
    // In a bidiVisual 2-column table: col 1 (right, 7066 dxa) is empty spacer,
    // col 2 (left, 3400 dxa) centers "مدرس المادة" above the teacher's name.
    final sigParagraphs = StringBuffer();
    if (title.isNotEmpty) {
      sigParagraphs.write(
        '<w:p><w:pPr><w:bidi/><w:spacing w:before="40" w:after="20"/><w:jc w:val="center"/></w:pPr>'
        '${_run(title, font, halfPt, bold: true)}</w:p>',
      );
    }
    if (name.isNotEmpty) {
      sigParagraphs.write(
        '<w:p><w:pPr><w:bidi/><w:spacing w:before="10" w:after="20"/><w:jc w:val="center"/></w:pPr>'
        '${_run(name, font, halfPt, bold: true)}</w:p>',
      );
    }
    return '<w:tbl>'
        '<w:tblPr>'
        '<w:bidiVisual/>'
        '<w:tblW w:w="$printableWidthDxa" w:type="dxa"/>'
        '<w:tblBorders>'
        '<w:top w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
        '<w:left w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
        '<w:bottom w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
        '<w:right w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
        '<w:insideH w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
        '<w:insideV w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
        '</w:tblBorders>'
        '<w:tblLayout w:type="fixed"/>'
        '</w:tblPr>'
        '<w:tblGrid><w:gridCol w:w="7066"/><w:gridCol w:w="3400"/></w:tblGrid>'
        '<w:tr>'
        '<w:tc><w:tcPr><w:tcW w:w="7066" w:type="dxa"/></w:tcPr><w:p><w:pPr><w:bidi/></w:pPr></w:p></w:tc>'
        '<w:tc><w:tcPr><w:tcW w:w="3400" w:type="dxa"/></w:tcPr>$sigParagraphs</w:tc>'
        '</w:tr>'
        '</w:tbl>';
  }

  static String _rPr(
    String escapedFont,
    int halfPt, {
    bool bold = true,
    bool underline = false,
  }) {
    final bXml = bold ? '<w:b/><w:bCs/>' : '';
    final uXml = underline ? '<w:u w:val="single"/>' : '';
    // Children follow the CT_RPr schema order (`w:u` comes after `w:szCs`).
    return '<w:rPr>'
        '<w:rFonts w:ascii="$escapedFont" w:hAnsi="$escapedFont" w:cs="$escapedFont"/>'
        '$bXml'
        '<w:sz w:val="$halfPt"/><w:szCs w:val="$halfPt"/>'
        '$uXml'
        '<w:rtl/>'
        '<w:lang w:val="en-US" w:bidi="ar-IQ"/>'
        '</w:rPr>';
  }

  static String _run(
    String text,
    String escapedFont,
    int halfPt, {
    bool bold = true,
    bool underline = false,
  }) =>
      '<w:r>'
      '${_rPr(escapedFont, halfPt, bold: bold, underline: underline)}'
      '${text.split('\n').map((line) => '<w:t xml:space="preserve">${_esc(line)}</w:t>').join('<w:br/>')}'
      '</w:r>';

  static String _esc(String raw) => raw
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  static const String _contentTypesXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
      '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
      '<Override PartName="/word/settings.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/>'
      '<Override PartName="/word/fontTable.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.fontTable+xml"/>'
      '<Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/>'
      '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
      '<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>'
      '</Types>';

  static const String _rootRelsXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
      '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>'
      '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>'
      '</Relationships>';

  static const String _documentRelsXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
      '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings" Target="settings.xml"/>'
      '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/fontTable" Target="fontTable.xml"/>'
      '<Relationship Id="rId4" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/>'
      '</Relationships>';

  static String _corePropsXml(ArabicExamPaper paper) =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<cp:coreProperties '
      'xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
      'xmlns:dc="http://purl.org/dc/elements/1.1/" '
      'xmlns:dcterms="http://purl.org/dc/terms/" '
      'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
      '<dc:title>${_esc('${paper.header.examTitleLine} — ${paper.header.subjectLine}')}</dc:title>'
      '<dc:subject>اللغة العربية — الأول المتوسط</dc:subject>'
      '<dc:creator>${_esc(paper.header.teacherName.isEmpty ? 'تطبيق بيان' : paper.header.teacherName)}</dc:creator>'
      '<dcterms:created xsi:type="dcterms:W3CDTF">2026-01-01T00:00:00Z</dcterms:created>'
      '<dcterms:modified xsi:type="dcterms:W3CDTF">2026-01-01T00:00:00Z</dcterms:modified>'
      '</cp:coreProperties>';

  static const String _appPropsXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">'
      '<Application>Bayan — First Intermediate Arabic</Application>'
      '</Properties>';

  static String _stylesXml(ArabicExamPaper paper) {
    final font = _esc(paper.typography.font.family);
    final halfPt = paper.typography.bodySizePt * 2;
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:docDefaults>'
        '<w:rPrDefault><w:rPr>'
        '<w:rFonts w:ascii="$font" w:hAnsi="$font" w:cs="$font"/>'
        '<w:sz w:val="$halfPt"/><w:szCs w:val="$halfPt"/>'
        '<w:lang w:val="en-US" w:bidi="ar-IQ"/>'
        '</w:rPr></w:rPrDefault>'
        '<w:pPrDefault><w:pPr><w:bidi/></w:pPr></w:pPrDefault>'
        '</w:docDefaults>'
        '<w:style w:type="paragraph" w:default="1" w:styleId="Normal">'
        '<w:name w:val="Normal"/>'
        '<w:pPr><w:bidi/></w:pPr>'
        '</w:style>'
        '</w:styles>';
  }

  static String _fontTableXml(String fontName) {
    final f = _esc(fontName);
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:fonts xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:font w:name="$f"><w:charset w:val="00"/><w:family w:val="swiss"/><w:pitch w:val="variable"/></w:font>'
        '<w:font w:name="Arial"><w:charset w:val="00"/><w:family w:val="swiss"/><w:pitch w:val="variable"/></w:font>'
        '<w:font w:name="Times New Roman"><w:charset w:val="00"/><w:family w:val="roman"/><w:pitch w:val="variable"/></w:font>'
        '</w:fonts>';
  }

  static const String _settingsXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
      '<w:zoom w:percent="100"/>'
      '<w:defaultTabStop w:val="720"/>'
      '<w:compat>'
      '<w:compatSetting w:name="compatibilityMode" w:uri="http://schemas.microsoft.com/office/word" w:val="15"/>'
      '</w:compat>'
      '</w:settings>';

  static String _numberingXml(String fontName) {
    final f = _esc(fontName);
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:abstractNum w:abstractNumId="0">'
        '<w:lvl w:ilvl="0">'
        '<w:start w:val="1"/>'
        '<w:numFmt w:val="decimal"/>'
        '<w:lvlText w:val="%1-"/>'
        '<w:lvlJc w:val="right"/>'
        '<w:pPr><w:bidi/><w:ind w:left="360" w:hanging="240"/></w:pPr>'
        '<w:rPr><w:rFonts w:ascii="$f" w:hAnsi="$f" w:cs="$f"/><w:b/><w:bCs/></w:rPr>'
        '</w:lvl>'
        '</w:abstractNum>'
        '<w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num>'
        '</w:numbering>';
  }
}
