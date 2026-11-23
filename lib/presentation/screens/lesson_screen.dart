import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';
import '../../core/widgets/app_page.dart';
import '../../domain/models/progress.dart';
import '../state/app_state.dart';
import '../widgets/illustration_figure.dart';
import '../widgets/text_scale_controls.dart';
import 'unit_screen.dart';

class LessonScreen extends StatelessWidget {
  const LessonScreen({super.key, required this.lessonId});

  final String lessonId;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final lesson = state.library.lessonById(lessonId);
    if (lesson == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('الدرس غير موجود')),
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = AppColors.resolveAccent(lesson.accent, theme.brightness);
    final bookmarkKey = 'lesson:${lesson.id}';
    final saved = state.isBookmarked(bookmarkKey);

    return Scaffold(
      appBar: AppBar(
        title: Text(lesson.title, overflow: TextOverflow.ellipsis),
        actions: <Widget>[
          const TextScaleControls(),
          IconButton(
            tooltip: saved ? 'إزالة من المحفوظات' : 'حفظ الملخص',
            onPressed: () => state.toggleBookmark(
              BookmarkItem(
                key: bookmarkKey,
                kind: BookmarkKind.lesson,
                targetId: lesson.id,
                title: 'ملخص القواعد: ${lesson.title}',
                subtitle: lesson.partLabel,
              ),
            ),
            icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: <Widget>[
          AppPage(
            maxWidth: AppLayout.readingMaxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    border: Border.all(color: accent.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        lesson.partLabel,
                        style: theme.textTheme.labelMedium?.copyWith(color: accent),
                      ),
                      const SizedBox(height: 4),
                      Text(lesson.title, style: theme.textTheme.headlineMedium),
                      const SizedBox(height: 6),
                      Text(lesson.summary, style: theme.textTheme.bodyLarge),
                      const SizedBox(height: AppSpacing.md),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => UnitScreen(
                              unitId: lesson.unitId,
                              initialCategory: 'grammar',
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.menu_book_outlined, size: 18),
                        label: const Text(
                          'فتح درس القواعد الكامل والتمرينات في الكتاب',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                if (lesson.figures.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.lg),
                  for (final fig in lesson.figures) ...<Widget>[
                    IllustrationFigure(figure: fig, accent: accent),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ],

                for (final plan in lesson.plans) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        for (final block in plan.body)
                          if (block.kind == 'heading')
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.md,
                                bottom: AppSpacing.sm,
                              ),
                              child: Text(
                                block.text,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: accent,
                                ),
                              ),
                            )
                          else if (block.kind == 'bullet')
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Padding(
                                    padding: const EdgeInsets.only(top: 9),
                                    child: Container(
                                      width: 7,
                                      height: 7,
                                      decoration: BoxDecoration(
                                        color: accent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: SelectableText(
                                      block.text,
                                      style: theme.textTheme.bodyLarge,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest
                                    .withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(AppRadii.sm),
                              ),
                              child: SelectableText(
                                block.text,
                                style: theme.textTheme.bodyLarge,
                              ),
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
    );
  }
}
