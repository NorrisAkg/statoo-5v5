import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/players/application/players_provider.dart';
import 'package:statoo/features/players/domain/player.dart';
import 'package:statoo/features/players/presentation/players_screen.dart';
import 'package:statoo/features/players/presentation/new_player_bottom_sheet.dart';
import 'package:statoo/features/ranking/application/ranking_providers.dart';
import 'package:statoo/features/shared/application/shared_providers.dart';
import 'package:statoo/features/shared/data/shared_service.dart';
import 'package:statoo/features/team/application/team_provider.dart';
import 'package:statoo/features/team/domain/team_info.dart';

final _date = DateTime(2026);

class _Players extends PlayersNotifier {
  @override
  Future<List<Player>> build() async => [
    Player(
      id: 'p',
      teamId: 'g',
      name: 'Alice',
      createdAt: _date,
      updatedAt: _date,
    ),
  ];
  @override
  Future<bool> isNameTaken(String name, {String? excludePlayerId}) async =>
      false;
  @override
  Future<Player> addPlayer({
    required String name,
    String? nickname,
    String? avatarUrl,
  }) async => throw StateError('Le rôle ADMIN a été retiré.');
}

class _Team extends TeamInfoNotifier {
  @override
  Future<TeamInfo?> build() async => const TeamInfo(id: 'g', name: 'Groupe');
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final role in ['MEMBER', 'CENSOR', 'SG', 'TR', 'ADMIN']) {
    testWidgets('UX06-02/04 players mutations reflect $role', (tester) async {
      final service = SharedService(AppDatabase.instance)
        ..protectedGroups.add('g')
        ..identity = {
          'group_id': 'g',
          'expires_at': '2099-01-01T00:00:00Z',
          'account': {
            'id': 'me',
            'roles': [role],
          },
        };
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTeamIdProvider.overrideWith(
              () => ActiveTeamIdNotifier(initialValue: 'g'),
            ),
            sharedServiceProvider.overrideWithValue(service),
            playersListProvider.overrideWith(_Players.new),
            teamInfoProvider.overrideWith(_Team.new),
            standingsProvider.overrideWith((ref) async => []),
            deletablePlayerIdsProvider.overrideWith((ref) async => {'p'}),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const PlayersScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Alice'), findsOneWidget);
      final subtitle = tester.widget<Text>(find.text('1 actifs · Groupe'));
      final fg = subtitle.style!.color!.computeLuminance();
      final bg = AppTheme.lightTheme.appBarTheme.backgroundColor!
          .computeLuminance();
      expect(
        (fg > bg ? (fg + .05) / (bg + .05) : (bg + .05) / (fg + .05)),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        find.byType(FloatingActionButton),
        role == 'ADMIN' ? findsOneWidget : findsNothing,
      );
      expect(
        find.byType(Dismissible),
        role == 'ADMIN' ? findsOneWidget : findsNothing,
      );
      expect(
        find.byTooltip('Supprimer ce joueur'),
        role == 'ADMIN' ? findsOneWidget : findsNothing,
      );
    });
  }
  testWidgets(
    'UX06-07 late denied submission retains inputs and displays error',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTeamIdProvider.overrideWith(
              () => ActiveTeamIdNotifier(initialValue: 'local'),
            ),
            playersListProvider.overrideWith(_Players.new),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(body: NewPlayerBottomSheet()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Test conservé');
      await tester.pump();
      final save = find.text('Créer');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.textContaining('ADMIN a été retiré'), findsWidgets);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'Test conservé',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
