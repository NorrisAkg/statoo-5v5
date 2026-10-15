import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/features/finance/application/finance_providers.dart';
import 'package:statoo/features/finance/data/finance_repository.dart';
import 'package:statoo/features/finance/domain/financial_defaults.dart';
import 'package:statoo/features/finance/domain/financial_point.dart';
import 'package:statoo/features/finance/presentation/financial_point_screen.dart';
import 'package:statoo/features/players/application/players_provider.dart';
import 'package:statoo/features/players/domain/player.dart';
import 'package:statoo/features/sessions/application/sessions_provider.dart';
import 'package:statoo/features/sessions/domain/session.dart';
import 'package:statoo/features/shared/application/shared_providers.dart';
import 'package:statoo/features/shared/data/shared_service.dart';
import 'package:statoo/features/team/application/team_provider.dart';

final _date = DateTime(2026, 10, 14);

class _Players extends PlayersNotifier {
  @override
  Future<List<Player>> build() async => [
    Player(
      id: 'a',
      teamId: 'g',
      name: 'Alice',
      createdAt: _date,
      updatedAt: _date,
    ),
  ];
}

class _Finance extends FinanceRepository {
  _Finance() : super(AppDatabase.instance, SharedService(AppDatabase.instance));
  int saves = 0;
  bool fail = false;
  FinancialPoint point = FinancialPoint(
    playedAt: _date,
    rate: 100,
    lines: const [FinancialLine(memberId: 'a')],
  );
  @override
  Future<FinancialPoint?> getPoint(String group, String session) async => point;
  @override
  Future<bool> isValidated(String group, String session) async => saves > 0;
  @override
  Future<FinancialPoint> prepare(
    String group,
    String session,
    DateTime date,
  ) async => point;
  @override
  Future<void> savePoint(
    String group,
    String session,
    FinancialPoint value, {
    String reason = '',
  }) async {
    if (fail) throw StateError('Écriture refusée');
    saves++;
    point = value;
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  Future<void> open(WidgetTester tester, _Finance repo) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeTeamIdProvider.overrideWith(
            () => ActiveTeamIdNotifier(initialValue: 'g'),
          ),
          financeRepositoryProvider.overrideWithValue(repo),
          sharedServiceProvider.overrideWithValue(repo.shared),
          playersListProvider.overrideWith(_Players.new),
          sessionDetailProvider('s')
              .overrideWith((ref) async => Session(id: 's', playedAt: _date)),
          sessionParticipantsProvider('s').overrideWith((ref) async => []),
          financialDefaultsProvider.overrideWith(
            (ref) async => const FinancialDefaults(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const FinancialPointScreen(sessionId: 's'),
                  ),
                ),
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
  }

  Finder amount() => find.byType(TextField).at(1);
  testWidgets('UX02-01 clean point exits without confirmation', (tester) async {
    await open(tester, _Finance());
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Ouvrir'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });
  testWidgets('UX02-02/04 dirty point stays with values on continue', (
    tester,
  ) async {
    final repo = _Finance();
    await open(tester, repo);
    await tester.enterText(amount(), '150');
    await tester.pump();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Abandonner les modifications'), findsOneWidget);
    await tester.tap(find.text('Continuer la saisie'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(amount()).controller!.text, '150');
    expect(repo.saves, 0);
  });
  testWidgets('UX02-03/05 system back asks before explicit discard', (
    tester,
  ) async {
    final repo = _Finance();
    await open(tester, repo);
    await tester.enterText(amount(), '150');
    await tester.pump();
    final context = tester.element(find.byType(FinancialPointScreen));
    await Navigator.of(context).maybePop();
    await tester.pumpAndSettle();
    expect(find.text('Abandonner les modifications'), findsOneWidget);
    await tester.tap(find.text('Abandonner les modifications'));
    await tester.pumpAndSettle();
    expect(find.text('Ouvrir'), findsOneWidget);
    expect(repo.saves, 0);
  });
  testWidgets('UX02-09 reverting values clears dirty state', (tester) async {
    await open(tester, _Finance());
    await tester.enterText(amount(), '150');
    await tester.enterText(amount(), '0');
    await tester.pump();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Ouvrir'), findsOneWidget);
  });
  testWidgets('UX02-14 success establishes a new clean baseline', (
    tester,
  ) async {
    final repo = _Finance();
    await open(tester, repo);
    await tester.enterText(amount(), '150');
    await tester.tap(find.text('Valider le point'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
    expect(repo.saves, 1);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Ouvrir'), findsOneWidget);
  });
}
