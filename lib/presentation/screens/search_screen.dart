import 'package:flutter/material.dart';

import '../../core/theme/dimens.dart';
import '../../core/utils/arabic_text.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/empty_state.dart';
import '../state/app_state.dart';
import '../widgets/text_scale_controls.dart';
import 'lesson_screen.dart';
import 'unit_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _ctrl = TextEditingController();
  bool _currentPartOnly = false;

  static const List<String> _suggestions = <String>[
    'أقسام الكلام',
    'تقويم اللسان',
    'الأفعال الخمسة',
    'كان وأخواتها',
    'ألف التفريق',
    'التاء المربوطة',
    'بغداد',
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final query = _ctrl.text.trim();
    final hits = state.searchEngine.search(
      query,
      partFilter: _currentPartOnly ? state.activePart : null,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('البحث الشامل في المنهج'),
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
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  key: const ValueKey<String>('curriculum-search-input'),
                  controller: _ctrl,
                  decoration: InputDecoration(
                    hintText:
                        'ابحث في النصوص، القواعد، تقويم اللسان، الأسئلة، والمعجم...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'مسح',
                            onPressed: () => setState(_ctrl.clear),
                            icon: const Icon(Icons.clear),
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    FilterChip(
                      label: Text(
                        'حصر في ${state.partTitle}',
                        overflow: TextOverflow.ellipsis,
                      ),
                      selected: _currentPartOnly,
                      onSelected: (v) => setState(() => _currentPartOnly = v),
                    ),
                    if (query.isNotEmpty)
                      Text(
                        '${toArabicDigits(hits.length)} نتيجة',
                        style: theme.textTheme.labelMedium,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (query.isEmpty) ...<Widget>[
                  Text(
                    'مقترحات سريعة:',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: <Widget>[
                      for (final suggestion in _suggestions)
                        ActionChip(
                          label: Text(suggestion),
                          onPressed: () => setState(() {
                            _ctrl.text = suggestion;
                          }),
                        ),
                    ],
                  ),
                ] else if (hits.isEmpty)
                  const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'لا توجد نتائج مطابقة',
                    message:
                        'البحث يتجاهل الحركات والهمزات تلقائياً؛ جرّب كلمة أقصر أو ألغِ حصر الجزء.',
                  )
                else
                  for (final hit in hits)
                    Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            hit.kind.label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                        title: Text(hit.title, style: theme.textTheme.titleMedium),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(hit.snippet, maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(hit.badge, style: theme.textTheme.labelSmall),
                          ],
                        ),
                        onTap: () {
                          if (hit.lessonId != null) {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    LessonScreen(lessonId: hit.lessonId!),
                              ),
                            );
                          } else {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => UnitScreen(unitId: hit.unitId),
                              ),
                            );
                          }
                        },
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
