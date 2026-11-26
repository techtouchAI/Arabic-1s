import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/saved_exam.dart';

/// How a restored backup is combined with the papers already on the device.
enum BackupImportMode {
  /// Add new papers and update existing ones only when the backup copy is
  /// newer; everything else on the device is kept.
  merge,

  /// Replace the whole library with the backup contents.
  replace,
}

/// Outcome of applying a backup import, counted per paper id.
class BackupImportResult {
  const BackupImportResult({
    required this.added,
    required this.updated,
    required this.skipped,
    required this.total,
  });

  /// Papers whose id was not present before the import.
  final int added;

  /// Existing papers replaced by a newer backup copy (merge mode only).
  final int updated;

  /// Papers ignored because the on-device copy is newer or identical.
  final int skipped;

  /// Valid papers found in the backup file.
  final int total;

  bool get hasChanges => added > 0 || updated > 0;
}

/// Local persistence for the teacher's saved exam papers.
abstract class SavedExamStore {
  List<SavedExamPaper> read();
  Future<void> write(List<SavedExamPaper> papers);

  static Future<SavedExamStore> open() async {
    final prefs = await SharedPreferences.getInstance();
    return SharedPrefsSavedExamStore(prefs);
  }

  /// Serialises [papers] as a versioned JSON envelope.
  static String encode(List<SavedExamPaper> papers) => jsonEncode(
        <String, dynamic>{
          'version': 1,
          'papers': papers.map((p) => p.toJson()).toList(growable: false),
        },
      );

  /// Decodes [encode]'s output. A damaged record is skipped on its own, so one
  /// bad entry never costs the teacher every other saved paper.
  static List<SavedExamPaper> decode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const <SavedExamPaper>[];
    }
    Object? root;
    try {
      root = jsonDecode(raw);
    } on FormatException catch (error) {
      debugPrint('Saved exams could not be decoded: $error');
      return const <SavedExamPaper>[];
    }
    final entries = root is Map<String, dynamic> ? root['papers'] : null;
    if (entries is! List<dynamic>) {
      return const <SavedExamPaper>[];
    }
    final papers = <SavedExamPaper>[];
    final seenIds = <String>{};
    for (final entry in entries) {
      try {
        final paper = SavedExamPaper.fromJson(entry as Map<String, dynamic>);
        if (seenIds.add(paper.id)) {
          papers.add(paper);
        }
      } catch (error) {
        // Skipped deliberately; see the method documentation.
        debugPrint('Skipped a damaged saved exam: $error');
      }
    }
    return List<SavedExamPaper>.unmodifiable(papers);
  }

  /// Identifier written into every backup envelope produced by [encodeBackup].
  static const String backupKind = 'saved_exams_backup';

  /// Application identifier written into every backup envelope.
  static const String backupApp = 'bayan';

  /// Serialises [papers] as a portable backup envelope that can be saved to
  /// a file and restored on any device running بَيَان.
  static String encodeBackup(
    List<SavedExamPaper> papers, {
    DateTime? exportedAt,
  }) =>
      jsonEncode(<String, dynamic>{
        'app': backupApp,
        'kind': backupKind,
        'version': 1,
        'exportedAt': (exportedAt ?? DateTime.now()).toIso8601String(),
        'paperCount': papers.length,
        'papers': papers.map((p) => p.toJson()).toList(growable: false),
      });

  /// Decodes a backup produced by [encodeBackup].
  ///
  /// A legacy store envelope (`{version, papers}` without `app`/`kind`) is
  /// also accepted, so a raw local-storage dump can be restored. Damaged
  /// records are skipped individually and duplicate ids keep the first
  /// occurrence, exactly like [decode]. Throws [FormatException] when the
  /// payload is not a بَيَان backup at all.
  static List<SavedExamPaper> decodeBackup(String raw) =>
      _decodeBackupEnvelope(raw).papers;

  /// Backup creation time recorded by [encodeBackup], or `null` when the
  /// envelope carries none (legacy dumps) or cannot be parsed.
  static DateTime? backupExportedAt(String raw) =>
      _decodeBackupEnvelope(raw, tolerant: true).exportedAt;

  static _BackupEnvelope _decodeBackupEnvelope(
    String raw, {
    bool tolerant = false,
  }) {
    Object? root;
    try {
      root = jsonDecode(raw);
    } on FormatException {
      if (tolerant) {
        return const _BackupEnvelope(papers: <SavedExamPaper>[]);
      }
      throw FormatException('ملف النسخة الاحتياطية ليس ملف JSON صالحاً.', raw);
    }
    if (root is! Map<String, dynamic>) {
      if (tolerant) {
        return const _BackupEnvelope(papers: <SavedExamPaper>[]);
      }
      throw const FormatException('ملف النسخة الاحتياطية غير صالح.');
    }
    final kind = root['kind'];
    final app = root['app'];
    if ((kind != null && kind != backupKind) ||
        (app != null && app != backupApp)) {
      if (tolerant) {
        return const _BackupEnvelope(papers: <SavedExamPaper>[]);
      }
      throw const FormatException(
        'هذا الملف ليس نسخة احتياطية من «أسئلتي المحفوظة» في تطبيق بَيَان.',
      );
    }
    final entries = root['papers'];
    if (entries is! List<dynamic>) {
      if (tolerant) {
        return const _BackupEnvelope(papers: <SavedExamPaper>[]);
      }
      throw const FormatException(
        'ملف النسخة الاحتياطية لا يحتوي على قائمة أوراق محفوظة.',
      );
    }
    final papers = <SavedExamPaper>[];
    final seenIds = <String>{};
    for (final entry in entries) {
      try {
        final paper = SavedExamPaper.fromJson(entry as Map<String, dynamic>);
        if (seenIds.add(paper.id)) {
          papers.add(paper);
        }
      } catch (error) {
        // Skipped deliberately; one damaged record must not block the rest.
        debugPrint('Skipped a damaged backup record: $error');
      }
    }
    final exportedAt = DateTime.tryParse((root['exportedAt'] as String?) ?? '');
    return _BackupEnvelope(
      papers: List<SavedExamPaper>.unmodifiable(papers),
      exportedAt: exportedAt,
    );
  }

  /// Combines [current] with [imported] according to [mode] and returns the
  /// merged list (newest first) together with the per-paper outcome.
  ///
  /// An empty [imported] list is always a no-op, so restoring an empty backup
  /// can never wipe the library by accident.
  static (List<SavedExamPaper>, BackupImportResult) mergeBackup({
    required List<SavedExamPaper> current,
    required List<SavedExamPaper> imported,
    required BackupImportMode mode,
  }) {
    if (imported.isEmpty) {
      return (
        List<SavedExamPaper>.unmodifiable(current),
        const BackupImportResult(added: 0, updated: 0, skipped: 0, total: 0),
      );
    }
    if (mode == BackupImportMode.replace) {
      final replaced = List<SavedExamPaper>.of(imported)
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return (
        List<SavedExamPaper>.unmodifiable(replaced),
        BackupImportResult(
          added: imported.length,
          updated: 0,
          skipped: 0,
          total: imported.length,
        ),
      );
    }
    final merged = <String, SavedExamPaper>{
      for (final paper in current) paper.id: paper,
    };
    var added = 0;
    var updated = 0;
    var skipped = 0;
    for (final paper in imported) {
      final existing = merged[paper.id];
      if (existing == null) {
        merged[paper.id] = paper;
        added++;
      } else if (paper.updatedAt.isAfter(existing.updatedAt)) {
        merged[paper.id] = paper;
        updated++;
      } else {
        skipped++;
      }
    }
    final sorted = merged.values.toList(growable: false)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return (
      List<SavedExamPaper>.unmodifiable(sorted),
      BackupImportResult(
        added: added,
        updated: updated,
        skipped: skipped,
        total: imported.length,
      ),
    );
  }
}

class _BackupEnvelope {
  const _BackupEnvelope({required this.papers, this.exportedAt});

  final List<SavedExamPaper> papers;
  final DateTime? exportedAt;
}

class SharedPrefsSavedExamStore implements SavedExamStore {
  SharedPrefsSavedExamStore(this._prefs);

  static const String storageKey = 'bayan.saved_exams.v1';

  final SharedPreferences _prefs;

  @override
  List<SavedExamPaper> read() =>
      SavedExamStore.decode(_prefs.getString(storageKey));

  @override
  Future<void> write(List<SavedExamPaper> papers) async {
    final saved =
        await _prefs.setString(storageKey, SavedExamStore.encode(papers));
    if (!saved) {
      throw StateError('Saved exams could not be written to local storage.');
    }
  }
}

/// In-memory store used by tests and as the default for [AppState].
///
/// It round-trips through JSON like the real store, so tests exercise the
/// serialisation that ships.
class MemorySavedExamStore implements SavedExamStore {
  MemorySavedExamStore([List<SavedExamPaper> initial = const <SavedExamPaper>[]])
      : _raw = SavedExamStore.encode(initial);

  String _raw;
  int writeCount = 0;

  @override
  List<SavedExamPaper> read() => SavedExamStore.decode(_raw);

  @override
  Future<void> write(List<SavedExamPaper> papers) async {
    writeCount++;
    _raw = SavedExamStore.encode(papers);
  }
}
