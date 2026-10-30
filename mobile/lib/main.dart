import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/data/app_database.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/widgets/browser_app_frame.dart';
import 'features/finance/application/finance_providers.dart';
import 'features/onboarding/application/onboarding_provider.dart';
import 'features/players/application/players_provider.dart';
import 'features/ranking/application/ranking_providers.dart';
import 'features/sessions/application/sessions_provider.dart';
import 'features/shared/application/shared_providers.dart';
import 'features/shared/data/shared_service.dart';
import 'features/stats/application/stats_providers.dart';
import 'features/team/application/team_provider.dart';
import 'features/team/data/team_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

  final teamRepository = SqliteTeamRepository(AppDatabase.instance);
  final team = await teamRepository.getTeamInfo();
  final hasTeam = team != null;

  final shared = SharedService(AppDatabase.instance);
  await shared.load();

  runApp(
    ProviderScope(
      overrides: [
        sharedServiceProvider.overrideWithValue(shared),
        hasSeenOnboardingProvider.overrideWith(
          () => OnboardingNotifier(initialValue: hasSeenOnboarding),
        ),
        hasTeamProvider.overrideWith(
          () => HasTeamNotifier(initialValue: hasTeam),
        ),
        activeTeamIdProvider.overrideWith(
          () => ActiveTeamIdNotifier(initialValue: team?.id),
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
    ref.read(sharedServiceProvider).onChanged = () {
      ref
        ..read(sharedStatusProvider.notifier).refresh()
        ..invalidate(allSessionsProvider)
        ..invalidate(activeSessionIdProvider)
        ..invalidate(playersListProvider)
        ..invalidate(sessionDetailProvider)
        ..invalidate(sessionParticipantsProvider)
        ..invalidate(playerStatsProvider)
        ..invalidate(playerMatchHistoryProvider)
        ..invalidate(canDeletePlayerProvider)
        ..invalidate(deletablePlayerIdsProvider)
        ..invalidate(standingsProvider)
        ..invalidate(standingsPerMatchProvider)
        ..invalidate(topScorersProvider)
        ..invalidate(topAssistsProvider)
        ..invalidate(topCardsProvider)
        ..invalidate(monthlyMvpRankingProvider)
        ..invalidate(groupTotalsProvider)
        ..invalidate(financialPointsProvider)
        ..invalidate(financialTotalsProvider);
    };
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Statoo',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) => BrowserAppFrame(child: child!),
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
