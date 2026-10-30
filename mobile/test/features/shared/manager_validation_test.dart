import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/core/data/shared_http_error.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/players/application/players_provider.dart';
import 'package:statoo/features/players/domain/player.dart';
import 'package:statoo/features/shared/application/shared_providers.dart';
import 'package:statoo/features/shared/data/shared_service.dart';
import 'package:statoo/features/shared/presentation/shared_group_screen.dart';

class Players extends PlayersNotifier {
  @override
  Future<List<Player>> build() async => [
    Player(
      id: 'a',
      teamId: 'g',
      name: 'Alice',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  ];
}

class Service extends SharedService {
  Service() : super(AppDatabase.instance) {
    identity = {
      'group_id': 'g',
      'account': {
        'id': 'me',
        'roles': ['ADMIN'],
      },
    };
    snapshot = {
      'name': 'Test',
      'documents': <String, dynamic>{},
      'accounts': <dynamic>[],
    };
  }
  int calls = 0;
  Exception? failure;
  bool syncFailure = false;
  Completer<void>? pending;
  Map<String, dynamic>? sent;
  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, [
    Object? body,
  ]) async {
    calls++;
    sent = body as Map<String, dynamic>?;
    if (pending != null) await pending!.future;
    if (failure != null) throw failure!;
    return {'id': 'created'};
  }

  @override
  Future<void> synchronize() async {
    if (syncFailure) throw const SharedNetworkException();
  }
}

Future<void> open(
  WidgetTester t,
  Service s, {
  double width = 800,
  double scale = 1,
  bool dark = false,
}) async {
  t.view.physicalSize = Size(width, 1800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(s.dispose);
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        sharedServiceProvider.overrideWithValue(s),
        playersListProvider.overrideWith(Players.new),
      ],
      child: MaterialApp(
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            viewInsets: const EdgeInsets.only(bottom: 250),
          ),
          child: child!,
        ),
        home: const SharedGroupScreen(),
      ),
    ),
  );
  await t.pumpAndSettle();
  await t.tap(find.text('Ajouter un gestionnaire'));
  await t.pumpAndSettle();
  await t.tap(find.byType(DropdownButtonFormField<String>));
  await t.pumpAndSettle();
  await t.tap(find.text('Alice').last);
  await t.pumpAndSettle();
  await t.tap(find.text('Président').first);
  await t.pumpAndSettle();
}

Future<void> fill(
  WidgetTester t, {
  String name = 'alice',
  String password = '12345678',
}) async {
  await t.enterText(find.byType(TextField).at(0), name);
  expect(find.byType(TextField), findsOneWidget);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final password in ['', '1234567']) {
    testWidgets(
      'V01 invalid credentials stay in dialog password length ${password.length}',
      (t) async {
        final s = Service();
        await open(t, s);
        await fill(t, name: '   ', password: password);
        await t.tap(find.text('Créer').last);
        await t.pumpAndSettle();
        expect(s.calls, 0);
        expect(find.text('Saisissez un identifiant.'), findsOneWidget);
        expect(
          find.text(
            'Un mot de passe de 8 caractères sera généré automatiquement.',
          ),
          findsOneWidget,
        );
        expect(find.text('Compte individuel et rôles'), findsOneWidget);
      },
    );
  }
  for (final failure in [
    const SharedApiException(422, [
      {'input': 'SECRET', 'msg': 'string_too_short'},
    ]),
    const SharedApiException(409, 'username taken'),
    const SharedNetworkException(),
    const SharedApiException(500, 'Trace SECRET'),
  ]) {
    testWidgets('V03 failure stays editable ${failure.runtimeType} $failure', (
      t,
    ) async {
      final s = Service()..failure = failure;
      await open(t, s);
      await fill(t);
      await t.tap(find.text('Créer').last);
      await t.pumpAndSettle();
      expect(find.text('Compte individuel et rôles'), findsOneWidget);
      expect(
        t.widget<TextField>(find.byType(TextField).first).controller!.text,
        'alice',
      );
      expect(find.textContaining('SECRET'), findsNothing);
      expect(s.calls, 1);
      s.failure = null;
      await t.tap(find.text('Créer').last);
      await t.pumpAndSettle();
      expect(s.calls, 2);
      expect(find.text('Compte individuel et rôles'), findsNothing);
    });
  }
  testWidgets('V02/04 valid credentials sent once while pending', (t) async {
    final s = Service()..pending = Completer<void>();
    await open(t, s);
    await fill(t, name: ' alice ');
    await t.tap(find.text('Créer').last);
    await t.pump();
    expect(find.text('Compte individuel et rôles'), findsOneWidget);
    expect(
      t
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Créer'))
          .onPressed,
      isNull,
    );
    expect(s.calls, 1);
    s.pending!.complete();
    await t.pumpAndSettle();
    expect(s.sent!['username'], 'alice');
    expect(s.sent!['password'], matches(r'^[A-Za-z0-9]{8}$'));
    expect(s.calls, 1);
    expect(find.text('Compte individuel et rôles'), findsNothing);
  });
  testWidgets('V04 sync failure after success cannot resubmit creation', (
    t,
  ) async {
    final s = Service()..syncFailure = true;
    await open(t, s);
    await fill(t);
    await t.tap(find.text('Créer').last);
    await t.pumpAndSettle();
    expect(s.calls, 1);
    expect(find.text('Compte individuel et rôles'), findsNothing);
    expect(find.textContaining('Compte créé'), findsOneWidget);
  });
  for (final width in [320.0, 393.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets('V06 dialog $width $scale $dark', (t) async {
          final s = Service();
          await open(t, s, width: width, scale: scale, dark: dark);
          expect(t.takeException(), isNull);
          expect(find.text('Annuler'), findsOneWidget);
        });
      }
    }
  }
  testWidgets('V05 cancel sends nothing', (t) async {
    final s = Service();
    await open(t, s);
    await t.tap(find.text('Annuler'));
    await t.pumpAndSettle();
    expect(s.calls, 0);
  });
}
