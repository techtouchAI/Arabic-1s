import 'package:flutter/material.dart';

import '../../core/theme/dimens.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/empty_state.dart';
import '../../domain/models/progress.dart';
import '../state/app_state.dart';
import '../widgets/text_scale_controls.dart';
import 'lesson_screen.dart';
import 'unit_screen.dart';

class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final bookmarks = state.progress.bookmarks;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('المحفوظات والمفضلة'),
        actions: const <Widget>[TextScaleControls()],
      ),
      body: bookmarks.isEmpty
          ? const EmptyState(
              icon: Icons.bookmark_border_rounded,
              title: 'قائمة المحفوظات فارغة',
              message:
                  'اضغط على أيقونة الحفظ داخل أي وحدة أو درس قواعد للرجوع إليه بسرعة قبل الدرس أو الامتحان.',
            )
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              children: <Widget>[
                AppPage(
                  maxWidth: AppLayout.readingMaxWidth,
                  child: Column(
                    children: <Widget>[
                      for (final item in bookmarks)
                        Card(
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: ListTile(
                            leading: Icon(
                              item.kind == BookmarkKind.lesson
                                  ? Icons.auto_stories_outlined
                                  : Icons.bookmark_rounded,
                              color: theme.colorScheme.primary,
                            ),
                            title: Text(
                              item.title,
                              style: theme.textTheme.titleMedium,
                            ),
                            subtitle: item.subtitle.isEmpty
                                ? null
                                : Text(item.subtitle),
                            trailing: IconButton(
                              tooltip: 'إزالة',
                              onPressed: () => state.toggleBookmark(item),
                              icon: const Icon(Icons.delete_outline),
                            ),
                            onTap: () {
                              if (item.kind == BookmarkKind.lesson) {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        LessonScreen(lessonId: item.targetId),
                                  ),
                                );
                              } else {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        UnitScreen(unitId: item.targetId),
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
