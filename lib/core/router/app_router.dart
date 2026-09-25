import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/home/presentation/home_screen.dart';
import '../../features/onboarding/application/onboarding_provider.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/players/presentation/player_detail_screen.dart';
import '../../features/players/presentation/players_screen.dart';
import '../../features/ranking/presentation/standings_screen.dart';
import '../../features/sessions/presentation/new_session_screen.dart';
import '../../features/sessions/presentation/session_detail_screen.dart';
import '../../features/sessions/presentation/sessions_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/stats/presentation/stats_screen.dart';
import '../../features/team/presentation/add_team_players_screen.dart';
import '../../features/team/presentation/create_team_screen.dart';
import 'app_scaffold.dart';

part 'app_router.g.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

@riverpod
GoRouter appRouter(Ref ref) {
  final hasSeenOnboarding = ref.watch(hasSeenOnboardingProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: hasSeenOnboarding ? '/' : '/onboarding',
    routes: [
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
                path: '/joueurs',
                builder: (context, state) => const PlayersScreen(),
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
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/creer-equipe',
        builder: (context, state) => const CreateTeamScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/ajouter-joueurs-initiaux',
        builder: (context, state) => const AddTeamPlayersScreen(),
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
