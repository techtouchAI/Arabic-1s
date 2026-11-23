import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';
import '../../core/utils/arabic_text.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/section_header.dart';
import '../../data/local/docx/exam_docx_builder.dart';
import '../../data/local/exam_document_exporter.dart';
import '../../domain/models/exam_paper.dart';
import '../../domain/services/exam_layout_plan.dart';
import '../state/app_state.dart';
import '../state/exam_autosaver.dart';
import '../state/exam_composer_state.dart';
import '../widgets/text_scale_controls.dart';
import '../widgets/underline_rich_text.dart';

typedef ExportExamCallback = Future<ExportOutcome> Function(ArabicExamPaper paper);

class ExamComposerScreen extends StatefulWidget {
  const ExamComposerScreen({super.key, this.onExport, this.savedExamId});

  final ExportExamCallback? onExport;

  /// Reopens this paper from «أسئلتي المحفوظة»; edits update the same record.
  final String? savedExamId;

  @override
  State<ExamComposerScreen> createState() => _ExamComposerScreenState();
}

class _ExamComposerScreenState extends State<ExamComposerScreen> {
  ExamComposerController? _controller;
  ExamAutosaver? _autosaver;
  int _tabIndex = 0; // 0 = التحرير والتخصيص, 1 = معاينة الورقة الرسمية
  bool _exporting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller == null) {
      final state = AppScope.of(context);
      final savedId = widget.savedExamId;
      final saved = savedId == null ? null : state.savedExams.byId(savedId);
      final controller = ExamComposerController(
        examBank: state.examBank,
        teacherProfile: state.teacherProfile,
        activePart: state.activePart,
        initialPaper: saved?.paper,
      );
      _controller = controller;
      _autosaver = ExamAutosaver(
        controller: controller,
        library: state.savedExams,
        savedId: saved?.id,
      );
    }
  }

  @override
  void dispose() {
    _autosaver?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _exportPaper() async {
    final ctrl = _controller;
    if (ctrl == null || _exporting) {
      return;
    }
    setState(() => _exporting = true);
    // Every exported paper is also kept in «أسئلتي المحفوظة».
    _autosaver?.saveNow();
    try {
      final exporter = widget.onExport ?? const ExamDocumentExporter().exportDocx;
      final outcome = await exporter(ctrl.paper);
      if (!mounted) {
        return;
      }
      if (outcome.kind == ExportOutcomeKind.savedToFile) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حفظ ملف Word بنجاح: ${outcome.filePath}'),
          ),
        );
      } else if (outcome.kind == ExportOutcomeKind.shared) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تجهيز ملف أسئلة الامتحان (.docx) للمشاركة.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذّر تصدير ملف Word: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller!;
    return AnimatedBuilder(
      animation: ctrl,
      builder: (BuildContext context, _) {
        final paper = ctrl.paper;
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;

        return Scaffold(
          appBar: AppBar(
            title: const Text('مولّد أسئلة الامتحان الرسمي (Word)'),
            actions: <Widget>[
              _AutosaveIndicator(saved: _autosaver?.hasSavedCopy ?? false),
              const TextScaleControls(),
            ],
          ),
          body: Column(
            children: <Widget>[
              // Mode toggle bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  border: Border(
                    bottom: BorderSide(color: scheme.outlineVariant),
                  ),
                ),
                child: AppPage(
                  maxWidth: AppLayout.readingMaxWidth,
                  padding: EdgeInsets.zero,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: <Widget>[
                      SegmentedButton<int>(
                        segments: const <ButtonSegment<int>>[
                          ButtonSegment<int>(
                            value: 0,
                            icon: Icon(Icons.tune, size: 18),
                            label: Text('إعداد الأسئلة'),
                          ),
                          ButtonSegment<int>(
                            value: 1,
                            icon: Icon(Icons.preview_outlined, size: 18),
                            label: Text('معاينة ورقة A4'),
                          ),
                        ],
                        selected: <int>{_tabIndex},
                        onSelectionChanged: (Set<int> next) {
                          if (next.isNotEmpty) {
                            setState(() => _tabIndex = next.first);
                          }
                        },
                      ),
                      _DegreeSummaryBadge(paper: paper),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _tabIndex == 0
                    ? _ComposerEditorView(controller: ctrl)
                    : _LivePaperPreview(paper: paper),
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
                          'المجموع الكلي: ${toArabicDigits(paper.totalDegree)} درجة '
                          '(${toArabicDigits(paper.composition.degree)} + '
                          '${toArabicDigits(paper.grammar.degree)} + '
                          '${toArabicDigits(paper.orthography.degree)})',
                          style: theme.textTheme.labelLarge,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      FilledButton.icon(
                        key: const ValueKey<String>('export-docx-button'),
                        onPressed: _exporting ? null : _exportPaper,
                        icon: _exporting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.download_outlined, size: 20),
                        label: Text(
                          _exporting ? 'جاري التصدير...' : 'تصدير Word (.docx)',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AutosaveIndicator extends StatelessWidget {
  const _AutosaveIndicator({required this.saved});

  final bool saved;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: saved
          ? 'تم حفظ آخر تعديل تلقائياً في «أسئلتي المحفوظة»'
          : 'تُحفظ الورقة تلقائياً في «أسئلتي المحفوظة» عند أول تعديل',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: Icon(
          saved ? Icons.cloud_done_outlined : Icons.cloud_outlined,
          key: ValueKey<String>(saved ? 'autosave-saved' : 'autosave-idle'),
        ),
      ),
    );
  }
}

class _DegreeSummaryBadge extends StatelessWidget {
  const _DegreeSummaryBadge({required this.paper});

  final ArabicExamPaper paper;

  @override
  Widget build(BuildContext context) {
    final balanced = paper.grammarBalanced && paper.orthographyBalanced;
    final okColor = AppColors.resolveAccent('green', Theme.of(context).brightness);
    final warnColor = Theme.of(context).colorScheme.error;
    final color = balanced ? okColor : warnColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            balanced ? Icons.verified_outlined : Icons.warning_amber_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            balanced
                ? 'توزيع الدرجات متوازن (${toArabicDigits(paper.totalDegree)})'
                : 'راجع مجموع درجات الأفرع',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _ComposerEditorView extends StatelessWidget {
  const _ComposerEditorView({required this.controller});

  final ExamComposerController controller;

  @override
  Widget build(BuildContext context) {
    final paper = controller.paper;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.only(
        top: AppSpacing.md,
        bottom: AppSpacing.xxl,
      ),
      children: <Widget>[
        AppPage(
          maxWidth: AppLayout.readingMaxWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // 1. Quick Presets & Official Word Templates
              SectionHeader(
                title: 'النماذج الرسمية والتوليد الذكي',
                subtitle:
                    'اختر نموذجاً رسمياً جاهزاً أو ولّد نسخة متوازنة جديدة بضغطة واحدة',
                accent: scheme.secondary,
              ),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'توليد امتحان جديد من بنك الأسئلة:',
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        FilledButton.tonalIcon(
                          key: const ValueKey<String>('gen-exam-part1'),
                          onPressed: () =>
                              controller.generateBalancedExam(scope: 'part1'),
                          icon: const Icon(Icons.auto_awesome, size: 17),
                          label: const Text('نصف السنة (الجزء الأول)'),
                        ),
                        FilledButton.tonalIcon(
                          key: const ValueKey<String>('gen-exam-part2'),
                          onPressed: () =>
                              controller.generateBalancedExam(scope: 'part2'),
                          icon: const Icon(Icons.auto_awesome, size: 17),
                          label: const Text('الفصل الثاني (الجزء الثاني)'),
                        ),
                        FilledButton.tonalIcon(
                          key: const ValueKey<String>('gen-exam-both'),
                          onPressed: () =>
                              controller.generateBalancedExam(scope: 'both'),
                          icon: const Icon(Icons.auto_awesome, size: 17),
                          label: const Text('نهاية السنة (شامل)'),
                        ),
                      ],
                    ),
                    const Divider(height: 22),
                    Text(
                      'أو تحميل أحد نماذج الأسئلة الرسمية الأربعة المعتمدة:',
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        for (final tpl in controller.examBank.officialTemplates)
                          ActionChip(
                            key: ValueKey<String>('tpl-${tpl.id}'),
                            avatar: const Icon(Icons.article_outlined, size: 17),
                            label: Text('${tpl.round} (${tpl.academicYear})'),
                            onPressed: () =>
                                controller.loadOfficialTemplate(tpl),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // 2. Header & Typography Card
              SectionHeader(
                title: 'ترويسة الورقة والخط المطبعي',
                subtitle: 'بيانات المدرسة، الدور، الوقت، واسم مدرس المادة',
                accent: scheme.primary,
              ),
              _HeaderAndTypographyEditor(controller: controller),

              const SizedBox(height: AppSpacing.xl),

              // 3. Section 1 — الإنشاء
              SectionHeader(
                title: 'أولاً: الإنشاء (${toArabicDigits(paper.composition.degree)} درجة)',
                subtitle: 'موضوعان يختار الطالب الكتابة في أحدهما',
                accent: AppColors.resolveAccent('gold', theme.brightness),
                trailing: TextButton.icon(
                  onPressed: () => _pickCompositionFromBank(context, controller),
                  icon: const Icon(Icons.library_add_outlined, size: 18),
                  label: const Text('من بنك الإنشاء'),
                ),
              ),
              _CompositionEditor(controller: controller),

              const SizedBox(height: AppSpacing.xl),

              // 4. Section 2 — قواعد اللغة العربية
              SectionHeader(
                title:
                    'ثانياً: قواعد اللغة العربية (${toArabicDigits(paper.grammar.degree)} درجة)',
                subtitle:
                    'مجموع الأفرع الحالي: ${toArabicDigits(paper.grammar.branchesSum)} درجة — ضع علامة _حول الكلمة_ لوضع خط تحتها في Word',
                accent: scheme.primary,
                trailing: TextButton.icon(
                  onPressed: () => controller.addQuestionBlock(isGrammar: true),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('سؤال جديد'),
                ),
              ),
              for (var qi = 0; qi < paper.grammar.questions.length; qi++)
                _QuestionBlockEditor(
                  controller: controller,
                  isGrammar: true,
                  questionIndex: qi,
                  block: paper.grammar.questions[qi],
                ),

              const SizedBox(height: AppSpacing.xl),

              // 5. Section 3 — الإملاء
              SectionHeader(
                title:
                    'ثالثاً: الإملاء (${toArabicDigits(paper.orthography.degree)} درجة)',
                subtitle:
                    'مجموع الأفرع الحالي: ${toArabicDigits(paper.orthography.branchesSum)} درجة',
                accent: AppColors.resolveAccent('green', theme.brightness),
                trailing: TextButton.icon(
                  onPressed: () => _pickOrthographyBranch(context, controller),
                  icon: const Icon(Icons.library_add_outlined, size: 18),
                  label: const Text('استبدال من بنك الإملاء'),
                ),
              ),
              for (var qi = 0; qi < paper.orthography.questions.length; qi++)
                _QuestionBlockEditor(
                  controller: controller,
                  isGrammar: false,
                  questionIndex: qi,
                  block: paper.orthography.questions[qi],
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _pickCompositionFromBank(
    BuildContext context,
    ExamComposerController ctrl,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: <Widget>[
            Text(
              'اختر موضوعاً لإضافته إلى قسم الإنشاء',
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            for (final item in ctrl.examBank.compositionTopics) ...<Widget>[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.text),
                subtitle: Text(
                  item.part == 'part1' ? 'الجزء الأول' : 'الجزء الثاني',
                ),
                trailing: const Icon(Icons.add_circle_outline),
                onTap: () {
                  final nextTopics = <String>[
                    ...ctrl.paper.composition.topics,
                    item.text,
                  ];
                  ctrl.updateComposition(
                    ctrl.paper.composition.copyWith(topics: nextTopics),
                  );
                  Navigator.of(ctx).pop();
                },
              ),
              const Divider(height: 1),
            ],
          ],
        );
      },
    );
  }

  void _pickOrthographyBranch(
    BuildContext context,
    ExamComposerController ctrl,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: <Widget>[
            Text(
              'اختر سؤال إملاء لإضافته كفرع جديد',
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            for (final item in ctrl.examBank.orthographyItems) ...<Widget>[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.prompt),
                subtitle: Text(
                  item.items.isEmpty
                      ? 'سؤال تعريفي / تمثيلي'
                      : item.items.join(' • '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.add_circle_outline),
                onTap: () {
                  ctrl.addBranchToQuestion(isGrammar: false, questionIndex: 0);
                  final lastIdx =
                      ctrl.paper.orthography.questions[0].branches.length - 1;
                  final currentBranch =
                      ctrl.paper.orthography.questions[0].branches[lastIdx];
                  ctrl.updateBranch(
                    isGrammar: false,
                    questionIndex: 0,
                    branchIndex: lastIdx,
                    updated: currentBranch.copyWith(
                      prompt: item.prompt,
                      degree: item.defaultDegree,
                      items: item.items,
                      itemLayout: item.itemLayout,
                    ),
                  );
                  Navigator.of(ctx).pop();
                },
              ),
              const Divider(height: 1),
            ],
          ],
        );
      },
    );
  }
}

class _HeaderAndTypographyEditor extends StatelessWidget {
  const _HeaderAndTypographyEditor({required this.controller});

  final ExamComposerController controller;

  @override
  Widget build(BuildContext context) {
    final h = controller.paper.header;
    final typo = controller.paper.typography;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _LabeledField(
            label: 'الإدارة',
            initialValue: h.administrationLine,
            onChanged: (v) => controller.updateHeader(h.copyWith(administrationLine: v)),
          ),
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('إظهار بيانات إضافية في الترويسة'),
            value: h.showAdditionalHeaderLines,
            onChanged: (v) => controller.updateHeader(h.copyWith(showAdditionalHeaderLines: v)),
          ),
          _LabeledField(
            label: 'الدولة',
            initialValue: h.countryLine,
            onChanged: (v) => controller.updateHeader(h.copyWith(countryLine: v)),
          ),
          const SizedBox(height: AppSpacing.sm),
          _LabeledField(
            label: 'الوزارة',
            initialValue: h.ministryLine,
            onChanged: (v) => controller.updateHeader(h.copyWith(ministryLine: v)),
          ),
          const SizedBox(height: AppSpacing.sm),
          _LabeledField(
            label: 'اسم المدرسة',
            initialValue: h.schoolName,
            onChanged: (v) => controller.updateHeader(h.copyWith(schoolName: v)),
          ),
          const SizedBox(height: AppSpacing.sm),
          _LabeledField(
            label: 'مديرية التربية',
            initialValue: h.directorateLine,
            onChanged: (v) =>
                controller.updateHeader(h.copyWith(directorateLine: v)),
          ),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              final titleField = _LabeledField(
                label: 'عنوان الامتحان',
                initialValue: h.examTitleLine,
                onChanged: (v) =>
                    controller.updateHeader(h.copyWith(examTitleLine: v)),
              );
              final roundField = _LabeledField(
                label: 'الدور / الفصل',
                initialValue: h.roundLine,
                onChanged: (v) =>
                    controller.updateHeader(h.copyWith(roundLine: v)),
              );
              if (c.maxWidth >= 540) {
                return Row(
                  children: <Widget>[
                    Expanded(child: titleField),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: roundField),
                  ],
                );
              }
              return Column(
                children: <Widget>[
                  titleField,
                  const SizedBox(height: AppSpacing.sm),
                  roundField,
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              final yearField = _LabeledField(
                label: 'العام الدراسي',
                initialValue: h.academicYear,
                onChanged: (v) =>
                    controller.updateHeader(h.copyWith(academicYear: v)),
              );
              final timeField = _LabeledField(
                label: 'الوقت المخصص',
                initialValue: h.timeAllowed,
                onChanged: (v) =>
                    controller.updateHeader(h.copyWith(timeAllowed: v)),
              );
              if (c.maxWidth >= 540) {
                return Row(
                  children: <Widget>[
                    Expanded(child: yearField),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: timeField),
                  ],
                );
              }
              return Column(
                children: <Widget>[
                  yearField,
                  const SizedBox(height: AppSpacing.sm),
                  timeField,
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          _LabeledField(
            label: 'المادة',
            initialValue: h.subjectLine,
            onChanged: (v) => controller.updateHeader(h.copyWith(subjectLine: v)),
          ),
          const SizedBox(height: AppSpacing.sm),
          _LabeledField(
            label: 'الصف',
            initialValue: h.gradeLine,
            onChanged: (v) => controller.updateHeader(h.copyWith(gradeLine: v)),
          ),
          const SizedBox(height: AppSpacing.sm),
          _LabeledField(
            label: 'تاريخ الامتحان',
            initialValue: h.examDate,
            onChanged: (v) => controller.updateHeader(h.copyWith(examDate: v)),
          ),
          const SizedBox(height: AppSpacing.sm),
          _LabeledField(
            label: 'ملاحظة الترويسة',
            initialValue: h.noteLine,
            onChanged: (v) => controller.updateHeader(h.copyWith(noteLine: v)),
          ),
          const SizedBox(height: AppSpacing.sm),
          _LabeledField(
            label: 'عبارة ختام الأسئلة',
            initialValue: h.closingWish,
            onChanged: (v) => controller.updateHeader(h.copyWith(closingWish: v)),
          ),
          const SizedBox(height: AppSpacing.sm),
          _LabeledField(
            label: 'عنوان التوقيع',
            initialValue: h.teacherTitle,
            onChanged: (v) => controller.updateHeader(h.copyWith(teacherTitle: v)),
          ),
          const SizedBox(height: AppSpacing.sm),
          _LabeledField(
            label: 'اسم مدرس المادة (في التوقيع أسفل اليسار)',
            initialValue: h.teacherName,
            onChanged: (v) =>
                controller.updateHeader(h.copyWith(teacherName: v)),
          ),
          _LabeledField(
            label: 'عنوان اسم الطالب',
            initialValue: h.studentNameLabel,
            onChanged: (v) => controller.updateHeader(h.copyWith(studentNameLabel: v)),
          ),
          const SizedBox(height: AppSpacing.sm),
          _LabeledField(
            label: 'عنوان الرقم الامتحاني',
            initialValue: h.studentNumberLabel,
            onChanged: (v) => controller.updateHeader(h.copyWith(studentNumberLabel: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('إظهار شريط (اسم الطالب والرقم الامتحاني)'),
            value: h.includeStudentFields,
            onChanged: (v) =>
                controller.updateHeader(h.copyWith(includeStudentFields: v)),
          ),
          const Divider(height: 16),
          DropdownButtonFormField<ExamFontChoice>(
            initialValue: typo.font,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'نوع خط ملف Word'),
            items: <DropdownMenuItem<ExamFontChoice>>[
              for (final f in ExamFontChoice.values)
                DropdownMenuItem<ExamFontChoice>(
                  value: f,
                  child: Text(f.label),
                ),
            ],
            onChanged: (ExamFontChoice? next) {
              if (next != null) {
                controller.updateTypography(typo.copyWith(font: next));
              }
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          // Label above the slider (as in the spacing controls), so narrow
          // phones and large text scales never overflow the row.
          Text('حجم الخط: ${toArabicDigits(typo.bodySizePt)} نقطة'),
          Slider(
            key: const ValueKey<String>('exam-body-font-size'),
            value: typo.bodySizePt.toDouble(),
            min: 8,
            max: 18,
            divisions: 10,
            label: '${typo.bodySizePt} pt',
            onChanged: (double v) => controller.updateTypography(
              typo.copyWith(
                bodySizePt: v.round(),
                headingSizePt: v.round() + 1,
              ),
            ),
          ),
          const Divider(height: 16),
          Text('تباعد الأسئلة والنقاط', style: Theme.of(context).textTheme.titleSmall),
          _SpacingControl(
            label: 'تباعد الأسطر',
            value: typo.spacing.lineHeight,
            min: 1, max: 2, divisions: 20,
            unit: '×',
            onChanged: (v) => controller.updateTypography(typo.copyWith(
              spacing: typo.spacing.copyWith(lineHeight: v),
            )),
          ),
          _SpacingControl(
            label: 'المسافة بين النقاط',
            value: typo.spacing.itemGapPt,
            max: 12, divisions: 24,
            onChanged: (v) => controller.updateTypography(typo.copyWith(
              spacing: typo.spacing.copyWith(itemGapPt: v),
            )),
          ),
          _SpacingControl(
            label: 'المسافة بين الفروع',
            value: typo.spacing.branchGapPt,
            max: 18, divisions: 36,
            onChanged: (v) => controller.updateTypography(typo.copyWith(
              spacing: typo.spacing.copyWith(branchGapPt: v),
            )),
          ),
          _SpacingControl(
            label: 'المسافة بين الأسئلة',
            value: typo.spacing.questionGapPt,
            max: 24, divisions: 48,
            onChanged: (v) => controller.updateTypography(typo.copyWith(
              spacing: typo.spacing.copyWith(questionGapPt: v),
            )),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              icon: const Icon(Icons.compress),
              label: const Text('استعادة التباعد المضغوط'),
              onPressed: () => controller.updateTypography(
                typo.copyWith(spacing: const ExamSpacing()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompositionEditor extends StatelessWidget {
  const _CompositionEditor({required this.controller});

  final ExamComposerController controller;

  @override
  Widget build(BuildContext context) {
    final comp = controller.paper.composition;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _LabeledField(
            label: 'صيغة سؤال الإنشاء',
            initialValue: comp.prompt,
            multiline: true,
            onChanged: (v) =>
                controller.updateComposition(comp.copyWith(prompt: v)),
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: SizedBox(
              width: 96,
              child: _DegreeStepper(
                degree: comp.degree,
                onChanged: (d) =>
                    controller.updateComposition(comp.copyWith(degree: d)),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < comp.topics.length; i++) ...<Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: _LabeledField(
                      label: 'الموضوع (${toArabicDigits(i + 1)})',
                      initialValue: comp.topics[i],
                      multiline: true,
                      onChanged: (String v) {
                        final list = List<String>.from(comp.topics);
                        list[i] = v;
                        controller.updateComposition(
                          comp.copyWith(topics: list),
                        );
                      },
                    ),
                  ),
                  if (comp.topics.length > 1)
                    IconButton(
                      tooltip: 'حذف الموضوع',
                      onPressed: () {
                        final list = List<String>.from(comp.topics)
                          ..removeAt(i);
                        controller.updateComposition(
                          comp.copyWith(topics: list),
                        );
                      },
                      icon: const Icon(Icons.delete_outline),
                    ),
                ],
              ),
            ),
          ],
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () {
                final list = <String>[...comp.topics, 'اكتب في موضوع جديد...'];
                controller.updateComposition(comp.copyWith(topics: list));
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('إضافة موضوع إنشاء يدوي'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionBlockEditor extends StatelessWidget {
  const _QuestionBlockEditor({
    required this.controller,
    required this.isGrammar,
    required this.questionIndex,
    required this.block,
  });

  final ExamComposerController controller;
  final bool isGrammar;
  final int questionIndex;
  final ExamQuestionBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'السؤال ${toArabicDigits(block.number)} '
                  '(${toArabicDigits(block.totalDegree)} درجات)',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              TextButton.icon(
                onPressed: () => controller.addBranchToQuestion(
                  isGrammar: isGrammar,
                  questionIndex: questionIndex,
                ),
                icon: const Icon(Icons.call_split, size: 17),
                label: const Text('إضافة فرع'),
              ),
              if ((isGrammar
                          ? controller.paper.grammar.questions.length
                          : controller.paper.orthography.questions.length) >
                  1)
                IconButton(
                  tooltip: 'حذف السؤال',
                  onPressed: () => controller.removeQuestionBlock(
                    isGrammar: isGrammar,
                    questionIndex: questionIndex,
                  ),
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          for (var bi = 0; bi < block.branches.length; bi++) ...<Widget>[
            const Divider(height: 20),
            _BranchEditor(
              controller: controller,
              isGrammar: isGrammar,
              questionIndex: questionIndex,
              branchIndex: bi,
              branch: block.branches[bi],
              canRemove: block.branches.length > 1,
            ),
          ],
        ],
      ),
    );
  }
}

class _BranchEditor extends StatelessWidget {
  const _BranchEditor({
    required this.controller,
    required this.isGrammar,
    required this.questionIndex,
    required this.branchIndex,
    required this.branch,
    required this.canRemove,
  });

  final ExamComposerController controller;
  final bool isGrammar;
  final int questionIndex;
  final int branchIndex;
  final ExamBranch branch;
  final bool canRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            if (branch.branch.isNotEmpty) Chip(label: Text('فرع ${branch.branch}')),
            SizedBox(
              width: 92,
              child: _DegreeStepper(
                degree: branch.degree,
                onChanged: (int d) => controller.updateBranch(
                  isGrammar: isGrammar,
                  questionIndex: questionIndex,
                  branchIndex: branchIndex,
                  updated: branch.copyWith(degree: d),
                ),
              ),
            ),
            if (canRemove)
              IconButton(
                tooltip: 'حذف الفرع',
                onPressed: () => controller.removeBranchFromQuestion(
                  isGrammar: isGrammar,
                  questionIndex: questionIndex,
                  branchIndex: branchIndex,
                ),
                icon: const Icon(Icons.close, size: 19),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        _LabeledField(
          label: 'منطوق السؤال / الفرع',
          initialValue: branch.prompt,
          multiline: true,
          onChanged: (String v) => controller.updateBranch(
            isGrammar: isGrammar,
            questionIndex: questionIndex,
            branchIndex: branchIndex,
            updated: branch.copyWith(prompt: v),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text('تنسيق النقاط:', style: theme.textTheme.labelMedium),
            for (final layout in ExamItemLayout.values)
              ChoiceChip(
                label: Text(layout.label),
                selected: branch.itemLayout == layout,
                onSelected: (_) => controller.updateBranch(
                  isGrammar: isGrammar,
                  questionIndex: questionIndex,
                  branchIndex: branchIndex,
                  updated: branch.copyWith(itemLayout: layout),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var ii = 0; ii < branch.items.length; ii++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: _LabeledField(
                    label: 'نقطة (${toArabicDigits(ii + 1)})',
                    initialValue: branch.items[ii],
                    multiline: true,
                    onChanged: (String v) {
                      final next = List<String>.from(branch.items);
                      next[ii] = v;
                      controller.updateBranch(
                        isGrammar: isGrammar,
                        questionIndex: questionIndex,
                        branchIndex: branchIndex,
                        updated: branch.copyWith(items: next),
                      );
                    },
                  ),
                ),
                IconButton(
                  tooltip: 'حذف النقطة',
                  onPressed: () {
                    final next = List<String>.from(branch.items)..removeAt(ii);
                    controller.updateBranch(
                      isGrammar: isGrammar,
                      questionIndex: questionIndex,
                      branchIndex: branchIndex,
                      updated: branch.copyWith(items: next),
                    );
                  },
                  icon: const Icon(Icons.remove_circle_outline, size: 19),
                ),
              ],
            ),
          ),
        Wrap(
          spacing: AppSpacing.sm,
          children: <Widget>[
            TextButton.icon(
              onPressed: () {
                final next = <String>[...branch.items, 'نقطة جديدة...'];
                controller.updateBranch(
                  isGrammar: isGrammar,
                  questionIndex: questionIndex,
                  branchIndex: branchIndex,
                  updated: branch.copyWith(items: next),
                );
              },
              icon: const Icon(Icons.add, size: 17),
              label: const Text('إضافة نقطة يدوية'),
            ),
            if (isGrammar)
              TextButton.icon(
                onPressed: () => _pickGrammarItemFromBank(context),
                icon: const Icon(Icons.library_books_outlined, size: 17),
                label: const Text('إضافة من بنك القواعد'),
              ),
          ],
        ),
      ],
    );
  }

  void _pickGrammarItemFromBank(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: <Widget>[
            Text(
              'اختر فقرة من بنك أسئلة القواعد الرسمي',
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final gi in controller.examBank.grammarItems) ...<Widget>[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: UnderlineRichText(gi.text),
                subtitle: Text(
                  '${gi.part == 'part1' ? 'الجزء الأول' : 'الجزء الثاني'} • ${gi.promptGroup}',
                ),
                trailing: const Icon(Icons.add_circle_outline),
                onTap: () {
                  final next = <String>[...branch.items, gi.text];
                  controller.updateBranch(
                    isGrammar: isGrammar,
                    questionIndex: questionIndex,
                    branchIndex: branchIndex,
                    updated: branch.copyWith(items: next),
                  );
                  Navigator.of(ctx).pop();
                },
              ),
              const Divider(height: 1),
            ],
          ],
        );
      },
    );
  }
}

/// Live preview sharing question order and spacing with the Word renderer.
class _LivePaperPreview extends StatelessWidget {
  const _LivePaperPreview({required this.paper});

  final ArabicExamPaper paper;

  @override
  Widget build(BuildContext context) {
    // A physical A4 canvas at 96 dpi, with the same half-inch margins as Word.
    // Scroll horizontally on narrow screens rather than reflowing the document.
    const pxPerPt = 96 / 72;
    const pageWidth = ExamDocxBuilder.pageWidthDxa / 20 * pxPerPt;
    const pageHeight = ExamDocxBuilder.pageHeightDxa / 20 * pxPerPt;
    const margin = ExamDocxBuilder.marginDxa / 20 * pxPerPt;
    final family = paper.typography.font.family;
    final baseStyle = TextStyle(
      fontFamily: family,
      fontSize: paper.typography.bodySizePt * pxPerPt,
      color: const Color(0xFF141414),
      fontWeight: FontWeight.w700,
      height: paper.typography.spacing.lineHeight,
    );
    final headerStyle = baseStyle.copyWith(
      fontSize: ExamHeaderLayout.fontSizePt * pxPerPt,
      fontWeight: FontWeight.normal,
      height: 1,
    );
    final sectionStyle = baseStyle.copyWith(
      fontSize: paper.typography.headingSizePt * pxPerPt,
    );
    final cells = ExamHeaderLayout.build(paper);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        const Text('معاينة تقريبية: قد تختلف الخطوط وتقسيم الصفحات في Word.'),
        const SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
            child: Container(
              width: pageWidth,
              constraints: const BoxConstraints(minHeight: pageHeight),
              padding: const EdgeInsets.all(margin),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black26),
                boxShadow: const <BoxShadow>[
                  BoxShadow(color: Color(0x1F000000), blurRadius: 14, offset: Offset(0, 6)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      for (var i = 0; i < cells.length; i++)
                        Expanded(
                          flex: ExamHeaderLayout.columnWidthsDxa[i],
                          child: Padding(
                            // Word table cells have a default horizontal inset of 108 twips.
                            padding: const EdgeInsets.symmetric(horizontal: 108 / 20 * pxPerPt),
                            child: Column(
                              children: <Widget>[
                                for (final line in cells[i])
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 24 / 20 * pxPerPt),
                                    child: Text(line, style: headerStyle, textAlign: TextAlign.center),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (paper.header.includeStudentFields) ...<Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(child: Text(paper.header.studentNameLabel, style: headerStyle)),
                        Expanded(child: Text(paper.header.studentNumberLabel, style: headerStyle)),
                      ],
                    ),
                  ],
                  const Divider(color: Colors.black, thickness: 1.5, height: 12),
                  for (final paragraph in ExamLayoutPlan.build(paper))
                    _PreviewExamParagraph(
                      paragraph: paragraph,
                      paper: paper,
                      style: paragraph.kind == ExamParagraphKind.heading ? sectionStyle : baseStyle,
                    ),
                  if (paper.header.closingWish.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 140 / 20 * pxPerPt),
                    Text(paper.header.closingWish.trim(), style: baseStyle, textAlign: TextAlign.center),
                  ],
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      children: <Widget>[
                        if (paper.header.teacherTitle.trim().isNotEmpty)
                          Text(paper.header.teacherTitle.trim(), style: baseStyle),
                        if (paper.header.teacherName.trim().isNotEmpty)
                          Text(paper.header.teacherName.trim(), style: baseStyle),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PreviewExamParagraph extends StatelessWidget {
  const _PreviewExamParagraph({
    required this.paragraph,
    required this.paper,
    required this.style,
  });

  final ExamLayoutParagraph paragraph;
  final ArabicExamPaper paper;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    // Points to logical pixels at the preview's nominal 96 dpi.
    const pxPerPt = 96 / 72;
    final text = UnderlineRichText(paragraph.text, style: style);
    return Padding(
      padding: EdgeInsetsDirectional.only(
        top: paragraph.spaceBeforePt * pxPerPt,
        start: paragraph.indentPt * pxPerPt,
      ),
      child: paragraph.degree == null ? text : _withDegreeBadge(text, pxPerPt),
    );
  }

  /// Mirrors the Word paragraph: the prompt wraps inside the start column and
  /// the badge ends flush with the left margin, on the prompt's (last) line.
  Widget _withDegreeBadge(Widget text, double pxPerPt) {
    final badge = ExamDegreeBadge.text(
      paragraph.degree!,
      westernDigits: paper.typography.useWesternDigits,
    );
    final fontSizePt = (style.fontSize ?? 14 * pxPerPt) / pxPerPt;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(child: text),
        SizedBox(
          width: ExamDegreeBadge.columnWidthPt(badge, fontSizePt) * pxPerPt,
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(badge, style: style, maxLines: 1),
            ),
          ),
        ),
      ],
    );
  }
}

class _SpacingControl extends StatelessWidget {
  const _SpacingControl({
    required this.label,
    required this.value,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.min = 0,
    this.unit = 'نقطة',
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String unit;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text('$label: ${toArabicDigits(value.toStringAsFixed(2))} $unit'),
      Slider(
        key: ValueKey<String>(label),
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        label: '${value.toStringAsFixed(2)} $unit',
        semanticFormatterCallback: (v) => '$label: $v $unit',
        onChanged: onChanged,
      ),
    ],
  );
}

class _LabeledField extends StatefulWidget {
  const _LabeledField({
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.multiline = false,
  });

  final String label;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final bool multiline;

  @override
  State<_LabeledField> createState() => _LabeledFieldState();
}

class _LabeledFieldState extends State<_LabeledField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant _LabeledField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != _ctrl.text &&
        widget.initialValue != oldWidget.initialValue) {
      _ctrl.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      minLines: widget.multiline ? 2 : 1,
      maxLines: widget.multiline ? null : 1,
      keyboardType: widget.multiline ? TextInputType.multiline : TextInputType.text,
      decoration: InputDecoration(
        labelText: widget.label,
        isDense: true,
      ),
      onChanged: widget.onChanged,
    );
  }
}

class _DegreeStepper extends StatelessWidget {
  const _DegreeStepper({required this.degree, required this.onChanged});

  final int degree;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          InkWell(
            onTap: degree > 1 ? () => onChanged(degree - 1) : null,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.remove, size: 16),
            ),
          ),
          Text(
            toArabicDigits(degree),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          InkWell(
            onTap: degree < 60 ? () => onChanged(degree + 1) : null,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.add, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}
