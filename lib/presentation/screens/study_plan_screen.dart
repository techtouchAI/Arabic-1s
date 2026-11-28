/// Daily and annual study-plan screen (الخطة اليومية والخطة السنوية).
///
/// The screen is the single place where a teacher designs and prints both
/// plan sheets:
/// - A faithful A4-ratio live preview of the sheet, so the A4 print is
///   immediately visible while designing.
/// - Full control over the content: every annual row and daily entry is
///   editable, rows/entries can be added or removed, and per-column
///   visibility plus typography are configurable.
/// - A4 print/PDF through [StudyPlanPdf], reusing the app's tested
///   print pipeline and embedded Arabic fonts.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';
import '../../core/utils/arabic_text.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/section_header.dart';
import '../../data/study_plan_pdf.dart';
import '../../domain/models/question_print_settings.dart';
import '../../domain/models/study_plan.dart';
import '../state/app_state.dart';

class StudyPlanScreen extends StatefulWidget {
  const StudyPlanScreen({super.key});

  @override
  State<StudyPlanScreen> createState() => _StudyPlanScreenState();
}

class _StudyPlanScreenState extends State<StudyPlanScreen> {
  StudyPlanMode _mode = StudyPlanMode.annual;
  bool _printing = false;
  bool _initRequested = false;

  @override
  void initState() {
    super.initState();
    // The plan service loads asynchronously from SharedPreferences; kick it
    // off after the first frame so the InheritedNotifier can rebuild us
    // once loading finishes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_initRequested) {
        _initRequested = true;
        final state = AppScope.of(context);
        if (!state.studyPlans.isLoaded) {
          state.initStudyPlans();
        }
      }
    });
  }

  StudyPlans get _plans => AppScope.of(context).studyPlans.plans;

  Future<void> _print() async {
    final state = AppScope.of(context);
    final service = state.studyPlans;
    if (!service.isLoaded || _printing) {
      return;
    }
    setState(() => _printing = true);
    try {
      await Printing.layoutPdf(
        name: '${_mode.id}_plan.pdf',
        format: PdfPageFormat.a4,
        onLayout: (_) => StudyPlanPdf.buildPlanPdfBytes(
          mode: _mode,
          plans: _plans,
          bundle: rootBundle,
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذّرت طباعة الخطة: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _printing = false);
      }
    }
  }

  /// Opens the sheet-options panel as a modal bottom sheet. The panel overlays
  /// the preview/editor instead of taking a slice of the page layout, so the
  /// plan content is never compressed or pushed down when the options open.
  Future<void> _openPrintOptions() async {
    final state = AppScope.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 480),
        child: _PrintOptions(
          mode: _mode,
          onChanged: state.updatePlanSettings,
          onToggleAnnual: state.toggleAnnualColumn,
          onToggleDaily: state.toggleDailyColumn,
        ),
      ),
    );
  }

  /// Opens the annual-row editor as a modal popup. Editing happens in a
  /// bottom sheet so the plan sheet itself is never split or resized.
  Future<void> _openAnnualEditor(AnnualPlanRow row) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) {
        final state = AppScope.of(context);
        return _EditorSheet(
          title: 'تحرير الوحدة',
          child: _AnnualRowCard(
            row: row,
            onChange: state.updateAnnualRow,
            onDelete: () {
              state.removeAnnualRow(row.id);
              Navigator.of(context).pop();
            },
          ),
        );
      },
    );
  }

  /// Opens the daily-entry editor as a modal popup, keeping the plan sheet
  /// as the single full-width display.
  Future<void> _openDailyEditor(DailyPlanEntry entry) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) {
        final state = AppScope.of(context);
        return _EditorSheet(
          title: 'تحرير اليوم',
          child: _DailyEntryCard(
            entry: entry,
            onChange: state.updateDailyEntry,
            onDelete: () {
              state.removeDailyEntry(entry.id);
              Navigator.of(context).pop();
            },
          ),
        );
      },
    );
  }

  Future<void> _reset() async {
    final state = AppScope.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('إعادة ضبط الخطط'),
        content: const Text(
          'سيتم استبدال محتوى الخطة اليومية والسنوية بالتقسيم الافتراضي. هل تريد المتابعة؟',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('إعادة الضبط'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await state.resetStudyPlans();
    }
  }

  void _addAnnualRow(AppState state) {
    final plans = _plans;
    final index = plans.annualRows.length + 1;
    final row = AnnualPlanRow(
      id: 'annual-custom-$index',
      sectionLabel: 'سطر مخصص',
      unitId: '',
      unitLabel: 'سطر جديد',
      unitTitle: '',
      pages: '',
      readingTitle: '',
      grammarTitle: '',
      teachingDays: 6,
      startWeek: plans.totalWeeks + 1,
      examFocus: '',
      notes: '',
    );
    state.appendAnnualRow(row);
    _openAnnualEditor(row);
  }

  void _addDailyEntry(AppState state) {
    final plans = _plans;
    final index = plans.dailyEntries.length + 1;
    final entry = DailyPlanEntry(
      id: 'daily-custom-$index',
      dayLabel: dayLabelFor(index),
      focus: StudyPlanFocus.options.first,
      content: '',
    );
    state.appendDailyEntry(entry);
    _openDailyEditor(entry);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (!state.studyPlans.isLoaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('الخطط الدراسية')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('الخطط الدراسية'),
        actions: <Widget>[
          IconButton(
            tooltip: 'خيارات الطباعة',
            icon: const Icon(Icons.tune),
            onPressed: _openPrintOptions,
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: FilledButton.icon(
              onPressed: _printing ? null : _print,
              icon: _printing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.print),
              label: Text(_printing ? 'جاري الطباعة...' : 'طباعة A4'),
            ),
          ),
        ],
      ),
      body: AppPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            DefaultTabController(
              length: 2,
              child: TabBar(
                // Not scrollable: both plan tabs always stay visible and
                // tappable on narrow phones instead of scrolling off-screen.
                isScrollable: false,
                onTap: (int index) => setState(() =>
                    _mode =
                        index == 0 ? StudyPlanMode.daily : StudyPlanMode.annual),
                tabs: const <Widget>[
                  Tab(text: 'الخطة اليومية'),
                  Tab(text: 'الخطة السنوية'),
                ],
              ),
            ),
            // Compact toolbar: summary + add/reset actions. It sits above the
            // single full-width sheet; the sheet is never split in two.
            SectionHeader(
              title: _mode == StudyPlanMode.annual
                  ? '${_plans.annualRows.length} وحدة — '
                      '${toArabicDigits(_plans.totalTeachingDays)} يوماً دراسياً'
                  : '${_plans.dailyEntries.length} يوماً مجدولاً',
              accent: Theme.of(context).colorScheme.primary,
              trailing: Wrap(
                alignment: WrapAlignment.end,
                spacing: AppSpacing.xs,
                children: <Widget>[
                  IconButton.outlined(
                    tooltip: 'إعادة الضبط',
                    icon: const Icon(Icons.refresh),
                    onPressed: _reset,
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => _mode == StudyPlanMode.annual
                        ? _addAnnualRow(state)
                        : _addDailyEntry(state),
                    icon: const Icon(Icons.add),
                    label: Text(
                      _mode == StudyPlanMode.annual ? 'سطر' : 'يوم',
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _PlanDisplay(
                mode: _mode,
                plans: _plans,
                onEditAnnual: _openAnnualEditor,
                onEditDaily: _openDailyEditor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Plan sheet display ---------------------------------------------------

/// The single full-width A4-ratio plan sheet. The sheet is the only content
/// area of the screen (no split preview/editor): it fills the available width
/// and keeps the exact A4 aspect ratio; long content scrolls inside the sheet
/// and the whole sheet scrolls when it is taller than the viewport.
class _PlanDisplay extends StatelessWidget {
  const _PlanDisplay({
    required this.mode,
    required this.plans,
    required this.onEditAnnual,
    required this.onEditDaily,
  });

  final StudyPlanMode mode;
  final StudyPlans plans;
  final void Function(AnnualPlanRow row) onEditAnnual;
  final void Function(DailyPlanEntry entry) onEditDaily;

  /// A4 page geometry (mm). The on-screen sheet keeps this exact ratio so
  /// the display matches the printed/exported A4 page.
  static const double _a4WidthMm = 210.0;
  static const double _a4HeightMm = 297.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final paper = isDark ? AppColors.nightElevated : AppColors.paperElevated;
    final border = isDark ? AppColors.nightBorder : AppColors.border;
    final teal = isDark ? AppColors.tealLight : AppColors.deepTeal;

    return Card(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // Fill the available width: no minimum-width clamp, so every
          // column/topic is visible without horizontal scrolling or crushed
          // text. The height follows the exact A4 ratio; content that does
          // not fit scrolls inside the sheet.
          final baseWidth = constraints.maxWidth;
          final baseHeight = baseWidth * (_a4HeightMm / _a4WidthMm);
          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                key: const ValueKey<String>('a4-sheet'),
                width: baseWidth,
                height: baseHeight,
                child: _PlanSheet(
                  mode: mode,
                  plans: plans,
                  teal: teal,
                  paper: paper,
                  border: border,
                  onEditAnnual: onEditAnnual,
                  onEditDaily: onEditDaily,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A single A4 sheet: header band, scrollable plan content and footer.
class _PlanSheet extends StatelessWidget {
  const _PlanSheet({
    required this.mode,
    required this.plans,
    required this.teal,
    required this.paper,
    required this.border,
    required this.onEditAnnual,
    required this.onEditDaily,
  });

  final StudyPlanMode mode;
  final StudyPlans plans;
  final Color teal;
  final Color paper;
  final Color border;
  final void Function(AnnualPlanRow row) onEditAnnual;
  final void Function(DailyPlanEntry entry) onEditDaily;

  @override
  Widget build(BuildContext context) {
    final settings = plans.settings;
    final headingSize = settings.headingFontSize.toDouble();
    final bodySize = settings.bodyFontSize.toDouble();
    final subtitle = mode == StudyPlanMode.annual
        ? 'المنهج التكاملي — اللغة العربية للصف الأول المتوسط'
        : 'جدول التدريس اليومي — '
            '${toArabicDigits(plans.dailyEntries.length)} يوماً';

    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: paper,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: teal,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Column(
                children: <Widget>[
                  Text(
                    mode == StudyPlanMode.annual
                        ? 'الخطة السنوية'
                        : 'الخطة اليومية',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: headingSize * 1.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFFE6F4F5),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
                children: mode == StudyPlanMode.annual
                    ? _annualChildren(
                      plans: plans,
                      teal: teal,
                      border: border,
                      bodySize: bodySize,
                      onEditAnnual: onEditAnnual,
                    )
                    : _dailyChildren(
                      plans: plans,
                      teal: teal,
                      border: border,
                      bodySize: bodySize,
                      onEditDaily: onEditDaily,
                    ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'منصة بيان للتعليم',
                    style: TextStyle(fontSize: 8.5),
                  ),
                ),
                Text(
                  'A4',
                  style: TextStyle(fontSize: 8.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _annualChildren({
    required StudyPlans plans,
    required Color teal,
    required Color border,
    required double bodySize,
    required void Function(AnnualPlanRow row) onEditAnnual,
  }) {
    final visible = plans.settings.visibleAnnualColumns;
    final children = <Widget>[];

    if (plans.annualRows.isEmpty) {
      children.add(_emptyHint(
        'لا توجد وحدات — اضغط «سطر» لإضافة سطر جديد',
        border,
      ));
      return children;
    }

    String? currentSection;
    for (final row in plans.annualRows) {
      if (row.sectionLabel != currentSection) {
        currentSection = row.sectionLabel;
        children.add(_sectionDivider(currentSection, teal));
      }
      children.add(
        _AnnualUnitCard(
          row: row,
          visible: visible,
          teal: teal,
          border: border,
          bodySize: bodySize,
          onEdit: () => onEditAnnual(row),
        ),
      );
    }

    children.add(
      Container(
        margin: const EdgeInsets.only(top: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: const Color(0xFFCCFBF1),
          border: Border.all(color: border, width: 0.5),
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Align(
          alignment: Alignment.center,
          child: Text(
            'المجموع: '
            '${toArabicDigits(plans.totalTeachingDays)} يوماً دراسياً',
            style: TextStyle(
              fontSize: bodySize,
              fontWeight: FontWeight.w700,
              color: teal,
            ),
          ),
        ),
      ),
    );
    return children;
  }

  List<Widget> _dailyChildren({
    required StudyPlans plans,
    required Color teal,
    required Color border,
    required double bodySize,
    required void Function(DailyPlanEntry entry) onEditDaily,
  }) {
    final visible = plans.settings.visibleDailyColumns;

    if (plans.dailyEntries.isEmpty) {
      return <Widget>[
        _emptyHint('لا توجد أيام — اضغط «يوم» لإضافة يوم جديد', border),
      ];
    }

    return <Widget>[
      for (final entry in plans.dailyEntries)
        _DailyTopicCard(
          entry: entry,
          visible: visible,
          teal: teal,
          border: border,
          bodySize: bodySize,
          onEdit: () => onEditDaily(entry),
        ),
    ];
  }

  Widget _sectionDivider(String label, Color teal) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: teal.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: teal.withValues(alpha: 0.35), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: teal,
        ),
      ),
    );
  }

  Widget _emptyHint(String text, Color border) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: border, width: 0.5),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

  /// A bordered labelled cell (label above value). The value wraps and is
  /// never truncated, so all information stays readable. The cell has no
  /// margin so it can be placed inside a flex row safely; callers add spacing.
  Widget _labeledCell(
    String label,
    String value, {
    required Color border,
    required Color muted,
    required double bodySize,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: border, width: 0.5),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            fontSize: bodySize * 0.8,
            fontWeight: FontWeight.w600,
            color: muted,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value.isEmpty ? '—' : value,
          style: TextStyle(
            fontSize: bodySize,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

/// Stacks [cells] as full-width labelled cells with even spacing. A plain
/// column keeps every cell readable at any width without flex constraints.
Widget _fieldsRow(List<Widget> cells) {
  if (cells.isEmpty) {
    return const SizedBox.shrink();
  }
  if (cells.length == 1) {
    return cells.first;
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      for (var i = 0; i < cells.length; i++) ...[
        cells[i],
        if (i != cells.length - 1) const SizedBox(height: AppSpacing.sm),
      ],
    ],
  );
}

Widget _indexBadge(String id, Color teal) {
  return Container(
    width: 26,
    height: 26,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: teal.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppRadii.sm),
    ),
    child: Text(
      toArabicDigits(id.split('-').last),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: teal,
      ),
    ),
  );
}

Widget _chip(String label, String value, Color teal, Color border) {
  return Container(
    padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm, vertical: 2),
    margin: const EdgeInsets.only(right: AppSpacing.xs, bottom: AppSpacing.xs),
    decoration: BoxDecoration(
      color: teal.withValues(alpha: 0.08),
      border: Border.all(color: border, width: 0.5),
      borderRadius: BorderRadius.circular(AppRadii.sm),
    ),
    child: Text(
      '$label: $value',
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: teal,
      ),
    ),
  );
}

Widget _doneBadge(bool done, Color teal) {
  return Container(
    width: 22,
    height: 22,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: done ? teal : Colors.transparent,
      border: Border.all(color: teal.withValues(alpha: 0.4), width: 0.5),
      borderRadius: BorderRadius.circular(6),
    ),
    child: done
        ? const Text(
            '✓',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          )
        : const SizedBox.shrink(),
  );
}

Widget _focusStrip(
  String focus,
  Color teal,
  Color border,
  Color muted,
  double bodySize,
) {
  return Container(
    padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
    decoration: BoxDecoration(
      color: teal.withValues(alpha: 0.08),
      border: Border.all(color: teal.withValues(alpha: 0.35), width: 0.5),
      borderRadius: BorderRadius.circular(AppRadii.sm),
    ),
    child: Row(
      children: <Widget>[
        Text(
          'محور الدرس',
          style: TextStyle(
            fontSize: bodySize * 0.8,
            fontWeight: FontWeight.w600,
            color: muted,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            focus.isEmpty ? '—' : focus,
            style: TextStyle(
              fontSize: bodySize,
              fontWeight: FontWeight.w700,
              color: teal,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Read-only, print-like card for one annual unit inside the sheet: unit
/// header with schedule chips, then labelled fields for every visible column.
class _AnnualUnitCard extends StatelessWidget {
  const _AnnualUnitCard({
    required this.row,
    required this.visible,
    required this.teal,
    required this.border,
    required this.bodySize,
    required this.onEdit,
  });

  final AnnualPlanRow row;
  final Set<String> visible;
  final Color teal;
  final Color border;
  final double bodySize;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink =
        theme.brightness == Brightness.dark ? AppColors.nightInk : AppColors.ink;
    final muted =
        theme.brightness == Brightness.dark ? AppColors.nightMuted : AppColors.inkMuted;
    final unitLabel = row.unitLabel.isEmpty ? 'الوحدة' : row.unitLabel;
    final hasSchedule =
        visible.contains('pages') ||
        visible.contains('week') ||
        visible.contains('days');

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: border, width: 0.5),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (visible.contains('index')) ...[
                _indexBadge(row.id, teal),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      unitLabel,
                      style: TextStyle(
                        fontSize: bodySize * 1.2,
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                    if (row.unitTitle.isNotEmpty)
                      Text(
                        row.unitTitle,
                        style: TextStyle(
                          fontSize: bodySize * 0.85,
                          color: muted,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'تعديل',
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: onEdit,
              ),
            ],
          ),
          if (hasSchedule) ...[
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                if (visible.contains('pages'))
                  _chip('الصفحات', row.pages, teal, border),
                if (visible.contains('week'))
                  _chip('الأسبوع', toArabicDigits(row.startWeek), teal, border),
                if (visible.contains('days'))
                  _chip('أيام التدريس', toArabicDigits(row.teachingDays), teal, border),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          _fieldsRow(<Widget>[
            if (visible.contains('reading'))
              _labeledCell(
                'المطالعة',
                row.readingTitle,
                border: border,
                muted: muted,
                bodySize: bodySize,
              ),
            if (visible.contains('grammar'))
              _labeledCell(
                'القواعد',
                row.grammarTitle,
                border: border,
                muted: muted,
                bodySize: bodySize,
              ),
          ]),
          const SizedBox(height: AppSpacing.sm),
          _fieldsRow(<Widget>[
            if (visible.contains('orthography'))
              _labeledCell(
                'الإملاء والتعبير',
                row.orthographyTitle,
                border: border,
                muted: muted,
                bodySize: bodySize,
              ),
            if (visible.contains('exam'))
              _labeledCell(
                'محور التقويم',
                row.examFocus,
                border: border,
                muted: muted,
                bodySize: bodySize,
              ),
          ]),
          const SizedBox(height: AppSpacing.sm),
          if (visible.contains('notes'))
            _labeledCell(
              'ملاحظات',
              row.notes,
              border: border,
              muted: muted,
              bodySize: bodySize,
            ),
        ],
      ),
    );
  }
}

/// Read-only, print-like card for one daily topic inside the sheet. The lesson
/// content is shown in full (it wraps and is never truncated), so every topic
/// is complete inside the A4 display.
class _DailyTopicCard extends StatelessWidget {
  const _DailyTopicCard({
    required this.entry,
    required this.visible,
    required this.teal,
    required this.border,
    required this.bodySize,
    required this.onEdit,
  });

  final DailyPlanEntry entry;
  final Set<String> visible;
  final Color teal;
  final Color border;
  final double bodySize;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink =
        theme.brightness == Brightness.dark ? AppColors.nightInk : AppColors.ink;
    final muted =
        theme.brightness == Brightness.dark ? AppColors.nightMuted : AppColors.inkMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: border, width: 0.5),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      entry.dayLabel.isEmpty ? 'اليوم' : entry.dayLabel,
                      style: TextStyle(
                        fontSize: bodySize * 1.2,
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                    if (visible.contains('date') && entry.dateText.isNotEmpty)
                      Text(
                        entry.dateText,
                        style: TextStyle(
                          fontSize: bodySize * 0.85,
                          color: muted,
                        ),
                      ),
                  ],
                ),
              ),
              if (visible.contains('done')) _doneBadge(entry.done, teal),
              IconButton(
                tooltip: 'تعديل',
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: onEdit,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _focusStrip(entry.focus, teal, border, muted, bodySize),
          // The lesson content is shown in full — it wraps, never truncates.
          _labeledCell(
            'محتوى الدرس',
            entry.content,
            border: border,
            muted: muted,
            bodySize: bodySize,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (visible.contains('homework'))
            _labeledCell(
              'الواجب',
              entry.homework,
              border: border,
              muted: muted,
              bodySize: bodySize,
            ),
          const SizedBox(height: AppSpacing.sm),
          if (visible.contains('notes'))
            _labeledCell(
              'ملاحظات',
              entry.notes,
              border: border,
              muted: muted,
              bodySize: bodySize,
            ),
        ],
      ),
    );
  }
}

/// Modal popup wrapper for the row/entry editor forms. Editing happens in a
/// bottom sheet, so the plan sheet stays the single full-width display.
class _EditorSheet extends StatelessWidget {
  const _EditorSheet({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final paper = isDark ? AppColors.nightElevated : AppColors.paperElevated;
    final border = isDark ? AppColors.nightBorder : AppColors.border;

    return Container(
      decoration: BoxDecoration(
        color: paper,
        border: Border.all(color: border, width: 0.5),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadii.lg),
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: border, width: 0.5)),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('إغلاق'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// ---- Print options -------------------------------------------------------

class _PrintOptions extends StatelessWidget {
  const _PrintOptions({
    required this.mode,
    required this.onChanged,
    required this.onToggleAnnual,
    required this.onToggleDaily,
  });

  final StudyPlanMode mode;
  final ValueChanged<StudyPlanSettings> onChanged;
  final void Function(String, bool) onToggleAnnual;
  final void Function(String, bool) onToggleDaily;

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).studyPlans.plans.settings;
    final columns =
        mode == StudyPlanMode.annual ? StudyPlanColumns.annual : StudyPlanColumns.daily;
    final visible = mode == StudyPlanMode.annual
        ? settings.visibleAnnualColumns
        : settings.visibleDailyColumns;
    return Card(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.settings, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('خيارات ال sheet',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.start),
              ),
              TextButton(
                onPressed: () =>
                    onChanged(settings.copyWith(
                      visibleAnnualColumns: StudyPlanColumns.annual
                          .map((c) => c.id)
                          .toSet(),
                      visibleDailyColumns: StudyPlanColumns.daily
                          .map((c) => c.id)
                          .toSet(),
                    )),
                child: const Text('إظهار الكل'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<QuestionPrintFont>(
            initialValue: settings.font,
            decoration: const InputDecoration(
              labelText: 'خط الطباعة',
              isDense: true,
            ),
            // Fill the full available width so long font names stay inside the
            // field instead of overflowing horizontally.
            isExpanded: true,
            items: QuestionPrintFont.values
                .map((f) => DropdownMenuItem<QuestionPrintFont>(
                      value: f,
                      child: Text(f.label),
                    ))
                .toList(growable: false),
            onChanged: (QuestionPrintFont? value) {
              if (value != null) {
                onChanged(settings.copyWith(font: value));
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          _FontSizeSlider(
            label: 'حجم الخط',
            value: settings.bodyFontSize,
            onChanged: (int value) =>
                onChanged(settings.copyWith(bodyFontSize: value)),
          ),
          const SizedBox(height: AppSpacing.sm),
          _FontSizeSlider(
            label: 'حجم العناوين',
            value: settings.headingFontSize,
            onChanged: (int value) =>
                onChanged(settings.copyWith(headingFontSize: value)),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text('أعمدة ال sheet',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: columns
                .map((c) {
                  final isVisible = visible.contains(c.id);
                  return FilterChip(
                    label: Text(c.label),
                    selected: isVisible,
                    onSelected: (bool selected) {
                      if (mode == StudyPlanMode.annual) {
                        onToggleAnnual(c.id, selected);
                      } else {
                        onToggleDaily(c.id, selected);
                      }
                    },
                  );
                })
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _FontSizeSlider extends StatelessWidget {
  const _FontSizeSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 120,
          child: Text(label, style: Theme.of(context).textTheme.labelMedium),
        ),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: StudyPlanSettings.minFontSize.toDouble(),
            max: StudyPlanSettings.maxFontSize.toDouble(),
            divisions: StudyPlanSettings.maxFontSize - StudyPlanSettings.minFontSize,
            label: value.toString(),
            onChanged: (double v) => onChanged(v.round()),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 40,
          child: Text(
            toArabicDigits(value),
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
      ],
    );
  }
}

// ---- Annual row editor form (opened as a modal popup) -------------------

class _AnnualRowCard extends StatefulWidget {
  const _AnnualRowCard({
    required this.row,
    required this.onChange,
    required this.onDelete,
  });

  final AnnualPlanRow row;
  final ValueChanged<AnnualPlanRow> onChange;
  final VoidCallback onDelete;

  @override
  State<_AnnualRowCard> createState() => _AnnualRowCardState();
}

class _AnnualRowCardState extends State<_AnnualRowCard> {
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = <String, TextEditingController>{
      'unitLabel': TextEditingController(text: widget.row.unitLabel),
      'pages': TextEditingController(text: widget.row.pages),
      'reading': TextEditingController(text: widget.row.readingTitle),
      'grammar': TextEditingController(text: widget.row.grammarTitle),
      'orthography':
          TextEditingController(text: widget.row.orthographyTitle),
      'exam': TextEditingController(text: widget.row.examFocus),
      'notes': TextEditingController(text: widget.row.notes),
      'startWeek':
          TextEditingController(text: toArabicDigits(widget.row.startWeek)),
      'teachingDays':
          TextEditingController(text: toArabicDigits(widget.row.teachingDays)),
    };
  }

  @override
  void didUpdateWidget(_AnnualRowCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.row != oldWidget.row) {
      _controllers['unitLabel']!.text = widget.row.unitLabel;
      _controllers['pages']!.text = widget.row.pages;
      _controllers['reading']!.text = widget.row.readingTitle;
      _controllers['grammar']!.text = widget.row.grammarTitle;
      _controllers['orthography']!.text = widget.row.orthographyTitle;
      _controllers['exam']!.text = widget.row.examFocus;
      _controllers['notes']!.text = widget.row.notes;
      _controllers['startWeek']!.text = toArabicDigits(widget.row.startWeek);
      _controllers['teachingDays']!.text =
          toArabicDigits(widget.row.teachingDays);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _commit({
    String? unitLabel,
    String? pages,
    String? reading,
    String? grammar,
    String? orthography,
    String? exam,
    String? notes,
    int? teachingDays,
    int? startWeek,
  }) {
    widget.onChange(
      widget.row.copyWith(
        unitLabel: unitLabel,
        pages: pages,
        readingTitle: reading,
        grammarTitle: grammar,
        orthographyTitle: orthography,
        examFocus: exam,
        notes: notes,
        teachingDays: teachingDays,
        startWeek: startWeek,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    widget.row.unitLabel.isEmpty
                        ? 'سطر'
                        : widget.row.unitLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'حذف',
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: widget.onDelete,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _field(
              'الوحدة',
              _controllers['unitLabel']!,
              (String v) => _commit(unitLabel: v),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: _field(
                    'الصفحات',
                    _controllers['pages']!,
                    (String v) => _commit(pages: v),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _numberField(
                    'الأسبوع',
                    _controllers['startWeek']!,
                    widget.row.startWeek,
                    (int v) => _commit(startWeek: v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _field(
              'المطالعة',
              _controllers['reading']!,
              (String v) => _commit(reading: v),
            ),
            const SizedBox(height: AppSpacing.sm),
            _field(
              'القواعد',
              _controllers['grammar']!,
              (String v) => _commit(grammar: v),
            ),
            const SizedBox(height: AppSpacing.sm),
            _field(
              'الإملاء والتعبير',
              _controllers['orthography']!,
              (String v) => _commit(orthography: v),
            ),
            const SizedBox(height: AppSpacing.sm),
            _field(
              'محور التقويم',
              _controllers['exam']!,
              (String v) => _commit(exam: v),
            ),
            const SizedBox(height: AppSpacing.sm),
            _field(
              'ملاحظات',
              _controllers['notes']!,
              (String v) => _commit(notes: v),
            ),
            const SizedBox(height: AppSpacing.sm),
            _numberField(
              'أيام التدريس',
              _controllers['teachingDays']!,
              widget.row.teachingDays,
              (int v) => _commit(teachingDays: v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller,
    ValueChanged<String> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 3),
        TextField(
          textDirection: TextDirection.rtl,
          controller: controller,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _numberField(
    String label,
    TextEditingController controller,
    int current,
    ValueChanged<int> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 3),
        TextField(
          textDirection: TextDirection.rtl,
          keyboardType: TextInputType.number,
          controller: controller,
          onChanged: (String v) => onChanged(int.tryParse(v) ?? current),
        ),
      ],
    );
  }
}

// ---- Daily entry editor form (opened as a modal popup) ------------------

class _DailyEntryCard extends StatefulWidget {
  const _DailyEntryCard({
    required this.entry,
    required this.onChange,
    required this.onDelete,
  });

  final DailyPlanEntry entry;
  final ValueChanged<DailyPlanEntry> onChange;
  final VoidCallback onDelete;

  @override
  State<_DailyEntryCard> createState() => _DailyEntryCardState();
}

class _DailyEntryCardState extends State<_DailyEntryCard> {
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = <String, TextEditingController>{
      'focus': TextEditingController(text: widget.entry.focus),
      'date': TextEditingController(text: widget.entry.dateText),
      'content': TextEditingController(text: widget.entry.content),
      'homework': TextEditingController(text: widget.entry.homework),
      'notes': TextEditingController(text: widget.entry.notes),
    };
  }

  @override
  void didUpdateWidget(_DailyEntryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entry != oldWidget.entry) {
      _controllers['focus']!.text = widget.entry.focus;
      _controllers['date']!.text = widget.entry.dateText;
      _controllers['content']!.text = widget.entry.content;
      _controllers['homework']!.text = widget.entry.homework;
      _controllers['notes']!.text = widget.entry.notes;
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _commit({
    String? focus,
    String? date,
    String? content,
    String? homework,
    String? notes,
    bool? done,
  }) {
    widget.onChange(
      widget.entry.copyWith(
        focus: focus,
        dateText: date,
        content: content,
        homework: homework,
        notes: notes,
        done: done,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    widget.entry.dayLabel.isEmpty
                        ? 'يوم'
                        : widget.entry.dayLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Checkbox(
                  value: widget.entry.done,
                  onChanged: (bool? value) => _commit(done: value ?? false),
                ),
                IconButton(
                  tooltip: 'حذف',
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: widget.onDelete,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: _field(
                    'محور الدرس',
                    _controllers['focus']!,
                    (String v) => _commit(focus: v),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _field(
                    'التاريخ',
                    _controllers['date']!,
                    (String v) => _commit(date: v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _field(
              'محتوى الدرس',
              _controllers['content']!,
              (String v) => _commit(content: v),
            ),
            const SizedBox(height: AppSpacing.sm),
            _field(
              'الواجب',
              _controllers['homework']!,
              (String v) => _commit(homework: v),
            ),
            const SizedBox(height: AppSpacing.sm),
            _field(
              'ملاحظات',
              _controllers['notes']!,
              (String v) => _commit(notes: v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller,
    ValueChanged<String> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 3),
        TextField(
          textDirection: TextDirection.rtl,
          controller: controller,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
