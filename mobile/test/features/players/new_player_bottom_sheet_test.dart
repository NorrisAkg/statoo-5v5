import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/players/application/players_provider.dart';
import 'package:statoo/features/players/data/players_repository.dart';
import 'package:statoo/features/players/domain/player.dart';
import 'package:statoo/features/players/domain/player_detail_data.dart';
import 'package:statoo/features/players/presentation/new_player_bottom_sheet.dart';
import 'package:statoo/features/shared/application/shared_providers.dart';
import 'package:statoo/features/team/application/team_provider.dart';

import '../../support/local_shared_service.dart';

class _MockPlayersRepository implements PlayersRepository {
  final List<Player> _players = [];

  @override
  Future<List<Player>> getPlayers({String? teamId}) async =>
      List.unmodifiable(_players);

  @override
  Future<Player?> getPlayer(String id, {required String teamId}) async =>
      _players.cast<Player?>().firstWhere(
        (p) => p?.id == id,
        orElse: () => null,
      );

  @override
  Future<PlayerDetailStats> getPlayerStats(
    String id, {
    required String teamId,
  }) async => const PlayerDetailStats.empty();

  @override
  Future<List<PlayerMatchHistoryItem>> getPlayerMatchHistory(
    String id, {
    required String teamId,
  }) async => const [];

  @override
  Future<Player> createPlayer({
    required String name,
    String? nickname,
    String? avatarUrl,
    String? teamId,
  }) async {
    final now = DateTime.now();
    final player = Player(
      id: 'p_${_players.length + 1}',
      teamId: teamId ?? 'team_1',
      name: name,
      nickname: nickname,
      avatarUrl: avatarUrl,
      createdAt: now,
      updatedAt: now,
    );
    _players.add(player);
    return player;
  }

  @override
  Future<void> updatePlayer({
    required String teamId,
    required String id,
    required String name,
    String? nickname,
  }) async {}

  @override
  Future<void> togglePlayerActive({
    required String teamId,
    required String id,
    required bool isActive,
  }) async {}

  @override
  Future<bool> canDeletePlayer(String id, {required String teamId}) async =>
      true;

  @override
  Future<Set<String>> getDeletablePlayerIds({required String teamId}) async =>
      _players.map((p) => p.id).toSet();

  @override
  Future<void> deletePlayer(String id, {required String teamId}) async {
    _players.removeWhere((p) => p.id == id);
  }

  @override
  Future<bool> isNameTaken({
    required String name,
    String? teamId,
    String? excludePlayerId,
  }) async {
    final cleanName = name.trim().toLowerCase();
    return _players.any(
      (p) =>
          (teamId == null || p.teamId == teamId) &&
          (excludePlayerId == null || p.id != excludePlayerId) &&
          p.name.trim().toLowerCase() == cleanName,
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  for (final outcome in ['valid', 'cancel', 'invalid']) {
    testWidgets(
      'photo picker preserves input and stores portable data: $outcome',
      (tester) async {
        final directory = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('statoo-picker-'),
        ))!;
        final file = (await tester.runAsync(
          () => File('${directory.path}/photo.png').writeAsBytes(
            base64Decode(
              'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==',
            ),
          ),
        ))!;
        addTearDown(() => directory.delete(recursive: true));
        const channel = MethodChannel('plugins.flutter.io/image_picker');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (_) async => outcome == 'cancel' ? null : file.path,
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
        if (outcome == 'invalid') {
          await tester.runAsync(() => file.writeAsString('invalid'));
        }
        final repo = _MockPlayersRepository();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedServiceProvider.overrideWithValue(LocalTestSharedService()),
              playersRepositoryProvider.overrideWithValue(repo),
              activeTeamIdProvider.overrideWith(
                () => ActiveTeamIdNotifier(initialValue: 'team_1'),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const Scaffold(body: NewPlayerBottomSheet()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'Photo Player');
        await tester.tap(find.byType(CircleAvatar));
        for (var i = 0; i < 30; i++) {
          await tester.pump();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
        }
        await tester.pumpAndSettle();
        expect(find.text('Photo Player'), findsOneWidget);
        if (outcome == 'invalid') {
          expect(find.textContaining('Photo non ajoutée'), findsOneWidget);
        }
        await tester.tap(find.byIcon(Remix.add_line));
        await tester.pumpAndSettle();
        final saved = (await repo.getPlayers()).single;
        expect(
          saved.avatarUrl,
          outcome == 'valid'
              ? 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg=='
              : isNull,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  group('NewPlayerBottomSheet', () {
    for (final width in [320.0, 393.0]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        for (final dark in [false, true]) {
          testWidgets(
            'keyboard actions reachable $width text $scale dark $dark',
            (tester) async {
              tester.view.physicalSize = Size(width, 844);
              tester.view.devicePixelRatio = 1;
              tester.view.viewInsets = const FakeViewPadding(bottom: 350);
              addTearDown(tester.view.reset);
              await tester.pumpWidget(
                ProviderScope(
                  overrides: [
                    sharedServiceProvider.overrideWithValue(
                      LocalTestSharedService(),
                    ),
                  ],
                  child: MaterialApp(
                    theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!,
                    ),
                    home: const Scaffold(
                      resizeToAvoidBottomInset: false,
                      body: NewPlayerBottomSheet(),
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              await tester.enterText(
                find.byType(TextField).first,
                'Jean-Pierre Karim très long',
              );
              await tester.pumpAndSettle();
              await tester.ensureVisible(find.text('Créer'));
              await tester.pumpAndSettle();
              expect(find.text('Créer').hitTestable(), findsOneWidget);
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }

    testWidgets(
      'keyboard keeps creation controls visible and can be dismissed without losing input',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 350);
        addTearDown(tester.view.reset);
        final repo = _MockPlayersRepository();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedServiceProvider.overrideWithValue(LocalTestSharedService()),
              playersRepositoryProvider.overrideWithValue(repo),
              activeTeamIdProvider.overrideWith(
                () => ActiveTeamIdNotifier(initialValue: 'team_1'),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const Scaffold(
                resizeToAvoidBottomInset: false,
                body: NewPlayerBottomSheet(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'Karim');
        await tester.pumpAndSettle();
        expect(
          tester.getBottomRight(find.text('Créer')).dy,
          lessThanOrEqualTo(494),
        );
        expect(find.text('Créer').hitTestable(), findsOneWidget);
        await tester.tap(find.byTooltip('Masquer le clavier'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller!
              .text,
          'Karim',
        );
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText).first)
              .focusNode
              .hasFocus,
          isFalse,
        );
        expect(await repo.getPlayers(), isEmpty);
      },
    );

    testWidgets(
      'refocuses name field after creating player with createAnother button',
      (tester) async {
        final repo = _MockPlayersRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedServiceProvider.overrideWithValue(LocalTestSharedService()),
              playersRepositoryProvider.overrideWithValue(repo),
              activeTeamIdProvider.overrideWith(
                () => ActiveTeamIdNotifier(initialValue: 'team_1'),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const Scaffold(body: NewPlayerBottomSheet()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final nameEditable = tester.widget<EditableText>(
          find.descendant(
            of: find.byType(TextField).first,
            matching: find.byType(EditableText),
          ),
        );
        // Autofocus is active on name field
        expect(nameEditable.focusNode.hasFocus, isTrue);

        // Enter player name and nickname
        await tester.enterText(find.byType(TextField).first, 'Antoine');
        await tester.enterText(find.byType(TextField).at(1), 'Anto');
        await tester.pumpAndSettle();

        // Tap create another button (+)
        await tester.tap(find.byIcon(Remix.add_line));
        await tester.pumpAndSettle();

        // Verify player added
        final players = await repo.getPlayers();
        expect(players.length, 1);
        expect(players.first.name, 'Antoine');

        // Verify name field is cleared and focus is returned
        expect(nameEditable.focusNode.hasFocus, isTrue);
      },
    );

    testWidgets(
      'shows inline error message when attempting to add duplicate player name',
      (tester) async {
        final repo = _MockPlayersRepository();
        await repo.createPlayer(name: 'Lucas', teamId: 'team_1');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              playersRepositoryProvider.overrideWithValue(repo),
              activeTeamIdProvider.overrideWith(
                () => ActiveTeamIdNotifier(initialValue: 'team_1'),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const Scaffold(body: NewPlayerBottomSheet()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).first, 'lucas');
        await tester.pumpAndSettle();

        await tester.tap(find.text('Créer'));
        await tester.pumpAndSettle();

        expect(find.textContaining('existe déjà'), findsOneWidget);
      },
    );
  });
}
