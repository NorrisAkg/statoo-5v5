import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/settings/data/backup_service.dart';
import 'package:statoo/features/settings/domain/backup_payload.dart';
import 'package:statoo/features/team/application/team_provider.dart';
import 'package:statoo/features/team/domain/team_info.dart';
import 'package:statoo/features/team/presentation/create_team_screen.dart';

class _Backup extends BackupService {
  _Backup() : super(AppDatabase.instance);
  int picks = 0;
  int restores = 0;
  Future<BackupPayload?>? selection;
  @override
  Future<BackupPayload?> pickBackupFile() async {
    picks++;
    return selection ??
        Future.value(
          BackupPayload(
            version: 2,
            exportedAt: DateTime(2026),
            team: const {'id': 'incoming', 'name': 'Importé'},
            players: const [],
            sessions: const [],
            participations: const [],
          ),
        );
  }

  @override
  Future<RestoreResult> restoreBackup(
    BackupPayload payload, {
    required bool merge,
    String? targetTeamId,
    Map<String, String>? expectedGroups,
  }) async {
    restores++;
    throw StateError('Échec de restauration simulé');
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  Future<void> open(WidgetTester tester, _Backup backup) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backupServiceProvider.overrideWithValue(backup),
          hasTeamProvider.overrideWith(
            () => HasTeamNotifier(initialValue: true),
          ),
          allTeamsProvider.overrideWith(
            (ref) async => [
              TeamInfo(id: 'a', name: 'Alpha', createdAt: DateTime(2026)),
              TeamInfo(id: 'b', name: 'Bêta', createdAt: DateTime(2026)),
            ],
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const CreateTeamScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text("J'ai déjà une sauvegarde Statoo"));
    await tester.tap(find.text("J'ai déjà une sauvegarde Statoo"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  testWidgets(
    'UX01-01/02 replacement needs informed confirmation and cancel never restores',
    (tester) async {
      final backup = _Backup();
      await open(tester, backup);
      expect(backup.restores, 0);
      expect(find.textContaining('tous les groupes'), findsWidgets);
      expect(find.textContaining('Alpha'), findsWidgets);
      expect(find.textContaining('Bêta'), findsWidgets);
      expect(find.textContaining('Importé'), findsWidgets);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(backup.restores, 0);
      expect(find.byType(CreateTeamScreen), findsOneWidget);
    },
  );
  testWidgets(
    'UX01-06/10 explicit confirmation restores once and failure remains actionable',
    (tester) async {
      final backup = _Backup();
      await open(tester, backup);
      expect(backup.restores, 0);
      await tester.tap(find.text('Remplacer toutes les données'));
      await tester.pumpAndSettle();
      expect(backup.restores, 1);
      expect(
        find.textContaining('Échec de restauration simulé'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('UX01-04 picker cancellation does not restore', (tester) async {
    final backup = _Backup()..selection = Future.value();
    await open(tester, backup);
    expect(backup.restores, 0);
    expect(find.byType(AlertDialog), findsNothing);
  });
  testWidgets('UX01-09 picker is single flight', (tester) async {
    final pending = Completer<BackupPayload?>();
    final backup = _Backup()..selection = pending.future;
    await open(tester, backup);
    await tester.tap(find.text("J'ai déjà une sauvegarde Statoo"));
    await tester.pump();
    expect(backup.picks, 1);
    pending.complete();
    await tester.pumpAndSettle();
  });
}
