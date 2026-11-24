import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/dimens.dart';
import '../../core/utils/arabic_text.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/section_header.dart';
import '../../data/local/question_pdf.dart';
import '../../domain/models/question_print_settings.dart';
import '../../domain/services/exam_bank_picker.dart';
import '../../domain/services/question_print_plan.dart';
import '../state/app_state.dart';
import '../widgets/text_scale_controls.dart';

typedef PrintQuestionsCallback = Future<void> Function(
  QuestionPrintPlan plan,
  String partTitle,
);

class QuestionPrintScreen extends StatefulWidget {
  const QuestionPrintScreen({super.key, this.printQuestions});

  final PrintQuestionsCallback? printQuestions;

  @override
  State<QuestionPrintScreen> createState() => _QuestionPrintScreenState();
}

class _QuestionPrintScreenState extends State<QuestionPrintScreen> {
  Set<String> _selectedIds = <String>{};
  Set<String> _selectedStyles = ExamBankPicker.unitQuestionStyles.toSet();
  String? _selectionPart;
  bool _initialized = false;
  bool _printing = false;
  bool _includeAnswers = true;
  QuestionPrintFont _font = QuestionPrintFont.plex;
  final TextEditingController _bodySize = TextEditingController(
    text: '${QuestionPrintSettings.defaultBodyFontSize}',
  );
  final TextEditingController _headingSize = TextEditingController(
    text: '${QuestionPrintSettings.defaultHeadingFontSize}',
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppScope.of(context);
    if (!_initialized || _selectionPart != state.activePart.id) {
      _selectionPart = state.activePart.id;
      _selectedIds =
          printableUnits(state.partUnits).map((unit) => unit.id).toSet();
      _selectedStyles = ExamBankPicker.unitQuestionStyles.toSet();
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _bodySize.dispose();
    _headingSize.dispose();
    super.dispose();
  }

  QuestionPrintSettings? get _settings {
    final body = parseIntegerDigits(_bodySize.text);
    final heading = parseIntegerDigits(_headingSize.text);
    if (!QuestionPrintSettings.isValidFontSize(body) ||
        !QuestionPrintSettings.isValidFontSize(heading)) {
      return null;
    }
    return QuestionPrintSettings(
      font: _font,
      bodyFontSize: body!,
      headingFontSize: heading!,
      includeAnswers: _includeAnswers,
    );
  }

  Future<void> _print(QuestionPrintPlan plan, String partTitle) async {
    if (plan.isEmpty || !plan.settings.isValid || _printing) {
      return;
    }
    setState(() => _printing = true);
    try {
      await (widget.printQuestions ?? QuestionPrinter.print)(plan, partTitle);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذّرت الطباعة: $error'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _printing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final units = printableUnits(state.partUnits);
    final settings = _settings;
    final plan = QuestionPrintPlan.fromSelection(
      units,
      _selectedIds,
      allowedExamStyles: _selectedStyles,
      settings: settings ?? const QuestionPrintSettings(),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('طباعة بنك الأسئلة (PDF A4)'),
        actions: const <Widget>[TextScaleControls()],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: <Widget>[
          AppPage(
            maxWidth: AppLayout.readingMaxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    border: Border.all(
                      color: scheme.secondary.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Text(
                    'اختر وحدة أو أكثر وأنماط الأسئلة الرسمية من ${state.partTitle} لطباعة بنك الأسئلة المطابق لنماذج الأسئلة الوزارية بتنسيق A4 جاهز للطباعة أو الحفظ بصيغة PDF.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                if (units.isEmpty)
                  const EmptyState(
                    icon: Icons.quiz_outlined,
                    title: 'لا توجد أسئلة للطباعة',
                    message: 'اختر جزءاً دراسياً يحتوي على وحدات.',
                  )
                else ...<Widget>[
                  SectionHeader(
                    title: 'أنماط الأسئلة الرسمية',
                    accent: scheme.primary,
                  ),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: <Widget>[
                      FilterChip(
                        key: const ValueKey<String>('print-style-all'),
                        label: const Text('كل الأنماط'),
                        selected: _selectedStyles.length ==
                            ExamBankPicker.unitQuestionStyles.length,
                        onSelected: _printing
                            ? null
                            : (bool sel) => setState(() {
                                  _selectedStyles = sel
                                      ? ExamBankPicker.unitQuestionStyles
                                          .toSet()
                                      : <String>{};
                                }),
                      ),
                      for (final style in ExamBankPicker.unitQuestionStyles)
                        FilterChip(
                          key: ValueKey<String>('print-style-$style'),
                          label: Text(ExamBankPicker.grammarStyleLabel(style)),
                          selected: _selectedStyles.contains(style),
                          onSelected: _printing
                              ? null
                              : (bool sel) => setState(() {
                                    if (sel) {
                                      _selectedStyles.add(style);
                                    } else {
                                      _selectedStyles.remove(style);
                                    }
                                  }),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SectionHeader(
                    title: 'اختر الوحدات (${state.partTitle})',
                    accent: scheme.secondary,
                  ),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: <Widget>[
                      TextButton.icon(
                        onPressed: _printing || plan.units.length == units.length
                            ? null
                            : () => setState(() {
                                  _selectedIds =
                                      units.map((u) => u.id).toSet();
                                }),
                        icon: const Icon(Icons.done_all, size: 18),
                        label: const Text('تحديد الكل'),
                      ),
                      TextButton(
                        onPressed: _printing || plan.isEmpty
                            ? null
                            : () => setState(_selectedIds.clear),
                        child: const Text('إلغاء التحديد'),
                      ),
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Column(
                      children: <Widget>[
                        for (var i = 0; i < units.length; i++) ...<Widget>[
                          if (i > 0) const Divider(height: 1),
                          CheckboxListTile(
                            key: ValueKey<String>('print-unit-${units[i].id}'),
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              units[i].displayTitle,
                              style: theme.textTheme.titleMedium,
                            ),
                            subtitle: Text(
                              '${toArabicDigits(units[i].questions.length)} أسئلة • ${units[i].grammarTitle}',
                              style: theme.textTheme.labelMedium,
                            ),
                            value: _selectedIds.contains(units[i].id),
                            onChanged: _printing
                                ? null
                                : (bool? v) => setState(() {
                                      if (v == true) {
                                        _selectedIds.add(units[i].id);
                                      } else {
                                        _selectedIds.remove(units[i].id);
                                      }
                                    }),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SectionHeader(
                    title: 'إعدادات الخط والأجوبة النموذجية',
                    accent: scheme.primary,
                  ),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('تضمين الأجوبة النموذجية تحت كل سؤال'),
                          value: _includeAnswers,
                          onChanged: _printing
                              ? null
                              : (bool v) => setState(() => _includeAnswers = v),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        DropdownButtonFormField<QuestionPrintFont>(
                          initialValue: _font,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'نوع الخط'),
                          items: <DropdownMenuItem<QuestionPrintFont>>[
                            for (final f in QuestionPrintFont.values)
                              DropdownMenuItem<QuestionPrintFont>(
                                value: f,
                                child: Text(
                                  f.label,
                                  style: TextStyle(fontFamily: f.family),
                                ),
                              ),
                          ],
                          onChanged: _printing
                              ? null
                              : (QuestionPrintFont? f) {
                                  if (f != null) {
                                    setState(() => _font = f);
                                  }
                                },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: TextField(
                                controller: _bodySize,
                                keyboardType: TextInputType.number,
                                textDirection: TextDirection.ltr,
                                inputFormatters: <TextInputFormatter>[
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9٠-٩]'),
                                  ),
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'حجم خط النص (٩–٢٤)',
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: TextField(
                                controller: _headingSize,
                                keyboardType: TextInputType.number,
                                textDirection: TextDirection.ltr,
                                inputFormatters: <TextInputFormatter>[
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9٠-٩]'),
                                  ),
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'حجم العناوين (٩–٢٤)',
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: AppPage(
              maxWidth: AppLayout.readingMaxWidth,
              padding: EdgeInsets.zero,
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      plan.isEmpty
                          ? 'اختر وحدة واحدة على الأقل'
                          : '${toArabicDigits(plan.units.length)} وحدة • '
                                '${toArabicDigits(plan.questionCount)} سؤالاً',
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  FilledButton.icon(
                    key: const ValueKey<String>('print-questions-button'),
                    onPressed: plan.isEmpty || _printing || settings == null
                        ? null
                        : () => _print(plan, state.partTitle),
                    icon: const Icon(Icons.print_outlined, size: 20),
                    label: Text(_printing ? 'جاري التحضير...' : 'طباعة / PDF'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
