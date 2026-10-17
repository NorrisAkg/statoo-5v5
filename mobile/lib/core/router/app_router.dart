import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/finance/presentation/finances_screen.dart';
import '../../features/finance/presentation/financial_point_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/onboarding/application/onboarding_provider.dart';
import '../../features/onboarding/presentation/group_entry_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/onboarding/presentation/splash_screen.dart';
import '../../features/players/presentation/player_detail_screen.dart';
import '../../features/players/presentation/players_screen.dart';
import '../../features/ranking/presentation/standings_screen.dart';
import '../../features/sessions/presentation/new_session_screen.dart';
import '../../features/sessions/presentation/session_detail_screen.dart';
import '../../features/sessions/presentation/sessions_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/shared/presentation/shared_group_screen.dart';
import '../../features/stats/presentation/stats_screen.dart';
import '../../features/team/application/team_provider.dart';
import '../../features/team/presentation/add_team_players_screen.dart';
import '../../features/team/presentation/create_team_screen.dart';
import 'app_scaffold.dart';

part 'app_router.g.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this._ref) {
    _ref.listen(hasSeenOnboardingProvider, (_, _) => notifyListeners());
    _ref.listen(hasTeamProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;
}

@riverpod
RouterNotifier routerNotifier(Ref ref) => RouterNotifier(ref);

@riverpod
GoRouter appRouter(Ref ref) {
  GoRouter.optionURLReflectsImperativeAPIs = true;
  final notifier = ref.watch(routerProvider);
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      if (loc == '/splash') {
        return null;
      }

      final seenOnboarding = ref.read(hasSeenOnboardingProvider);
      final teamCreated = ref.read(hasTeamProvider);

      final isOnboarding = loc == '/onboarding';
      final isCreatingTeam = loc == '/creer-equipe';
      final isAddingPlayers = loc == '/ajouter-joueurs-initiaux';

      if (!seenOnboarding) {
        return isOnboarding ? null : '/onboarding';
      }

      if (loc == '/groupe-partage' || loc == '/bienvenue') {
        return null;
      }

      if (!teamCreated) {
        if (isCreatingTeam || isAddingPlayers) {
          return null;
        }
        return '/bienvenue';
      }

      if (isOnboarding) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/bienvenue', parentNavigatorKey: _rootNavigatorKey, builder: (context, state) => const GroupEntryScreen()),
      GoRoute(path: '/finances', parentNavigatorKey: _rootNavigatorKey, builder: (context, state) => const FinancesScreen()),
      GoRoute(path: '/groupe-partage', parentNavigatorKey: _rootNavigatorKey, builder: (context, state) => SharedGroupScreen(initialCreate: state.uri.queryParameters['creation'] == '1', setup: state.uri.queryParameters['installation'] == '1')),
      GoRoute(path: '/seances/:id/finances', parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => FinancialPointScreen(sessionId: state.pathParameters['id']!)),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/seances',
                builder: (context, state) => const SessionsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/joueurs',
                builder: (context, state) => const PlayersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/classement',
                builder: (context, state) => const StandingsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/stats',
                builder: (context, state) => const StatsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/creer-equipe',
        builder: (context, state) => CreateTeamScreen(setupShared: state.uri.queryParameters['partage'] == '1'),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/ajouter-joueurs-initiaux',
        builder: (context, state) => AddTeamPlayersScreen(setupShared: state.uri.queryParameters['partage'] == '1'),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/reglages',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/joueurs/:id',
        builder: (context, state) => PlayerDetailScreen(playerId: state.pathParameters['id']!),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/seances/nouvelle',
        builder: (context, state) => const NewSessionScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/seances/:id',
        builder: (context, state) => SessionDetailScreen(sessionId: state.pathParameters['id']!),
      ),
    ],
  );
}
