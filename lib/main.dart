import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/data/app_database.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/onboarding/application/onboarding_provider.dart';
import 'features/settings/application/settings_provider.dart';
import 'features/team/application/team_provider.dart';
import 'features/team/data/team_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

  final teamRepository = SqliteTeamRepository(AppDatabase.instance);
  final team = await teamRepository.getTeamInfo();
  final hasTeam = team != null;

  final minPlayers = prefs.getInt('min_players_per_session') ?? 6;

  runApp(
    ProviderScope(
      overrides: [
        hasSeenOnboardingProvider.overrideWith(
          () => OnboardingNotifier(initialValue: hasSeenOnboarding),
        ),
        hasTeamProvider.overrideWith(
          () => HasTeamNotifier(initialValue: hasTeam),
        ),
        minPlayersPerSessionProvider.overrideWith(
          () => MinPlayersNotifier(initialValue: minPlayers),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Statoo',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', 'FR'),
      ],
      debugShowCheckedModeBanner: false,
    );
  }
}
