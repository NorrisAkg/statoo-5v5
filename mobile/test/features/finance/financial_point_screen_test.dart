import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/core/theme/app_theme.dart';
import 'package:statoo/core/widgets/app_card.dart';
import 'package:statoo/core/widgets/primary_button.dart';
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
  _Players([this.name = 'Alice']);
  final String name;
  @override
  Future<List<Player>> build() async => [
    Player(
      id: 'a',
      teamId: 'g',
      name: name,
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
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('fr_FR');
  });
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(393, 852);
    view.devicePixelRatio = 1;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  });
  Future<void> open(
    WidgetTester tester,
    _Finance repo, {
    bool dark = false,
    double scale = 1,
    String name = 'Alice',
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeTeamIdProvider.overrideWith(
            () => ActiveTeamIdNotifier(initialValue: 'g'),
          ),
          financeRepositoryProvider.overrideWithValue(repo),
          sharedServiceProvider.overrideWithValue(repo.shared),
          playersListProvider.overrideWith(() => _Players(name)),
          sessionDetailProvider('s')
              .overrideWith((ref) async => Session(id: 's', playedAt: _date)),
          sessionParticipantsProvider('s').overrideWith((ref) async => []),
          financialDefaultsProvider.overrideWith(
            (ref) async => const FinancialDefaults(),
          ),
        ],
        child: MaterialApp(
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
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
  testWidgets('PF01/02 shared cards, button and visible amount labels', (
    tester,
  ) async {
    await open(tester, _Finance());
    expect(find.byType(AppCard), findsWidgets);
    expect(find.byType(PrimaryButton), findsOneWidget);
    expect(find.text('Cotisation reçue'), findsOneWidget);
    expect(find.text('Pénalité reçue'), findsOneWidget);
    expect(find.textContaining('14 oct.'), findsOneWidget);
  });
  testWidgets('PF06 search empty state and amount retained', (tester) async {
    await open(tester, _Finance());
    await tester.enterText(amount(), '150');
    await tester.enterText(find.byType(TextField).first, 'Introuvable');
    await tester.pumpAndSettle();
    expect(find.text('Aucun membre trouvé'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(amount()).controller!.text, '150');
  });
  testWidgets('PF08 explicit empty expenses', (tester) async {
    await open(tester, _Finance());
    await tester.tap(find.text('Dépenses').first);
    await tester.pumpAndSettle();
    expect(find.text('Aucune dépense'), findsOneWidget);
    expect(find.text('Ajouter une dépense'), findsOneWidget);
  });
  testWidgets('PF09 read only keeps values without mutation actions', (
    tester,
  ) async {
    final repo = _Finance();
    repo.shared.protectedGroups.add('g');
    await open(tester, repo);
    expect(find.text('Consultation uniquement'), findsOneWidget);
    expect(find.text('Valider le point'), findsNothing);
    expect(find.text('Modifier'), findsNothing);
    for (final field
        in tester.widgetList<TextField>(find.byType(TextField)).skip(1)) {
      expect(field.enabled, false);
    }
  });
  testWidgets('PF05 keyboard resizes form and tab preserves input', (
    tester,
  ) async {
    await open(tester, _Finance());
    final scaffold = tester.widget<Scaffold>(
      find.descendant(
        of: find.byType(FinancialPointScreen),
        matching: find.byType(Scaffold),
      ),
    );
    expect(scaffold.resizeToAvoidBottomInset, isNot(false));
    await tester.enterText(amount(), '150');
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dépenses').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Encaissements'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(amount()).controller!.text, '150');
  });
  testWidgets('PF08 add and remove expense changes saved totals', (
    tester,
  ) async {
    final repo = _Finance();
    await open(tester, repo);
    await tester.tap(find.text('Dépenses').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajouter une dépense'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Terrain');
    await tester.enterText(find.byType(TextField).at(1), '80');
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();
    expect(find.text('Terrain'), findsOneWidget);
    await tester.tap(find.byTooltip('Retirer la dépense'));
    await tester.pumpAndSettle();
    expect(find.text('Aucune dépense'), findsOneWidget);
    expect(repo.saves, 0);
  });
  testWidgets('PF10 cancelled point disables member money fields', (
    tester,
  ) async {
    await open(tester, _Finance());
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    for (final field
        in tester.widgetList<TextField>(find.byType(TextField)).skip(1)) {
      expect(field.enabled, false);
    }
    expect(find.text('Autre encaissement / don'), findsNothing);
  });
  testWidgets('PF13/14 cancel confirmation and failed save preserve input', (
    tester,
  ) async {
    final repo = _Finance()..fail = true;
    await open(tester, repo);
    await tester.enterText(amount(), '150');
    await tester.tap(find.text('Valider le point'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revenir'));
    await tester.pumpAndSettle();
    expect(repo.saves, 0);
    expect(tester.widget<TextField>(amount()).controller!.text, '150');
    await tester.tap(find.text('Valider le point'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
    expect(repo.saves, 0);
    expect(find.textContaining('Écriture refusée'), findsOneWidget);
    expect(tester.widget<TextField>(amount()).controller!.text, '150');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Continuer la saisie'), findsOneWidget);
  });
  testWidgets('PF11 changing rate keeps existing contribution', (tester) async {
    await open(tester, _Finance());
    await tester.enterText(amount(), '150');
    await tester.ensureVisible(find.text('Modifier'));
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '200');
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
    expect(find.text('Cotisation : 200 F'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Cotisation reçue'),
      150,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(tester.widget<TextField>(amount()).controller!.text, '150');
  });
  testWidgets('PF17 large text tabs and compact fixed footer', (tester) async {
    await open(tester, _Finance(), scale: 2);
    expect(tester.widget<TabBar>(find.byType(TabBar)).isScrollable, true);
    final footer = find
        .ancestor(
          of: find.byType(PrimaryButton),
          matching: find.byType(SafeArea),
        )
        .first;
    expect(tester.getSize(footer).height, lessThan(180));
    await tester.scrollUntilVisible(
      find.text('Cotisation reçue'),
      150,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.text('Cotisation reçue')).bottom,
      lessThan(tester.getRect(footer).top),
    );
  });
  for (final width in [320.0, 393.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets('PF03/04 $width $scale dark=$dark', (tester) async {
          tester.view.physicalSize = Size(width, 852);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final repo = _Finance();
          repo.point = FinancialPoint(
            playedAt: _date,
            rate: 100,
            lines: const [
              FinancialLine(memberId: 'a', contribution: 999999999999),
            ],
          );
          await open(
            tester,
            repo,
            dark: dark,
            scale: scale,
            name: 'Alice au nom de famille particulièrement long',
          );
          await tester.scrollUntilVisible(
            find.text('Cotisation reçue'),
            180,
            scrollable: find
                .descendant(
                  of: find.byType(ListView).first,
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pumpAndSettle();
          expect(find.text('Cotisation reçue'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.text('Dépenses').first);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Dépenses').first);
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text('Aucune dépense'),
            180,
            scrollable: find
                .descendant(
                  of: find.byType(ListView).first,
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pumpAndSettle();
          expect(find.text('Aucune dépense'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
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
