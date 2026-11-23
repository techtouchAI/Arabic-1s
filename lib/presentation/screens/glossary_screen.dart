import 'package:flutter/material.dart';

import '../../core/theme/dimens.dart';
import '../../core/utils/arabic_text.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/empty_state.dart';
import '../state/app_state.dart';
import '../widgets/text_scale_controls.dart';
import 'unit_screen.dart';

class GlossaryScreen extends StatefulWidget {
  const GlossaryScreen({super.key});

  @override
  State<GlossaryScreen> createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends State<GlossaryScreen> {
  String _partFilter = 'all';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final normQuery = normalizeArabicForSearch(_query);

    final filtered = state.library.glossary.where((term) {
      if (_partFilter != 'all' && term.part != _partFilter) {
        return false;
      }
      if (normQuery.isEmpty) {
        return true;
      }
      final hay = normalizeArabicForSearch('${term.term} ${term.definition}');
      return hay.contains(normQuery);
    }).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('معجم الطالب اللغوي'),
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
                  decoration: const InputDecoration(
                    hintText: 'ابحث في مفردات المعجم (بدون تشكيل)...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: <Widget>[
                    ChoiceChip(
                      label: const Text('الجزأين معاً'),
                      selected: _partFilter == 'all',
                      onSelected: (_) => setState(() => _partFilter = 'all'),
                    ),
                    ChoiceChip(
                      label: const Text('معجم الجزء الأول'),
                      selected: _partFilter == 'part1',
                      onSelected: (_) => setState(() => _partFilter = 'part1'),
                    ),
                    ChoiceChip(
                      label: const Text('معجم الجزء الثاني'),
                      selected: _partFilter == 'part2',
                      onSelected: (_) => setState(() => _partFilter = 'part2'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (filtered.isEmpty)
                  const EmptyState(
                    icon: Icons.translate_rounded,
                    title: 'لا توجد مفردة مطابقة',
                    message: 'جرّب كتابة الجذر أو جزء من الكلمة.',
                  )
                else
                  for (final term in filtered)
                    Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        title: Text(term.term, style: theme.textTheme.titleMedium),
                        subtitle: Text(
                          term.definition,
                          style: theme.textTheme.bodyMedium,
                        ),
                        trailing: const Icon(Icons.open_in_new, size: 18),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => UnitScreen(unitId: term.unitId),
                          ),
                        ),
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
