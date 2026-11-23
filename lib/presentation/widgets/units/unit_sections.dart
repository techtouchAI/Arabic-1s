import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/dimens.dart';
import '../../../core/utils/arabic_text.dart';
import '../../../domain/models/library.dart';
import '../../../domain/models/progress.dart';
import '../../state/app_state.dart';

/// Renders a single textbook topic (reading text, poetry stanza, grammar rules,
/// تقويم اللسان, orthography/expression, or exercises).
class TopicCard extends StatelessWidget {
  const TopicCard({
    super.key,
    required this.unit,
    required this.topic,
    required this.accent,
  });

  final Unit unit;
  final Topic topic;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bookmarkKey = 'topic:${unit.id}:${topic.id}';
    final saved = state.isBookmarked(bookmarkKey);
    final isRules = topic.kind == 'rules';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        color: isRules
            ? accent.withValues(alpha: scheme.brightness == Brightness.dark ? 0.14 : 0.06)
            : scheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: isRules ? accent.withValues(alpha: 0.45) : scheme.outlineVariant,
          width: isRules ? 1.4 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Badge + Bookmark button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (topic.lessonBadge.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            topic.lessonBadge,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      Text(topic.title, style: theme.textTheme.titleLarge),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: saved ? 'إزالة من المحفوظات' : 'حفظ الدرس',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => state.toggleBookmark(
                    BookmarkItem(
                      key: bookmarkKey,
                      kind: BookmarkKind.topic,
                      targetId: unit.id,
                      topicId: topic.id,
                      title: topic.title,
                      subtitle: unit.displayTitle,
                    ),
                  ),
                  icon: Icon(
                    saved ? Icons.bookmark : Icons.bookmark_border,
                    color: saved ? accent : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Bullets / Verses / Paragraphs
            for (var i = 0; i < topic.bullets.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: AppSpacing.sm),
              if (topic.bullets[i].contains('✦'))
                _VerseRow(verse: topic.bullets[i], accent: accent)
              else
                _ProseBullet(
                  text: topic.bullets[i],
                  accent: accent,
                  isExercise: topic.kind == 'exercises',
                ),
            ],

            // تقويم اللسان structured comparison cards
            if (topic.taqwim.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              _TaqwimSection(pairs: topic.taqwim),
            ],

            // Sidebar notes / list items
            if (topic.listItems.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (topic.listTitle != null && topic.listTitle!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Row(
                          children: <Widget>[
                            Icon(Icons.lightbulb_outline, size: 17, color: accent),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                topic.listTitle!,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    for (var j = 0; j < topic.listItems.length; j++) ...<Widget>[
                      if (j > 0) const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.only(top: 7),
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              topic.listItems[j],
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProseBullet extends StatelessWidget {
  const _ProseBullet({
    required this.text,
    required this.accent,
    required this.isExercise,
  });

  final String text;
  final Color accent;
  final bool isExercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSubhead = isExercise && text.startsWith('التمرين (');
    if (isSubhead) {
      return Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Text(
          text,
          style: theme.textTheme.titleSmall?.copyWith(color: accent),
        ),
      );
    }
    return SelectableText(
      text,
      style: theme.textTheme.bodyLarge,
    );
  }
}

/// Renders a classical two-hemistich Arabic verse (`الصدر ✦ العجز`) responsively.
class _VerseRow extends StatelessWidget {
  const _VerseRow({required this.verse, required this.accent});

  final String verse;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final parts = verse.split('✦').map((s) => s.trim()).toList(growable: false);
    final sadr = parts.isNotEmpty ? parts[0] : verse;
    final ajuz = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    final scheme = Theme.of(context).colorScheme;
    final verseStyle = TextStyle(
      fontFamily: AppTheme.literaryFont,
      fontSize: 18.5,
      height: 1.7,
      fontWeight: FontWeight.w700,
      color: scheme.onSurface,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border(
          right: BorderSide(color: accent, width: 3),
        ),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (ajuz.isEmpty) {
            return Text(sadr, style: verseStyle, textAlign: TextAlign.center);
          }
          if (constraints.maxWidth >= 540) {
            return Row(
              children: <Widget>[
                Expanded(
                  child: Text(sadr, style: verseStyle, textAlign: TextAlign.right),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '✦',
                    style: TextStyle(color: accent, fontSize: 15),
                  ),
                ),
                Expanded(
                  child: Text(ajuz, style: verseStyle, textAlign: TextAlign.left),
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(sadr, style: verseStyle, textAlign: TextAlign.right),
              const SizedBox(height: 2),
              Text(ajuz, style: verseStyle, textAlign: TextAlign.left),
            ],
          );
        },
      ),
    );
  }
}

/// Renders structured `تقويم اللسان (قُلْ / ولا تَقُلْ)` cards.
class _TaqwimSection extends StatelessWidget {
  const _TaqwimSection({required this.pairs});

  final List<TaqwimPair> pairs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final okColor = isDark ? AppColors.greenLight : AppColors.sageGreen;
    final errColor = isDark ? AppColors.terracottaLight : AppColors.terracotta;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: okColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: okColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.spellcheck_rounded, size: 19, color: okColor),
              const SizedBox(width: 6),
              Text(
                'تقويم اللسان',
                style: theme.textTheme.titleMedium?.copyWith(color: okColor),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < pairs.length; i++) ...<Widget>[
            if (i > 0) const Divider(height: 16),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: 6,
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.check_circle, size: 17, color: okColor),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'قُلْ: ${pairs[i].say}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.cancel, size: 17, color: errColor),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'وَلا تَقُلْ: ${pairs[i].dontSay}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: errColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Interactive self-assessment card for a unit question.
class UnitQuestionCard extends StatefulWidget {
  const UnitQuestionCard({
    super.key,
    required this.index,
    required this.question,
    required this.accent,
  });

  final int index;
  final Question question;
  final Color accent;

  @override
  State<UnitQuestionCard> createState() => _UnitQuestionCardState();
}

class _UnitQuestionCardState extends State<UnitQuestionCard> {
  bool _revealed = false;
  int? _pickedOption;
  bool? _pickedBool;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final q = widget.question;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'س${toArabicDigits(widget.index)}: ${q.prompt}',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (q.kind == QuestionKind.trueFalse)
            Wrap(
              spacing: AppSpacing.sm,
              children: <Widget>[
                ChoiceChip(
                  label: const Text('صح'),
                  selected: _pickedBool == true,
                  onSelected: (_) => setState(() {
                    _pickedBool = true;
                    _revealed = true;
                  }),
                ),
                ChoiceChip(
                  label: const Text('خطأ'),
                  selected: _pickedBool == false,
                  onSelected: (_) => setState(() {
                    _pickedBool = false;
                    _revealed = true;
                  }),
                ),
              ],
            )
          else if (q.kind == QuestionKind.choice)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var i = 0; i < q.options.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        alignment: AlignmentDirectional.centerStart,
                        backgroundColor: _revealed && i == q.answerIndex
                            ? AppColors.sageGreen.withValues(alpha: 0.14)
                            : (_revealed && _pickedOption == i && i != q.answerIndex)
                                ? scheme.error.withValues(alpha: 0.12)
                                : null,
                      ),
                      onPressed: () => setState(() {
                        _pickedOption = i;
                        _revealed = true;
                      }),
                      child: Text(q.options[i]),
                    ),
                  ),
              ],
            )
          else
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => setState(() => _revealed = !_revealed),
                icon: Icon(
                  _revealed ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 18,
                ),
                label: Text(_revealed ? 'إخفاء الجواب النموذجي' : 'إظهار الجواب النموذجي'),
              ),
            ),
          if (_revealed) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: widget.accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Text(
                'الجواب النموذجي: ${q.displayAnswer}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
