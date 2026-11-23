import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';
import '../../core/utils/arabic_text.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/section_header.dart';
import '../../domain/models/library.dart';
import '../state/app_state.dart';
import '../widgets/text_scale_controls.dart';
import 'glossary_screen.dart';
import 'lesson_screen.dart';
import 'unit_screen.dart';

enum _IndexFilter { all, part1, part2, grammar }

class IndexScreen extends StatefulWidget {
  const IndexScreen({super.key});

  @override
  State<IndexScreen> createState() => _IndexScreenState();
}

class _IndexScreenState extends State<IndexScreen> {
  _IndexFilter _filter = _IndexFilter.all;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p1Units = state.library.unitsForPart(CurriculumPart.part1);
    final p2Units = state.library.unitsForPart(CurriculumPart.part2);
    final lessons = state.library.lessons;

    return Scaffold(
      appBar: AppBar(
        title: const Text('فهرست الكتابين الكامل'),
        actions: <Widget>[
          const TextScaleControls(),
          IconButton(
            tooltip: 'معجم الطالب',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const GlossaryScreen(),
              ),
            ),
            icon: const Icon(Icons.translate_rounded),
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
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: <Widget>[
                    ChoiceChip(
                      label: const Text('جميع الأقسام (١٩ وحدة)'),
                      selected: _filter == _IndexFilter.all,
                      onSelected: (_) => setState(() => _filter = _IndexFilter.all),
                    ),
                    ChoiceChip(
                      label: const Text('الجزء الأول (١٠ وحدات)'),
                      selected: _filter == _IndexFilter.part1,
                      onSelected: (_) => setState(() => _filter = _IndexFilter.part1),
                    ),
                    ChoiceChip(
                      label: const Text('الجزء الثاني (٩ وحدات)'),
                      selected: _filter == _IndexFilter.part2,
                      onSelected: (_) => setState(() => _filter = _IndexFilter.part2),
                    ),
                    ChoiceChip(
                      label: const Text('دروس القواعد (١٩ درساً)'),
                      selected: _filter == _IndexFilter.grammar,
                      onSelected: (_) => setState(() => _filter = _IndexFilter.grammar),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                if (_filter == _IndexFilter.all || _filter == _IndexFilter.part1) ...<Widget>[
                  SectionHeader(
                    title: 'الجزء الأول — الفصل الدراسي الأول',
                    subtitle: 'عشر وحدات دراسية متكاملة (ص ٤–١٥٢)',
                    accent: scheme.primary,
                  ),
                  for (final u in p1Units) _IndexUnitRow(unit: u),
                  const SizedBox(height: AppSpacing.xl),
                ],

                if (_filter == _IndexFilter.all || _filter == _IndexFilter.part2) ...<Widget>[
                  SectionHeader(
                    title: 'الجزء الثاني — الفصل الدراسي الثاني',
                    subtitle: 'تسع وحدات دراسية متكاملة (ص ٣–١٣٢)',
                    accent: scheme.secondary,
                  ),
                  for (final u in p2Units) _IndexUnitRow(unit: u),
                  const SizedBox(height: AppSpacing.xl),
                ],

                if (_filter == _IndexFilter.all || _filter == _IndexFilter.grammar) ...<Widget>[
                  SectionHeader(
                    title: 'ملخصات القواعد وتقويم اللسان والإعراب',
                    subtitle: 'تسعة عشر موضوعاً نحوياً مقرراً في الجزأين',
                    accent: AppColors.resolveAccent('gold', theme.brightness),
                  ),
                  for (final lesson in lessons)
                    Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: scheme.tertiaryContainer,
                          child: Text(
                            toArabicDigits(lesson.order),
                            style: theme.textTheme.labelLarge,
                          ),
                        ),
                        title: Text(lesson.title, style: theme.textTheme.titleMedium),
                        subtitle: Text(
                          '${lesson.partLabel} • ${lesson.summary}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => LessonScreen(lessonId: lesson.id),
                          ),
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

class _IndexUnitRow extends StatelessWidget {
  const _IndexUnitRow({required this.unit});

  final Unit unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppColors.resolveAccent(unit.accent, theme.brightness);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        leading: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Text(
            toArabicDigits(unit.order),
            style: theme.textTheme.titleSmall?.copyWith(color: accent),
          ),
        ),
        title: Text(unit.title, style: theme.textTheme.titleMedium),
        subtitle: Text(
          [
            'المطالعة: ${unit.readingTitle}',
            'القواعد: ${unit.grammarTitle}',
            if (unit.thirdLessonTitle != null) unit.thirdLessonTitle!,
            if (unit.evaluativeTitle != null) 'التقويمي: ${unit.evaluativeTitle}',
          ].join(' • '),
          style: theme.textTheme.bodySmall,
        ),
        trailing: Text(unit.pageRange, style: theme.textTheme.labelSmall),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => UnitScreen(unitId: unit.id),
          ),
        ),
      ),
    );
  }
}
