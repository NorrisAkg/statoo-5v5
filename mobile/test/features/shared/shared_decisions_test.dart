import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/shared/application/shared_providers.dart';
import 'package:statoo/features/shared/data/shared_service.dart';
import 'package:statoo/features/shared/presentation/shared_group_screen.dart';

class _Shared extends SharedService {
  _Shared() : super(AppDatabase.instance) {
    identity = {
      'group_id': 'g',
      'expires_at': '2099-01-01T00:00:00Z',
      'account': {
        'id': 'pdt',
        'roles': ['PDT'],
      },
    };
    snapshot = {
      'name': 'Groupe démo',
      'documents': <String, dynamic>{},
      'accounts': [
        {'id': 'tr', 'username': 'Trésorier'},
        {'id': 'sg', 'username': 'Secrétaire'},
      ],
      'members': [
        {'id': 'a', 'name': 'Alice'},
        {'id': 'b', 'name': 'Benoît'},
      ],
    };
  }
  final calls = <({String path, Object? body})>[];
  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, [
    Object? body,
  ]) async {
    calls.add((path: path, body: body));
    return {};
  }

  @override
  Future<void> synchronize() async {}
}

Map<String, dynamic> _point(String label, int amount) => {
  'played_at': '2026-10-14T18:00:00',
  'rate': 100,
  'cancelled': false,
  'lines': [
    {
      'member_id': 'a',
      'contribution': 100,
      'penalty_paid': 10,
      'penalty_due': 20,
      'reason': 'Retard',
    },
  ],
  'expenses': [
    {'id': 'e', 'label': label, 'amount': amount},
  ],
  'donations': [
    {'id': 'd', 'label': 'Soutien', 'amount': 40},
  ],
};

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('fr_FR');
  });
  Future<void> open(
    WidgetTester tester,
    _Shared service,
    String action, {
    Size size = const Size(600, 1500),
    double scale = 1,
    bool dark = false,
    double keyboard = 0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              viewInsets: EdgeInsets.only(bottom: keyboard),
            ),
            child: child!,
          ),
          home: const SharedGroupScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(action),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(action));
    await tester.pumpAndSettle();
  }

  _Shared conflict({bool identical = false}) {
    final current = _point('Terrain', 30);
    final candidate = _point(
      identical ? 'Terrain' : 'Eau',
      identical ? 30 : 80,
    );
    for (final point in [current, candidate]) {
      point['lines'] = [
        for (var i = 0; i < 6; i++)
          {
            'member_id': '$i',
            'contribution': 100,
            'penalty_paid': 0,
            'penalty_due': 0,
            'reason': 'Identique',
          },
      ];
    }
    return _Shared()
      ..snapshot!['documents'] = {
        'finance:ref': {
          'domain': 'finance',
          'occurrence_id': 'ref',
          'revision': 2,
          'owner': 'tr',
          'payload': current,
          'candidates': [
            {'id': 'candidate', 'actor': 'sg', 'payload': candidate},
          ],
        },
      };
  }

  testWidgets(
    'D02-01/02 six identical members do not hide expense differences',
    (tester) async {
      await open(
        tester,
        conflict(),
        'Conflit financier',
        size: const Size(393, 852),
      );
      expect(find.textContaining('Terrain').hitTestable(), findsOneWidget);
      expect(find.textContaining('Eau').hitTestable(), findsOneWidget);
      expect(find.textContaining('Détails inchangés'), findsNWidgets(2));
      expect(find.textContaining('Identique'), findsNothing);
      await tester.tap(find.textContaining('Détails inchangés').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Identique'), findsWidgets);
      expect(find.textContaining('Soutien'), findsWidgets);
    },
  );

  for (final spaces in ['', '   ']) {
    testWidgets(
      'D03-01/02/03 reason error is visible and announced ($spaces)',
      (tester) async {
        final service = conflict();
        final semantics = tester.ensureSemantics();
        try {
          await open(
            tester,
            service,
            'Conflit financier',
            size: const Size(393, 852),
          );
          if (spaces.isNotEmpty) {
            await tester.ensureVisible(find.byType(TextField));
            await tester.enterText(find.byType(TextField), spaces);
          }
          await tester.tap(find.text('Retenir cette version'));
          await tester.pumpAndSettle();
          expect(
            find.text('Indiquez le motif de décision.').hitTestable(),
            findsOneWidget,
          );
          expect(
            find.byWidgetPredicate(
              (w) => w is Semantics && w.properties.liveRegion == true,
            ),
            findsWidgets,
          );
          expect(service.calls, isEmpty);
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  testWidgets('D02-04 identical versions explicitly say no difference', (
    tester,
  ) async {
    await open(tester, conflict(identical: true), 'Conflit financier');
    expect(
      find.text('Aucune différence avec les autres versions.'),
      findsNWidgets(2),
    );
  });

  for (final dark in [false, true]) {
    testWidgets(
      'D02-08/D03-05 compact dialog remains usable enlarged dark=$dark',
      (tester) async {
        final service = conflict();
        await open(
          tester,
          service,
          'Conflit financier',
          size: const Size(320, 852),
          scale: 2,
          dark: dark,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Retenir cette version'));
        await tester.pumpAndSettle();
        expect(
          find.text('Indiquez le motif de décision.').hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'D02-05/06 D03-04 selected candidate survives details and invalid reason',
    (tester) async {
      final service = conflict();
      await open(tester, service, 'Conflit financier');
      await tester.tap(find.text('Version concurrente'));
      await tester.tap(find.textContaining('Détails inchangés').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.textContaining('Détails inchangés').first,
      );
      await tester.tap(find.textContaining('Détails inchangés').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retenir cette version'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '  Vérifié  ');
      await tester.tap(find.text('Retenir cette version'));
      await tester.pumpAndSettle();
      expect(service.calls.single.body, {
        'revision': 2,
        'candidate_id': 'candidate',
        'reason': 'Vérifié',
      });
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('D03-05 keyboard leaves reason and error visible', (
    tester,
  ) async {
    final service = conflict();
    await open(
      tester,
      service,
      'Conflit financier',
      size: const Size(393, 852),
      keyboard: 300,
    );
    await tester.tap(find.text('Retenir cette version'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField).hitTestable(), findsOneWidget);
    expect(
      find.text('Indiquez le motif de décision.').hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(service.calls, isEmpty);
  });

  testWidgets('UX05-01/02/04 review shows balances and cancel never approves', (
    tester,
  ) async {
    final service = _Shared()
      ..snapshot!['opening_proposal'] = {
        'cash': 1000,
        'start_date': '2026-10-01',
        'members': {
          'a': {'contribution_balance': 200, 'penalty_debt': 30},
          'b': {'contribution_balance': -100, 'penalty_debt': 0},
        },
      };
    service.snapshot!['leaders'] = [
      {'id': 'tr', 'username': 'Trésorier'},
    ];
    service.snapshot!['audit'] = [
      {
        'action': 'opening_proposed',
        'actor': 'tr',
        'at': '2026-10-14T12:00:00Z',
      },
    ];
    await open(tester, service, 'Approuver les soldes initiaux');
    expect(service.calls, isEmpty);
    expect(find.textContaining('1 000'), findsWidgets);
    expect(find.textContaining('Alice'), findsWidgets);
    expect(find.textContaining('avance'), findsWidgets);
    expect(find.textContaining('dette'), findsWidgets);
    expect(find.textContaining('Proposé par : Trésorier'), findsOneWidget);
    await tester.tap(find.text('Revenir'));
    await tester.pumpAndSettle();
    expect(service.calls, isEmpty);
  });
  testWidgets('UX05-05 explicit approval sends exact reviewed proposal', (
    tester,
  ) async {
    final proposal = {
      'cash': 1000,
      'start_date': '2026-10-01',
      'members': <String, dynamic>{},
    };
    final service = _Shared()..snapshot!['opening_proposal'] = proposal;
    await open(tester, service, 'Approuver les soldes initiaux');
    expect(service.calls, isEmpty);
    await tester.tap(find.text('Confirmer les soldes'));
    await tester.pumpAndSettle();
    expect(service.calls.single.path, '/groups/g/opening/approve');
    expect(service.calls.single.body, {'proposal': proposal});
  });
  testWidgets(
    'UX04-01/03/04 versions expose expenses, donations, penalties and authors',
    (tester) async {
      final service = _Shared();
      service.snapshot!['documents'] = {
        'finance:ref': {
          'domain': 'finance',
          'occurrence_id': 'ref',
          'revision': 2,
          'owner': 'tr',
          'updated_at': '2026-10-14T19:00:00Z',
          'payload': _point('Terrain', 30),
          'candidates': [
            {
              'id': 'candidate',
              'actor': 'sg',
              'at': '2026-10-14T20:00:00Z',
              'reason': 'Correction',
              'payload': _point('Eau', 80),
            },
          ],
        },
      };
      await open(tester, service, 'Conflit financier');
      expect(service.calls, isEmpty);
      expect(find.textContaining('Terrain'), findsWidgets);
      expect(find.textContaining('Eau'), findsWidgets);
      await tester.tap(find.textContaining('Détails inchangés').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Soutien'), findsWidgets);
      expect(find.textContaining('Retard'), findsWidgets);
      expect(find.textContaining('Trésorier'), findsWidgets);
      expect(find.textContaining('Secrétaire'), findsWidgets);
    },
  );
  testWidgets(
    'UX04-13 empty decision reason retains dialog and selected version',
    (tester) async {
      final service = _Shared();
      service.snapshot!['documents'] = {
        'finance:ref': {
          'domain': 'finance',
          'occurrence_id': 'ref',
          'revision': 2,
          'owner': 'tr',
          'payload': _point('Terrain', 30),
          'candidates': [
            {'id': 'candidate', 'actor': 'sg', 'payload': _point('Eau', 80)},
          ],
        },
      };
      await open(tester, service, 'Conflit financier');
      await tester.tap(find.text('Retenir cette version'));
      await tester.pumpAndSettle();
      expect(find.text('Choisir la version à retenir'), findsOneWidget);
      expect(find.textContaining('Indiquez'), findsWidgets);
      expect(service.calls, isEmpty);
    },
  );
  testWidgets(
    'UX04-07 actual wire tournament names and victories are comparable',
    (tester) async {
      final service = _Shared();
      Map<String, dynamic> sport(int wins) => {
        'session': {
          'played_at': '2026-10-14T18:00:00',
          'session_type': 'TOURNAMENT_3',
          'status': 'CLOSED',
          'is_ranked': 1,
          'wins_a': wins,
          'wins_b': 1,
          'wins_c': 0,
          'result': 'A',
          'team_names': '{"A":"Lions","B":"Aigles","C":"Tigres"}',
        },
        'participations': <dynamic>[],
      };
      service.snapshot!['documents'] = {
        'sport:ref': {
          'domain': 'sport',
          'occurrence_id': 'ref',
          'revision': 2,
          'owner': 'tr',
          'payload': sport(3),
          'candidates': [
            {'id': 'candidate', 'actor': 'sg', 'payload': sport(4)},
          ],
        },
      };
      await open(tester, service, 'Conflit sportif');
      expect(find.textContaining('Victoires A : 3'), findsWidgets);
      expect(find.textContaining('Victoires A : 4'), findsWidgets);
      await tester.tap(find.textContaining('Détails inchangés').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Lions'), findsWidgets);
    },
  );
}
