import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/models/exam_paper.dart';
import 'docx/exam_docx_builder.dart';

enum ExportOutcomeKind { savedToFile, shared, cancelled }

class ExportOutcome {
  const ExportOutcome({required this.kind, this.filePath});

  final ExportOutcomeKind kind;
  final String? filePath;
}

class ExamDocumentExporter {
  const ExamDocumentExporter();

  static const String docxMimeType =
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

  Future<ExportOutcome> exportDocx(ArabicExamPaper paper) async {
    final Uint8List bytes = ExamDocxBuilder.build(paper);
    final sanitizedRound = paper.header.roundLine
        .replaceAll(RegExp(r'[^\u0621-\u064A0-9a-zA-Z _-]'), '')
        .trim()
        .replaceAll(' ', '_');
    final suggestedName = sanitizedRound.isEmpty
        ? 'أسئلة_اللغة_العربية_الأول_المتوسط.docx'
        : 'أسئلة_العربية_الأول_المتوسط_$sanitizedRound.docx';

    // Desktop platforms (Windows / Linux / macOS): native Save-As file dialog.
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      final FileSaveLocation? location = await getSaveLocation(
        suggestedName: suggestedName,
        acceptedTypeGroups: const <XTypeGroup>[
          XTypeGroup(
            label: 'Microsoft Word (.docx)',
            extensions: <String>['docx'],
          ),
        ],
      );
      if (location == null) {
        return const ExportOutcome(kind: ExportOutcomeKind.cancelled);
      }
      var targetPath = location.path;
      if (!targetPath.toLowerCase().endsWith('.docx')) {
        targetPath = '$targetPath.docx';
      }
      final file = File(targetPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      return ExportOutcome(
        kind: ExportOutcomeKind.savedToFile,
        filePath: file.path,
      );
    }

    // Android / mobile: write to temporary file and open native system share sheet.
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$suggestedName');
    await tempFile.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      <XFile>[
        XFile(
          tempFile.path,
          mimeType: docxMimeType,
          name: suggestedName,
        ),
      ],
      subject: '${paper.header.examTitleLine} — اللغة العربية للأول المتوسط',
    );
    return ExportOutcome(
      kind: ExportOutcomeKind.shared,
      filePath: tempFile.path,
    );
  }
}
