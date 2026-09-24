import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'app_scaffold.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/players/presentation/players_screen.dart';
import '../../features/players/presentation/player_detail_screen.dart';
import '../../features/sessions/presentation/sessions_screen.dart';
import '../../features/sessions/presentation/session_detail_screen.dart';
import '../../features/sessions/presentation/new_session_screen.dart';
import '../widgets/placeholder_screen.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(AppRouterRef ref) {
  return GoRouter(
    initialLocation: '/',
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
                routes: [
                  GoRoute(
                    path: 'reglages',
                    builder: (context, state) => const PlaceholderScreen(title: 'Réglages'),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/joueurs',
                builder: (context, state) => const PlayersScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => PlayerDetailScreen(playerId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/seances',
                builder: (context, state) => const SessionsScreen(),
                routes: [
                  GoRoute(
                    path: 'nouvelle',
                    builder: (context, state) => const NewSessionScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => SessionDetailScreen(sessionId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/classement',
                builder: (context, state) => const PlaceholderScreen(title: 'Classement'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/stats',
                builder: (context, state) => const PlaceholderScreen(title: 'Statistiques globales'),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
