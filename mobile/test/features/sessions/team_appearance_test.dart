import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/sessions/application/sessions_provider.dart';
import 'package:statoo/features/sessions/data/sessions_repository.dart';
import 'package:statoo/features/sessions/domain/participation.dart';
import 'package:statoo/features/sessions/domain/session.dart';
import 'package:statoo/features/sessions/domain/team_appearance.dart';
import 'package:statoo/features/sessions/presentation/team_appearance_editor.dart';
import 'package:statoo/features/settings/data/backup_service.dart';
import 'package:statoo/features/team/application/team_provider.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  test('optional fields use distinct defaults and compare trimmed case-insensitive names', () {
    expect(teamAppearanceError(SessionType.classic2, {}, {}), isNull);
    expect(effectiveTeamName(Team.a, {'A': '  '}), 'Équipe A');
    expect(
      teamAppearanceError(SessionType.classic2, {
        'A': ' Toto ',
        'B': 'toto',
      }, {}),
      isNotNull,
    );
    expect(
      teamAppearanceError(SessionType.classic2, {'A': 'équipe b'}, {}),
      isNotNull,
    );
    expect(
      teamAppearanceError(SessionType.classic2, {}, {
        'A': defaultTeamColor(Team.b),
      }),
      isNotNull,
    );
    expect(
      teamAppearanceError(SessionType.tournament3, {}, {
        'C': defaultTeamColor(Team.a),
      }),
      isNotNull,
    );
    expect(
      teamAppearanceError(SessionType.classic2, {}, {
        'C': defaultTeamColor(Team.a),
      }),
      isNull,
    );
  });

  test('v7 appearance migration preserves existing rows and supplies nullable defaults', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await db.execute('CREATE TABLE sessions (id TEXT PRIMARY KEY, notes TEXT)');
    await db.insert('sessions', {'id': 'old', 'notes': 'keep'});
    await AppDatabase.forTesting(db).migrateTeamAppearance(db);
    final row = (await db.query('sessions')).single;
    expect(row['notes'], 'keep');
    expect(row.containsKey('team_names'), isTrue);
    expect(row['team_names'], isNull);
    expect(row['team_colors'], isNull);
  });

  test('controller blocks duplicates before saving and SQLite backup keeps custom teams', () async {
    SharedPreferences.setMockInitialValues({});
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    addTearDown(db.close);
    final appDb = AppDatabase.forTesting(db);
    await appDb.initSchemaForTest(db);
    await db.insert('teams', {
      'id': 't',
      'name': 'Group',
      'created_at': DateTime.now().toIso8601String(),
    });
    final repo = SqliteSessionsRepository(appDb);
    final container = ProviderContainer(
      overrides: [
        sessionsRepositoryProvider.overrideWithValue(repo),
        activeTeamIdProvider.overrideWith(
          () => ActiveTeamIdNotifier(initialValue: 't'),
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(sessionsControllerProvider);
    Future<String> create(Map<String, String> names, Map<String, int> colors) =>
        controller.createDraftSession(
          playedAt: DateTime(2026, 10, 12),
          isRanked: true,
          allowUnevenTeams: false,
          playerTeamAssignments: {},
          teamNames: names,
          teamColors: colors,
          startImmediately: false,
        );
    await expectLater(
      create({'A': ' Toto ', 'B': 'toto'}, {}),
      throwsArgumentError,
    );
    await expectLater(
      create({}, {'A': defaultTeamColor(Team.b)}),
      throwsArgumentError,
    );
    expect(await db.query('sessions'), isEmpty);
    final id = await create(
      {'A': ' Lions ', 'B': 'Tigres'},
      {'A': sessionTeamPalette['Violet']!},
    );
    var saved = (await repo.getSession(id, teamId: 't'))!;
    expect(saved.teamName(Team.a), 'Lions');
    expect(saved.teamColors['A'], sessionTeamPalette['Violet']);
    final backup = await BackupService(appDb).createBackupPayload();
    await BackupService(appDb).restoreBackup(backup, merge: false);
    saved = (await repo.getSession(id, teamId: 't'))!;
    expect(saved.teamName(Team.b), 'Tigres');
    expect(saved.teamColors['A'], sessionTeamPalette['Violet']);
    final json = saved.toJson();
    expect(Session.fromJson(json).teamNames, saved.teamNames);
  });

  testWidgets('palette selection, duplicate feedback, name focus and reset', (
    tester,
  ) async {
    final names = <String, String>{};
    final colors = <String, int>{};
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, update) => TeamAppearanceEditor(
                type: SessionType.classic2,
                names: names,
                colors: colors,
                onNameChanged: (team, name) =>
                    update(() => names[teamKey(team)] = name),
                onColorChanged: (team, color) =>
                    update(() => colors[teamKey(team)] = color),
                onReset: (team) => update(() {
                  names.remove(teamKey(team));
                  colors.remove(teamKey(team));
                }),
              ),
            ),
          ),
        ),
      ),
    );
    final a = find.byKey(const ValueKey('team-name-A'));
    await tester.enterText(a, 'Toto');
    await tester.pump();
    expect(tester.widget<TextFormField>(a).controller!.text, 'Toto');
    await tester.enterText(find.byKey(const ValueKey('team-name-B')), ' toto ');
    await tester.pump();
    expect(
      find.text('Chaque équipe doit avoir un nom différent.'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Réinitialiser Équipe B'));
    await tester.pump();
    expect(find.byKey(const ValueKey('team-appearance-error')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('team-color-A-Orange')));
    await tester.pump();
    expect(
      find.text('Chaque équipe doit avoir une couleur différente.'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Réinitialiser Équipe A'));
    await tester.pump();
    expect(find.byKey(const ValueKey('team-appearance-error')), findsNothing);
    expect(tester.widget<TextFormField>(a).controller!.text, '');
  });
}
