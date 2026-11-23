import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'presentation/screens/landing_shell.dart';
import 'presentation/screens/onboarding_screen.dart';
import 'presentation/state/app_state.dart';

class BayanApp extends StatelessWidget {
  const BayanApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: AnimatedBuilder(
        animation: state,
        builder: (BuildContext context, _) {
          return MaterialApp(
            title: 'بَيَان — اللغة العربية للأول المتوسط',
            debugShowCheckedModeBanner: false,
            locale: const Locale('ar'),
            supportedLocales: const <Locale>[Locale('ar')],
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: state.themeMode,
            builder: (BuildContext context, Widget? child) {
              final media = MediaQuery.of(context);
              return Directionality(
                textDirection: TextDirection.rtl,
                child: MediaQuery(
                  data: media.copyWith(
                    textScaler: TextScaler.linear(state.textScale),
                  ),
                  child: child ?? const SizedBox.shrink(),
                ),
              );
            },
            home: state.needsOnboarding
                ? const OnboardingScreen()
                : const LandingShell(),
          );
        },
      ),
    );
  }
}
