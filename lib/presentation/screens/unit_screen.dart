import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';
import '../../core/utils/arabic_text.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/section_header.dart';
import '../../domain/models/library.dart';
import '../../domain/models/progress.dart';
import '../state/app_state.dart';
import '../widgets/illustration_figure.dart';
import '../widgets/text_scale_controls.dart';
import '../widgets/units/unit_sections.dart';
import 'lesson_screen.dart';

class UnitScreen extends StatefulWidget {
  const UnitScreen({
    super.key,
    required this.unitId,
    this.initialCategory,
  });

  final String unitId;
  final String? initialCategory;

  @override
  State<UnitScreen> createState() => _UnitScreenState();
}

class _UnitScreenState extends State<UnitScreen> {
  String _selectedCategory = 'all';
  bool _markedVisited = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_markedVisited) {
      _markedVisited = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          AppScope.of(context).markUnitVisited(widget.unitId);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final unit = state.library.unitById(widget.unitId);
    if (unit == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('الوحدة غير موجودة')),
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = AppColors.resolveAccent(unit.accent, theme.brightness);
    final bookmarkKey = 'unit:${unit.id}';
    final saved = state.isBookmarked(bookmarkKey);

    final linkedLesson = state.library.lessons
        .where((l) => l.unitId == unit.id)
        .firstOrNull;

    final unitGlossary = state.library.glossary
        .where((g) => g.unitId == unit.id)
        .toList(growable: false);

    final availableCategories = <MapEntry<String, String>>[
      const MapEntry<String, String>('all', 'الكل'),
      if (unit.topics.any((t) => t.category == 'reading'))
        const MapEntry<String, String>('reading', 'المطالعة'),
      if (unit.topics.any((t) => t.category == 'grammar'))
        const MapEntry<String, String>('grammar', 'القواعد'),
      if (unit.topics.any(
        (t) => t.category == 'orthography' || t.category == 'expression',
      ))
        const MapEntry<String, String>('third', 'الإملاء والتعبير'),
      if (unit.topics.any((t) => t.category == 'evaluative'))
        const MapEntry<String, String>('evaluative', 'النص التقويمي'),
      if (unit.questions.isNotEmpty)
        const MapEntry<String, String>('questions', 'الأسئلة'),
    ];

    final filteredTopics = unit.topics.where((Topic t) {
      if (_selectedCategory == 'all') {
        return true;
      }
      if (_selectedCategory == 'questions') {
        return false;
      }
      if (_selectedCategory == 'third') {
        return t.category == 'orthography' || t.category == 'expression';
      }
      return t.category == _selectedCategory;
    }).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(unit.displayTitle, overflow: TextOverflow.ellipsis),
        actions: <Widget>[
          const TextScaleControls(),
          if (unitGlossary.isNotEmpty)
            IconButton(
              tooltip: 'مفردات الوحدة في معجم الطالب',
              onPressed: () => _showUnitGlossary(context, unit, unitGlossary),
              icon: const Icon(Icons.translate_rounded),
            ),
          IconButton(
            tooltip: saved ? 'إزالة الوحدة من المحفوظات' : 'حفظ الوحدة',
            onPressed: () => state.toggleBookmark(
              BookmarkItem(
                key: bookmarkKey,
                kind: BookmarkKind.unit,
                targetId: unit.id,
                title: unit.title,
                subtitle: '${unit.grade} • ${unit.pageRange}',
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
                // Unit header card
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: accent.withValues(
                      alpha: theme.brightness == Brightness.dark ? 0.16 : 0.09,
                    ),
                    borderRadius: BorderRadius.circular(AppRadii.xl),
                    border: Border.all(color: accent.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: 4,
                        children: <Widget>[
                          _MetaPill(label: unit.grade, color: accent),
                          if (unit.unitLabel.isNotEmpty)
                            _MetaPill(label: unit.unitLabel, color: accent),
                          if (unit.pageRange.isNotEmpty)
                            _MetaPill(label: unit.pageRange, color: accent),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(unit.title, style: theme.textTheme.headlineMedium),
                      const SizedBox(height: 6),
                      Text(
                        [
                          if (unit.readingTitle.isNotEmpty)
                            'النص: ${unit.readingTitle}',
                          if (unit.grammarTitle.isNotEmpty)
                            'القواعد: ${unit.grammarTitle}',
                          if (unit.thirdLessonTitle != null)
                            unit.thirdLessonTitle!,
                        ].join('  •  '),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if (linkedLesson != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.md),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  LessonScreen(lessonId: linkedLesson.id),
                            ),
                          ),
                          icon: const Icon(Icons.auto_stories_outlined, size: 18),
                          label: Text(
                            'ملخص القواعد والإعراب: ${linkedLesson.title}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Category filter chips
                if (availableCategories.length > 2) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: <Widget>[
                      for (final entry in availableCategories)
                        ChoiceChip(
                          label: Text(entry.value),
                          selected: _selectedCategory == entry.key,
                          onSelected: (_) =>
                              setState(() => _selectedCategory = entry.key),
                        ),
                    ],
                  ),
                ],

                // Figures
                if (unit.figures.isNotEmpty &&
                    (_selectedCategory == 'all' ||
                        _selectedCategory == 'grammar')) ...<Widget>[
                  const SizedBox(height: AppSpacing.lg),
                  for (final fig in unit.figures) ...<Widget>[
                    IllustrationFigure(figure: fig, accent: accent),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ],

                const SizedBox(height: AppSpacing.md),

                // Topics
                for (final topic in filteredTopics)
                  TopicCard(unit: unit, topic: topic, accent: accent),

                // Self-assessment questions
                if (unit.questions.isNotEmpty &&
                    (_selectedCategory == 'all' ||
                        _selectedCategory == 'questions')) ...<Widget>[
                  const SizedBox(height: AppSpacing.lg),
                  SectionHeader(
                    title: 'أسئلة المراجعة والاختبار الذاتي',
                    subtitle:
                        '${toArabicDigits(unit.questions.length)} أسئلة شاملة للمطالعة والقواعد وتقويم اللسان',
                    accent: accent,
                  ),
                  for (var i = 0; i < unit.questions.length; i++)
                    UnitQuestionCard(
                      index: i + 1,
                      question: unit.questions[i],
                      accent: accent,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showUnitGlossary(
    BuildContext context,
    Unit unit,
    List<GlossaryTerm> terms,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) {
        final theme = Theme.of(ctx);
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: <Widget>[
            Text(
              'معجم مفردات ${unit.displayTitle}',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            for (final term in terms) ...<Widget>[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(term.term, style: theme.textTheme.titleMedium),
                subtitle: Text(term.definition, style: theme.textTheme.bodyMedium),
              ),
              const Divider(height: 1),
            ],
          ],
        );
      },
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}
