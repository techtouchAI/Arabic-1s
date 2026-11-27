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
  bool _optionsExpanded = false;
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
    state.appendAnnualRow(
      AnnualPlanRow(
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
      ),
    );
  }

  void _addDailyEntry(AppState state) {
    final plans = _plans;
    final index = plans.dailyEntries.length + 1;
    state.appendDailyEntry(
      DailyPlanEntry(
        id: 'daily-custom-$index',
        dayLabel: dayLabelFor(index),
        focus: StudyPlanFocus.options.first,
        content: '',
      ),
    );
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
            onPressed: () => setState(() => _optionsExpanded = !_optionsExpanded),
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
                isScrollable: true,
                onTap: (int index) => setState(() =>
                    _mode =
                        index == 0 ? StudyPlanMode.daily : StudyPlanMode.annual),
                tabs: const <Widget>[
                  Tab(text: 'الخطة اليومية'),
                  Tab(text: 'الخطة السنوية'),
                ],
              ),
            ),
            Expanded(
              child: _optionsExpanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(
                          0, AppSpacing.md, 0, 0),
                      child: _PrintOptions(
                        mode: _mode,
                        onChanged: state.updatePlanSettings,
                        onToggleAnnual: state.toggleAnnualColumn,
                        onToggleDaily: state.toggleDailyColumn,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                    Flexible(
                      flex: _mode == StudyPlanMode.annual ? 7 : 6,
                      child: _SheetPreview(mode: _mode, plans: _plans),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Flexible(
                      flex: _mode == StudyPlanMode.annual ? 5 : 6,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 720),
                        child: _mode == StudyPlanMode.annual
                            ? _AnnualEditor(
                                plans: _plans,
                                onChange: state.updateAnnualRow,
                                onAdd: () => _addAnnualRow(state),
                                onDelete: state.removeAnnualRow,
                                onReset: _reset,
                              )
                            : _DailyEditor(
                                plans: _plans,
                                onChange: state.updateDailyEntry,
                                onAdd: () => _addDailyEntry(state),
                                onDelete: state.removeDailyEntry,
                                onReset: _reset,
                              ),
                      ),
                    ),
                  ],
                ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- A4 sheet preview -----------------------------------------------------

class _SheetPreview extends StatelessWidget {
  const _SheetPreview({required this.mode, required this.plans});

  final StudyPlanMode mode;
  final StudyPlans plans;

  /// A4 page geometry (mm). The preview keeps this exact aspect ratio so the
  /// on-screen sheet matches the printed/exported A4 page.
  static const double _a4WidthMm = 210.0;
  static const double _a4HeightMm = 297.0;

  /// Readable minimum/maximum on-screen sheet width (px). Below the minimum,
  /// table columns would be too narrow to read; the sheet scrolls instead of
  /// crushing its columns or scaling text down.
  static const double _minSheetWidth = 640.0;
  static const double _maxSheetWidth = 920.0;

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
          // Size the sheet to the exact A4 aspect ratio. Clamp the width to a
          // readable range; the sheet scrolls (never scales text or crushes
          // columns) when it is larger than the available viewport.
          final baseWidth =
              constraints.maxWidth.clamp(_minSheetWidth, _maxSheetWidth);
          final baseHeight = baseWidth / (_a4WidthMm / _a4HeightMm);
          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  key: const ValueKey<String>('a4-sheet'),
                  width: baseWidth,
                  height: baseHeight,
                  child: _a4Sheet(
                    mode: mode,
                    plans: plans,
                    teal: teal,
                    paper: paper,
                    border: border,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// A single A4-proportioned sheet: title bar, the plan table (scrollable
  /// inside the sheet), and a footer.
  Widget _a4Sheet({
    required StudyPlanMode mode,
    required StudyPlans plans,
    required Color teal,
    required Color paper,
    required Color border,
  }) {
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (mode == StudyPlanMode.annual)
                    const Text(
                      'المنهج التكاملي — اللغة العربية للصف الأول المتوسط',
                      style: TextStyle(
                        color: Color(0xFFE6F4F5),
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: mode == StudyPlanMode.annual
                  ? _annualTable(teal)
                  : _dailyTable(teal),
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

  Widget _cell(Widget child, {Color? background, bool center = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        border: const Border(
          right: BorderSide(color: Color(0xFF94A3B8), width: 0.5),
          bottom: BorderSide(color: Color(0xFF94A3B8), width: 0.5),
        ),
      ),
      child: Align(
        alignment: center ? Alignment.center : Alignment.topRight,
        child: child,
      ),
    );
  }

  Widget _annualTable(Color teal) {
    final visible = StudyPlanColumns.annual
        .where((c) => plans.settings.visibleAnnualColumns.contains(c.id))
        .toList(growable: false);

    Widget headerCell(String label) => _cell(
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
          background: teal,
          center: true,
        );

    Widget dataRow(AnnualPlanRow row) {
      final byId = <String, Widget>{
        'index': _cell(
          Text(toArabicDigits(row.id.split('-').last),
              style: const TextStyle(fontSize: 9.5)),
          center: true,
        ),
        'unit': _cell(
          Text(row.unitLabel, style: const TextStyle(fontSize: 9.5)),
        ),
        'pages': _cell(
          Text(row.pages, style: const TextStyle(fontSize: 9.5)),
          center: true,
        ),
        'reading': _cell(
          Text(row.readingTitle, style: const TextStyle(fontSize: 9.5)),
        ),
        'grammar': _cell(
          Text(row.grammarTitle, style: const TextStyle(fontSize: 9.5)),
        ),
        'orthography': _cell(
          Text(
            row.orthographyTitle.isNotEmpty ? row.orthographyTitle : '—',
            style: const TextStyle(fontSize: 9.5),
          ),
        ),
        'days': _cell(
          Text(toArabicDigits(row.teachingDays),
              style: const TextStyle(fontSize: 9.5)),
          center: true,
        ),
        'week': _cell(
          Text(toArabicDigits(row.startWeek),
              style: const TextStyle(fontSize: 9.5)),
          center: true,
        ),
        'exam': _cell(
          Text(row.examFocus, style: const TextStyle(fontSize: 9.5)),
        ),
        'notes': _cell(
          Text(row.notes, style: const TextStyle(fontSize: 9.5)),
        ),
      };
      return Row(
        children: visible
            .map((c) => Expanded(flex: c.weight.toInt(), child: byId[c.id]!))
            .toList(growable: false),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: visible
              .map((c) =>
                  Expanded(flex: c.weight.toInt(), child: headerCell(c.label)))
              .toList(growable: false),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: plans.annualRows.length + 1,
            itemBuilder: (BuildContext context, int index) {
              if (index == plans.annualRows.length) {
                return _cell(
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    alignment: Alignment.center,
                    child: Text(
                      'المجموع: ${toArabicDigits(plans.totalTeachingDays)} يوماً دراسياً',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepTeal,
                      ),
                    ),
                  ),
                  background: const Color(0xFFCCFBF1),
                  center: true,
                );
              }
              return dataRow(plans.annualRows[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _dailyTable(Color teal) {
    final visible = StudyPlanColumns.daily
        .where((c) => plans.settings.visibleDailyColumns.contains(c.id))
        .toList(growable: false);

    Widget dataRow(DailyPlanEntry entry) {
      final byId = <String, Widget>{
        'day': _cell(
          Text(entry.dayLabel, style: const TextStyle(fontSize: 9.5)),
        ),
        'date': _cell(
          Text(entry.dateText.isEmpty ? '—' : entry.dateText,
              style: const TextStyle(fontSize: 9.5)),
          center: true,
        ),
        'focus': _cell(
          Text(entry.focus, style: const TextStyle(fontSize: 9.5)),
        ),
        'content': _cell(
          Text(entry.content, style: const TextStyle(fontSize: 9.5)),
        ),
        'homework': _cell(
          Text(entry.homework.isEmpty ? '—' : entry.homework,
              style: const TextStyle(fontSize: 9.5)),
        ),
        'notes': _cell(
          Text(entry.notes, style: const TextStyle(fontSize: 9.5)),
        ),
        'done': _cell(
          Text(entry.done ? '✓' : '—',
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700)),
          center: true,
        ),
      };
      return Row(
        children: visible
            .map((c) => Expanded(flex: c.weight.toInt(), child: byId[c.id]!))
            .toList(growable: false),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: visible
              .map((c) => Expanded(
                    flex: c.weight.toInt(),
                    child: _cell(
                      Text(
                        c.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                      background: teal,
                      center: true,
                    ),
                  ))
              .toList(growable: false),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: plans.dailyEntries.length,
            itemBuilder: (BuildContext context, int index) =>
                dataRow(plans.dailyEntries[index]),
          ),
        ),
      ],
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
              Text('خيارات ال sheet',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
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

// ---- Annual editor -------------------------------------------------------

class _AnnualEditor extends StatelessWidget {
  const _AnnualEditor({
    required this.plans,
    required this.onChange,
    required this.onAdd,
    required this.onDelete,
    required this.onReset,
  });

  final StudyPlans plans;
  final ValueChanged<AnnualPlanRow> onChange;
  final ValueChanged<String> onDelete;
  final VoidCallback onAdd;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: 'الخطة السنوية',
          subtitle:
              '${plans.annualRows.length} وحدة — ${toArabicDigits(plans.totalTeachingDays)} يوماً دراسياً',
          trailing: Wrap(
            alignment: WrapAlignment.end,
            spacing: AppSpacing.xs,
            children: <Widget>[
              IconButton.outlined(
                tooltip: 'إعادة الضبط',
                icon: const Icon(Icons.refresh),
                onPressed: onReset,
              ),
              FilledButton.tonalIcon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('سطر'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            itemCount: plans.annualRows.length,
            itemBuilder: (BuildContext context, int index) {
              final row = plans.annualRows[index];
              return _AnnualRowCard(
                row: row,
                onChange: onChange,
                onDelete: () => onDelete(row.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

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

// ---- Daily editor --------------------------------------------------------

class _DailyEditor extends StatelessWidget {
  const _DailyEditor({
    required this.plans,
    required this.onChange,
    required this.onAdd,
    required this.onDelete,
    required this.onReset,
  });

  final StudyPlans plans;
  final ValueChanged<DailyPlanEntry> onChange;
  final ValueChanged<String> onDelete;
  final VoidCallback onAdd;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: 'الخطة اليومية',
          subtitle: '${plans.dailyEntries.length} يوماً مجدولاً',
          trailing: Wrap(
            alignment: WrapAlignment.end,
            spacing: AppSpacing.xs,
            children: <Widget>[
              IconButton.outlined(
                tooltip: 'إعادة الضبط',
                icon: const Icon(Icons.refresh),
                onPressed: onReset,
              ),
              FilledButton.tonalIcon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('يوم'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            itemCount: plans.dailyEntries.length,
            itemBuilder: (BuildContext context, int index) {
              final entry = plans.dailyEntries[index];
              return _DailyEntryCard(
                entry: entry,
                onChange: onChange,
                onDelete: () => onDelete(entry.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

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
