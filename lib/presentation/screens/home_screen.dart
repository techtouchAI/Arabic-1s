import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';
import '../../core/utils/arabic_text.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/section_header.dart';
import '../../domain/models/library.dart';
import '../state/app_state.dart';
import '../widgets/bayan_emblem.dart';
import '../widgets/text_scale_controls.dart';
import 'exam_composer_screen.dart';
import 'glossary_screen.dart';
import 'lesson_screen.dart';
import 'question_print_screen.dart';
import 'study_plan_screen.dart';
import 'saved_exams_screen.dart';
import 'settings_screen.dart';
import 'unit_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final units = state.partUnits;
    final lessons = state.partLessons;
    final introUnit = state.library.unitById('intro');
    final orthoUnit = state.library.unitById('orthography-expression');
    final resume = state.resumeUnit;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            const BayanEmblem(size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'بَيَان — ${state.partTitle}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          const TextScaleControls(),
          IconButton(
            key: const ValueKey<String>('home-settings-button'),
            tooltip: 'الإعدادات وبيانات المدرس',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SettingsScreen(),
              ),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: <Widget>[
          AppPage(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: AppSpacing.sm),
                _HeroBanner(state: state),
                const SizedBox(height: AppSpacing.lg),

                // Teacher & Exam Quick Actions
                SectionHeader(
                  title: 'أدوات المدرس والامتحانات',
                  subtitle: 'تصدير أسئلة Word رسمية (.docx) وملخص للطالب (PDF)',
                  accent: scheme.secondary,
                ),
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final wide = constraints.maxWidth >= 680;
                    final composerCard = _ToolActionCard(
                      cardKey: const ValueKey<String>('open-exam-composer'),
                      icon: Icons.description_outlined,
                      title: 'توليد أسئلة امتحان رسمي (Word)',
                      subtitle:
                          'مطابق ١٠٠٪ لنماذج الوزارة (الإنشاء ٣٠ • القواعد ٣٥ • الإملاء ١٥) بصيغة .docx قابلة للتعديل',
                      accent: scheme.primary,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ExamComposerScreen(),
                        ),
                      ),
                    );
                    final printCard = _ToolActionCard(
                      cardKey: const ValueKey<String>('open-question-printer'),
                      icon: Icons.print_outlined,
                      title: 'ملخص للطالب (PDF)',
                      subtitle:
                          'خياران: أسئلة وأجوبة نموذجية، أو ملخص قواعد فقط — لوحدة أو عدة وحدات على ورق A4',
                      accent: scheme.secondary,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const QuestionPrintScreen(),
                        ),
                      ),
                    );
                    final savedCard = ListenableBuilder(
                      listenable: state.savedExams,
                      builder: (BuildContext context, _) {
                        final count = state.savedExams.papers.length;
                        return _ToolActionCard(
                          cardKey: const ValueKey<String>('open-saved-exams'),
                          icon: Icons.inventory_2_outlined,
                          title: 'أسئلتي المحفوظة',
                          subtitle: count == 0
                              ? 'كل ورقة أسئلة تنشئها تُحفظ هنا تلقائياً مع كل تعديل'
                              : 'عدد الأوراق المحفوظة: ${toArabicDigits(count)} • تُحدَّث تلقائياً مع كل تعديل',
                          accent: scheme.tertiary,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const SavedExamsScreen(),
                            ),
                          ),
                        );
                      },
                    );
                    final planCard = _ToolActionCard(
                      cardKey: const ValueKey<String>('open-study-plan'),
                      icon: Icons.calendar_month_outlined,
                      title: 'الخطة اليومية والسنوية',
                      subtitle:
                          'جدول تدريس يومي وسنوي رسمي، قابل للتعديل والطباعة على ورق A4 بتصميم مهني',
                      accent: scheme.tertiary,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const StudyPlanScreen(),
                        ),
                      ),
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(child: composerCard),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(child: printCard),
                            ],
                          )
                        else ...<Widget>[
                          composerCard,
                          const SizedBox(height: AppSpacing.sm),
                          printCard,
                        ],
                        SizedBox(height: wide ? AppSpacing.md : AppSpacing.sm),
                        planCard,
                        SizedBox(height: wide ? AppSpacing.md : AppSpacing.sm),
                        savedCard,
                      ],
                    );
                  },
                ),

                if (resume != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xl),
                  _ResumeCard(unit: resume),
                ],

                // Units of active part
                const SizedBox(height: AppSpacing.xl),
                SectionHeader(
                  title: 'وحدات ${state.partTitle}',
                  subtitle:
                      '${toArabicDigits(units.length)} وحدات متكاملة (المطالعة • القواعد • الإملاء والتعبير • النص التقويمي)',
                  accent: scheme.primary,
                ),
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final cols = constraints.maxWidth >= 900
                        ? 2
                        : 1;
                    if (cols == 1) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          for (final unit in units) ...<Widget>[
                            _UnitSummaryTile(unit: unit),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                        ],
                      );
                    }
                    final rows = <Widget>[];
                    for (var i = 0; i < units.length; i += 2) {
                      rows.add(
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(child: _UnitSummaryTile(unit: units[i])),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: i + 1 < units.length
                                    ? _UnitSummaryTile(unit: units[i + 1])
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return Column(children: rows);
                  },
                ),

                // Grammar & Taqwim quick strip
                const SizedBox(height: AppSpacing.xl),
                SectionHeader(
                  title: 'ملخصات القواعد وتقويم اللسان (${state.partTitle})',
                  subtitle: 'مراجعة سريعة للضوابط النحوية ونماذج الإعراب المقررة',
                  accent: AppColors.resolveAccent('gold', theme.brightness),
                ),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    for (final lesson in lessons)
                      ActionChip(
                        avatar: const Icon(Icons.auto_stories_outlined, size: 17),
                        label: Text(lesson.title),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => LessonScreen(lessonId: lesson.id),
                          ),
                        ),
                      ),
                  ],
                ),

                // Reference cards: Glossary, Orthography, Intro
                const SizedBox(height: AppSpacing.xl),
                SectionHeader(
                  title: 'المراجع المساندة في الكتاب',
                  subtitle: 'معجم الطالب، جامع الإملاء والتعبير، ومقدمة المنهج',
                  accent: AppColors.resolveAccent('green', theme.brightness),
                ),
                _ReferenceCard(
                  icon: Icons.translate_rounded,
                  title: 'معجم الطالب (${state.partTitle})',
                  subtitle:
                      'شرح المفردات اللغوية الواردة في نهاية الكتاب الرسمي مرتبة بوضوح',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const GlossaryScreen(),
                    ),
                  ),
                ),
                if (orthoUnit != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  _ReferenceCard(
                    icon: Icons.edit_note_rounded,
                    title: orthoUnit.title,
                    subtitle: orthoUnit.readingTitle,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => UnitScreen(unitId: orthoUnit.id),
                      ),
                    ),
                  ),
                ],
                if (introUnit != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  _ReferenceCard(
                    icon: Icons.info_outline_rounded,
                    title: introUnit.title,
                    subtitle: 'فلسفة الطريقة التكاملية وتوزيع الدرجات الرسمية',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => UnitScreen(unitId: introUnit.id),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final profile = state.teacherProfile;
    final readCount = state.partUnits
        .where((u) => state.isUnitRead(u.id))
        .length;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: <Color>[
            scheme.primaryContainer.withValues(alpha: 0.72),
            scheme.secondaryContainer.withValues(alpha: 0.55),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              FittedBox(
                fit: BoxFit.scaleDown,
                child: SegmentedButton<CurriculumPart>(
                  segments: <ButtonSegment<CurriculumPart>>[
                    for (final part in CurriculumPart.values)
                      ButtonSegment<CurriculumPart>(
                        value: part,
                        label: Text(part.title),
                      ),
                  ],
                  selected: <CurriculumPart>{state.activePart},
                  onSelectionChanged: (Set<CurriculumPart> next) {
                    if (next.isNotEmpty) {
                      state.selectPart(next.first);
                    }
                  },
                ),
              ),
              Text(
                'تمت قراءة ${toArabicDigits(readCount)} من ${toArabicDigits(state.partUnits.length)} وحدات',
                style: theme.textTheme.labelMedium,
              ),
            ],
          ),
          if (profile.teacherName.isNotEmpty || profile.schoolName.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              <String>[
                if (profile.teacherName.isNotEmpty) 'الأستاذ: ${profile.teacherName}',
                if (profile.schoolName.isNotEmpty) profile.schoolName,
              ].join(' • '),
              style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary),
            ),
          ],
        ],
      ),
    );
  }
}

class _ToolActionCard extends StatelessWidget {
  const _ToolActionCard({
    required this.cardKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final Key cardKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      key: cardKey,
      color: scheme.surface,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: accent.withValues(alpha: 0.45)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.unit});

  final Unit unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => UnitScreen(unitId: unit.id),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: <Widget>[
              Icon(Icons.play_circle_outline, size: 30, color: scheme.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('متابعة الدراسة', style: theme.textTheme.labelMedium),
                    Text(unit.title, style: theme.textTheme.titleMedium),
                    Text(
                      '${unit.readingTitle} • ${unit.grammarTitle}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnitSummaryTile extends StatelessWidget {
  const _UnitSummaryTile({required this.unit});

  final Unit unit;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = AppColors.resolveAccent(unit.accent, theme.brightness);
    final isRead = state.isUnitRead(unit.id);

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey<String>('unit-card-${unit.id}'),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => UnitScreen(unitId: unit.id),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Text(
                  toArabicDigits(unit.order),
                  style: theme.textTheme.titleMedium?.copyWith(color: accent),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            unit.displayTitle,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        if (isRead)
                          Icon(
                            Icons.check_circle,
                            size: 17,
                            color: AppColors.resolveAccent('green', theme.brightness),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'المطالعة: ${unit.readingTitle}',
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      'القواعد: ${unit.grammarTitle} • ${unit.pageRange}',
                      style: theme.textTheme.labelMedium?.copyWith(color: accent),
                    ),
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

class _ReferenceCard extends StatelessWidget {
  const _ReferenceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(AppRadii.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, color: scheme.secondary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: theme.textTheme.titleSmall),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
