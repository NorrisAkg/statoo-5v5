import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/settings/presentation/settings_screen.dart';
import 'package:statoo/features/shared/application/shared_providers.dart';
import 'package:statoo/features/shared/data/shared_service.dart';
import 'package:statoo/features/team/application/team_provider.dart';

class _FakeActiveTeamId extends ActiveTeamIdNotifier {
  _FakeActiveTeamId(this._id);
  final String _id;
  @override
  String? build() => _id;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('SettingsScreen affiche Activer le groupe partagé quand non publié', (tester) async {
    final service = SharedService(AppDatabase.instance);
    addTearDown(service.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeTeamIdProvider.overrideWith(() => _FakeActiveTeamId('local-team-1')),
          sharedServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Activer le groupe partagé'), findsOneWidget);
  });

  testWidgets('SettingsScreen affiche Gérer le groupe partagé quand déjà publié', (tester) async {
    final service = SharedService(AppDatabase.instance)
      ..identity = {
        'group_id': '#13120987',
        'account': {'id': 'a1', 'username': 'admin', 'shared': false, 'roles': ['ADMIN']},
      }
      ..token = 'tok';
    addTearDown(service.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeTeamIdProvider.overrideWith(() => _FakeActiveTeamId('#13120987')),
          sharedServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Gérer le groupe partagé'), findsOneWidget);
  });
}
