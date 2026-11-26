import 'package:flutter/material.dart';

import '../../core/theme/dimens.dart';
import '../../core/utils/arabic_text.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/local/exam_document_exporter.dart';
import '../../data/local/saved_exam_backup_file.dart';
import '../../data/local/saved_exam_store.dart';
import '../../domain/models/saved_exam.dart';
import '../state/app_state.dart';
import '../state/saved_exam_library.dart';
import 'exam_composer_screen.dart';

/// Writes a backup JSON payload to a file; returns the export outcome.
typedef ExportBackupCallback = Future<ExportOutcome> Function(String backupJson);

/// Picks a backup file and returns its raw JSON, or `null` when cancelled.
typedef PickBackupCallback = Future<String?> Function();

/// «أسئلتي المحفوظة»: every exam paper the teacher created, autosaved by the
/// composer, newest first, with full-library backup export and restore.
class SavedExamsScreen extends StatefulWidget {
  const SavedExamsScreen({
    super.key,
    this.onExport,
    this.onExportBackup,
    this.onPickBackup,
  });

  /// Overrides the Word exporter (used by tests); defaults to the real one.
  final ExportExamCallback? onExport;

  /// Overrides the backup file writer (used by tests).
  final ExportBackupCallback? onExportBackup;

  /// Overrides the backup file picker (used by tests).
  final PickBackupCallback? onPickBackup;

  @override
  State<SavedExamsScreen> createState() => _SavedExamsScreenState();
}

class _SavedExamsScreenState extends State<SavedExamsScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final library = AppScope.of(context).savedExams;
    return Scaffold(
      appBar: AppBar(
        title: const Text('أسئلتي المحفوظة'),
        actions: <Widget>[
          IconButton(
            key: const ValueKey<String>('saved-exams-backup-export'),
            tooltip: 'إنشاء نسخة احتياطية',
            onPressed: _busy ? null : () => _exportBackup(library),
            icon: const Icon(Icons.backup_outlined),
          ),
          IconButton(
            key: const ValueKey<String>('saved-exams-backup-import'),
            tooltip: 'استعادة نسخة احتياطية',
            onPressed: _busy ? null : () => _importBackup(library),
            icon: const Icon(Icons.settings_backup_restore),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey<String>('saved-exams-new'),
        onPressed: () => _openComposer(context),
        icon: const Icon(Icons.add),
        label: const Text('ورقة أسئلة جديدة'),
      ),
      body: ListenableBuilder(
        listenable: library,
        builder: (BuildContext context, _) {
          final papers = library.papers;
          if (papers.isEmpty) {
            return const EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'لا توجد أسئلة محفوظة بعد',
              message:
                  'كل ورقة أسئلة تنشئها أو تعدّلها في مولّد الأسئلة تُحفظ هنا تلقائياً مع آخر تعديل.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(
              top: AppSpacing.md,
              // Clear the floating action button.
              bottom: AppSpacing.xxl * 2.5,
            ),
            itemCount: papers.length,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (BuildContext context, int index) => AppPage(
              maxWidth: AppLayout.readingMaxWidth,
              child: _SavedExamCard(
                saved: papers[index],
                onOpen: () => _openComposer(context, papers[index].id),
                onAction: (action) =>
                    _handleAction(context, library, papers[index], action),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openComposer(BuildContext context, [String? savedId]) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExamComposerScreen(
          savedExamId: savedId,
          onExport: widget.onExport,
        ),
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    SavedExamLibrary library,
    SavedExamPaper saved,
    _SavedExamAction action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    switch (action) {
      case _SavedExamAction.open:
        _openComposer(context, saved.id);
      case _SavedExamAction.export:
        await _export(messenger, saved);
      case _SavedExamAction.duplicate:
        library.duplicate(saved.id);
        messenger.showSnackBar(
          const SnackBar(content: Text('تم إنشاء نسخة مستقلة من الورقة.')),
        );
      case _SavedExamAction.rename:
        final title = await _askForTitle(context, saved);
        if (title != null) {
          library.rename(saved.id, title);
        }
      case _SavedExamAction.delete:
        if (await _confirmDelete(context, saved)) {
          library.delete(saved.id);
          messenger.showSnackBar(
            SnackBar(content: Text('تم حذف «${saved.displayTitle}».')),
          );
        }
    }
  }

  Future<void> _export(
    ScaffoldMessengerState messenger,
    SavedExamPaper saved,
  ) async {
    final exporter = widget.onExport ?? const ExamDocumentExporter().exportDocx;
    try {
      final outcome = await exporter(saved.paper);
      switch (outcome.kind) {
        case ExportOutcomeKind.savedToFile:
          messenger.showSnackBar(SnackBar(
            content: Text('تم حفظ ملف Word بنجاح: ${outcome.filePath}'),
          ));
        case ExportOutcomeKind.shared:
          messenger.showSnackBar(const SnackBar(
            content: Text('تم تجهيز ملف أسئلة الامتحان (.docx) للمشاركة.'),
          ));
        case ExportOutcomeKind.cancelled:
          break;
      }
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('تعذّر تصدير ملف Word: $error')),
      );
    }
  }

  Future<String?> _askForTitle(BuildContext context, SavedExamPaper saved) {
    return showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: saved.customTitle),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, SavedExamPaper saved) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('حذف الورقة المحفوظة؟'),
        content: Text(
          'سيُحذف «${saved.displayTitle}» نهائياً من هذا الجهاز.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            key: const ValueKey<String>('saved-exam-confirm-delete'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _exportBackup(SavedExamLibrary library) async {
    final messenger = ScaffoldMessenger.of(context);
    if (library.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('لا توجد أوراق محفوظة لإنشاء نسخة احتياطية منها.'),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final exporter =
          widget.onExportBackup ?? const SavedExamBackupFileService().exportBackup;
      final outcome = await exporter(library.buildBackupJson());
      if (!mounted) {
        return;
      }
      switch (outcome.kind) {
        case ExportOutcomeKind.savedToFile:
          messenger.showSnackBar(SnackBar(
            content: Text('تم حفظ النسخة الاحتياطية بنجاح: ${outcome.filePath}'),
          ));
        case ExportOutcomeKind.shared:
          messenger.showSnackBar(
            const SnackBar(
              content: Text('تم تجهيز النسخة الاحتياطية للمشاركة.'),
            ),
          );
        case ExportOutcomeKind.cancelled:
          break;
      }
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('تعذّر إنشاء النسخة الاحتياطية: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _importBackup(SavedExamLibrary library) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    String? raw;
    try {
      final picker =
          widget.onPickBackup ?? const SavedExamBackupFileService().pickBackupJson;
      raw = await picker();
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('تعذّرت قراءة ملف النسخة الاحتياطية: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
    if (!mounted || raw == null) {
      return;
    }
    List<SavedExamPaper> imported;
    try {
      imported = SavedExamStore.decodeBackup(raw);
    } on FormatException catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(error.message)),
      );
      return;
    }
    if (imported.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('لم يتم العثور على أوراق صالحة في ملف النسخة الاحتياطية.'),
        ),
      );
      return;
    }
    final exportedAt = SavedExamStore.backupExportedAt(raw);
    final mode = await showDialog<BackupImportMode>(
      context: context,
      builder: (_) => _BackupImportDialog(
        count: imported.length,
        exportedAt: exportedAt,
      ),
    );
    if (!mounted || mode == null) {
      return;
    }
    final result = library.importBackupPapers(imported, mode: mode);
    await library.flush();
    if (!mounted) {
      return;
    }
    if (library.lastWriteError != null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('تمت الاستعادة في الذاكرة لكن تعذّر الحفظ على الجهاز.'),
        ),
      );
      return;
    }
    if (!result.hasChanges) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'كل الأوراق في النسخة أقدم من الموجودة على هذا الجهاز — لم يتم تغيير شيء.',
          ),
        ),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'تمت الاستعادة: ${toArabicDigits(result.added)} جديدة، '
          '${toArabicDigits(result.updated)} محدّثة، '
          '${toArabicDigits(result.skipped)} بدون تغيير.',
        ),
      ),
    );
  }
}

class _BackupImportDialog extends StatefulWidget {
  const _BackupImportDialog({required this.count, required this.exportedAt});

  final int count;
  final DateTime? exportedAt;

  @override
  State<_BackupImportDialog> createState() => _BackupImportDialogState();
}

class _BackupImportDialogState extends State<_BackupImportDialog> {
  BackupImportMode _mode = BackupImportMode.merge;

  @override
  Widget build(BuildContext context) {
    final exportedAt = widget.exportedAt;
    return AlertDialog(
      title: const Text('استعادة نسخة احتياطية؟'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'تحتوي النسخة على ${toArabicDigits(widget.count)} ورقة محفوظة'
                '${exportedAt == null ? '' : ' • أُنشئت ${formatSavedTimestamp(exportedAt)}'}.',
              ),
              const SizedBox(height: AppSpacing.md),
              _ImportModeOptionCard(
                key: const ValueKey<String>('backup-import-merge'),
                title: 'دمج مع الموجود',
                subtitle:
                    'إضافة الأوراق الجديدة وتحديث الموجودة فقط إذا كانت نسخة الملف أحدث.',
                selected: _mode == BackupImportMode.merge,
                onTap: () => setState(() => _mode = BackupImportMode.merge),
              ),
              const SizedBox(height: AppSpacing.sm),
              _ImportModeOptionCard(
                key: const ValueKey<String>('backup-import-replace'),
                title: 'استبدال الكل',
                subtitle:
                    'حذف الأوراق الحالية على هذا الجهاز واستبدالها بمحتوى النسخة بالكامل.',
                selected: _mode == BackupImportMode.replace,
                onTap: () => setState(() => _mode = BackupImportMode.replace),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          key: const ValueKey<String>('backup-import-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          key: const ValueKey<String>('backup-import-confirm'),
          onPressed: () => Navigator.of(context).pop(_mode),
          child: const Text('استعادة'),
        ),
      ],
    );
  }
}

class _ImportModeOptionCard extends StatelessWidget {
  const _ImportModeOptionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.55)
          : scheme.surface,
      borderRadius: BorderRadius.circular(AppRadii.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _SavedExamAction { open, export, duplicate, rename, delete }

class _SavedExamCard extends StatelessWidget {
  const _SavedExamCard({
    required this.saved,
    required this.onOpen,
    required this.onAction,
  });

  final SavedExamPaper saved;
  final VoidCallback onOpen;
  final ValueChanged<_SavedExamAction> onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final paper = saved.paper;
    final details = <String>[
      if (paper.header.schoolName.trim().isNotEmpty)
        paper.header.schoolName.trim(),
      'المجموع ${toArabicDigits(paper.totalDegree)} درجة '
          '(${toArabicDigits(paper.composition.degree)} + '
          '${toArabicDigits(paper.effectiveGrammarDegree)} + '
          '${toArabicDigits(paper.effectiveOrthographyDegree)})',
    ].join(' • ');

    return Material(
      key: ValueKey<String>('saved-exam-${saved.id}'),
      color: scheme.surface,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.xs, AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(Icons.description_outlined, color: scheme.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(saved.displayTitle, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(details, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 2),
                    Text(
                      'آخر حفظ تلقائي: ${formatSavedTimestamp(saved.updatedAt)}'
                      ' • النسخة ${toArabicDigits(saved.revision)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_SavedExamAction>(
                key: ValueKey<String>('saved-exam-menu-${saved.id}'),
                tooltip: 'خيارات الورقة',
                onSelected: onAction,
                itemBuilder: (_) => const <PopupMenuEntry<_SavedExamAction>>[
                  PopupMenuItem<_SavedExamAction>(
                    value: _SavedExamAction.open,
                    child: _MenuRow(Icons.edit_outlined, 'فتح وتعديل'),
                  ),
                  PopupMenuItem<_SavedExamAction>(
                    value: _SavedExamAction.export,
                    child: _MenuRow(Icons.download_outlined, 'تصدير Word (.docx)'),
                  ),
                  PopupMenuItem<_SavedExamAction>(
                    value: _SavedExamAction.duplicate,
                    child: _MenuRow(Icons.copy_outlined, 'إنشاء نسخة'),
                  ),
                  PopupMenuItem<_SavedExamAction>(
                    value: _SavedExamAction.rename,
                    child: _MenuRow(Icons.drive_file_rename_outline, 'إعادة التسمية'),
                  ),
                  PopupMenuItem<_SavedExamAction>(
                    value: _SavedExamAction.delete,
                    child: _MenuRow(Icons.delete_outline, 'حذف'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        children: <Widget>[
          Icon(icon, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Flexible(child: Text(label)),
        ],
      );
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _text =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إعادة تسمية الورقة'),
      content: TextField(
        key: const ValueKey<String>('saved-exam-title-field'),
        controller: _text,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'اسم الورقة',
          helperText: 'اتركه فارغاً لاستعمال عنوان الامتحان والدور',
        ),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          key: const ValueKey<String>('saved-exam-title-save'),
          onPressed: () => Navigator.of(context).pop(_text.text),
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

/// `٢٠٢٦/١١/٢٣ — ٠٩:٠٥` in local time with Arabic-Indic digits.
String formatSavedTimestamp(DateTime moment) {
  final local = moment.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return toArabicDigits(
    '${local.year}/${two(local.month)}/${two(local.day)} — '
    '${two(local.hour)}:${two(local.minute)}',
  );
}
