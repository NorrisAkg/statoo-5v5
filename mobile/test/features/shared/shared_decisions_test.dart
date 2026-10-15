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
  Future<void> open(WidgetTester tester, _Shared service, String action) async {
    tester.view.physicalSize = const Size(600, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const SharedGroupScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(action));
    await tester.tap(find.text(action));
    await tester.pumpAndSettle();
  }

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
      expect(find.textContaining('Lions'), findsWidgets);
      expect(find.textContaining('Victoires A : 3'), findsWidgets);
      expect(find.textContaining('Victoires A : 4'), findsWidgets);
    },
  );
}
