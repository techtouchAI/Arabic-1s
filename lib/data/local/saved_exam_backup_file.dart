import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'exam_document_exporter.dart';

/// File-system bridge for the «أسئلتي المحفوظة» backup (export + import).
///
/// Pure backup encoding/decoding lives in [SavedExamStore]; this class only
/// moves the JSON payload to and from a user-chosen file, following the same
/// desktop save-dialog / mobile share-sheet pattern as [ExamDocumentExporter].
class SavedExamBackupFileService {
  const SavedExamBackupFileService();

  static const String jsonMimeType = 'application/json';

  /// Suggested backup file name, e.g.
  /// `بيان_نسخة_احتياطية_أسئلتي_المحفوظة_20261126_1200.json`.
  static String suggestedFileName({DateTime? now}) {
    final moment = (now ?? DateTime.now()).toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    final stamp =
        '${moment.year}${two(moment.month)}${two(moment.day)}_${two(moment.hour)}${two(moment.minute)}';
    return 'بيان_نسخة_احتياطية_أسئلتي_المحفوظة_$stamp.json';
  }

  /// Saves [backupJson] to a user-chosen `.json` file (desktop) or opens the
  /// system share sheet with it (mobile).
  Future<ExportOutcome> exportBackup(String backupJson) async {
    final suggestedName = suggestedFileName();
    final bytes = Uint8List.fromList(utf8.encode(backupJson));

    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      final FileSaveLocation? location = await getSaveLocation(
        suggestedName: suggestedName,
        acceptedTypeGroups: const <XTypeGroup>[
          XTypeGroup(
            label: 'نسخة احتياطية (JSON)',
            extensions: <String>['json'],
          ),
        ],
      );
      if (location == null) {
        return const ExportOutcome(kind: ExportOutcomeKind.cancelled);
      }
      var targetPath = location.path;
      if (!targetPath.toLowerCase().endsWith('.json')) {
        targetPath = '$targetPath.json';
      }
      final file = File(targetPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      return ExportOutcome(
        kind: ExportOutcomeKind.savedToFile,
        filePath: file.path,
      );
    }

    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$suggestedName');
    await tempFile.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      <XFile>[
        XFile(
          tempFile.path,
          mimeType: jsonMimeType,
          name: suggestedName,
        ),
      ],
      subject: 'نسخة احتياطية — أسئلتي المحفوظة (بَيَان)',
    );
    return ExportOutcome(
      kind: ExportOutcomeKind.shared,
      filePath: tempFile.path,
    );
  }

  /// Opens a file picker for a backup `.json` file and returns its text.
  ///
  /// Returns `null` when the teacher cancels the picker.
  Future<String?> pickBackupJson() async {
    final XFile? picked = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(
          label: 'نسخة احتياطية (JSON)',
          extensions: <String>['json'],
          mimeTypes: <String>[
            'application/json',
            'text/plain',
            'application/octet-stream',
          ],
        ),
      ],
    );
    if (picked == null) {
      return null;
    }
    return picked.readAsString(encoding: utf8);
  }
}
