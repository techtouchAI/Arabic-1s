import 'package:bayan/core/theme/app_theme.dart';
import 'package:bayan/presentation/screens/lesson_screen.dart';
import 'package:bayan/presentation/screens/settings_screen.dart';
import 'package:bayan/presentation/screens/unit_screen.dart';
import 'package:bayan/presentation/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_harness.dart';

Widget _wrapForPhone(AppState state, Widget child) {
  return DefaultAssetBundle(
    bundle: DiskAssetBundle(),
    child: AppScope(
      state: state,
      child: MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const <Locale>[Locale('ar')],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('all 21 units render on a 390px phone without overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = createTestAppState(textScale: 1.1);

    for (final unit in state.library.units) {
      await tester.pumpWidget(
        _wrapForPhone(
          state,
          UnitScreen(key: ValueKey<String>(unit.id), unitId: unit.id),
        ),
      );
      await tester.pump();
      expect(
        tester.takeException(),
        isNull,
        reason: 'layout exception on unit ${unit.id}',
      );
    }
  });

  testWidgets('all 19 grammar lessons and SettingsScreen render on a 390px phone without overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = createTestAppState(textScale: 1.1);

    for (final lesson in state.library.lessons) {
      await tester.pumpWidget(
        _wrapForPhone(
          state,
          LessonScreen(key: ValueKey<String>(lesson.id), lessonId: lesson.id),
        ),
      );
      await tester.pump();
      expect(
        tester.takeException(),
        isNull,
        reason: 'layout exception on lesson ${lesson.id}',
      );
    }

    await tester.pumpWidget(_wrapForPhone(state, const SettingsScreen()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
